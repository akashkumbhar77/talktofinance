import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepo {
  static const _kTierGpuUrl = 'gemma_tier_gpu_url';
  static const _kTierGpuSha = 'gemma_tier_gpu_sha256';
  static const _kTierCpuUrl = 'gemma_tier_cpu_url';
  static const _kTierCpuSha = 'gemma_tier_cpu_sha256';
  static const _kSelectedTier = 'gemma_selected_tier'; // "gpu" | "cpu"
  static const _kUseMock = 'use_mock_extractor'; // kept for compatibility; now means "use mock instead of Gemma"

  Future<String> getTierGpuUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTierGpuUrl) ??
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';
  }

  Future<String?> getTierGpuSha256() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTierGpuSha);
  }

  Future<String> getTierCpuUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTierCpuUrl) ??
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task';
  }

  Future<String?> getTierCpuSha256() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTierCpuSha);
  }

  Future<void> setTierGpuUrl(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTierGpuUrl, v);
  }

  Future<void> setTierGpuSha256(String? v) async {
    final p = await SharedPreferences.getInstance();
    if (v == null || v.trim().isEmpty) {
      await p.remove(_kTierGpuSha);
    } else {
      await p.setString(_kTierGpuSha, v.trim());
    }
  }

  Future<void> setTierCpuUrl(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTierCpuUrl, v);
  }

  Future<void> setTierCpuSha256(String? v) async {
    final p = await SharedPreferences.getInstance();
    if (v == null || v.trim().isEmpty) {
      await p.remove(_kTierCpuSha);
    } else {
      await p.setString(_kTierCpuSha, v.trim());
    }
  }

  Future<String> getSelectedTier() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kSelectedTier) ?? 'gpu';
  }

  Future<void> setSelectedTier(String tier) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSelectedTier, tier);
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

