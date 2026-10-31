// CI에서 한지붕 메모 웹 빌드를 띄워 실제 화면을 찍는다.
// 전제: API(wrangler dev)가 127.0.0.1:8787, 웹 빌드가 localhost:8080에서 돌고 있음.
// 실행: cd e2e && node memo.mjs
//
// 흐름: 메모집 만들기 → (엄마는 API로 참여·작성) → 메모 목록 → 보는 중 표시 → 자동 병합 → 충돌 화면
//       → 체크리스트 → 오프라인 체크 → 다시 연결 → 설정·멤버 관리
import { chromium } from 'playwright';
import { execSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const OUT = process.env.OUT ?? '../ci-out/screenshots';
const APP = process.env.APP ?? 'http://localhost:8080';
const API = process.env.API ?? 'http://127.0.0.1:8787';
mkdirSync(OUT, { recursive: true });

let shotNo = 0;
let failures = 0;

function sql(command) {
  const out = execSync(`npx wrangler d1 execute onehouse --local --json --command ${JSON.stringify(command)}`, {
    cwd: '../server',
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });
  return JSON.parse(out)[0].results;
}

async function api(token, method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json();
  if (res.status >= 400) throw new Error(`${method} ${path} → ${res.status} ${JSON.stringify(json)}`);
  return json;
}

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  locale: 'ko-KR',
  timezoneId: 'Asia/Seoul',
});
const page = await context.newPage();
page.on('pageerror', (e) => console.log('[pageerror]', e.message));

async function shot(name) {
  await page.waitForTimeout(1200);
  shotNo += 1;
  const file = `${OUT}/${String(shotNo).padStart(2, '0')}-${name}.png`;
  await page.screenshot({ path: file });
  console.log('📸', file);
}

async function step(name, fn) {
  try {
    await fn();
    console.log('✓', name);
  } catch (e) {
    failures += 1;
    console.log('✗', name, '-', e.message.split('\n')[0]);
    await shot(`error-${name}`).catch(() => {});
  }
}

const button = (name) => page.getByRole('button', { name });
const text = (t) => page.getByText(t).first();

async function typeInto(index, value) {
  const box = page.getByRole('textbox').nth(index);
  await box.click();
  await page.waitForTimeout(300);
  await page.keyboard.insertText(value);
  await page.waitForTimeout(300);
}

/** 본문 맨 끝에 글자를 붙인다 */
async function appendToBody(value) {
  const box = page.getByRole('textbox').nth(1);
  await box.click();
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+End');
  await page.keyboard.insertText(value);
}

async function back() {
  await page.getByRole('button', { name: /Back|뒤로/ }).first().click();
  await page.waitForTimeout(800);
}

// ── 시작 → 메모집 만들기 → 복구코드 → 목록
await step('start', async () => {
  await page.goto(APP);
  await text('새 메모집 만들기').waitFor({ timeout: 60_000 });
  await shot('start');
});
await step('create', async () => {
  await button('새 메모집 만들기').click();
  await text('메모집 이름').waitFor();
  await typeInto(0, '우리집 메모');
  await typeInto(1, '아빠');
  await button('만들기').click();
  await text('꼭 저장해 주세요').waitFor({ timeout: 15_000 });
  await shot('recovery-code');
  await page.getByRole('checkbox').click();
  await button('메모집 시작하기').click();
  await text('내 메모집').waitFor({ timeout: 15_000 });
  await shot('notebook-list');
});

// ── 엄마: API로 참여(승인은 DB) 후 메모 작성
let mom;
let N = '';
let groceryId = '';
await step('seed', async () => {
  const [nb] = sql(
    "SELECT id, invite_code, owner_member_id FROM ledgers WHERE kind = 'memo' AND deleted_at IS NULL AND name = '우리집 메모' ORDER BY created_at DESC LIMIT 1",
  );
  mom = await api(null, 'POST', '/devices', { install_key: randomBytes(32).toString('hex') });
  await api(mom.token, 'POST', '/notebooks/join', { code: nb.invite_code, nickname: '엄마' });
  sql(
    `UPDATE ledger_members SET status = 'approved', decided_at = datetime('now'), decided_by_member_id = '${nb.owner_member_id}' WHERE device_id = '${mom.device_id}'`,
  );
  N = `/notebooks/${nb.id}`;
  await api(mom.token, 'POST', `${N}/memos`, { kind: 'text', title: '와이파이', body: '이름: onehouse-5G\n비밀번호: 우리집1234' });
  const cl = await api(mom.token, 'POST', `${N}/memos`, {
    kind: 'checklist',
    title: '여행 준비물',
    items: ['여권', '충전기', '선크림', '상비약'],
  });
  await api(mom.token, 'POST', `${N}/memos/${cl.id}/items/${cl.items[0].id}/check`, { checked: true });
  const g = await api(mom.token, 'POST', `${N}/memos`, { kind: 'text', title: '장보기', body: '우유\n두부 1모\n대파\n양파' });
  groceryId = g.id;
  await api(mom.token, 'PATCH', `${N}/memos/${groceryId}/pin`, { pinned: true });
  // 다른 사람 화면에 "참여 요청 1건"이 보이게
  const aunt = await api(null, 'POST', '/devices', { install_key: randomBytes(32).toString('hex') });
  await api(aunt.token, 'POST', '/notebooks/join', { code: nb.invite_code, nickname: '이모' });
});

