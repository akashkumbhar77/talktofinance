import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_cubit.dart';
import 'package:flutter_mvp/features/add_expense/add_expense_state.dart';

class VoiceAddScreen extends StatefulWidget {
  const VoiceAddScreen({super.key});

  @override
  State<VoiceAddScreen> createState() => _VoiceAddScreenState();
}

class _VoiceAddScreenState extends State<VoiceAddScreen> {
  final _text = TextEditingController();
  bool _synced = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<AddExpenseCubit>();

    return BlocConsumer<AddExpenseCubit, AddExpenseState>(
      listenWhen: (prev, next) => prev.text != next.text || prev.prefsLoaded != next.prefsLoaded,
      listener: (context, state) {
        final nextText = state.text;
        if (!_synced && state.prefsLoaded) {
          _text.text = nextText;
          _synced = true;
        } else if (_text.text != nextText) {
          _text.value = TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Add'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Describe an expense',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _text,
                        onChanged: cubit.setText,
                        minLines: 3,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'Example: Bought coffee for ₹250 at CCD',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: state.busy ? null : cubit.toggleMic,
                              icon: Icon(state.isListening ? Icons.stop : Icons.mic),
                              label: Text(state.isListening ? 'Stop' : 'Talk'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: state.busy ? null : cubit.pickReceiptImageAndOcr,
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Receipt OCR'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: state.busy ? null : cubit.extractAndSave,
                          child: Text(state.busy ? 'Extracting…' : 'Extract & Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: cs.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: cs.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.streaming.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Streaming', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SelectableText(state.streaming, style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.finalJson.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saved', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SelectableText(state.finalJson, style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}