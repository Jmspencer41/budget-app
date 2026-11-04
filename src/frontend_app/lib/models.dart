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

enum PayFrequency { weekly, biweekly, semimonthly, monthly }

extension PayFrequencyLabel on PayFrequency {
  String get label {
    switch (this) {
      case PayFrequency.weekly:
        return 'Weekly';
      case PayFrequency.biweekly:
        return 'Every 2 weeks';
      case PayFrequency.semimonthly:
        return 'Twice a month';
      case PayFrequency.monthly:
        return 'Monthly';
    }
  }
}

/// Every payday from [from] to [to], both days included, oldest first.
/// Same rules as IncomeSourceService.getPayDates on the server, so local-only
/// mode and the server always agree.
List<DateTime> payDatesBetween(
  PayFrequency frequency,
  DateTime anchorDate,
  int? secondPayDay,
  DateTime from,
  DateTime to,
) {
  final payDates = <DateTime>[];
  final anchor = _dateOnly(anchorDate);
  var start = _dateOnly(from);
  final end = _dateOnly(to);
  if (start.isBefore(anchor)) start = anchor; // nothing is paid before the anchor
  if (start.isAfter(end)) return payDates; // empty range

  switch (frequency) {
    case PayFrequency.weekly:
      _addEveryNDays(payDates, anchor, 7, start, end);
    case PayFrequency.biweekly:
      _addEveryNDays(payDates, anchor, 14, start, end);
    case PayFrequency.monthly:
      _addMonthly(payDates, anchor, start, end);
    case PayFrequency.semimonthly:
      _addSemimonthly(payDates, anchor, secondPayDay ?? anchor.day, start, end);
  }
  return payDates;
}

/// Whole days from [a] to [b]. Uses UTC so a daylight saving change can't make a day 23 hours.
int _daysBetween(DateTime a, DateTime b) {
  return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// [date] plus [months], clamped to the end of a short month (Jan 31 + 1 month is Feb 28).
DateTime _addMonths(DateTime date, int months) {
  final firstOfMonth = DateTime(date.year, date.month + months, 1); // DateTime rolls month 13 into next year
  final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day; // day 0 = last day of the month before
  final day = date.day < lastDay ? date.day : lastDay;
  return DateTime(firstOfMonth.year, firstOfMonth.month, day);
}

void _addEveryNDays(List<DateTime> payDates, DateTime anchor, int stepDays, DateTime start, DateTime end) {
  var index = (_daysBetween(anchor, start) + stepDays - 1) ~/ stepDays; // round up to the first payday on or after start
  var payDate = DateTime(anchor.year, anchor.month, anchor.day + index * stepDays);
  while (!payDate.isAfter(end)) {
    payDates.add(payDate);
    index++;
    payDate = DateTime(anchor.year, anchor.month, anchor.day + index * stepDays); // always measured from the anchor
  }
}

void _addMonthly(List<DateTime> payDates, DateTime anchor, DateTime start, DateTime end) {
  var index = (start.year - anchor.year) * 12 + (start.month - anchor.month) - 1; // one month early, to be safe
  if (index < 0) index = 0;
  var payDate = _addMonths(anchor, index);
  while (payDate.isBefore(start)) { // walk forward to the first payday on or after start
    index++;
    payDate = _addMonths(anchor, index);
  }
  while (!payDate.isAfter(end)) {
    payDates.add(payDate);
    index++;
    payDate = _addMonths(anchor, index);
  }
}

void _addSemimonthly(List<DateTime> payDates, DateTime anchor, int secondPayDay, DateTime start, DateTime end) {
  final firstDay = anchor.day < secondPayDay ? anchor.day : secondPayDay; // earlier day of the month goes first
  final secondDay = anchor.day < secondPayDay ? secondPayDay : anchor.day;
  var year = start.year;
  var month = start.month;
  while (year < end.year || (year == end.year && month <= end.month)) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final firstDate = DateTime(year, month, firstDay < lastDay ? firstDay : lastDay); // the 31st becomes the 30th, 29th, or 28th
    final secondDate = DateTime(year, month, secondDay < lastDay ? secondDay : lastDay);
    if (!firstDate.isBefore(start) && !firstDate.isAfter(end)) {
      payDates.add(firstDate);
    }
    if (secondDate != firstDate && !secondDate.isBefore(start) && !secondDate.isAfter(end)) { // 30th and 31st both land on Feb 28, count it once
      payDates.add(secondDate);
    }
    month++;
    if (month == 13) {
      month = 1;
      year++;
    }
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
  DateTime? anchorDate;
  int? secondPayDay;
  final List<IncomePayment> payments;

  /// Calculated by the API for the current month. Null in local-only mode.
  final double? receivedThisMonth;
  final double? expectedThisMonth;
  final DateTime? nextPayDate;

  IncomeSource({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.kind,
    this.frequency,
    this.paycheckAmount = 0,
    this.anchorDate,
    this.secondPayDay,
    this.receivedThisMonth,
    this.expectedThisMonth,
    this.nextPayDate,
    List<IncomePayment>? payments,
  }) : payments = payments ?? [];

  double get totalLogged => payments.fold(0, (sum, payment) => sum + payment.amount);

  /// Money that has already come in during [month].
  double receivedDuring(DateTime month) {
    if (receivedThisMonth != null && sameMonth(month, DateTime.now())) {
      return receivedThisMonth!; // the server's number only describes the current month
    }
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final today = _dateOnly(DateTime.now());
    final end = today.isBefore(monthEnd) ? today : monthEnd; // the current month stops at today
    return _localTotal(monthStart, end);
  }

  /// Money that will come in over all of [month].
  double expectedDuring(DateTime month) {
    if (expectedThisMonth != null && sameMonth(month, DateTime.now())) {
      return expectedThisMonth!;
    }
    return _localTotal(DateTime(month.year, month.month, 1), DateTime(month.year, month.month + 1, 0));
  }

  /// The next payday after today. Uses the server's date when there is one.
  DateTime? get upcomingPayDate {
    if (nextPayDate != null) return nextPayDate;
    final anchor = anchorDate;
    if (kind != IncomeKind.paycheck || anchor == null) return null;
    final today = _dateOnly(DateTime.now());
    if (anchor.isAfter(today)) return _dateOnly(anchor); // schedule hasn't started, and the anchor is a payday
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final searchEnd = DateTime(today.year, today.month + 2, today.day); // longest gap is about a month
    final dates = payDatesBetween(frequency ?? PayFrequency.monthly, anchor, secondPayDay, tomorrow, searchEnd);
    return dates.isEmpty ? null : dates.first;
  }

  /// Calculated on the device, for local-only mode or when the server can't be reached.
  double _localTotal(DateTime from, DateTime to) {
    if (kind == IncomeKind.paycheck) {
      final anchor = anchorDate;
      if (anchor == null) return 0; // no payday picked, nothing to count from
      final count = payDatesBetween(frequency ?? PayFrequency.monthly, anchor, secondPayDay, from, to).length;
      return count * paycheckAmount;
    }
    var total = 0.0;
    for (final payment in payments) {
      final day = _dateOnly(payment.date);
      if (!day.isBefore(from) && !day.isAfter(to)) total += payment.amount;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'name': name,
        'kind': kind.name,
        'frequency': frequency?.name,
        'paycheckAmount': paycheckAmount,
        'anchorDate': anchorDate?.toIso8601String(),
        'secondPayDay': secondPayDay,
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
      anchorDate: DateTime.tryParse(json['anchorDate'] as String? ?? ''),
      secondPayDay: (json['secondPayDay'] as num?)?.toInt(),
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
