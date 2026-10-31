/** 받침 여부에 맞는 조사. josa('메모집', '을', '를') → '메모집을' */
export function josa(word: string, withFinal: string, withoutFinal: string): string {
  const last = word.charCodeAt(word.length - 1);
  const isHangul = last >= 0xac00 && last <= 0xd7a3;
  const hasFinal = isHangul && (last - 0xac00) % 28 !== 0;
  return word + (hasFinal ? withFinal : withoutFinal);
}