await step('memo-list', async () => {
  await page.goto(APP);
  await text('요청 1건').waitFor({ timeout: 20_000 });
  await shot('notebook-list-with-data');
  await text('우리집 메모').click();
  await text('여행 준비물').waitFor({ timeout: 15_000 });
  await shot('memo-list');
});

// ── 보는 중 표시: 엄마가 같은 메모를 고치는 중
await step('presence', async () => {
  await api(mom.token, 'POST', `${N}/memos/${groceryId}/presence`, { editing: true });
  await text('장보기').click();
  await text('고치고 있어요').waitFor({ timeout: 15_000 });
  await shot('text-memo-viewers');
});

// ── 자동 병합: 엄마는 첫 줄, 아빠(화면)는 마지막 줄
await step('auto-merge', async () => {
  const cur = await api(mom.token, 'GET', `${N}/memos/${groceryId}`);
  await api(mom.token, 'PATCH', `${N}/memos/${groceryId}`, {
    base_version: cur.version,
    title: '장보기',
    body: '우유 2개\n두부 1모\n대파\n양파',
  });
  await appendToBody(' 3개');
  await text('합쳐서 저장했어요').waitFor({ timeout: 15_000 });
  await text('우유 2개').waitFor({ timeout: 5_000 });
  await shot('auto-merged');
});

// ── 충돌: 같은 줄(두 번째 줄 끝 = 마지막 줄)을 서로 다르게
await step('conflict', async () => {
  const cur = await api(mom.token, 'GET', `${N}/memos/${groceryId}`);
  await api(mom.token, 'PATCH', `${N}/memos/${groceryId}`, {
    base_version: cur.version,
    title: '장보기',
    body: cur.body.replace(/양파.*$/, '양파 1망'),
  });
  await appendToBody(' (큰 거)');
  await text('다른 멤버가 먼저 고쳤어요').waitFor({ timeout: 15_000 });
  await shot('conflict-saved');
  await page.getByRole('tab', { name: '내가 쓴 내용' }).click();
  await shot('conflict-mine');
  await button('둘 다 남기기').click();
  await text('새 메모로 저장했어요').waitFor({ timeout: 10_000 });
  await shot('conflict-kept-both');
  await back();
  await text('(내 수정본)').waitFor({ timeout: 15_000 });
  await shot('memo-list-after-conflict');
});

// ── 체크리스트: 체크 → 오프라인 체크 → 다시 연결
await step('checklist', async () => {
  await text('여행 준비물').click();
  await text('충전기').waitFor({ timeout: 15_000 });
  await page.getByRole('checkbox').nth(1).click();
  await shot('checklist');
});
await step('offline-check', async () => {
  await context.setOffline(true);
  await page.getByRole('checkbox').nth(2).click();
  await text('연결되면 반영돼요').waitFor({ timeout: 15_000 });
  await shot('checklist-offline');
  await context.setOffline(false);
  await page.getByText('연결되면 반영돼요').waitFor({ state: 'detached', timeout: 30_000 });
  await shot('checklist-back-online');
  const memos = await api(mom.token, 'GET', `${N}/memos`);
  const cl = memos.memos.find((m) => m.kind === 'checklist');
  if (cl.checked_count !== 3) throw new Error(`서버 체크 수 ${cl.checked_count} (3이어야 함)`);
});

// ── 설정·멤버 관리
await step('settings', async () => {
  await back();
  await text('여행 준비물').waitFor({ timeout: 15_000 });
  await page.getByRole('button', { name: '메모집 설정' }).click();
  await text('초대코드').waitFor({ timeout: 15_000 });
  await shot('settings');
  await text('멤버 관리').click();
  await text('참여 요청 1').waitFor({ timeout: 15_000 });
  await shot('members');
});

await browser.close();
console.log(`\n스크린샷 ${shotNo}장, 실패 ${failures}단계`);
process.exit(failures ? 1 : 0);
