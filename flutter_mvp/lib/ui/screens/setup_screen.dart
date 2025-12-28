import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:flutter_mvp/services/gemma_models.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
import 'package:flutter_mvp/services/download_cancel_token.dart';
import 'package:flutter_mvp/services/settings_repo.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _settings = SettingsRepo();
  final _runtime = GemmaRuntime.instance;

  final _gpuUrl = TextEditingController();
  final _gpuSha = TextEditingController();
  final _cpuUrl = TextEditingController();
  final _cpuSha = TextEditingController();

  bool _useMock = true; // means "do not use Gemma" for now
  bool _wifiOnly = true;
  String _selectedTier = 'gpu';
  String _status = 'Not loaded.';
  int? _downloadProgress;
  bool _isDownloading = false;
  DownloadCancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _gpuUrl.text = await _settings.getTierGpuUrl();
    _gpuSha.text = (await _settings.getTierGpuSha256()) ?? '';
    _cpuUrl.text = await _settings.getTierCpuUrl();
    _cpuSha.text = (await _settings.getTierCpuSha256()) ?? '';
    _selectedTier = await _settings.getSelectedTier();
    _useMock = await _settings.getUseMockExtractor();
    _wifiOnly = await _settings.getWifiOnlyDownloads();
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    await _settings.setTierGpuUrl(_gpuUrl.text.trim());
    await _settings.setTierGpuSha256(_gpuSha.text.trim().isEmpty ? null : _gpuSha.text.trim());
    await _settings.setTierCpuUrl(_cpuUrl.text.trim());
    await _settings.setTierCpuSha256(_cpuSha.text.trim().isEmpty ? null : _cpuSha.text.trim());
    await _settings.setSelectedTier(_selectedTier);
    await _settings.setUseMockExtractor(_useMock);
    await _settings.setWifiOnlyDownloads(_wifiOnly);
  }

  Future<GemmaTierConfig> _tierConfig(String which) async {
    if (which == 'cpu') {
      return GemmaTierConfig(
        tier: GemmaTier.cpu,
        backend: PreferredBackend.cpu,
        url: _cpuUrl.text.trim(),
        sha256Hex: _cpuSha.text.trim().isEmpty ? null : _cpuSha.text.trim(),
      );
    }
    return GemmaTierConfig(
      tier: GemmaTier.gpu,
      backend: PreferredBackend.gpu,
      url: _gpuUrl.text.trim(),
      sha256Hex: _gpuSha.text.trim().isEmpty ? null : _gpuSha.text.trim(),
    );
  }

  Future<void> _downloadAndLoad() async {
    await _savePrefs();
    if (_useMock) {
      setState(() => _status = 'Mock extractor enabled (Gemma disabled).');
      return;
    }
    setState(() {
      _status = 'Preparing Gemma…';
      _downloadProgress = null;
      _isDownloading = true;
    });

    final gpu = await _tierConfig('gpu');
    final cpu = await _tierConfig('cpu');

    if (_wifiOnly) {
      final connectivity = await Connectivity().checkConnectivity();
      final isWifi = connectivity.contains(ConnectivityResult.wifi);
      if (!isWifi) {
        setState(() {
          _isDownloading = false;
          _status = 'Wi‑Fi only is enabled. Connect to Wi‑Fi to download the model.';
        });
        return;
      }
    }

    final cancelToken = _cancelToken = DownloadCancelToken();

    Stream<int> progressStream;
    if (_selectedTier == 'gpu') {
      progressStream = _runtime.prepareAuto(
        gpu: gpu,
        cpu: cpu,
        onFallback: (msg) => setState(() => _status = msg),
        cancelToken: cancelToken,
        onRetry: (attempt, error, nextDelay) {
          if (!mounted) return;
          setState(() => _status = 'Retry $attempt due to $error. Next attempt in ${nextDelay.inSeconds}s…');
        },
      );
    } else {
      progressStream = _runtime.prepareTier(
        cpu,
        cancelToken: cancelToken,
        onRetry: (attempt, error, nextDelay) {
          if (!mounted) return;
          setState(() => _status = 'Retry $attempt due to $error. Next attempt in ${nextDelay.inSeconds}s…');
        },
      );
    }

    try {
      await for (final p in progressStream) {
        setState(() => _downloadProgress = p);
      }
      final active = _runtime.activeTier;
      if (active != null) {
        _selectedTier = active == GemmaTier.cpu ? 'cpu' : 'gpu';
        await _settings.setSelectedTier(_selectedTier);
      }
      setState(() => _status = 'Gemma ready ($active).');
    } catch (e) {
      final msg = e is DownloadCancelled ? 'Download cancelled.' : 'Gemma load failed: $e';
      setState(() => _status = msg);
    } finally {
      _cancelToken = null;
      setState(() => _isDownloading = false);
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  @override
  void dispose() {
    _gpuUrl.dispose();
    _gpuSha.dispose();
    _cpuUrl.dispose();
    _cpuSha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'On-device model',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Download the Gemma “.task” bundle once, then run fully offline.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _useMock,
                    onChanged: (v) async {
                      setState(() => _useMock = v);
                      await _savePrefs();
                    },
                    title: const Text('Use mock extractor'),
                    subtitle: const Text('Keeps the app usable without downloading the model.'),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _wifiOnly,
                    onChanged: (v) async {
                      setState(() => _wifiOnly = v);
                      await _savePrefs();
                    },
                    title: const Text('Wi‑Fi only downloads'),
                    subtitle: const Text('Recommended for large model downloads.'),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preference',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'gpu', label: Text('GPU')),
                      ButtonSegment(value: 'cpu', label: Text('CPU')),
                    ],
                    selected: {_selectedTier},
                    onSelectionChanged: (s) async {
                      setState(() => _selectedTier = s.first);
                      await _savePrefs();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Download sources',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _gpuUrl,
                    decoration: const InputDecoration(labelText: 'Tier A (GPU) .task URL'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gpuSha,
                    decoration: const InputDecoration(labelText: 'Tier A SHA-256 (optional)'),
                  ),
                  const Divider(),
                  TextField(
                    controller: _cpuUrl,
                    decoration: const InputDecoration(labelText: 'Tier B (CPU) .task URL'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cpuSha,
                    decoration: const InputDecoration(labelText: 'Tier B SHA-256 (optional)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadAndLoad,
                  icon: Icon(_useMock ? Icons.save : Icons.download),
                  label: Text(_useMock ? 'Save settings' : 'Download & load'),
                ),
              ),
              const SizedBox(width: 12),
              if (_isDownloading)
                IconButton.filledTonal(
                  onPressed: _cancelDownload,
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_downloadProgress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: _downloadProgress! / 100.0),
            ),
            const SizedBox(height: 8),
            Text('Download: $_downloadProgress%', style: Theme.of(context).textTheme.bodySmall),
          ],
          Card(
            color: cs.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

