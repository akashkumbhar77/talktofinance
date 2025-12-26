import 'package:flutter/material.dart';
import 'package:flutter_mvp/ui/screens/history_screen.dart';
import 'package:flutter_mvp/ui/screens/import_pdf_screen.dart';
import 'package:flutter_mvp/ui/screens/setup_screen.dart';
import 'package:flutter_mvp/ui/screens/voice_add_screen.dart';

class EdgeExpenseApp extends StatelessWidget {
  const EdgeExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Expense AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      SetupScreen(),
      VoiceAddScreen(),
      ImportPdfScreen(),
      HistoryScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.settings), label: 'Setup'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf), label: 'Import'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

