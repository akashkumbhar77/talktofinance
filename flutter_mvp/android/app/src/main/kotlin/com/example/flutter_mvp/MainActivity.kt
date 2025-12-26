package com.example.flutter_mvp

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import ai.mlc.mlcllm.MLCEngine
import ai.mlc.mlcllm.OpenAIProtocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
  private val channelName = "edge_ai/mlc"
  private val eventName = "edge_ai/mlc_stream"

  private val streamSinkRef = AtomicReference<EventChannel.EventSink?>(null)
  private val mainHandler = Handler(Looper.getMainLooper())

  private val engineRef = AtomicReference<MLCEngine?>(null)
  private val scope = CoroutineScope(Dispatchers.Default + Job())

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventName).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          streamSinkRef.set(events)
        }

        override fun onCancel(arguments: Any?) {
          streamSinkRef.set(null)
        }
      }
    )

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "loadModel" -> {
          try {
            val modelId = (call.argument<String>("modelId") ?: "").trim()
            val modelLib = (call.argument<String>("modelLib") ?: "").trim()
            if (modelId.isEmpty() || modelLib.isEmpty()) {
              result.error("bad_args", "modelId and modelLib are required", null)
              return@setMethodCallHandler
            }

            val modelDir = getExternalFilesDir(null)
            if (modelDir == null) {
              result.error("no_storage", "external files dir unavailable", null)
              return@setMethodCallHandler
            }
            val modelPath = java.io.File(modelDir, modelId).absolutePath

            val engine = engineRef.get() ?: MLCEngine().also { engineRef.set(it) }
            engine.unload()
            engine.reload(modelPath, modelLib)

            // Warmup: a tiny request so first-token latency is better.
            scope.launch {
              try {
                val channel = engine.chat.completions.create(
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
                for (_ in channel) {
                  // drain
                }
              } catch (_: Throwable) {
                // ignore warmup errors; model load is what matters
              }
            }

            result.success(null)
          } catch (e: UnsatisfiedLinkError) {
            result.error("mlc_link_error", "Native MLC runtime not packaged: ${e.message}", null)
          } catch (e: Throwable) {
            result.error("mlc_load_error", e.message ?: e.toString(), null)
          }
        }

        "extractExpense" -> {
          val input = (call.argument<String>("input") ?: "").trim()
          val engine = engineRef.get()
          if (engine == null) {
            // Fallback to mock if model not loaded.
            val json = mockExtractExpense(input)
            emitStreaming(json)
            result.success(json)
            return@setMethodCallHandler
          }
          scope.launch {
            try {
              val sys = """
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
                    content = sys
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

              val sb = StringBuilder()
              for (resp in channel) {
                if (resp.usage != null) break
                if (resp.choices.isNotEmpty()) {
                  val delta = resp.choices[0].delta.content?.asText().orEmpty()
                  if (delta.isNotEmpty()) {
                    sb.append(delta)
                    emitStreaming(delta)
                  }
                }
              }
              mainHandler.post { result.success(sb.toString()) }
            } catch (e: Throwable) {
              mainHandler.post { result.error("mlc_extract_error", e.message ?: e.toString(), null) }
            }
          }
        }

        "extractStatement" -> {
          val input = (call.argument<String>("input") ?: "").trim()
          val engine = engineRef.get()
          if (engine == null) {
            val json = mockExtractStatement(input)
            emitStreaming(json)
            result.success(json)
            return@setMethodCallHandler
          }
          scope.launch {
            try {
              val sys = """
You extract bank statement transactions from text.

Return ONLY a JSON array (no markdown, no extra text). Each array element MUST match:
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
- Extract as many transactions as you can.
- If you are unsure, set fields to null and confidence low.
              """.trimIndent()

              val channel = engine.chat.completions.create(
                messages = listOf(
                  OpenAIProtocol.ChatCompletionMessage(
                    role = OpenAIProtocol.ChatCompletionRole.system,
                    content = sys
                  ),
                  OpenAIProtocol.ChatCompletionMessage(
                    role = OpenAIProtocol.ChatCompletionRole.user,
                    content = input
                  )
                ),
                temperature = 0.0f,
                max_tokens = 512,
                stream_options = OpenAIProtocol.StreamOptions(include_usage = true)
              )

              val sb = StringBuilder()
              for (resp in channel) {
                if (resp.usage != null) break
                if (resp.choices.isNotEmpty()) {
                  val delta = resp.choices[0].delta.content?.asText().orEmpty()
                  if (delta.isNotEmpty()) {
                    sb.append(delta)
                    emitStreaming(delta)
                  }
                }
              }
              mainHandler.post { result.success(sb.toString()) }
            } catch (e: Throwable) {
              mainHandler.post { result.error("mlc_extract_error", e.message ?: e.toString(), null) }
            }
          }
        }

        else -> result.notImplemented()
      }
    }
  }

  private fun emitStreaming(text: String) {
    val sink = streamSinkRef.get() ?: return
    mainHandler.post { sink.success(text) }
  }

  // Keeping mock methods for quick fallback / demo without MLC artifacts.
  private fun mockExtractExpense(input: String): String {
    val amountMatch = Regex("(\\d+(?:\\.\\d+)?)").find(input)
    val amount = amountMatch?.groups?.get(1)?.value?.toDoubleOrNull()
    val currency = when {
      input.contains("₹") || input.lowercase().contains("inr") || input.lowercase().contains("rs") -> "INR"
      input.contains("$") -> "USD"
      else -> JSONObject.NULL
    }

    val obj = JSONObject()
    obj.put("amount", amount ?: JSONObject.NULL)
    obj.put("currency", currency)
    obj.put("merchant", JSONObject.NULL)
    obj.put("category", JSONObject.NULL)
    obj.put("date", JSONObject.NULL)
    obj.put("notes", JSONObject.NULL)
    obj.put("confidence", if (amount == null) 0.2 else 0.4)
    return obj.toString(2)
  }

  private fun mockExtractStatement(text: String): String {
    val lines = text.split(Regex("\\r?\\n")).map { it.trim() }.filter { it.isNotEmpty() }
    val arr = JSONArray()
    for (line in lines) {
      val amountMatch = Regex("(\\d+(?:\\.\\d+)?)").find(line) ?: continue
      val amount = amountMatch.groups[1]?.value?.toDoubleOrNull() ?: continue
      val obj = JSONObject()
      obj.put("amount", amount)
      obj.put(
        "currency",
        when {
          line.contains("₹") || line.lowercase().contains("inr") || line.lowercase().contains("rs") -> "INR"
          line.contains("$") -> "USD"
          else -> JSONObject.NULL
        }
      )
      obj.put("merchant", JSONObject.NULL)
      obj.put("category", JSONObject.NULL)
      obj.put("date", JSONObject.NULL)
      obj.put("notes", line)
      obj.put("confidence", 0.25)
      arr.put(obj)
    }
    return arr.toString(2)
  }
}
