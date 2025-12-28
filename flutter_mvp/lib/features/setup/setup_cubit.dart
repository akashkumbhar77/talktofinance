import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:flutter_mvp/features/setup/setup_state.dart';
import 'package:flutter_mvp/services/download_cancel_token.dart';
import 'package:flutter_mvp/services/gemma_models.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
import 'package:flutter_mvp/services/settings_repo.dart';

class SetupCubit extends Cubit<SetupState> {
  SetupCubit({
    required SettingsRepo settings,
    required GemmaRuntime runtime,
  })  : _settings = settings,
        _runtime = runtime,
        super(SetupState.initial());

  final SettingsRepo _settings;
  final GemmaRuntime _runtime;

  DownloadCancelToken? _cancelToken;

  Future<void> init() async {
    final gpuUrl = await _settings.getTierGpuUrl();
    final gpuSha = (await _settings.getTierGpuSha256()) ?? '';
    final cpuUrl = await _settings.getTierCpuUrl();
    final cpuSha = (await _settings.getTierCpuSha256()) ?? '';
    final selectedTier = await _settings.getSelectedTier();
    final useMock = await _settings.getUseMockExtractor();
    final wifiOnly = await _settings.getWifiOnlyDownloads();

    emit(
      state.copyWith(
        prefsLoaded: true,
        gpuUrl: gpuUrl,
        gpuSha256: gpuSha,
        cpuUrl: cpuUrl,
        cpuSha256: cpuSha,
        selectedTier: selectedTier,
        useMockExtractor: useMock,
        wifiOnlyDownloads: wifiOnly,
      ),
    );
  }

  Future<void> setUseMockExtractor(bool v) async {
    emit(state.copyWith(useMockExtractor: v));
    await _settings.setUseMockExtractor(v);
  }

  Future<void> setWifiOnlyDownloads(bool v) async {
    emit(state.copyWith(wifiOnlyDownloads: v));
    await _settings.setWifiOnlyDownloads(v);
  }

  Future<void> setSelectedTier(String v) async {
    emit(state.copyWith(selectedTier: v));
    await _settings.setSelectedTier(v);
  }

  Future<void> setGpuUrl(String v) async {
    emit(state.copyWith(gpuUrl: v));
    await _settings.setTierGpuUrl(v.trim());
  }

  Future<void> setGpuSha256(String v) async {
    emit(state.copyWith(gpuSha256: v));
    await _settings.setTierGpuSha256(v.trim().isEmpty ? null : v.trim());
  }

  Future<void> setCpuUrl(String v) async {
    emit(state.copyWith(cpuUrl: v));
    await _settings.setTierCpuUrl(v.trim());
  }

  Future<void> setCpuSha256(String v) async {
    emit(state.copyWith(cpuSha256: v));
    await _settings.setTierCpuSha256(v.trim().isEmpty ? null : v.trim());
  }

  GemmaTierConfig _tierConfig(String which) {
    if (which == 'cpu') {
      return GemmaTierConfig(
        tier: GemmaTier.cpu,
        backend: PreferredBackend.cpu,
        url: state.cpuUrl.trim(),
        sha256Hex: state.cpuSha256.trim().isEmpty ? null : state.cpuSha256.trim(),
      );
    }
    return GemmaTierConfig(
      tier: GemmaTier.gpu,
      backend: PreferredBackend.gpu,
      url: state.gpuUrl.trim(),
      sha256Hex: state.gpuSha256.trim().isEmpty ? null : state.gpuSha256.trim(),
    );
  }

  Future<void> downloadAndLoad() async {
    if (state.isDownloading) return;

    if (state.useMockExtractor) {
      emit(state.copyWith(status: 'Mock extractor enabled (Gemma disabled).'));
      return;
    }

    emit(state.copyWith(status: 'Preparing Gemma…', downloadProgress: null, isDownloading: true));

    if (state.wifiOnlyDownloads) {
      final connectivity = await Connectivity().checkConnectivity();
      final isWifi = connectivity.contains(ConnectivityResult.wifi);
      if (!isWifi) {
        emit(
          state.copyWith(
            isDownloading: false,
            status: 'Wi‑Fi only is enabled. Connect to Wi‑Fi to download the model.',
          ),
        );
        return;
      }
    }

    final token = _cancelToken = DownloadCancelToken();

    Stream<int> progressStream;
    final gpu = _tierConfig('gpu');
    final cpu = _tierConfig('cpu');

    if (state.selectedTier == 'gpu') {
      progressStream = _runtime.prepareAuto(
        gpu: gpu,
        cpu: cpu,
        cancelToken: token,
        onFallback: (msg) => emit(state.copyWith(status: msg)),
        onRetry: (attempt, error, nextDelay) {
          emit(state.copyWith(status: 'Retry $attempt due to $error. Next attempt in ${nextDelay.inSeconds}s…'));
        },
      );
    } else {
      progressStream = _runtime.prepareTier(
        cpu,
        cancelToken: token,
        onRetry: (attempt, error, nextDelay) {
          emit(state.copyWith(status: 'Retry $attempt due to $error. Next attempt in ${nextDelay.inSeconds}s…'));
        },
      );
    }

    try {
      await for (final p in progressStream) {
        emit(state.copyWith(downloadProgress: p));
      }
      final active = _runtime.activeTier;
      if (active != null) {
        final activeTierStr = active == GemmaTier.cpu ? 'cpu' : 'gpu';
        emit(state.copyWith(selectedTier: activeTierStr));
        await _settings.setSelectedTier(activeTierStr);
      }
      emit(state.copyWith(status: 'Gemma ready ($active).'));
    } catch (e) {
      final msg = e is DownloadCancelled ? 'Download cancelled.' : 'Gemma load failed: $e';
      emit(state.copyWith(status: msg));
    } finally {
      _cancelToken = null;
      emit(state.copyWith(isDownloading: false));
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }
}

