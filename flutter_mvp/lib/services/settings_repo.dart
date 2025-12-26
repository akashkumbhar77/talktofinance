import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepo {
  static const _kModelId = 'model_id';
  static const _kModelLib = 'model_lib';
  static const _kUseMock = 'use_mock_extractor';

  Future<String> getModelId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kModelId) ?? 'phi-2-q4f16_1-MLC';
  }

  Future<String> getModelLib() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kModelLib) ?? '';
  }

  Future<void> setModelId(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kModelId, v);
  }

  Future<void> setModelLib(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kModelLib, v);
  }

  Future<bool> getUseMockExtractor() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kUseMock) ?? true;
  }

  Future<void> setUseMockExtractor(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUseMock, v);
  }
}

