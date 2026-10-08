import 'package:flutter/material.dart';

import '../format.dart';
import '../ledger.dart';
import '../models.dart';
import '../theme.dart';

class OverviewScreen extends StatelessWidget {
  final Ledger ledger;

  const OverviewScreen({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final income = ledger.expectedIncomeDuring(now);
    final spent = ledger.spentDuring(now);
    final left = income - spent;
    final spending = <_SpendLine>[];
    final overLimit = <BudgetCategory>[];
    for (final budget in ledger.budgets) {
      for (final category in budget.categories) {
        if (category.isOver) overLimit.add(category);
        for (final expense in category.expenses) {
          if (category.kind == CategoryKind.recurring && sameMonth(expense.date, now)) {
            spending.add(_SpendLine(budget.name, category.name, expense));
          }
        }
      }
    }
    spending.sort((a, b) => b.expense.date.compareTo(a.expense.date));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('This month', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${ledger.account?.displayName ?? 'Account'} · ${monthYear(now)}',
                    style: const TextStyle(color: AppColors.inkFade),
                  ),
                ),
                TextButton(onPressed: ledger.signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              children: [
                _summaryRow('Income', income, AppColors.moss),
                const SizedBox(height: 10),
                _summaryRow('Spent', spent, spent > income && income > 0 ? AppColors.rust : AppColors.ink),
                const SizedBox(height: 10),
                _summaryRow('Left', left, left < 0 ? AppColors.rust : AppColors.moss),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Hairline()),
        ),
        const SliverToBoxAdapter(child: SectionHeader(title: 'Over the limit')),
        if (overLimit.isEmpty)
          const SliverToBoxAdapter(child: EmptyNote('No recurring category is over its limit.')),
        SliverList.builder(
          itemCount: overLimit.length,
          itemBuilder: (context, index) {
            final category = overLimit[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                    '${money(category.current)} / ${money(category.target)}',
                    style: ledgerNumber(size: 13, color: AppColors.rust),
                  ),
                ],
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SectionHeader(title: 'Spending')),
        if (spending.isEmpty)
          const SliverToBoxAdapter(child: EmptyNote('No expenses this month yet.')),
        SliverList.builder(
          itemCount: spending.length,
          itemBuilder: (context, index) {
            final line = spending[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.expense.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${line.budgetName} · ${line.categoryName} · ${dateShort(line.expense.date)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
                        ),
                      ],
                    ),
                  ),
                  Text(money(line.expense.amount), style: ledgerNumber(size: 14)),
                ],
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SectionHeader(title: 'Income')),
        if (ledger.incomes.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyNote('Add a paycheck or a side hustle from the Income tab.'),
          ),
        SliverList.builder(
          itemCount: ledger.incomes.length,
          itemBuilder: (context, index) {
            final source = ledger.incomes[index];
            final budgetName = _budgetName(ledger, source.budgetId);
            final detail = source.kind.isAutomatic
                ? '${source.frequency?.label ?? 'Monthly'} · ${money(source.expectedDuring(now))} this month'
                : 'Manual · ${money(source.expectedDuring(now))} logged this month';
            final shown = source.kind.isAutomatic ? source.paycheckAmount : source.totalLogged;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '$budgetName · $detail',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
                        ),
                      ],
                    ),
                  ),
                  Text(money(shown), style: ledgerNumber(size: 14, color: AppColors.moss)),
                ],
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _summaryRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.inkFade, fontSize: 14)),
        Text(money(value), style: ledgerNumber(size: 17, color: color)),
      ],
    );
  }
}

class _SpendLine {
  final String budgetName;
  final String categoryName;
  final Expense expense;

  const _SpendLine(this.budgetName, this.categoryName, this.expense);
}

String _budgetName(Ledger ledger, String budgetId) {
  for (final budget in ledger.budgets) {
    if (budget.id == budgetId) return budget.name;
  }
  return 'Budget';
}
