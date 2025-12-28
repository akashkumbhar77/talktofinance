import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_cubit.dart';
import 'package:flutter_mvp/features/import_pdf/import_pdf_state.dart';

class ImportPdfScreen extends StatefulWidget {
  const ImportPdfScreen({super.key});

  @override
  State<ImportPdfScreen> createState() => _ImportPdfScreenState();
}

class _ImportPdfScreenState extends State<ImportPdfScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<ImportPdfCubit>();

    return BlocBuilder<ImportPdfCubit, ImportPdfState>(
      builder: (context, state) {
        final preview = state.statementText.length > 900 ? '${state.statementText.substring(0, 900)}\n…' : state.statementText;
        final suggestOcr = (state.pdfPath != null) && state.statementText.trim().isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Import'),
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
                        'Bank statement (PDF)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(state.status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: state.busy ? null : cubit.pickPdf,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Pick PDF'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (state.isOcring)
                            IconButton.filledTonal(
                              onPressed: cubit.cancelOcr,
                              icon: const Icon(Icons.close),
                              tooltip: 'Cancel OCR',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: (state.busy || state.isOcring || !suggestOcr) ? null : cubit.runOcr,
                              icon: const Icon(Icons.document_scanner),
                              label: const Text('Run OCR'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: state.busy || state.statementText.trim().isEmpty ? null : cubit.extractTransactions,
                              child: Text(state.busy ? 'Working…' : 'Extract'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: state.busy || state.selected.isEmpty ? null : cubit.importSelected,
                          child: const Text('Import selected'),
                        ),
                      ),
                      if (state.isOcring && state.ocrPage != null && state.ocrPageCount != null) ...[
                        const SizedBox(height: 12),
                        Text('OCR: ${state.ocrPage} / ${state.ocrPageCount}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: state.ocrPageCount == 0 ? null : (state.ocrPage! / state.ocrPageCount!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (state.useMockExtractor)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Mock extractor is enabled in Setup.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              if (state.statementText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Text preview', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        SelectableText(preview, style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.parsed.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Candidates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...List.generate(state.parsed.length, (i) {
                  final m = state.parsed[i];
                  final title = [
                    m['amount']?.toString(),
                    m['currency']?.toString(),
                    m['merchant']?.toString(),
                  ].whereType<String>().where((e) => e.isNotEmpty).join(' ');
                  final subtitle = (m['notes']?.toString() ?? '').trim();
                  final isSelected = state.selected.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: CheckboxListTile(
                        value: isSelected,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => cubit.toggleSelected(i, v == true),
                        title: Text(title.isEmpty ? 'Transaction ${i + 1}' : title),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}