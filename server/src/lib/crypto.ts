// 헷갈리는 문자(0/O, 1/I/L)를 뺀 31자
const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

export async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** 기기 토큰: 32바이트 랜덤, base64url */
export function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** 4자리씩 하이픈으로 묶은 코드. groups=2 → 8자(초대·이전 코드), groups=3 → 12자(복구코드) */
export function randomCode(groups: number): string {
  const parts: string[] = [];
  for (let g = 0; g < groups; g++) {
    // 모듈로 편향을 없애려고 248 이상(31*8) 값은 버린다
    let part = '';
    while (part.length < 4) {
      const [byte] = crypto.getRandomValues(new Uint8Array(1));
      if (byte < 248) part += CODE_ALPHABET[byte % 31];
    }
    parts.push(part);
  }
  return parts.join('-');
}

/** 사용자가 입력한 코드를 정규화: 공백·하이픈 제거, 대문자, 4자마다 하이픈 */
export function normalizeCode(input: string): string {
  const raw = input.replace(/[\s-]/g, '').toUpperCase();
  return raw.match(/.{1,4}/g)?.join('-') ?? '';
}

export function newId(): string {
  return crypto.randomUUID();
}
