import 'package:flutter/material.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:flutter_mvp/services/gemma_models.dart';
import 'package:flutter_mvp/services/gemma_runtime.dart';
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
  String _selectedTier = 'gpu';
  String _status = 'Not loaded.';
  int? _downloadProgress;

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
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    await _settings.setTierGpuUrl(_gpuUrl.text.trim());
    await _settings.setTierGpuSha256(_gpuSha.text.trim().isEmpty ? null : _gpuSha.text.trim());
    await _settings.setTierCpuUrl(_cpuUrl.text.trim());
    await _settings.setTierCpuSha256(_cpuSha.text.trim().isEmpty ? null : _cpuSha.text.trim());
    await _settings.setSelectedTier(_selectedTier);
    await _settings.setUseMockExtractor(_useMock);
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
    });

    final gpu = await _tierConfig('gpu');
    final cpu = await _tierConfig('cpu');

    Stream<int> progressStream;
    if (_selectedTier == 'gpu') {
      progressStream = _runtime.prepareAuto(
        gpu: gpu,
        cpu: cpu,
        onFallback: (msg) => setState(() => _status = msg),
      );
    } else {
      progressStream = _runtime.prepareTier(cpu);
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
      setState(() => _status = 'Gemma load failed: $e');
    }
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Setup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('MediaPipe Gemma runtime (flutter_gemma). Download the “AI brain” (.task) once, then run fully on-device.'),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _useMock,
          onChanged: (v) async {
            setState(() => _useMock = v);
            await _savePrefs();
          },
          title: const Text('Use mock extractor (Gemma disabled)'),
          subtitle: const Text('Turn off to download/load Gemma task bundle.'),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'gpu', label: Text('GPU (default)')),
            ButtonSegment(value: 'cpu', label: Text('CPU (fallback only)')),
          ],
          selected: {_selectedTier},
          onSelectionChanged: (s) async {
            setState(() => _selectedTier = s.first);
            await _savePrefs();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gpuUrl,
          decoration: const InputDecoration(
            labelText: 'Tier A (GPU) .task URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gpuSha,
          decoration: const InputDecoration(
            labelText: 'Tier A SHA256 (optional, recommended)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cpuUrl,
          decoration: const InputDecoration(
            labelText: 'Tier B (CPU fallback) .task URL',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cpuSha,
          decoration: const InputDecoration(
            labelText: 'Tier B SHA256 (optional, recommended)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _downloadAndLoad,
          icon: const Icon(Icons.download),
          label: Text(_useMock ? 'Save' : 'Download + Load'),
        ),
        const SizedBox(height: 12),
        if (_downloadProgress != null) Text('Download: $_downloadProgress%'),
        Text(_status),
      ],
    );
  }
}

