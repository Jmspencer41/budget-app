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
    final budget = await showCreateBudgetDialog(context, ownerName: ledger.ownerLabel);
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
          child: EmptyNote(
            'A shared budget holds categories. A category is a recurring limit or a savings goal.',
          ),
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
                    '${money(budget.totalSpent)}\n/ ${money(budget.totalLimit)}',
                    textAlign: TextAlign.right,
                    style: ledgerNumber(
                      size: 13,
                      color: budget.totalSpent > budget.totalLimit && budget.totalLimit > 0
                          ? AppColors.rust
                          : AppColors.ink,
                    ),
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

  Future<void> _addCategory() async {
    final category = await showCategoryDialog(context);
    if (category != null) ledger.addCategory(budget.id, category);
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
        content: Text('Delete ${budget.name}? Its categories, expenses, and income will be removed too.'),
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
                    const Text('Spent against limits', style: TextStyle(color: AppColors.inkFade)),
                    const SizedBox(height: 4),
                    Text(
                      '${money(budget.totalSpent)} / ${money(budget.totalLimit)}',
                      style: ledgerNumber(size: 28),
                    ),
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
                title: 'Categories',
                onAdd: _addCategory,
                addKey: const Key('add-category'),
              ),
            ),
            if (budget.categories.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyNote('Add a recurring limit or a savings goal, then log amounts that count toward it.'),
              ),
            SliverList.builder(
              itemCount: budget.categories.length,
              itemBuilder: (context, index) {
                final category = budget.categories[index];
                final isGoal = category.kind == CategoryKind.goal;
                final color = isGoal ? AppColors.gold : (category.isOver ? AppColors.rust : AppColors.moss);
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CategoryScreen(
                              ledger: ledger,
                              budget: budget,
                              category: category,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text(
                                  '${money(category.current)} / ${money(category.target)}',
                                  style: ledgerNumber(size: 13, color: color),
                                ),
                                RowAction(
                                  icon: Icons.close,
                                  color: AppColors.rust,
                                  onTap: () => ledger.removeCategory(budget.id, category.id),
                                ),
                              ],
                            ),
                            Text(
                              isGoal ? 'Savings goal' : '${category.kind.label} · ${category.frequency.label}',
                              style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
                            ),
                            const SizedBox(height: 6),
                            FillBar(fraction: category.fraction, color: color),
                          ],
                        ),
                      ),
                    ),
                    if (index != budget.categories.length - 1)
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
                child: EmptyNote('Automatic paychecks and manual income on this budget show up here.'),
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

class CategoryScreen extends StatefulWidget {
  final Ledger ledger;
  final Budget budget;
  final BudgetCategory category;

  const CategoryScreen({
    super.key,
    required this.ledger,
    required this.budget,
    required this.category,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
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
    final stillThere = widget.budget.categories.contains(widget.category);
    if (!stillThere || !widget.ledger.budgets.contains(widget.budget)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  Future<void> _addExpense() async {
    final expense = await showExpenseDialog(context);
    if (expense != null) {
      widget.ledger.addExpense(widget.budget.id, widget.category.id, expense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final isGoal = category.kind == CategoryKind.goal;
    final color = isGoal ? AppColors.gold : (category.isOver ? AppColors.rust : AppColors.moss);
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: SpaceBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGoal ? 'Toward the goal' : 'Counted against the limit',
                      style: const TextStyle(color: AppColors.inkFade),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${money(category.current)} / ${money(category.target)}',
                      style: ledgerNumber(size: 28, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGoal
                          ? '${money(category.remaining)} left to save'
                          : '${money(category.remaining)} left · ${category.frequency.label}',
                      style: TextStyle(color: category.isOver ? AppColors.rust : AppColors.inkFade, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    FillBar(fraction: category.fraction, color: color),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: isGoal ? 'Contributions' : 'Expenses',
                onAdd: _addExpense,
                addKey: const Key('add-expense'),
              ),
            ),
            if (category.expenses.isEmpty)
              SliverToBoxAdapter(
                child: EmptyNote(
                  isGoal
                      ? 'Nothing saved yet. Add an amount and it counts toward the goal.'
                      : 'Nothing spent yet. Add an expense and it counts against the limit.',
                ),
              ),
            SliverList.builder(
              itemCount: category.expenses.length,
              itemBuilder: (context, index) {
                final expense = category.expenses[index];
                return Padding(
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
                      Text(money(expense.amount), style: ledgerNumber(size: 14, color: color)),
                      RowAction(
                        icon: Icons.close,
                        color: AppColors.rust,
                        onTap: () => widget.ledger.removeExpense(widget.budget.id, category.id, expense.id),
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
