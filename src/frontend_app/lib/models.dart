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
  final String name;
  final BudgetRole role;

  const Member(this.name, this.role);

  Map<String, dynamic> toJson() => {'name': name, 'role': role.name};

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      json['name'] as String? ?? '',
      BudgetRole.values.asNameMap()[json['role']] ?? BudgetRole.viewer,
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

class Budget {
  final String id;
  String name;
  final List<Member> members;
  final List<Expense> expenses;

  Budget({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
  });

  double get totalSpent => expenses.fold(0, (sum, expense) => sum + expense.amount);

  double spentDuring(DateTime month) {
    return expenses
        .where((expense) => sameMonth(expense.date, month))
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((member) => member.toJson()).toList(),
        'expenses': expenses.map((expense) => expense.toJson()).toList(),
      };

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      members: _mapList(json['members'], Member.fromJson),
      expenses: _mapList(json['expenses'], Expense.fromJson),
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
