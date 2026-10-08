import 'package:flutter/material.dart';

import '../dialogs.dart';
import '../format.dart';
import '../ledger.dart';
import '../models.dart';
import '../theme.dart';

class IncomeScreen extends StatelessWidget {
  final Ledger ledger;

  const IncomeScreen({super.key, required this.ledger});

  Future<void> _add(BuildContext context) async {
    if (ledger.budgets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a budget first so this income has a home.')),
      );
      return;
    }
    final source = await showIncomeDialog(context, budgets: ledger.budgets);
    if (source != null) ledger.addIncome(source);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Expanded(child: Text('Income', style: Theme.of(context).textTheme.headlineSmall)),
                InkWell(
                  key: const Key('add-income'),
                  onTap: () => _add(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.add_circle_outline, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: EmptyNote('Paychecks repeat on a schedule. Side hustles stay at zero until you log what came in.'),
        ),
        if (ledger.incomes.isEmpty)
          const SliverToBoxAdapter(child: EmptyNote('No income yet.')),
        SliverList.builder(
          itemCount: ledger.incomes.length,
          itemBuilder: (context, index) {
            final source = ledger.incomes[index];
            return Column(
              children: [
                IncomeRow(
                  ledger: ledger,
                  source: source,
                  budgetName: _nameFor(ledger, source.budgetId),
                ),
                if (index != ledger.incomes.length - 1)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Hairline()),
              ],
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class IncomeRow extends StatelessWidget {
  final Ledger ledger;
  final IncomeSource source;
  final String budgetName;

  const IncomeRow({
    super.key,
    required this.ledger,
    required this.source,
    required this.budgetName,
  });

  Future<void> _open(BuildContext context) async {
    if (source.kind == IncomeKind.sideHustle) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SideHustleScreen(ledger: ledger, source: source),
        ),
      );
      return;
    }
    final updated = await showIncomeDialog(
      context,
      budgets: ledger.budgets,
      existing: source,
    );
    if (updated != null) {
      ledger.updatePaycheck(
        source,
        name: updated.name,
        amount: updated.paycheckAmount,
        frequency: updated.frequency ?? PayFrequency.monthly,
      );
    }
  }

  Future<void> _log(BuildContext context) async {
    final payment = await showLogIncomeDialog(context);
    if (payment != null) ledger.logSideHustle(source.id, payment);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPaycheck = source.kind == IncomeKind.paycheck;
    final subtitle = isPaycheck
        ? '$budgetName · ${source.frequency?.label ?? 'Monthly'} · ${money(source.expectedDuring(now))} / month'
        : '$budgetName · Side hustle · ${money(source.expectedDuring(now))} this month';
    final amount = isPaycheck ? source.paycheckAmount : source.totalLogged;

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.inkFade)),
                ],
              ),
            ),
            Text(money(amount), style: ledgerNumber(size: 15, color: AppColors.moss)),
            if (!isPaycheck)
              TextButton(
                key: Key('log-${source.id}'),
                onPressed: () => _log(context),
                child: const Text('Log'),
              ),
            RowAction(
              icon: Icons.close,
              color: AppColors.rust,
              onTap: () => ledger.removeIncome(source.id),
            ),
          ],
        ),
      ),
    );
  }
}

class SideHustleScreen extends StatefulWidget {
  final Ledger ledger;
  final IncomeSource source;

  const SideHustleScreen({super.key, required this.ledger, required this.source});

  @override
  State<SideHustleScreen> createState() => _SideHustleScreenState();
}

class _SideHustleScreenState extends State<SideHustleScreen> {
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
    if (!mounted) return;
    if (!widget.ledger.incomes.contains(widget.source)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  Future<void> _log() async {
    final payment = await showLogIncomeDialog(context);
    if (payment != null) widget.ledger.logSideHustle(widget.source.id, payment);
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(source.name),
        actions: [
          IconButton(
            key: const Key('log-side-hustle'),
            tooltip: 'Log money',
            onPressed: _log,
            icon: const Icon(Icons.add, color: AppColors.moss),
          ),
        ],
      ),
      body: SpaceBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Brought in', style: TextStyle(color: AppColors.inkFade)),
                    const SizedBox(height: 4),
                    Text(money(source.totalLogged), style: ledgerNumber(size: 28, color: AppColors.moss)),
                    const SizedBox(height: 4),
                    Text(
                      '${money(source.expectedDuring(now))} this month',
                      style: const TextStyle(color: AppColors.inkFade, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Logged')),
            if (source.payments.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyNote('Nothing logged yet. Add what this hustle brought in and the total updates.'),
              ),
            SliverList.builder(
              itemCount: source.payments.length,
              itemBuilder: (context, index) {
                final payment = source.payments[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateShort(payment.date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(money(payment.amount), style: ledgerNumber(size: 14, color: AppColors.moss)),
                      RowAction(
                        icon: Icons.close,
                        color: AppColors.rust,
                        onTap: () => widget.ledger.removePayment(source.id, payment.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _nameFor(Ledger ledger, String budgetId) {
  for (final budget in ledger.budgets) {
    if (budget.id == budgetId) return budget.name;
  }
  return 'Budget';
}
