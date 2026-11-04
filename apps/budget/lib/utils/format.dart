/// 1284500 → "1,284,500"
String comma(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 1284500 → "1,284,500원"
String won(int amount, {bool signed = false}) {
  final sign = amount < 0 ? '-' : (signed && amount > 0 ? '+' : '');
  return '$sign${comma(amount.abs())}원';
}

/// 달력 칸에 들어가는 짧은 금액: 8000 → "8,000", 18000 → "1.8만", 4200000 → "420만"
String compactWon(int amount) {
  final abs = amount.abs();
  if (abs < 10000) return comma(abs);
  final man = abs / 10000;
  final text = man >= 100 ? man.round().toString() : man.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  return '$text만';
}

/// "86,400" 같은 입력 → 86400. 숫자가 없으면 0
int parseAmount(String text) => int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// 한국 시간 기준 오늘
DateTime todayKst([DateTime? now]) {
  final kst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return DateTime(kst.year, kst.month, kst.day);
}

/// 한국 시간 기준 YYYY-MM
String currentMonth([DateTime? now]) => monthKey(todayKst(now));

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

String dateKey(DateTime d) => '${monthKey(d)}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDate(String ymd) {
  final p = ymd.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// "2026-10" + 1 → "2026-11"
String addMonths(String month, int delta) {
  final p = month.split('-').map(int.parse).toList();
  return monthKey(DateTime(p[0], p[1] + delta));
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "27일 화요일"
String dayHeading(DateTime d) => '${d.day}일 ${_weekdays[d.weekday - 1]}요일';

/// "2026. 10. 27 (화)"
String dateLabel(DateTime d) =>
    '${d.year}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')} (${_weekdays[d.weekday - 1]})';

/// "2026년 10월"
String monthLabel(String month) {
  final p = month.split('-');
  return '${p[0]}년 ${int.parse(p[1])}월';
}
