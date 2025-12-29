package com.example.flutter_mvp

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val deviceChannel = "edge_ai/device"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
      when (call.method) {
        "getFreeDiskBytes" -> {
          try {
            val stat = StatFs(filesDir.absolutePath)
            result.success(stat.availableBytes)
          } catch (e: Throwable) {
            result.error("disk_error", e.message ?: e.toString(), null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
