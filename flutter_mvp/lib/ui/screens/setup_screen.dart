import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mvp/services/mlc_client.dart';
import 'package:flutter_mvp/services/settings_repo.dart';
import 'package:path_provider/path_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _settings = SettingsRepo();
  final _mlc = MlcClient();

  final _modelId = TextEditingController();
  final _modelLib = TextEditingController();
  bool _useMock = true;
  String _status = 'Not loaded';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _modelId.text = await _settings.getModelId();
    _modelLib.text = await _settings.getModelLib();
    _useMock = await _settings.getUseMockExtractor();
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    await _settings.setModelId(_modelId.text.trim());
    await _settings.setModelLib(_modelLib.text.trim());
    await _settings.setUseMockExtractor(_useMock);
  }

  Future<void> _loadModel() async {
    await _savePrefs();
    if (_useMock) {
      setState(() => _status = 'Mock extractor enabled (no model loaded).');
      return;
    }
    try {
      setState(() => _status = 'Loading model…');
      await _mlc.loadModel(modelId: _modelId.text.trim(), modelLib: _modelLib.text.trim());
      setState(() => _status = 'Model loaded + warmed up.');
    } on PlatformException catch (e) {
      setState(() => _status = 'Load failed: ${e.message ?? e.code}');
    } catch (e) {
      setState(() => _status = 'Load failed: $e');
    }
  }

  Future<String> _expectedModelPath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        return '${dir.path}/${_modelId.text.trim()}';
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/${_modelId.text.trim()}';
  }

  @override
  void dispose() {
    _modelId.dispose();
    _modelLib.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Setup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Android-first Flutter MVP. Model download/packaging is next; for now you can run with the mock extractor or wire MLC on Android via the channel.'),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _useMock,
          onChanged: (v) async {
            setState(() => _useMock = v);
            await _savePrefs();
          },
          title: const Text('Use mock extractor (builds without MLC artifacts)'),
          subtitle: const Text('Turn off once you’ve wired MLC runtime + model.'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _modelId,
          decoration: const InputDecoration(
            labelText: 'model_id folder name',
            hintText: 'e.g. phi-2-q4f16_1-MLC',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelLib,
          decoration: const InputDecoration(
            labelText: 'model_lib',
            hintText: 'read from mlc-chat-config.json',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<String>(
          future: _expectedModelPath(),
          builder: (context, snap) {
            final path = snap.data ?? '…';
            return SelectableText(
              'Expected model folder path (device):\n$path',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loadModel,
          child: const Text('Load (and warm up)'),
        ),
        const SizedBox(height: 12),
        Text(_status),
      ],
    );
  }
}

