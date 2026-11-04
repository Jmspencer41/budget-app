import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Empty unless the app is started with `--dart-define=API_BASE=http://localhost:8080`.
const apiBaseUrl = String.fromEnvironment('API_BASE', defaultValue: '');

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class BudgetApi {
  final String base;

  BudgetApi([String? base]) : base = base ?? apiBaseUrl;

  Future<Account> createUser(Account account) async {
    final body = await _object('POST', '/api/users', {
      'firstName': account.firstName,
      'lastName': account.lastName,
      'email': account.email,
      'password': account.password,
    });
    return _account(body, account.password);
  }

  Future<Account> login(String email, String password) async {
    final body = await _object('POST', '/api/users/login', {
      'email': email.trim(),
      'password': password,
    });
    return _account(body, password);
  }

  Future<void> createBudget({required String ownerId, required String title}) async {
    await _object('POST', '/api/budgets', {'title': title, 'ownerId': ownerId});
  }

  Future<void> addMember({
    required String budgetId,
    required String name,
    required String email,
    required BudgetRole role,
  }) async {
    final userId = await _userIdFor(name, email);
    await _object('POST', '/api/budgetmembers', {
      'budgetId': budgetId,
      'userId': userId,
      'role': role.name.toUpperCase(),
    });
  }

  Future<void> addCategory({
    required String budgetId,
    required String name,
    required CategoryKind kind,
    required CategoryFrequency frequency,
    DateTime? anchorDate,
    required double target,
  }) async {
    final isGoal = kind == CategoryKind.goal;
    await _object('POST', '/api/categories', {
      'budgetId': budgetId,
      'name': name,
      'categoryType': isGoal ? 'GOAL' : 'RECURRING',
      'frequency': isGoal ? null : frequency.name.toUpperCase(),
      'amountCents': _cents(target),
      'anchorDate': isGoal || anchorDate == null ? null : _date(anchorDate),
    });
  }

  Future<void> addExpense({
    required String categoryId,
    required String userId,
    required String label,
    required double amount,
    required DateTime date,
  }) async {
    await _object('POST', '/api/transactions', {
      'categoryId': categoryId,
      'userId': userId,
      'merchant': label,
      'description': label,
      'amountCents': _cents(amount),
      'transactionDate': _date(date),
    });
  }

  Future<void> addIncome(IncomeSource source, String userId) async {
    await _object('POST', '/api/incomesources', {
      'userId': userId,
      'budgetId': source.budgetId,
      'autoGenerate': source.kind.isAutomatic,
      ..._incomeSchedule(source),
    });
  }

  Future<void> updateIncome(IncomeSource source) async {
    await _object('PUT', '/api/incomesources/${source.id}', _incomeSchedule(source));
  }

  /// The fields that POST and PUT share: name, amount, and the pay schedule.
  Map<String, dynamic> _incomeSchedule(IncomeSource source) {
    final automatic = source.kind.isAutomatic;
    final frequency = source.frequency ?? PayFrequency.monthly;
    return {
      'name': source.name,
      'amountCents': automatic ? _cents(source.paycheckAmount) : 0,
      'frequency': automatic ? _apiFrequency(frequency) : 'IRREGULAR',
      // Phase 6 adds a date picker. Until then a new paycheck starts today.
      'anchorDate': automatic ? _date(source.anchorDate ?? DateTime.now()) : null,
      'secondPayDay': automatic && frequency == PayFrequency.semimonthly ? source.secondPayDay : null,
    };
  }

  Future<void> logPayment({
    required String incomeSourceId,
    required double amount,
    required DateTime date,
  }) async {
    await _object('POST', '/api/incomeentries', {
      'incomeSourceId': incomeSourceId,
      'amountCents': _cents(amount),
      'receivedDate': _date(date),
    });
  }

  Future<void> deleteBudget(String budgetId) async {
    await _object('DELETE', '/api/budgets/$budgetId');
  }

  Future<void> deleteCategory(String categoryId) async {
    await _object('DELETE', '/api/categories/$categoryId');
  }

  Future<void> deleteExpense(String transactionId) async {
    await _object('DELETE', '/api/transactions/$transactionId');
  }

  Future<void> deleteMember(String memberId) async {
    await _object('DELETE', '/api/budgetmembers/$memberId');
  }

  Future<void> deleteIncome(String incomeSourceId) async {
    await _object('DELETE', '/api/incomesources/$incomeSourceId');
  }

  Future<void> deletePayment(String incomeEntryId) async {
    await _object('DELETE', '/api/incomeentries/$incomeEntryId');
  }

  Future<List<PeriodSummary>> loadHistory(String categoryId, {int periods = 12}) async {
    final rows = await _list('/api/categories/$categoryId/history?periods=$periods');
    final history = <PeriodSummary>[];
    for (final row in rows) {
      history.add(
        PeriodSummary(
          start: DateTime.parse(row['periodStart'] as String),
          end: DateTime.parse(row['periodEnd'] as String),
          limit: _dollars(row['limitCents']),
          spent: _dollars(row['spentCents']),
        ),
      );
    }
    return history;
  }

  Future<List<Expense>> loadExpenses(String categoryId, {DateTime? from, DateTime? to}) async {
    final params = <String>[];
    if (from != null) params.add('from=${_date(from)}');
    if (to != null) params.add('to=${_date(to)}');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final rows = await _list('/api/transactions/category/$categoryId$query');
    final expenses = <Expense>[];
    for (final row in rows) {
      expenses.add(_expense(row));
    }
    return expenses;
  }

  Future<List<Budget>> loadBudgets(String ownerId) async {
    final rows = await _list('/api/budgets?userId=$ownerId');
    final budgets = <Budget>[];
    for (final row in rows) {
      final id = row['id'] as String;
      budgets.add(
        Budget(
          id: id,
          name: row['title'] as String? ?? '',
          members: await _members(id),
          categories: await _categories(id),
        ),
      );
    }
    return budgets;
  }

  Future<List<IncomeSource>> loadIncome(List<Budget> budgets) async {
    final sources = <IncomeSource>[];
    final asOf = _date(DateTime.now()); // the device's own date, so the server uses the user's timezone
    for (final budget in budgets) {
      final rows = await _list('/api/incomesources/budget/${budget.id}?asOf=$asOf');
      for (final row in rows) {
        final id = row['id'] as String;
        final automatic = row['autoGenerate'] == true;
        final entries = await _list('/api/incomeentries/source/$id');
        sources.add(
          IncomeSource(
            id: id,
            budgetId: budget.id,
            name: row['name'] as String? ?? '',
            kind: automatic ? IncomeKind.paycheck : IncomeKind.sideHustle,
            frequency: _payFrequency(row['frequency'] as String?),
            paycheckAmount: _dollars(row['amountCents']),
            anchorDate: DateTime.tryParse(row['anchorDate'] as String? ?? ''),
            secondPayDay: (row['secondPayDay'] as num?)?.toInt(),
            receivedThisMonth: _dollars(row['receivedThisMonthCents']),
            expectedThisMonth: _dollars(row['expectedThisMonthCents']),
            nextPayDate: DateTime.tryParse(row['nextPayDate'] as String? ?? ''),
            payments: [
              for (final entry in entries)
                IncomePayment(
                  id: entry['id'] as String? ?? '',
                  amount: _dollars(entry['amountCents']),
                  date: DateTime.tryParse(entry['receivedDate'] as String? ?? '') ?? DateTime.now(),
                ),
            ],
          ),
        );
      }
    }
    return sources;
  }

  Future<String> _userIdFor(String name, String email) async {
    try {
      final existing = await _object('GET', '/api/users/by-email?email=${Uri.encodeQueryComponent(email)}');
      return existing['id'] as String;
    } on ApiException catch (error) {
      if (error.message.contains('(404)')) {
        throw ApiException('No account found for $email. They need to sign up first.');
      }
      rethrow;
    }
  }

  Future<List<Member>> _members(String budgetId) async {
    final rows = await _list('/api/budgetmembers/budget/$budgetId');
    return [
      for (final row in rows)
        Member(
          row['name'] as String? ?? 'Member',
          _role(row['role'] as String?),
          id: row['id'] as String?,
          userId: row['userId'] as String?,
        ),
    ];
  }

  Future<List<BudgetCategory>> _categories(String budgetId) async {
    final rows = await _list('/api/categories/budget/$budgetId');
    final categories = <BudgetCategory>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final expenses = await loadExpenses(id);
      categories.add(
        BudgetCategory(
          id: id,
          name: row['name'] as String? ?? '',
          kind: row['categoryType'] == 'GOAL' ? CategoryKind.goal : CategoryKind.recurring,
          frequency: _categoryFrequency(row['frequency'] as String?),
          anchorDate: DateTime.tryParse(row['anchorDate'] as String? ?? ''),
          periodStart: DateTime.tryParse(row['periodStart'] as String? ?? ''),
          periodEnd: DateTime.tryParse(row['periodEnd'] as String? ?? ''),
          target: _dollars(row['amountCents']),
          expenses: expenses,
        ),
      );
    }
    return categories;
  }

  Expense _expense(Map<String, dynamic> row) {
    final merchant = row['merchant'] as String?;
    return Expense(
      id: row['id'] as String? ?? '',
      label: merchant != null && merchant.isNotEmpty ? merchant : (row['description'] as String? ?? 'Expense'),
      amount: _dollars(row['amountCents']),
      date: DateTime.tryParse(row['transactionDate'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final response = await http.get(Uri.parse('$base$path'));
    _check(response, 'GET', path);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw ApiException('Unexpected list from $path');
    return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<Map<String, dynamic>> _object(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$base$path');
    final headers = {'Content-Type': 'application/json'};
    final response = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => await http.put(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => await http.delete(uri, headers: headers),
      _ => throw ApiException('Unsupported $method'),
    };
    _check(response, method, path);
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw ApiException('Unexpected response from $path');
    return Map<String, dynamic>.from(decoded);
  }

  void _check(http.Response response, String method, String path) {
    if (response.statusCode >= 400) {
      throw ApiException('API $method $path failed (${response.statusCode})');
    }
  }

  Account _account(Map<String, dynamic> body, String password) {
    return Account(
      id: body['id'] as String?,
      firstName: body['firstName'] as String? ?? '',
      lastName: body['lastName'] as String? ?? '',
      email: body['email'] as String? ?? '',
      password: password,
    );
  }
}

int _cents(double amount) => (amount * 100).round();

double _dollars(Object? cents) => ((cents as num?) ?? 0) / 100;

String _date(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _apiFrequency(PayFrequency frequency) {
  switch (frequency) {
    case PayFrequency.weekly:
      return 'WEEKLY';
    case PayFrequency.biweekly:
      return 'BIWEEKLY';
    case PayFrequency.semimonthly:
      return 'SEMIMONTHLY';
    case PayFrequency.monthly:
      return 'MONTHLY';
  }
}

PayFrequency _payFrequency(String? raw) {
  switch (raw) {
    case 'WEEKLY':
      return PayFrequency.weekly;
    case 'BIWEEKLY':
      return PayFrequency.biweekly;
    case 'SEMIMONTHLY':
      return PayFrequency.semimonthly;
    default:
      return PayFrequency.monthly;
  }
}

CategoryFrequency _categoryFrequency(String? raw) {
  if (raw == null) return CategoryFrequency.monthly;
  return CategoryFrequency.values.asNameMap()[raw.toLowerCase()] ?? CategoryFrequency.monthly;
}

BudgetRole _role(String? raw) {
  switch (raw) {
    case 'OWNER':
      return BudgetRole.owner;
    case 'EDITOR':
      return BudgetRole.editor;
    default:
      return BudgetRole.viewer;
  }
}
