import 'package:flutter/material.dart';

import 'ledger.dart';
import 'screens/budgets_screen.dart';
import 'screens/income_screen.dart';
import 'screens/overview_screen.dart';
import 'theme.dart';

void main() {
  runApp(const BudgetApp());
}

class BudgetApp extends StatefulWidget {
  const BudgetApp({super.key});

  @override
  State<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp> {
  final Ledger _ledger = Ledger();

  @override
  void initState() {
    super.initState();
    _ledger.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Buddy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeShell(ledger: _ledger),
    );
  }
}

class HomeShell extends StatefulWidget {
  final Ledger ledger;

  const HomeShell({super.key, required this.ledger});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.ledger.addListener(_onLedger);
  }

  @override
  void dispose() {
    widget.ledger.removeListener(_onLedger);
    super.dispose();
  }

  void _onLedger() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ledger.loaded) {
      return const Scaffold(
        body: SpaceBackground(
          child: Center(child: CircularProgressIndicator(color: AppColors.moss)),
        ),
      );
    }

    final screens = [
      OverviewScreen(ledger: widget.ledger),
      BudgetsScreen(ledger: widget.ledger),
      IncomeScreen(ledger: widget.ledger),
    ];

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(child: IndexedStack(index: _index, children: screens)),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_shared_outlined),
              selectedIcon: Icon(Icons.folder_shared),
              label: 'Budgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.trending_up),
              label: 'Income',
            ),
          ],
        ),
      ),
    );
  }
}
