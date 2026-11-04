import 'package:flutter/material.dart';

import '../format.dart';
import '../ledger.dart';
import '../models.dart';
import '../theme.dart';

class CategoryHistoryScreen extends StatefulWidget {
  final Ledger ledger;
  final BudgetCategory category;

  const CategoryHistoryScreen({super.key, required this.ledger, required this.category});

  @override
  State<CategoryHistoryScreen> createState() => _CategoryHistoryScreenState();
}

class _CategoryHistoryScreenState extends State<CategoryHistoryScreen> {
  static const _pageSize = 12;
  static const _maxPeriods = 60;

  int _count = _pageSize;
  late Future<List<PeriodSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.ledger.loadHistory(widget.category.id, periods: _count);
  }

  void _showMore() {
    setState(() {
      _count = _count + _pageSize > _maxPeriods ? _maxPeriods : _count + _pageSize;
      _future = widget.ledger.loadHistory(widget.category.id, periods: _count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.category.name} history')),
      body: SpaceBackground(
        child: FutureBuilder<List<PeriodSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const EmptyNote('Could not load history. Check that the server is running.');
            }
            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return const EmptyNote('History is available when the app is connected to the server.');
            }
            return _HistoryList(
              ledger: widget.ledger,
              category: widget.category,
              history: history,
              canShowMore: history.length == _count && _count < _maxPeriods,
              onShowMore: _showMore,
            );
          },
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final Ledger ledger;
  final BudgetCategory category;
  final List<PeriodSummary> history;
  final bool canShowMore;
  final VoidCallback onShowMore;

  const _HistoryList({
    required this.ledger,
    required this.category,
    required this.history,
    required this.canShowMore,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    var overCount = 0;
    var totalSpent = 0.0;
    for (final period in history) {
      if (period.isOver) overCount++;
      totalSpent += period.spent;
    }
    final average = totalSpent / history.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Over the limit in $overCount of ${history.length} periods',
                  style: TextStyle(
                    color: overCount > 0 ? AppColors.rust : AppColors.inkFade,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Average ${money(average)} per period',
                  style: const TextStyle(color: AppColors.inkFade, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: history.length,
          itemBuilder: (context, index) => PeriodRow(
            period: history[index],
            isCurrent: index == 0,
            ledger: ledger,
            category: category,
          ),
        ),
        if (canShowMore)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(onPressed: onShowMore, child: const Text('Show more')),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// One period's summary. Tapping it opens that period's transactions when [ledger] and [category] are given.
class PeriodRow extends StatelessWidget {
  final PeriodSummary period;
  final bool isCurrent;
  final Ledger? ledger;
  final BudgetCategory? category;

  const PeriodRow({
    super.key,
    required this.period,
    required this.isCurrent,
    this.ledger,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final color = spendColor(period.spent, period.limit);
    final ledger = this.ledger;
    final category = this.category;
    final tappable = ledger != null && category != null;
    return GlassCard(
      tint: color,
      onTap: tappable
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PeriodDetailScreen(ledger: ledger, category: category, period: period),
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(periodRange(period.start, period.end), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (isCurrent)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Current', style: TextStyle(fontSize: 11, color: AppColors.moss)),
                  ),
                Text(
                  '${money(period.spent)} / ${money(period.limit)}',
                  style: ledgerNumber(size: 13, color: color),
                ),
                if (tappable) const Icon(Icons.chevron_right, size: 18, color: AppColors.inkFade),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              period.isOver ? 'Over by ${money(-period.remaining)}' : '${money(period.remaining)} left',
              style: TextStyle(fontSize: 12, color: period.isOver ? AppColors.rust : AppColors.inkFade),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FillBar(fraction: period.fraction, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The transactions inside one period, fetched with the from/to filter.
class PeriodDetailScreen extends StatefulWidget {
  final Ledger ledger;
  final BudgetCategory category;
  final PeriodSummary period;

  const PeriodDetailScreen({
    super.key,
    required this.ledger,
    required this.category,
    required this.period,
  });

  @override
  State<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends State<PeriodDetailScreen> {
  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.ledger.loadExpenses(
      widget.category.id,
      from: widget.period.start,
      to: widget.period.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    final color = spendColor(period.spent, period.limit);
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: SpaceBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(periodRange(period.start, period.end), style: const TextStyle(color: AppColors.inkFade)),
                    const SizedBox(height: 4),
                    Text(
                      '${money(period.spent)} / ${money(period.limit)}',
                      style: ledgerNumber(size: 28, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period.isOver ? 'Over by ${money(-period.remaining)}' : '${money(period.remaining)} left',
                      style: TextStyle(color: period.isOver ? AppColors.rust : AppColors.inkFade, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    FillBar(fraction: period.fraction, color: color),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Transactions')),
            SliverToBoxAdapter(
              child: FutureBuilder<List<Expense>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const EmptyNote('Could not load transactions.');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final expenses = snapshot.data!;
                  if (expenses.isEmpty) {
                    return const EmptyNote('No transactions in this period.');
                  }
                  expenses.sort((a, b) => b.date.compareTo(a.date));
                  return Column(
                    children: [
                      for (final expense in expenses)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
