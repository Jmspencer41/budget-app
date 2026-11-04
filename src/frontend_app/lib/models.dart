import 'format.dart';

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

enum IncomeKind { paycheck, sideHustle }

extension IncomeKindLabel on IncomeKind {
  /// A paycheck is counted on a schedule. A side hustle is logged by hand.
  bool get isAutomatic => this == IncomeKind.paycheck;

  String get label => isAutomatic ? 'Automatic' : 'Manual';
}

enum CategoryKind { recurring, goal }

extension CategoryKindLabel on CategoryKind {
  String get label => this == CategoryKind.recurring ? 'Recurring limit' : 'Savings goal';

  String get targetLabel => this == CategoryKind.recurring ? 'Limit' : 'Goal amount';
}

enum CategoryFrequency { daily, weekly, biweekly, monthly, quarterly, semiannually, yearly }

extension CategoryFrequencyLabel on CategoryFrequency {
  String get label {
    switch (this) {
      case CategoryFrequency.daily:
        return 'Daily';
      case CategoryFrequency.weekly:
        return 'Weekly';
      case CategoryFrequency.biweekly:
        return 'Every 2 weeks';
      case CategoryFrequency.monthly:
        return 'Monthly';
      case CategoryFrequency.quarterly:
        return 'Quarterly';
      case CategoryFrequency.semiannually:
        return 'Every 6 months';
      case CategoryFrequency.yearly:
        return 'Yearly';
    }
  }
}

enum PayFrequency { weekly, biweekly, monthly }

extension PayFrequencyLabel on PayFrequency {
  String get label {
    switch (this) {
      case PayFrequency.weekly:
        return 'Weekly';
      case PayFrequency.biweekly:
        return 'Every 2 weeks';
      case PayFrequency.monthly:
        return 'Monthly';
    }
  }
}

/// A paycheck's set amount, expressed as what it contributes in a typical month.
double monthlyEquivalent(PayFrequency frequency, double amount) {
  switch (frequency) {
    case PayFrequency.weekly:
      return amount * 52 / 12;
    case PayFrequency.biweekly:
      return amount * 26 / 12;
    case PayFrequency.monthly:
      return amount;
  }
}

class Member {
  final String? id;
  final String? userId;
  final String name;
  final String? email;
  final BudgetRole role;

  const Member(this.name, this.role, {this.id, this.userId, this.email});

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'email': email,
        'role': role.name,
      };

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      json['name'] as String? ?? '',
      BudgetRole.values.asNameMap()[json['role']] ?? BudgetRole.viewer,
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      email: json['email'] as String?,
    );
  }
}

class Expense {
  final String id;
  final String label;
  final double amount;
  final DateTime date;

