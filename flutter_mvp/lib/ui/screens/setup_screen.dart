import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/features/setup/setup_cubit.dart';
import 'package:flutter_mvp/features/setup/setup_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _gpuUrl = TextEditingController();
  final _gpuSha = TextEditingController();
  final _cpuUrl = TextEditingController();
  final _cpuSha = TextEditingController();

  bool _syncedControllers = false;

  @override
  void initState() {
    super.initState();
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
    final cubit = context.read<SetupCubit>();

    return BlocConsumer<SetupCubit, SetupState>(
      listenWhen: (prev, next) => prev.prefsLoaded != next.prefsLoaded || prev.gpuUrl != next.gpuUrl || prev.cpuUrl != next.cpuUrl,
      listener: (context, state) {
        if (state.prefsLoaded && !_syncedControllers) {
          _gpuUrl.text = state.gpuUrl;
          _gpuSha.text = state.gpuSha256;
          _cpuUrl.text = state.cpuUrl;
          _cpuSha.text = state.cpuSha256;
          _syncedControllers = true;
        }
      },
      builder: (context, state) {
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
                        value: state.wifiOnlyDownloads,
                        onChanged: cubit.setWifiOnlyDownloads,
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
                        selected: {state.selectedTier},
                        onSelectionChanged: (s) => cubit.setSelectedTier(s.first),
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
                        onChanged: cubit.setGpuUrl,
                        decoration: const InputDecoration(labelText: 'Tier A (GPU) .task URL'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _gpuSha,
                        onChanged: cubit.setGpuSha256,
                        decoration: const InputDecoration(labelText: 'Tier A SHA-256 (optional)'),
                      ),
                      const Divider(),
                      TextField(
                        controller: _cpuUrl,
                        onChanged: cubit.setCpuUrl,
                        decoration: const InputDecoration(labelText: 'Tier B (CPU) .task URL'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cpuSha,
                        onChanged: cubit.setCpuSha256,
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
                      onPressed: state.isDownloading ? null : cubit.downloadAndLoad,
                      icon: const Icon(Icons.download),
                      label: const Text('Download & load'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (state.isDownloading)
                    IconButton.filledTonal(
                      onPressed: cubit.cancelDownload,
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.downloadProgress != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: state.downloadProgress! / 100.0),
                ),
                const SizedBox(height: 8),
                Text('Download: ${state.downloadProgress}%', style: Theme.of(context).textTheme.bodySmall),
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
                      Expanded(child: Text(state.status)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

