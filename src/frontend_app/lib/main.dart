// Budget App — Flutter front end
//
// This is a UI-only build against mock, in-memory data: there is no
// backend yet (per the project README, the Spring Boot API is still in
// progress), so every model below is a stand-in for what the API will
// eventually return. Add/edit/delete here just mutate local state —
// swap those handlers for real API calls once the backend has
// endpoints to hit.
//
// Editable in this build:
//   - Budgets: add, with optional starting members and roles
//   - Income sources: add, edit, delete — name, amount, frequency
//   - Budget categories ("expenses"): add, edit, delete, per budget —
//     name, kind (recurring limit vs. savings goal), limit/goal amount,
//     and amount spent or saved so far
//
// ---- Design notes -------------------------------------------------
// This still reads as a ledger, not a dashboard — hairline rules
// instead of card shadows, and tabular monospace figures that line up
// the way numbers do in a real ledger book — but the ledger is now lit
// like a night sky: a near-black navy background, a faint radial glow,
// and a scattering of static stars sitting quietly behind the content.
// Category health is still a thin fill bar under each line rather than
// a colored card, so the page stays quiet and the numbers stay legible.
//
// Palette:
//   paper    #070B14  background (near-black navy)
//   paperDim #121A2C  panel / chip fill
//   bgGlow   #16213B  radial glow behind the starfield
//   ink      #EDEFF5  primary text / headings
//   inkFade  #8C96B3  secondary text
//   hairline #232C44  rules & borders
//   moss     #4FD1A5  income / under budget
//   rust     #FF6B5B  over budget / warnings
//   gold     #F2C14E  savings goals
//
// Numbers are set in the platform monospace family so amounts align
// on their decimal points — the one place a monospace face earns its
// keep in this design, rather than being used decoratively on labels.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const BudgetApp());
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

class AppColors {
  static const paper = Color(0xFF070B14);
  static const paperDim = Color(0xFF121A2C);
  static const bgGlow = Color(0xFF16213B);
  static const ink = Color(0xFFEDEFF5);
  static const inkFade = Color(0xFF8C96B3);
  static const hairline = Color(0xFF232C44);
  static const moss = Color(0xFF4FD1A5);
  static const rust = Color(0xFFFF6B5B);
  static const gold = Color(0xFFF2C14E);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.moss,
      brightness: Brightness.dark,
      surface: AppColors.paperDim,
    ),
    dividerColor: AppColors.hairline,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    )
        .copyWith(
      headlineSmall: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleMedium: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColors.inkFade,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
  );
}

