import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models.dart';

void main() {
  test('biweekly November has two paychecks', () {
    expect(
      payDatesBetween(PayFrequency.biweekly, DateTime(2026, 10, 24), null, DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
      [DateTime(2026, 11, 7), DateTime(2026, 11, 21)],
    );
  });

  test('biweekly January has three paychecks', () {
    expect(
      payDatesBetween(PayFrequency.biweekly, DateTime(2026, 10, 24), null, DateTime(2027, 1, 1), DateTime(2027, 1, 31)),
      [DateTime(2027, 1, 2), DateTime(2027, 1, 16), DateTime(2027, 1, 30)],
    );
  });

  test('monthly anchor on the 31st clamps in February, then returns to the 31st', () {
    final anchor = DateTime(2027, 1, 31);
    expect(payDatesBetween(PayFrequency.monthly, anchor, null, DateTime(2027, 2, 1), DateTime(2027, 2, 28)), [DateTime(2027, 2, 28)]);
    expect(payDatesBetween(PayFrequency.monthly, anchor, null, DateTime(2027, 3, 1), DateTime(2027, 3, 31)), [DateTime(2027, 3, 31)]);
  });

  test('semimonthly 31st becomes the 30th in a 30 day month', () {
    expect(
      payDatesBetween(PayFrequency.semimonthly, DateTime(2026, 10, 15), 31, DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
      [DateTime(2026, 11, 15), DateTime(2026, 11, 30)],
    );
  });

  test('semimonthly skips dates before the anchor', () {
    expect(
      payDatesBetween(PayFrequency.semimonthly, DateTime(2026, 10, 15), 1, DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      [DateTime(2026, 10, 15)],
    );
  });

  test('future anchor has no paydays yet', () {
    expect(
      payDatesBetween(PayFrequency.biweekly, DateTime(2026, 12, 4), null, DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
      isEmpty,
    );
  });

  test('local expected total counts the real paychecks, not an average', () {
    final paycheck = IncomeSource(
      id: 'test',
      budgetId: 'test',
      name: 'Paycheck',
      kind: IncomeKind.paycheck,
      frequency: PayFrequency.biweekly,
      paycheckAmount: 2000,
      anchorDate: DateTime(2026, 10, 24),
    );
    expect(paycheck.expectedDuring(DateTime(2026, 11, 1)), 4000); // 2 paychecks, not 4333.33
    expect(paycheck.expectedDuring(DateTime(2027, 1, 1)), 6000); // 3 paychecks
  });
}