import 'package:flutter/material.dart';
import 'package:flutter_mvp/data/app_db.dart';
import 'package:flutter_mvp/domain/transaction.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<TransactionRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TransactionRecord>> _load() async {
    final db = await AppDb.open();
    final items = await db.listTransactions();
    await db.close();
    return items;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _clear() async {
    final db = await AppDb.open();
    await db.clearAll();
    await db.close();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<TransactionRecord>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: [
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
              IconButton(
                onPressed: items.isEmpty ? null : _clear,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear',
              ),
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 40, color: cs.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text(
                              'No transactions yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add one from the Add tab, or import from a PDF statement.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (context, i) {
                        final tx = items[i];
                        final createdAt = DateTime.fromMillisecondsSinceEpoch(tx.createdAtEpochMs);
                        final created =
                            '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
                        final title = [
                          if (tx.amount != null) tx.amount!.toStringAsFixed(2),
                          if (tx.currency?.isNotEmpty == true) tx.currency,
                          if (tx.merchant?.isNotEmpty == true) '· ${tx.merchant}',
                        ].join(' ');
                        final subtitle = [
                          if (tx.category?.isNotEmpty == true) tx.category,
                          if (tx.date?.isNotEmpty == true) tx.date,
                          if (tx.confidence != null) 'conf=${tx.confidence!.toStringAsFixed(2)}',
                        ].join(' · ');

                        return Card(
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            title: Text(
                              title.isEmpty ? 'Transaction #${tx.id}' : title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  subtitle.isEmpty ? 'Saved $created' : '$subtitle · Saved $created',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                            children: [
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Extracted JSON', style: Theme.of(context).textTheme.labelLarge),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(tx.extractedJson, style: const TextStyle(fontFamily: 'monospace')),
                            ],
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}

