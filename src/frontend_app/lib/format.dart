const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String money(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final text = '\$$buffer.${parts[1]}';
  return negative ? '-$text' : text;
}

String dateShort(DateTime date) => '${shortMonths[date.month - 1]} ${date.day}';

String monthYear(DateTime date) => '${monthNames[date.month - 1]} ${date.year}';

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

double? parseMoney(String raw) {
  final cleaned = raw.replaceAll('\$', '').replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
