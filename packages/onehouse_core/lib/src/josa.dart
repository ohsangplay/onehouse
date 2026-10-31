/// 받침 여부에 맞는 조사. josa('메모집', '을', '를') → '메모집을'
String josa(String word, String withFinal, String withoutFinal) {
  if (word.isEmpty) return word + withoutFinal;
  final last = word.codeUnitAt(word.length - 1);
  final isHangul = last >= 0xAC00 && last <= 0xD7A3;
  final hasFinal = isHangul && (last - 0xAC00) % 28 != 0;
  return word + (hasFinal ? withFinal : withoutFinal);
}