TextStyle ledgerNumber({
  double size = 15,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.ink,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

// ---------------------------------------------------------------------------
// Space backdrop — a quiet radial glow plus a fixed scattering of stars,
// painted once and never animated so it stays out of the way of the data.
// ---------------------------------------------------------------------------

class _Starfield extends StatelessWidget {
  const _Starfield();

  static final math.Random _rand = math.Random(7);
  static final List<Offset> _positions = List.generate(90, (_) => Offset(_rand.nextDouble(), _rand.nextDouble()));
  static final List<double> _radii = List.generate(90, (_) => _rand.nextDouble() * 1.3 + 0.4);
  static final List<double> _opacities = List.generate(90, (_) => _rand.nextDouble() * 0.5 + 0.15);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarfieldPainter(_positions, _radii, _opacities),
      size: Size.infinite,
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<Offset> positions;
  final List<double> radii;
  final List<double> opacities;
  _StarfieldPainter(this.positions, this.radii, this.opacities);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length; i++) {
      final paint = Paint()..color = Colors.white.withOpacity(opacities[i]);
      canvas.drawCircle(
        Offset(positions[i].dx * size.width, positions[i].dy * size.height),
        radii[i],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}

/// Wraps a screen's content with the dark-navy gradient and starfield.
/// Used at the app shell level and on pushed full-screen routes so the
/// backdrop stays consistent everywhere.
class SpaceBackground extends StatelessWidget {
  final Widget child;
  const SpaceBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -0.9),
                radius: 1.3,
                colors: [AppColors.bgGlow, AppColors.paper],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: _Starfield())),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Models (mock, mutable — mirrors the shape the future API is expected to
// return; fields are non-final so the UI below can edit them in place)
// ---------------------------------------------------------------------------

enum BudgetRole { owner, editor, viewer }

extension BudgetRoleLabel on BudgetRole {
  String get label {
    switch (this) {
      case BudgetRole.owner:
        return 'Owner';
      case BudgetRole.editor:
        return 'Editor';
      case BudgetRole.viewer:
        return 'Viewer';
    }
  }
}

class Member {
  final String name;
  final BudgetRole role;
  const Member(this.name, this.role);
}

enum CategoryKind { recurringLimit, savingsGoal }

extension CategoryKindLabel on CategoryKind {
  String get label => this == CategoryKind.recurringLimit ? 'Recurring limit' : 'Savings goal';
  String get amountLabel => this == CategoryKind.recurringLimit ? 'Spent so far' : 'Saved so far';
  String get targetLabel => this == CategoryKind.recurringLimit ? 'Limit' : 'Goal amount';
}

class BudgetCategory {
  String name;
  CategoryKind kind;
  double limitOrGoal;
  double current; // spent (limit) or saved (goal) so far

  BudgetCategory({
    required this.name,
    required this.kind,
    required this.limitOrGoal,
    required this.current,
  });

  double get fraction => (limitOrGoal == 0) ? 0 : (current / limitOrGoal).clamp(0, 1.4);
  bool get isOver => kind == CategoryKind.recurringLimit && current > limitOrGoal;
}

class Budget {
  String name;
  List<Member> members;
  List<BudgetCategory> categories;

  Budget({
    required this.name,
    required this.members,
    required this.categories,
  });

  double get totalLimit => categories
      .where((c) => c.kind == CategoryKind.recurringLimit)
      .fold(0.0, (sum, c) => sum + c.limitOrGoal);

  double get totalSpent => categories
      .where((c) => c.kind == CategoryKind.recurringLimit)
      .fold(0.0, (sum, c) => sum + c.current);
}

enum IncomeFrequency { manual, weekly, biweekly, monthly }

extension IncomeFrequencyLabel on IncomeFrequency {
  String get label {
    switch (this) {
      case IncomeFrequency.manual:
        return 'One-off';
      case IncomeFrequency.weekly:
        return 'Weekly';
      case IncomeFrequency.biweekly:
        return 'Every 2 weeks';
      case IncomeFrequency.monthly:
        return 'Monthly';
    }
  }
}

class IncomeSource {
  String name;
  double amount;
  IncomeFrequency frequency;
  DateTime nextDate;

  IncomeSource({
    required this.name,
    required this.amount,
    required this.frequency,
    required this.nextDate,
  });
}

// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

class MockData {
  static List<Budget> budgets() => [
    Budget(
      name: 'Household',
      members: const [
        Member('You', BudgetRole.owner),
        Member('Jordan', BudgetRole.editor),
        Member('Sam', BudgetRole.viewer),
      ],
      categories: [
        BudgetCategory(
          name: 'Groceries',
          kind: CategoryKind.recurringLimit,
          limitOrGoal: 600,
          current: 512.40,
        ),
        BudgetCategory(
          name: 'Utilities',
          kind: CategoryKind.recurringLimit,
          limitOrGoal: 220,
          current: 238.10,
        ),
        BudgetCategory(
          name: 'Dining out',
          kind: CategoryKind.recurringLimit,
          limitOrGoal: 150,
          current: 96.75,
        ),
        BudgetCategory(
          name: 'Emergency fund',
          kind: CategoryKind.savingsGoal,
          limitOrGoal: 5000,
          current: 3180,
        ),
      ],
    ),
    Budget(
      name: 'Trip to Japan',
      members: const [
        Member('You', BudgetRole.owner),
        Member('Jordan', BudgetRole.editor),
      ],
      categories: [
        BudgetCategory(
          name: 'Flights',
          kind: CategoryKind.savingsGoal,
          limitOrGoal: 1800,
          current: 1800,
        ),
        BudgetCategory(
          name: 'Lodging',
          kind: CategoryKind.savingsGoal,
          limitOrGoal: 1200,
          current: 640,
        ),
        BudgetCategory(
          name: 'Spending money',
          kind: CategoryKind.recurringLimit,
          limitOrGoal: 100,
          current: 0,
        ),
      ],
    ),
  ];

  static List<IncomeSource> income() => [
    IncomeSource(
      name: 'Salary — Castellan Group',
      amount: 3200,
      frequency: IncomeFrequency.biweekly,
      nextDate: DateTime.now().add(const Duration(days: 6)),
    ),
    IncomeSource(
      name: 'Freelance invoice',
      amount: 450,
      frequency: IncomeFrequency.manual,
      nextDate: DateTime.now().add(const Duration(days: 2)),
    ),
    IncomeSource(
      name: 'Dividend payout',
      amount: 38.20,
      frequency: IncomeFrequency.monthly,
      nextDate: DateTime.now().add(const Duration(days: 14)),
    ),
  ];
}

String money(double v) {
  final sign = v < 0 ? '-' : '';
  final abs = v.abs();
  return '$sign\$${abs.toStringAsFixed(2)}';
}

String dateShort(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

// ---------------------------------------------------------------------------
// App shell
// ---------------------------------------------------------------------------

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget App',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<Budget> _budgets = MockData.budgets();
  late final List<IncomeSource> _income = MockData.income();

  // Every mutation below just edits the in-memory lists and calls this to
  // rebuild — swap for a real API call + refetch once the backend exists.
  void _refresh() => setState(() {});

  void _addIncome(IncomeSource source) {
    setState(() => _income.insert(0, source));
  }

  void _editIncome(IncomeSource source, IncomeSource updated) {
    setState(() {
      source
        ..name = updated.name
        ..amount = updated.amount
        ..frequency = updated.frequency
        ..nextDate = updated.nextDate;
    });
  }

  void _deleteIncome(IncomeSource source) {
    setState(() => _income.remove(source));
  }

  void _addBudget(Budget budget) {
    setState(() => _budgets.insert(0, budget));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      OverviewScreen(budgets: _budgets, income: _income),
      BudgetsScreen(budgets: _budgets, onChanged: _refresh, onAddBudget: _addBudget),
      IncomeScreen(
        income: _income,
        onAdd: _addIncome,
        onEdit: _editIncome,
        onDelete: _deleteIncome,
      ),
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
          backgroundColor: AppColors.paper,
          elevation: 0,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
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
              selectedIcon: Icon(Icons.trending_up),
              label: 'Income',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onAdd;
  const SectionHeader({super.key, required this.title, this.trailing, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null)
            Text(trailing!, style: ledgerNumber(size: 13, color: AppColors.inkFade)),
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.add_circle_outline, size: 20, color: AppColors.moss),
              ),
            ),
        ],
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: AppColors.hairline);
}

