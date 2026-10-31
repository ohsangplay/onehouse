/// "방금", "3분 전", "2시간 전", "어제", "10월 3일", "2025년 10월 3일"
String relativeTime(DateTime time, [DateTime? now]) {
  final current = (now ?? DateTime.now()).toLocal();
  final t = time.toLocal();
  final diff = current.difference(t);
  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return '${diff.inHours}시간 전';
  if (today.difference(day).inDays == 1) return '어제';
  if (t.year == current.year) return '${t.month}월 ${t.day}일';
  return '${t.year}년 ${t.month}월 ${t.day}일';
}
