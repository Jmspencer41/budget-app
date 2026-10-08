import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('expenses count toward the budget and show up this month', (tester) async {
    await tester.pumpWidget(const BudgetApp());
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder_shared_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-budget')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('budget-name-field')), 'Household');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Household'), findsWidgets);
    await tester.tap(find.text('Household').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-expense')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expense-label-field')), 'Groceries');
    await tester.enterText(find.byKey(const Key('expense-amount-field')), '42.50');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('\$42.50'), findsWidgets);

    await tester.tap(find.byKey(const Key('add-member')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-name-field')), 'Jordan');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Jordan'), findsOneWidget);

    await tester.pumpWidget(const BudgetApp(key: Key('reloaded')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.folder_shared_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Household'), findsWidgets);
    await tester.tap(find.text('Household').first);
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);
  });

  testWidgets('a side hustle total updates when money is logged', (tester) async {
    await tester.pumpWidget(const BudgetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.folder_shared_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-budget')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('budget-name-field')), 'Household');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.trending_up));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-income')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Side hustle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('income-name-field')), 'Weekends');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Weekends'), findsOneWidget);
    expect(find.text('\$0.00'), findsWidgets);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-amount-field')), '80');
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();

    expect(find.text('\$80.00'), findsWidgets);
  });
}
