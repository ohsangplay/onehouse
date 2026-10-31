/// 충돌 화면에서 강조할 줄: 상대 쪽에 같은 줄이 없는 줄의 번호.
/// 정확한 diff는 아니지만 "어디가 다른지"를 보여주기엔 충분하다.
Set<int> changedLines(String text, String other) {
  final otherCounts = <String, int>{};
  for (final line in other.split('\n')) {
    otherCounts[line] = (otherCounts[line] ?? 0) + 1;
  }
  final changed = <int>{};
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final left = otherCounts[lines[i]] ?? 0;
    if (left > 0) {
      otherCounts[lines[i]] = left - 1;
    } else {
      changed.add(i);
    }
  }
  return changed;
}
