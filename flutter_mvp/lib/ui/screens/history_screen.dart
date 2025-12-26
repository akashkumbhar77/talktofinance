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
    return FutureBuilder<List<TransactionRecord>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('History (local only)'),
            actions: [
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
              IconButton(onPressed: items.isEmpty ? null : _clear, icon: const Icon(Icons.delete)),
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(child: Text('No transactions yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemBuilder: (context, i) {
                        final tx = items[i];
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

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title.isEmpty ? 'Transaction #${tx.id}' : title, style: Theme.of(context).textTheme.titleMedium),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                            ],
                            const SizedBox(height: 8),
                            Text(tx.extractedJson, style: const TextStyle(fontFamily: 'monospace')),
                          ],
                        );
                      },
                    ),
        );
      },
    );
  }
}