/// A thin fill bar used under a ledger line to show progress toward a
/// limit or a goal — deliberately not a rounded progress "card".
class FillBar extends StatelessWidget {
  final double fraction;
  final Color color;
  const FillBar({super.key, required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(height: 3, color: AppColors.hairline),
            Container(height: 3, width: constraints.maxWidth * clamped, color: color),
          ],
        );
      },
    );
  }
}

class RoleBadge extends StatelessWidget {
  final BudgetRole role;
  const RoleBadge({super.key, required this.role});

  Color get _color {
    switch (role) {
      case BudgetRole.owner:
        return AppColors.moss;
      case BudgetRole.editor:
        return AppColors.gold;
      case BudgetRole.viewer:
        return AppColors.inkFade;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: _color), borderRadius: BorderRadius.circular(2)),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
      ),
    );
  }
}

/// Small ghost icon button used for row-level edit/delete actions —
/// kept quiet (no fill, no shadow) so it doesn't compete with the ledger.
class RowAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const RowAction({super.key, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: color ?? AppColors.inkFade),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class OverviewScreen extends StatelessWidget {
  final List<Budget> budgets;
  final List<IncomeSource> income;
  const OverviewScreen({super.key, required this.budgets, required this.income});

  @override
  Widget build(BuildContext context) {
    final totalLimit = budgets.fold(0.0, (s, b) => s + b.totalLimit);
    final totalSpent = budgets.fold(0.0, (s, b) => s + b.totalSpent);
    final monthIncome = income
        .where((i) => i.frequency != IncomeFrequency.manual)
        .fold(0.0, (s, i) => s + i.amount);
    final remaining = totalLimit - totalSpent;
    final overCats = budgets.expand((b) => b.categories).where((c) => c.isOver).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('This month', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Income booked', monthIncome, AppColors.moss),
                const SizedBox(height: 10),
                _summaryRow('Budgeted', totalLimit, AppColors.ink),
                const SizedBox(height: 10),
                _summaryRow('Spent', totalSpent, remaining < 0 ? AppColors.rust : AppColors.ink),
                const SizedBox(height: 10),
                _summaryRow('Left to spend', remaining, remaining < 0 ? AppColors.rust : AppColors.moss),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Hairline())),
        const SliverToBoxAdapter(child: SectionHeader(title: 'Categories over the line')),
        SliverList.builder(
          itemCount: overCats.length,
          itemBuilder: (context, i) => _CategoryLine(category: overCats[i]),
        ),
        if (overCats.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('Nothing over its limit right now.', style: TextStyle(color: AppColors.inkFade)),
            ),
          ),
        const SliverToBoxAdapter(child: SectionHeader(title: 'Upcoming income')),
        SliverList.builder(
          itemCount: income.length > 3 ? 3 : income.length,
          itemBuilder: (context, i) => _IncomeLine(source: income[i]),
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

class _CategoryLine extends StatelessWidget {
  final BudgetCategory category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _CategoryLine({required this.category, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isGoal = category.kind == CategoryKind.savingsGoal;
    final color = isGoal ? AppColors.gold : (category.isOver ? AppColors.rust : AppColors.moss);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${money(category.current)} / ${money(category.limitOrGoal)}',
                style: ledgerNumber(size: 13, color: color),
              ),
              if (onDelete != null) RowAction(icon: Icons.close, onTap: onDelete!, color: AppColors.rust),
            ],
          ),
          const SizedBox(height: 6),
          FillBar(fraction: category.fraction, color: color),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _IncomeLine extends StatelessWidget {
  final IncomeSource source;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _IncomeLine({required this.source, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${source.frequency.label} · due ${dateShort(source.nextDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
                ),
              ],
            ),
          ),
          Text(money(source.amount), style: ledgerNumber(size: 15, color: AppColors.moss)),
          if (onDelete != null) RowAction(icon: Icons.close, onTap: onDelete!, color: AppColors.rust),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

// ---------------------------------------------------------------------------
// Budgets
// ---------------------------------------------------------------------------

class BudgetsScreen extends StatelessWidget {
  final List<Budget> budgets;
  final VoidCallback onChanged;
  final ValueChanged<Budget> onAddBudget;
  const BudgetsScreen({
    super.key,
    required this.budgets,
    required this.onChanged,
    required this.onAddBudget,
  });

  Future<void> _addBudget(BuildContext context) async {
    final result = await showDialog<Budget>(
      context: context,
      builder: (_) => const _AddBudgetDialog(),
    );
    if (result != null) onAddBudget(result);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budgets', style: Theme.of(context).textTheme.headlineSmall),
                InkWell(
                  onTap: () => _addBudget(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.add_circle_outline, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (budgets.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('No budgets yet — add one above.', style: TextStyle(color: AppColors.inkFade)),
            ),
          ),
        SliverList.builder(
          itemCount: budgets.length,
          itemBuilder: (context, i) {
            final b = budgets[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i != 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Hairline()),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: b.members.map((m) => Chip(
                        label: Text('${m.name} · ${m.role.label}', style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.paperDim,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      )).toList(),
                    ),
                  ),
                  trailing: Text(
                    '${money(b.totalSpent)}\n/ ${money(b.totalLimit)}',
                    textAlign: TextAlign.right,
                    style: ledgerNumber(size: 13, color: b.totalSpent > b.totalLimit ? AppColors.rust : AppColors.ink),
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BudgetDetailScreen(budget: b, onChanged: onChanged)),
                    );
                    onChanged();
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
  final Budget budget;
  final VoidCallback onChanged;
  const BudgetDetailScreen({super.key, required this.budget, required this.onChanged});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  Budget get budget => widget.budget;

  Future<void> _addExpense() async {
    final result = await showDialog<BudgetCategory>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
    if (result != null) {
      setState(() => budget.categories.add(result));
      widget.onChanged();
    }
  }

  Future<void> _editExpense(BudgetCategory category) async {
    final result = await showDialog<BudgetCategory>(
      context: context,
      builder: (_) => _CategoryDialog(existing: category),
    );
    if (result != null) {
      setState(() {
        category
          ..name = result.name
          ..kind = result.kind
          ..limitOrGoal = result.limitOrGoal
          ..current = result.current;
      });
      widget.onChanged();
    }
  }

  void _deleteExpense(BudgetCategory category) {
    setState(() => budget.categories.remove(category));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(budget.name)),
      body: SpaceBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SectionHeader(title: 'Categories', onAdd: _addExpense),
            ),
            if (budget.categories.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text('No categories yet — add one above.', style: TextStyle(color: AppColors.inkFade)),
                ),
              ),
            SliverList.builder(
              itemCount: budget.categories.length,
              itemBuilder: (context, i) {
                final c = budget.categories[i];
                return Column(
                  children: [
                    _CategoryLine(
                      category: c,
                      onTap: () => _editExpense(c),
                      onDelete: () => _deleteExpense(c),
                    ),
                    if (i != budget.categories.length - 1)
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Hairline()),
                  ],
                );
              },
            ),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Members')),
            SliverList.builder(
              itemCount: budget.members.length,
              itemBuilder: (context, i) {
                final m = budget.members[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      RoleBadge(role: m.role),
                    ],
                  ),
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

/// Add/edit dialog for a budget category ("expense"): a name, whether it's
/// a recurring limit or a savings goal, the target amount, and how much has
/// been spent or saved against it so far.
class _CategoryDialog extends StatefulWidget {
  final BudgetCategory? existing;
  const _CategoryDialog({this.existing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _targetController =
  TextEditingController(text: widget.existing == null ? '' : widget.existing!.limitOrGoal.toStringAsFixed(2));
  late final _currentController =
  TextEditingController(text: widget.existing == null ? '' : widget.existing!.current.toStringAsFixed(2));
  late CategoryKind _kind = widget.existing?.kind ?? CategoryKind.recurringLimit;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit category' : 'Add expense category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CategoryKind>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: CategoryKind.values
                  .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                  .toList(),
              onChanged: (k) => setState(() => _kind = k ?? _kind),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: _kind.targetLabel, prefixText: '\$'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: _kind.amountLabel, prefixText: '\$'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.moss),
          onPressed: () {
            final target = double.tryParse(_targetController.text) ?? 0;
            final current = double.tryParse(_currentController.text) ?? 0;
            if (_nameController.text.trim().isEmpty || target <= 0) return;
            Navigator.of(context).pop(
              BudgetCategory(
                name: _nameController.text.trim(),
                kind: _kind,
                limitOrGoal: target,
                current: current,
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// Dialog for creating a new budget: a name plus an optional list of
/// members (beyond the creator, who is always added as owner).
class _AddBudgetDialog extends StatefulWidget {
  const _AddBudgetDialog();

  @override
  State<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<_AddBudgetDialog> {
  final _nameController = TextEditingController();
  final _memberNameController = TextEditingController();
  BudgetRole _memberRole = BudgetRole.editor;
  final List<Member> _members = [];

  @override
  void dispose() {
    _nameController.dispose();
    _memberNameController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _members.add(Member(name, _memberRole));
      _memberNameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Budget name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Members', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberNameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<BudgetRole>(
                  value: _memberRole,
                  items: [BudgetRole.editor, BudgetRole.viewer]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                      .toList(),
                  onChanged: (r) => setState(() => _memberRole = r ?? _memberRole),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.moss),
                  onPressed: _addMember,
                ),
              ],
            ),
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _members
                    .map((m) => Chip(
                  label: Text('${m.name} · ${m.role.label}', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.paperDim,
                  side: const BorderSide(color: AppColors.hairline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  onDeleted: () => setState(() => _members.remove(m)),
                ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.moss),
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              Budget(
                name: name,
                members: [const Member('You', BudgetRole.owner), ..._members],
                categories: [],
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Income
// ---------------------------------------------------------------------------

class IncomeScreen extends StatelessWidget {
  final List<IncomeSource> income;
  final ValueChanged<IncomeSource> onAdd;
  final void Function(IncomeSource source, IncomeSource updated) onEdit;
  final ValueChanged<IncomeSource> onDelete;
  const IncomeScreen({
    super.key,
    required this.income,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _add(BuildContext context) async {
    final result = await showDialog<IncomeSource>(
      context: context,
      builder: (_) => const _AddIncomeDialog(),
    );
    if (result != null) onAdd(result);
  }

  Future<void> _edit(BuildContext context, IncomeSource source) async {
    final result = await showDialog<IncomeSource>(
      context: context,
      builder: (_) => _AddIncomeDialog(existing: source),
    );
    if (result != null) onEdit(source, result);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Income', style: Theme.of(context).textTheme.headlineSmall),
                InkWell(
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
        if (income.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('No income sources yet — add one above.', style: TextStyle(color: AppColors.inkFade)),
            ),
          ),
        SliverList.builder(
          itemCount: income.length,
          itemBuilder: (context, i) => Column(
            children: [
              _IncomeLine(
                source: income[i],
                onTap: () => _edit(context, income[i]),
                onDelete: () => onDelete(income[i]),
              ),
              if (i != income.length - 1)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Hairline()),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _AddIncomeDialog extends StatefulWidget {
  final IncomeSource? existing;
  const _AddIncomeDialog({this.existing});

  @override
  State<_AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<_AddIncomeDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _amountController =
  TextEditingController(text: widget.existing == null ? '' : widget.existing!.amount.toStringAsFixed(2));
  late IncomeFrequency _frequency = widget.existing?.frequency ?? IncomeFrequency.manual;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit income source' : 'Add income source'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Source name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<IncomeFrequency>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: IncomeFrequency.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                .toList(),
            onChanged: (f) => setState(() => _frequency = f ?? _frequency),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.moss),
          onPressed: () {
            final amount = double.tryParse(_amountController.text) ?? 0;
            if (_nameController.text.trim().isEmpty || amount <= 0) return;
            Navigator.of(context).pop(
              IncomeSource(
                name: _nameController.text.trim(),
                amount: amount,
                frequency: _frequency,
                nextDate: widget.existing?.nextDate ?? DateTime.now().add(const Duration(days: 7)),
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}