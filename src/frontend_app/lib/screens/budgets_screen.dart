import 'package:flutter/material.dart';

import '../dialogs.dart';
import '../format.dart';
import '../ledger.dart';
import '../models.dart';
import '../theme.dart';
import 'income_screen.dart';

class BudgetsScreen extends StatelessWidget {
  final Ledger ledger;

  const BudgetsScreen({super.key, required this.ledger});

  Future<void> _create(BuildContext context) async {
    final budget = await showCreateBudgetDialog(context);
    if (budget != null) ledger.addBudget(budget);
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ledger.budgets;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Expanded(child: Text('Budgets', style: Theme.of(context).textTheme.headlineSmall)),
                InkWell(
                  key: const Key('add-budget'),
                  onTap: () => _create(context),
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
          child: EmptyNote('A budget is a shared place for spending. Expenses you add count toward its total.'),
        ),
        if (budgets.isEmpty)
          const SliverToBoxAdapter(child: EmptyNote('No budgets yet. Create one to get started.')),
        SliverList.builder(
          itemCount: budgets.length,
          itemBuilder: (context, index) {
            final budget = budgets[index];
            return Column(
              children: [
                if (index != 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Hairline()),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  title: Text(budget.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final member in budget.members)
                          Chip(
                            label: Text(
                              '${member.name} · ${member.role.label}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.paperDim,
                            side: const BorderSide(color: AppColors.hairline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          ),
                      ],
                    ),
                  ),
                  trailing: Text(
                    money(budget.totalSpent),
                    style: ledgerNumber(size: 13),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BudgetDetailScreen(ledger: ledger, budget: budget),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class BudgetDetailScreen extends StatefulWidget {
  final Ledger ledger;
  final Budget budget;

  const BudgetDetailScreen({super.key, required this.ledger, required this.budget});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  Ledger get ledger => widget.ledger;
  Budget get budget => widget.budget;

  @override
  void initState() {
    super.initState();
    ledger.addListener(_onLedger);
  }

  @override
  void dispose() {
    ledger.removeListener(_onLedger);
    super.dispose();
  }

  void _onLedger() {
    if (!mounted) return;
    if (!ledger.budgets.contains(budget)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  Future<void> _addExpense() async {
    final expense = await showExpenseDialog(context);
    if (expense != null) ledger.addExpense(budget.id, expense);
  }

  Future<void> _addMember() async {
    final member = await showAddMemberDialog(context, budget);
    if (member != null) ledger.addMember(budget.id, member);
  }

  Future<void> _addIncome() async {
    final source = await showIncomeDialog(context, budgets: ledger.budgets, lockedBudget: budget);
    if (source != null) ledger.addIncome(source);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget'),
        content: Text('Delete ${budget.name}? Its expenses and income will be removed too.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rust, foregroundColor: AppColors.paper),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) ledger.deleteBudget(budget.id);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sources = ledger.incomeFor(budget.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(budget.name),
        actions: [
          IconButton(
            tooltip: 'Delete budget',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.inkFade),
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
                    const Text('In this budget', style: TextStyle(color: AppColors.inkFade)),
                    const SizedBox(height: 4),
                    Text(money(budget.totalSpent), style: ledgerNumber(size: 28)),
                    const SizedBox(height: 4),
                    Text(
                      '${money(budget.spentDuring(now))} this month',
                      style: const TextStyle(color: AppColors.inkFade, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Expenses',
                onAdd: _addExpense,
                addKey: const Key('add-expense'),
              ),
            ),
            if (budget.expenses.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyNote('Nothing spent yet. Add an expense and it counts toward the total above.'),
              ),
            SliverList.builder(
              itemCount: budget.expenses.length,
              itemBuilder: (context, index) {
                final expense = budget.expenses[index];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(expense.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  dateShort(expense.date),
                                  style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
                                ),
                              ],
                            ),
                          ),
                          Text(money(expense.amount), style: ledgerNumber(size: 14)),
                          RowAction(
                            icon: Icons.close,
                            color: AppColors.rust,
                            onTap: () => ledger.removeExpense(budget.id, expense.id),
                          ),
                        ],
                      ),
                    ),
                    if (index != budget.expenses.length - 1)
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Hairline()),
                  ],
                );
              },
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'People',
                onAdd: _addMember,
                addKey: const Key('add-member'),
              ),
            ),
            SliverList.builder(
              itemCount: budget.members.length,
              itemBuilder: (context, index) {
                final member = budget.members[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      RoleBadge(role: member.role),
                      if (member.role != BudgetRole.owner)
                        RowAction(
                          icon: Icons.close,
                          color: AppColors.rust,
                          onTap: () => ledger.removeMember(budget.id, member),
                        ),
                    ],
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Income',
                onAdd: _addIncome,
                addKey: const Key('add-budget-income'),
              ),
            ),
            if (sources.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyNote('Paychecks and side hustles on this budget show up here.'),
              ),
            SliverList.builder(
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return IncomeRow(
                  ledger: ledger,
                  source: source,
                  budgetName: budget.name,
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
