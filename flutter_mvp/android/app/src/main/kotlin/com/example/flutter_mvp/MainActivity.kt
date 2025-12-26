package com.example.flutter_mvp

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
  private val channelName = "edge_ai/mlc"
  private val eventName = "edge_ai/mlc_stream"

  private val streamSinkRef = AtomicReference<EventChannel.EventSink?>(null)
  private val mainHandler = Handler(Looper.getMainLooper())

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
          // This MVP keeps MLC optional. When you wire real MLC, load the model here.
          result.success(null)
        }

        "extractExpense" -> {
          val input = (call.argument<String>("input") ?: "").trim()
          val json = mockExtractExpense(input)
          emitStreaming(json)
          result.success(json)
        }

        "extractStatement" -> {
          val input = (call.argument<String>("input") ?: "").trim()
          val json = mockExtractStatement(input)
          emitStreaming(json)
          result.success(json)
        }

        else -> result.notImplemented()
      }
    }
  }

  private fun emitStreaming(text: String) {
    val sink = streamSinkRef.get() ?: return
    val chunkSize = 24
    var i = 0
    while (i < text.length) {
      val end = minOf(i + chunkSize, text.length)
      val chunk = text.substring(i, end)
      val delayMs = ((i / chunkSize) * 20L).coerceAtMost(800L)
      mainHandler.postDelayed({ streamSinkRef.get()?.success(chunk) }, delayMs)
      i = end
    }
  }

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
