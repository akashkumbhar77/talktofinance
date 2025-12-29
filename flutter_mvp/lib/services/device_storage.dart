import 'dart:io';

import 'package:flutter/services.dart';

class DeviceStorage {
  static const MethodChannel _ch = MethodChannel('edge_ai/device');

  /// Best-effort free disk bytes for the app’s internal storage volume.
  /// Returns null if unavailable.
  static Future<int?> tryGetFreeDiskBytes() async {
    if (!Platform.isAndroid) return null;
    try {
      final v = await _ch.invokeMethod<int>('getFreeDiskBytes');
      return v;
    } catch (_) {
      return null;
    }
  }
}

