/// 1284500 → "1,284,500원"
String won(int amount, {bool signed = false}) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = negative ? '-' : (signed && amount > 0 ? '+' : '');
  return '$sign$buffer원';
}

/// 한국 시간 기준 YYYY-MM
String currentMonth([DateTime? now]) {
  final kst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return '${kst.year}-${kst.month.toString().padLeft(2, '0')}';
}
