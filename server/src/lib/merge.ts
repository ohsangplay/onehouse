/**
 * 줄 단위 3방향 병합 (git merge와 같은 원리).
 *
 * base: 내가 고치기 시작한 원본, mine: 내가 고친 것, theirs: 그 사이 다른 사람이 저장한 것.
 * 서로 다른 줄을 고쳤으면 둘 다 반영하고, 같은 줄을 서로 다르게 고쳤을 때만 충돌로 본다.
 */

export type MergeResult = { ok: true; text: string } | { ok: false };

// 메모가 아주 길면 비교 비용이 커서 병합하지 않고 충돌로 처리한다 (줄 수 곱 기준)
const MAX_CELLS = 4_000_000;

/** LCS로 base의 각 줄이 other의 몇 번째 줄과 짝인지 (없으면 -1) */
function matchLines(base: string[], other: string[]): number[] | null {
  const n = base.length;
  const m = other.length;
  if ((n + 1) * (m + 1) > MAX_CELLS) return null;

  // 앞뒤 공통 부분은 바로 짝을 지어 표를 줄인다
  let head = 0;
  while (head < n && head < m && base[head] === other[head]) head++;
  let tail = 0;
  while (tail < n - head && tail < m - head && base[n - 1 - tail] === other[m - 1 - tail]) tail++;

  const result = new Array<number>(n).fill(-1);
  for (let i = 0; i < head; i++) result[i] = i;
  for (let k = 0; k < tail; k++) result[n - 1 - k] = m - 1 - k;

  const b = base.slice(head, n - tail);
  const o = other.slice(head, m - tail);
  const bn = b.length;
  const on = o.length;
  if (bn === 0 || on === 0) return result;

  // dp[i][j] = b[i..], o[j..]의 LCS 길이
  const width = on + 1;
  const dp = new Uint32Array((bn + 1) * width);
  for (let i = bn - 1; i >= 0; i--) {
    for (let j = on - 1; j >= 0; j--) {
      dp[i * width + j] =
        b[i] === o[j] ? dp[(i + 1) * width + j + 1] + 1 : Math.max(dp[(i + 1) * width + j], dp[i * width + j + 1]);
    }
  }
  let i = 0;
  let j = 0;
  while (i < bn && j < on) {
    if (b[i] === o[j]) {
      result[head + i] = head + j;
      i++;
      j++;
    } else if (dp[(i + 1) * width + j] >= dp[i * width + j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return result;
}

const sameLines = (x: string[], y: string[]) => x.length === y.length && x.every((v, i) => v === y[i]);

/** 바뀐 덩어리 하나를 합친다. 셋의 줄 수가 같으면 줄마다 따로 판단한다 (서로 다른 줄을 고친 경우) */
function mergeChunk(base: string[], mine: string[], theirs: string[]): string[] | null {
  if (sameLines(mine, base)) return theirs;
  if (sameLines(theirs, base)) return mine;
  if (sameLines(mine, theirs)) return mine;
  if (base.length === mine.length && base.length === theirs.length) {
    const out: string[] = [];
    for (let k = 0; k < base.length; k++) {
      if (mine[k] === base[k]) out.push(theirs[k]);
      else if (theirs[k] === base[k] || theirs[k] === mine[k]) out.push(mine[k]);
      else return null;
    }
    return out;
  }
  return null;
}

export function merge3(base: string, mine: string, theirs: string): MergeResult {
  if (mine === theirs) return { ok: true, text: mine };
  if (mine === base) return { ok: true, text: theirs };
  if (theirs === base) return { ok: true, text: mine };

  const o = base.split('\n');
  const a = mine.split('\n');
  const b = theirs.split('\n');
  const ma = matchLines(o, a);
  const mb = matchLines(o, b);
  if (!ma || !mb) return { ok: false };

  const out: string[] = [];
  let i = 0;
  let ia = 0;
  let ib = 0;
  for (;;) {
    // 셋 모두 같은 줄이 이어지는 구간
    while (i < o.length && ma[i] === ia && mb[i] === ib) {
      out.push(o[i]);
      i++;
      ia++;
      ib++;
    }
    if (i >= o.length && ia >= a.length && ib >= b.length) break;

    // 다음으로 셋이 다시 만나는 원본 줄
    let j = i;
    while (j < o.length && (ma[j] === -1 || mb[j] === -1)) j++;
    const ea = j < o.length ? ma[j] : a.length;
    const eb = j < o.length ? mb[j] : b.length;

    const merged = mergeChunk(o.slice(i, j), a.slice(ia, ea), b.slice(ib, eb));
    if (!merged) return { ok: false };
    out.push(...merged);
    i = j;
    ia = ea;
    ib = eb;
  }
  return { ok: true, text: out.join('\n') };
}

/** 제목처럼 한 덩어리인 값: 한쪽만 바뀌었으면 그쪽, 둘 다 다르게 바뀌었으면 충돌 */
export function mergeValue(base: string, mine: string, theirs: string): MergeResult {
  if (mine === theirs || theirs === base) return { ok: true, text: mine };
  if (mine === base) return { ok: true, text: theirs };
  return { ok: false };
}
