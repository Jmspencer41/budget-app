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
    required PayFrequency frequency,
    required double target,
  }) async {
    await _object('POST', '/api/categories', {
      'budgetId': budgetId,
      'name': name,
      'categoryType': kind == CategoryKind.goal ? 'GOAL' : 'RECURRING',
      'frequency': _apiFrequency(frequency),
      'amountCents': _cents(target),
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
    final automatic = source.kind.isAutomatic;
    await _object('POST', '/api/incomesources', {
      'userId': userId,
      'budgetId': source.budgetId,
      'name': source.name,
      'amountCents': automatic ? _cents(source.paycheckAmount) : 0,
      'frequency': automatic ? _apiFrequency(source.frequency ?? PayFrequency.monthly) : 'IRREGULAR',
      'autoGenerate': automatic,
      'nextPayDate': _date(DateTime.now()),
    });
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
    for (final budget in budgets) {
      final rows = await _list('/api/incomesources/budget/${budget.id}');
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
      final expenses = await _list('/api/transactions/category/$id');
      categories.add(
        BudgetCategory(
          id: id,
          name: row['name'] as String? ?? '',
          kind: row['categoryType'] == 'GOAL' ? CategoryKind.goal : CategoryKind.recurring,
          frequency: _payFrequency(row['frequency'] as String?),
          target: _dollars(row['amountCents']),
          expenses: [
            for (final expense in expenses)
              Expense(
                id: expense['id'] as String? ?? '',
                label: (expense['merchant'] as String?)?.isNotEmpty == true
                    ? expense['merchant'] as String
                    : (expense['description'] as String? ?? 'Expense'),
                amount: _dollars(expense['amountCents']),
                date: DateTime.tryParse(expense['transactionDate'] as String? ?? '') ?? DateTime.now(),
              ),
          ],
        ),
      );
    }
    return categories;
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
    default:
      return PayFrequency.monthly;
  }
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