  const Expense({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class Account {
  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  const Account({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  String get displayName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class BudgetCategory {
  final String id;
  String name;
  CategoryKind kind;
  CategoryFrequency frequency;
  DateTime? anchorDate;
  DateTime? periodStart;
  DateTime? periodEnd;
  double target;
  final List<Expense> expenses;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.frequency,
    this.anchorDate,
    this.periodStart,
    this.periodEnd,
    required this.target,
    List<Expense>? expenses,
  }) : expenses = expenses ?? [];

  /// True when the server gave us the current period. False for goals and device-only mode.
  bool get hasPeriod => kind == CategoryKind.recurring && periodStart != null && periodEnd != null;

  /// Expenses inside the current period, or all expenses when there is no period.
  List<Expense> get periodExpenses {
    if (!hasPeriod) return expenses;
    final start = _dateOnly(periodStart!);
    final end = _dateOnly(periodEnd!);
    final result = <Expense>[];
    for (final expense in expenses) {
      final day = _dateOnly(expense.date);
      if (!day.isBefore(start) && !day.isAfter(end)) result.add(expense);
    }
    return result;
  }

  double get current {
    var sum = 0.0;
    for (final expense in periodExpenses) {
      sum += expense.amount;
    }
    return sum;
  }

  double get remaining => target - current;

  bool get isOver => kind == CategoryKind.recurring && current > target;

  double get fraction => target == 0 ? 0 : (current / target).clamp(0, 1.4).toDouble();

  /// "Nov 1 to Nov 30", or null when there is no period.
  String? get periodLabel {
    if (!hasPeriod) return null;
    final start = periodStart!;
    final end = periodEnd!;
    if (start.year != end.year) {
      return '${dateShort(start)}, ${start.year} to ${dateShort(end)}, ${end.year}';
    }
    if (_dateOnly(start) == _dateOnly(end)) return dateShort(start);
    return '${dateShort(start)} to ${dateShort(end)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'frequency': frequency.name,
        'anchorDate': anchorDate?.toIso8601String(),
        'periodStart': periodStart?.toIso8601String(),
        'periodEnd': periodEnd?.toIso8601String(),
        'target': target,
        'expenses': expenses.map((expense) => expense.toJson()).toList(),
      };

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: CategoryKind.values.asNameMap()[json['kind']] ?? CategoryKind.recurring,
      frequency: CategoryFrequency.values.asNameMap()[json['frequency']] ?? CategoryFrequency.monthly,
      anchorDate: DateTime.tryParse(json['anchorDate'] as String? ?? ''),
      periodStart: DateTime.tryParse(json['periodStart'] as String? ?? ''),
      periodEnd: DateTime.tryParse(json['periodEnd'] as String? ?? ''),
      target: (json['target'] as num?)?.toDouble() ?? 0,
      expenses: _mapList(json['expenses'], Expense.fromJson),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class Budget {
  final String id;
  String name;
  final List<Member> members;
  final List<BudgetCategory> categories;

  Budget({
    required this.id,
    required this.name,
    required this.members,
    required this.categories,
  });

  double get totalLimit => categories
      .where((category) => category.kind == CategoryKind.recurring)
      .fold(0, (sum, category) => sum + category.target);

  double get totalSpent => categories
      .where((category) => category.kind == CategoryKind.recurring)
      .fold(0, (sum, category) => sum + category.current);

  double spentDuring(DateTime month) {
    var sum = 0.0;
    for (final category in categories) {
      if (category.kind != CategoryKind.recurring) continue;
      for (final expense in category.expenses) {
        if (sameMonth(expense.date, month)) sum += expense.amount;
      }
    }
    return sum;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((member) => member.toJson()).toList(),
        'categories': categories.map((category) => category.toJson()).toList(),
      };

  factory Budget.fromJson(Map<String, dynamic> json) {
    final categories = _mapList(json['categories'], BudgetCategory.fromJson);
    final looseExpenses = _mapList(json['expenses'], Expense.fromJson);
    if (categories.isEmpty && looseExpenses.isNotEmpty) {
      final spent = looseExpenses.fold<double>(0, (sum, expense) => sum + expense.amount);
      categories.add(
        BudgetCategory(
          id: 'migrated-spending',
          name: 'Spending',
          kind: CategoryKind.recurring,
          frequency: CategoryFrequency.monthly,
          target: spent,
          expenses: looseExpenses,
        ),
      );
    }
    return Budget(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      members: _mapList(json['members'], Member.fromJson),
      categories: categories,
    );
  }
}

class IncomePayment {
  final String id;
  final double amount;
  final DateTime date;

  const IncomePayment({
    required this.id,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory IncomePayment.fromJson(Map<String, dynamic> json) {
    return IncomePayment(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class IncomeSource {
  final String id;
  final String budgetId;
  String name;
  final IncomeKind kind;
  PayFrequency? frequency;
  double paycheckAmount;
  final List<IncomePayment> payments;

  IncomeSource({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.kind,
    this.frequency,
    this.paycheckAmount = 0,
    List<IncomePayment>? payments,
  }) : payments = payments ?? [];

  double get totalLogged => payments.fold(0, (sum, payment) => sum + payment.amount);

  double expectedDuring(DateTime month) {
    if (kind == IncomeKind.paycheck) {
      final cadence = frequency ?? PayFrequency.monthly;
      return monthlyEquivalent(cadence, paycheckAmount);
    }
    return payments
        .where((payment) => sameMonth(payment.date, month))
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'name': name,
        'kind': kind.name,
        'frequency': frequency?.name,
        'paycheckAmount': paycheckAmount,
        'payments': payments.map((payment) => payment.toJson()).toList(),
      };

  factory IncomeSource.fromJson(Map<String, dynamic> json) {
    return IncomeSource(
      id: json['id'] as String? ?? '',
      budgetId: json['budgetId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: IncomeKind.values.asNameMap()[json['kind']] ?? IncomeKind.paycheck,
      frequency: PayFrequency.values.asNameMap()[json['frequency']],
      paycheckAmount: (json['paycheckAmount'] as num?)?.toDouble() ?? 0,
      payments: _mapList(json['payments'], IncomePayment.fromJson),
    );
  }
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((item) => decode(Map<String, dynamic>.from(item))).toList();
}

/// One row from GET /api/categories/{id}/history.
class PeriodSummary {
  final DateTime start;
  final DateTime end;
  final double limit;
  final double spent;

  const PeriodSummary({
    required this.start,
    required this.end,
    required this.limit,
    required this.spent,
  });

  double get remaining => limit - spent;

  bool get isOver => spent > limit;

  double get fraction => limit == 0 ? 0 : (spent / limit).clamp(0, 1.4).toDouble();
}
