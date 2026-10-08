import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const ownerName = 'You';

/// On-device ledger. The home-lab API will replace [load] and [_touch]
/// once budgets, expenses, and income can be read back from Postgres.
class Ledger extends ChangeNotifier {
  static const storageKey = 'budget_buddy_ledger_v2';
  static const _legacyKey = 'budget_buddy_ledger_v1';

  final List<Budget> budgets = [];
  final List<IncomeSource> incomes = [];
  Account? account;
  bool signedIn = false;
  bool loaded = false;

  String get ownerLabel => account?.firstName.isNotEmpty == true ? account!.firstName : ownerName;

  Future<void> _tail = Future<void>.value();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey) ?? prefs.getString(_legacyKey);
      budgets.clear();
      incomes.clear();
      account = null;
      signedIn = false;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          budgets.addAll(_mapList(data['budgets'], Budget.fromJson));
          incomes.addAll(_mapList(data['incomes'], IncomeSource.fromJson));
          final savedAccount = data['account'];
          if (savedAccount is Map) {
            account = Account.fromJson(Map<String, dynamic>.from(savedAccount));
            signedIn = data['signedIn'] == true;
          }
        }
      }
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      budgets.clear();
      incomes.clear();
      account = null;
      signedIn = false;
    }
    loaded = true;
    notifyListeners();
  }

  void createAccount(Account next) {
    account = next;
    signedIn = true;
    _touch();
  }

  bool signIn(String email, String password) {
    final saved = account;
    if (saved == null) return false;
    final matches = saved.email.toLowerCase() == email.trim().toLowerCase() && saved.password == password;
    if (!matches) return false;
    signedIn = true;
    _touch();
    return true;
  }

  void signOut() {
    signedIn = false;
    _touch();
  }

  void addBudget(Budget budget) {
    budgets.insert(0, budget);
    _touch();
  }

  void deleteBudget(String budgetId) {
    budgets.removeWhere((budget) => budget.id == budgetId);
    incomes.removeWhere((income) => income.budgetId == budgetId);
    _touch();
  }

  void addMember(String budgetId, Member member) {
    final budget = _budget(budgetId);
    if (budget == null) return;
    final taken = budget.members.any(
      (existing) => existing.name.toLowerCase() == member.name.toLowerCase(),
    );
    if (taken || member.name.trim().isEmpty) return;
    budget.members.add(member);
    _touch();
  }

  void removeMember(String budgetId, Member member) {
    if (member.role == BudgetRole.owner) return;
    final budget = _budget(budgetId);
    budget?.members.remove(member);
    _touch();
  }

  void addCategory(String budgetId, BudgetCategory category) {
    final budget = _budget(budgetId);
    if (budget == null) return;
    budget.categories.insert(0, category);
    _touch();
  }

  void removeCategory(String budgetId, String categoryId) {
    _budget(budgetId)?.categories.removeWhere((category) => category.id == categoryId);
    _touch();
  }

  void addExpense(String budgetId, String categoryId, Expense expense) {
    final category = _category(budgetId, categoryId);
    if (category == null) return;
    category.expenses.insert(0, expense);
    _touch();
  }

  void removeExpense(String budgetId, String categoryId, String expenseId) {
    _category(budgetId, categoryId)?.expenses.removeWhere((expense) => expense.id == expenseId);
    _touch();
  }

  void addIncome(IncomeSource source) {
    incomes.insert(0, source);
    _touch();
  }

  void updatePaycheck(IncomeSource source, {required String name, required double amount, required PayFrequency frequency}) {
    source
      ..name = name
      ..paycheckAmount = amount
      ..frequency = frequency;
    _touch();
  }

  void logSideHustle(String incomeId, IncomePayment payment) {
    final source = _income(incomeId);
    if (source == null || source.kind.isAutomatic) return;
    source.payments.insert(0, payment);
    _touch();
  }

  void removePayment(String incomeId, String paymentId) {
    _income(incomeId)?.payments.removeWhere((payment) => payment.id == paymentId);
    _touch();
  }

  void removeIncome(String incomeId) {
    incomes.removeWhere((income) => income.id == incomeId);
    _touch();
  }

  List<IncomeSource> incomeFor(String budgetId) {
    return incomes.where((income) => income.budgetId == budgetId).toList();
  }

  double expectedIncomeDuring(DateTime month) {
    return incomes.fold(0, (sum, income) => sum + income.expectedDuring(month));
  }

  double spentDuring(DateTime month) {
    return budgets.fold(0, (sum, budget) => sum + budget.spentDuring(month));
  }

  Budget? _budget(String id) {
    for (final budget in budgets) {
      if (budget.id == id) return budget;
    }
    return null;
  }

  BudgetCategory? _category(String budgetId, String categoryId) {
    final budget = _budget(budgetId);
    if (budget == null) return null;
    for (final category in budget.categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  IncomeSource? _income(String id) {
    for (final income in incomes) {
      if (income.id == id) return income;
    }
    return null;
  }

  void _touch() {
    final snapshot = jsonEncode({
      'account': account?.toJson(),
      'signedIn': signedIn,
      'budgets': budgets.map((budget) => budget.toJson()).toList(),
      'incomes': incomes.map((income) => income.toJson()).toList(),
    });
    notifyListeners();
    _tail = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, snapshot);
    });
  }
}

String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final noise = Random().nextInt(0xFFFFFF).toRadixString(16);
  return '$time$noise';
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((item) => decode(Map<String, dynamic>.from(item))).toList();
}
