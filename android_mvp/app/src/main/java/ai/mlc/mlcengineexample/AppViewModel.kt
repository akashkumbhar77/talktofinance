package ai.mlc.mlcengineexample

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import ai.mlc.mlcengineexample.data.AppDatabase
import ai.mlc.mlcengineexample.data.TransactionEntity
import ai.mlc.mlcengineexample.mlc.ExpenseExtraction
import ai.mlc.mlcengineexample.mlc.MlcChatConfig
import ai.mlc.mlcllm.MLCEngine
import ai.mlc.mlcllm.OpenAIProtocol
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

data class UiTransaction(
    val id: Long,
    val title: String,
    val subtitle: String,
    val extractedJson: String
)

sealed class EngineUiState {
    data object Unloaded : EngineUiState
    data object Loading : EngineUiState
    data class Ready(val modelId: String, val modelLib: String) : EngineUiState
    data class Error(val message: String) : EngineUiState
}

data class ExtractionUiState(
    val input: String = "",
    val streamingText: String = "",
    val parsed: ExpenseExtraction? = null,
    val parsedJson: String? = null,
    val lastError: String? = null,
    val isRunning: Boolean = false,
    val lastPerfLabel: String? = null
)

class AppViewModel(application: Application) : AndroidViewModel(application) {
    private val gson = Gson()
    private val db = AppDatabase.create(application)
    private val dao = db.transactions()

    // NOTE: MLCEngine spins background threads on init; keep single instance.
    private val engine: MLCEngine by lazy { MLCEngine() }

    var engineState by mutableStateOf<EngineUiState>(EngineUiState.Unloaded)
        private set

    var extractionState by mutableStateOf(ExtractionUiState())
        private set

    val transactions: StateFlow<List<UiTransaction>> =
        dao.observeAll()
            .map { list ->
                list.map { tx ->
                    val title = buildString {
                        if (tx.amount != null) append(tx.amount)
                        if (!tx.currency.isNullOrBlank()) append(" ${tx.currency}")
                        if (!tx.merchant.isNullOrBlank()) append(" · ${tx.merchant}")
                        if (isBlank()) append("Transaction #${tx.id}")
                    }
                    val subtitle = listOfNotNull(
                        tx.category?.takeIf { it.isNotBlank() },
                        tx.dateIso?.takeIf { it.isNotBlank() },
                        tx.confidence?.let { "conf=${"%.2f".format(it)}" }
                    ).joinToString(" · ")
                    UiTransaction(
                        id = tx.id,
                        title = title,
                        subtitle = subtitle,
                        extractedJson = tx.extractedJson
                    )
                }
            }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun setExtractionInput(text: String) {
        extractionState = extractionState.copy(input = text)
    }

    suspend fun tryReadModelLib(modelDir: File): String? = withContext(Dispatchers.IO) {
        val configFile = File(modelDir, "mlc-chat-config.json")
        if (!configFile.exists()) return@withContext null
        val cfg = gson.fromJson(configFile.readText(), MlcChatConfig::class.java)
        cfg.modelLib
    }

    fun loadModel(modelId: String, modelLib: String) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                engineState = EngineUiState.Loading
                val baseDir = getApplication<Application>().getExternalFilesDir("") ?: getApplication<Application>().filesDir
                val modelPath = File(baseDir, modelId).absolutePath
                engine.unload()
                engine.reload(modelPath, modelLib)
                // Warmup (tiny request) to reduce first-token latency.
                val ch = engine.chat.completions.create(
                    messages = listOf(
                        OpenAIProtocol.ChatCompletionMessage(
                            role = OpenAIProtocol.ChatCompletionRole.user,
                            content = "Hi"
                        )
                    ),
                    max_tokens = 1,
                    temperature = 0.0f,
                    stream_options = OpenAIProtocol.StreamOptions(include_usage = true)
                )
                for (_ in ch) {
                    // Drain.
                }
                engineState = EngineUiState.Ready(modelId = modelId, modelLib = modelLib)
            } catch (e: Exception) {
                engineState = EngineUiState.Error("Load model failed: ${e.localizedMessage}")
                extractionState = extractionState.copy(lastError = "Load model failed: ${e.localizedMessage}")
            }
        }
    }

    fun extractAndSave() {
        val input = extractionState.input.trim()
        if (input.isEmpty()) return

        extractionState = extractionState.copy(
            isRunning = true,
            streamingText = "",
            parsed = null,
            parsedJson = null,
            lastError = null,
            lastPerfLabel = null
        )

        viewModelScope.launch {
            try {
                val systemPrompt = """
You are an on-device finance assistant. Extract ONE expense transaction from the user's text.

Return ONLY valid JSON (no markdown, no extra text) matching this schema:
{
  "amount": number|null,
  "currency": string|null,
  "merchant": string|null,
  "category": string|null,
  "date": string|null,
  "notes": string|null,
  "confidence": number|null
}

Rules:
- If unknown, use null and set confidence low (<= 0.4).
- Use ISO date when possible (YYYY-MM-DD).
""".trimIndent()

                val channel = engine.chat.completions.create(
                    messages = listOf(
                        OpenAIProtocol.ChatCompletionMessage(
                            role = OpenAIProtocol.ChatCompletionRole.system,
                            content = systemPrompt
                        ),
                        OpenAIProtocol.ChatCompletionMessage(
                            role = OpenAIProtocol.ChatCompletionRole.user,
                            content = input
                        )
                    ),
                    temperature = 0.0f,
                    max_tokens = 256,
                    stream_options = OpenAIProtocol.StreamOptions(include_usage = true)
                )

                var finalText = ""
                var perf: String? = null
                for (response in channel) {
                    val usage = response.usage
                    if (usage != null) {
                        perf = usage.extra?.asTextLabel()
                    } else if (response.choices.isNotEmpty()) {
                        val delta = response.choices[0].delta.content?.asText().orEmpty()
                        finalText += delta
                        extractionState = extractionState.copy(streamingText = finalText)
                    }
                }

                val jsonOnly = finalText.extractJsonObject()
                val parsed = gson.fromJson(jsonOnly, ExpenseExtraction::class.java)

                withContext(Dispatchers.IO) {
                    dao.insert(
                        TransactionEntity(
                            createdAtEpochMs = System.currentTimeMillis(),
                            rawText = input,
                            extractedJson = jsonOnly,
                            amount = parsed.amount,
                            currency = parsed.currency,
                            merchant = parsed.merchant,
                            category = parsed.category,
                            dateIso = parsed.date,
                            notes = parsed.notes,
                            confidence = parsed.confidence
                        )
                    )
                }

                extractionState = extractionState.copy(
                    isRunning = false,
                    parsed = parsed,
                    parsedJson = jsonOnly,
                    lastPerfLabel = perf
                )
            } catch (e: Exception) {
                extractionState = extractionState.copy(
                    isRunning = false,
                    lastError = "Extraction failed: ${e.localizedMessage}"
                )
            }
        }
    }

    fun clearAllTransactions() {
        viewModelScope.launch(Dispatchers.IO) {
            dao.deleteAll()
        }
    }
}

private fun String.extractJsonObject(): String {
    val start = indexOf('{')
    val end = lastIndexOf('}')
    if (start == -1 || end == -1 || end <= start) {
        throw IllegalArgumentException("Model did not return a JSON object")
    }
    return substring(start, end + 1).trim()
}

