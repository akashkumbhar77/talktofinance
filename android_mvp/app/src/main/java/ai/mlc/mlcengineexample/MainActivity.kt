package ai.mlc.mlcengineexample

import ai.mlc.mlcengineexample.ui.theme.MLCEngineExampleTheme
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import java.io.File


class MainActivity : ComponentActivity() {
    @ExperimentalMaterial3Api
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            MLCEngineExampleTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    ExpenseMvpApp()
                }
            }
        }
    }
}

private enum class TopRoute(val label: String, val route: String) {
    Setup("Setup", "setup"),
    Extract("Extract", "extract"),
    History("History", "history")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ExpenseMvpApp(appViewModel: AppViewModel = viewModel()) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar {
                TopRoute.entries.forEach { top ->
                    val selected = currentRoute == top.route
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(top.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        label = { Text(top.label) },
                        icon = {
                            when (top) {
                                TopRoute.Setup -> Icon(Icons.Filled.Settings, contentDescription = null)
                                TopRoute.Extract -> Icon(Icons.Filled.SmartToy, contentDescription = null)
                                TopRoute.History -> Icon(Icons.Filled.History, contentDescription = null)
                            }
                        }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = TopRoute.Setup.route,
            modifier = Modifier.padding(padding)
        ) {
            composable(TopRoute.Setup.route) { SetupScreen(appViewModel) }
            composable(TopRoute.Extract.route) { ExtractScreen(appViewModel) }
            composable(TopRoute.History.route) { HistoryScreen(appViewModel) }
        }
    }
}

@Composable
private fun SetupScreen(vm: AppViewModel) {
    val context = LocalContext.current
    var modelId by remember { mutableStateOf("phi-2-q4f16_1-MLC") }
    var modelLib by remember { mutableStateOf("") }
    val engineState = vm.engineState
    val appExternalDir = context.getExternalFilesDir("") ?: context.filesDir
    val baseDir = File(appExternalDir, modelId)

    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("On-device Model Setup", style = MaterialTheme.typography.titleLarge)
        Text(
            "Put the packaged model folder under:\n${baseDir.absolutePath}",
            style = MaterialTheme.typography.bodySmall,
            fontFamily = FontFamily.Monospace
        )

        OutlinedTextField(
            value = modelId,
            onValueChange = { modelId = it },
            label = { Text("Model folder name (model_id)") },
            singleLine = true,
            modifier = Modifier.widthIn(max = 520.dp)
        )

        OutlinedTextField(
            value = modelLib,
            onValueChange = { modelLib = it },
            label = { Text("model_lib (from mlc-chat-config.json)") },
            singleLine = true,
            modifier = Modifier.widthIn(max = 520.dp)
        )

        RowButtons(onLoad = { vm.loadModel(modelId.trim(), modelLib.trim()) })

        LaunchedEffect(modelId) {
            val detected = vm.tryReadModelLib(File(appExternalDir, modelId.trim()))
            if (!detected.isNullOrBlank()) {
                modelLib = detected
            }
        }

        when (engineState) {
            EngineUiState.Unloaded -> Text("Engine: not loaded")
            EngineUiState.Loading -> Text("Engine: loading…")
            is EngineUiState.Ready -> Text("Engine: ready (${engineState.modelId})")
            is EngineUiState.Error -> Text("Engine error: ${engineState.message}", color = MaterialTheme.colorScheme.error)
        }

        vm.extractionState.lastError?.let { err ->
            Text(err, color = MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
private fun RowButtons(onLoad: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Button(onClick = onLoad) { Text("Load + Warmup") }
    }
}

@Composable
private fun ExtractScreen(vm: AppViewModel) {
    val state = vm.extractionState
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Extract transaction → JSON → Save locally", style = MaterialTheme.typography.titleLarge)

        OutlinedTextField(
            value = state.input,
            onValueChange = vm::setExtractionInput,
            label = { Text("Paste SMS / receipt OCR text / typed note") },
            minLines = 4,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 140.dp)
        )

        androidx.compose.foundation.layout.Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(onClick = { vm.extractAndSave() }, enabled = !state.isRunning) {
                Text(if (state.isRunning) "Running…" else "Extract & Save")
            }
            Button(onClick = { vm.clearAllTransactions() }, enabled = !state.isRunning) {
                Text("Clear history")
            }
        }

        state.lastPerfLabel?.let { Text(it, style = MaterialTheme.typography.bodySmall) }

        if (state.streamingText.isNotBlank()) {
            Text("Model output (streaming):", style = MaterialTheme.typography.titleSmall)
            Text(
                state.streamingText,
                fontFamily = FontFamily.Monospace,
                style = MaterialTheme.typography.bodySmall
            )
        }

        state.parsedJson?.let { json ->
            Text("Saved JSON:", style = MaterialTheme.typography.titleSmall)
            Text(json, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
        }

        state.lastError?.let { err ->
            Text(err, color = MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
private fun HistoryScreen(vm: AppViewModel) {
    val items by vm.transactions.collectAsStateWithLifecycle()
    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Local transactions", style = MaterialTheme.typography.titleLarge)
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp)) {
            items(items, key = { it.id }) { tx ->
                Column(modifier = Modifier.padding(vertical = 8.dp)) {
                    Text(tx.title, style = MaterialTheme.typography.titleMedium)
                    if (tx.subtitle.isNotBlank()) {
                        Text(tx.subtitle, style = MaterialTheme.typography.bodySmall)
                    }
                    Text(
                        tx.extractedJson,
                        style = MaterialTheme.typography.bodySmall,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }
        }
    }
}
