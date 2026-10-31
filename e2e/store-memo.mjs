// 스토어용 한지붕 메모 화면 촬영 (store-screenshots.yml에서 실행)
// 전제: API(wrangler dev)가 127.0.0.1:8787, 웹 빌드가 localhost:8080에서 돌고 있음.
// 결과: OUT 폴더에 01.png ~ 06.png (1206×2622 = 402×874 논리 픽셀 × 3)
//
//  01 메모 목록  02 체크리스트  03 보는 중 표시  04 충돌 화면  05 오프라인 체크  06 멤버 관리
import { chromium } from 'playwright';
import { execSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const OUT = process.env.OUT ?? '../store-assets/memo/raw';
const APP = process.env.APP ?? 'http://localhost:8080';
const API = process.env.API ?? 'http://127.0.0.1:8787';
mkdirSync(OUT, { recursive: true });

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

const device = async () => api(null, 'POST', '/devices', { install_key: randomBytes(32).toString('hex') });

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 402, height: 874 },
  deviceScaleFactor: 3,
  locale: 'ko-KR',
  timezoneId: 'Asia/Seoul',
});
const page = await context.newPage();
page.on('pageerror', (e) => console.log('[pageerror]', e.message));

const text = (t) => page.getByText(t).first();
const button = (name) => page.getByRole('button', { name });

async function shot(name) {
  // 툴팁·hover 표시가 찍히지 않게 마우스를 제목 쪽으로 치운다
  await page.mouse.move(201, 2);
  await page.waitForTimeout(1500);
  const file = `${OUT}/${name}.png`;
  await page.screenshot({ path: file });
  console.log('📸', file);
}

async function typeInto(index, value) {
  const box = page.getByRole('textbox').nth(index);
  await box.click();
  await page.waitForTimeout(300);
  await page.keyboard.insertText(value);
  await page.waitForTimeout(300);
}

async function back() {
  await page.getByRole('button', { name: /Back|뒤로/ }).first().click();
  await page.waitForTimeout(800);
}

// ── 엄마(이 화면)가 메모집을 만든다
await page.goto(APP);
await text('새 메모집 만들기').waitFor({ timeout: 60_000 });
await button('새 메모집 만들기').click();
await text('메모집 이름').waitFor();
await typeInto(0, '우리집 메모');
await typeInto(1, '엄마');
await button('만들기').click();
await text('꼭 저장해 주세요').waitFor({ timeout: 15_000 });
await page.getByRole('checkbox').click();
await button('메모집 시작하기').click();
await text('내 메모집').waitFor({ timeout: 15_000 });

// ── 아빠·딸은 API로 참여, 승인은 DB로
const [nb] = sql(
  "SELECT id, invite_code, owner_member_id FROM ledgers WHERE kind = 'memo' AND deleted_at IS NULL AND name = '우리집 메모' ORDER BY created_at DESC LIMIT 1",
);
const N = `/notebooks/${nb.id}`;
const people = {};
for (const nickname of ['아빠', '딸']) {
  const d = await device();
  await api(d.token, 'POST', '/notebooks/join', { code: nb.invite_code, nickname });
  sql(
    `UPDATE ledger_members SET status = 'approved', decided_at = datetime('now'), decided_by_member_id = '${nb.owner_member_id}' WHERE device_id = '${d.device_id}'`,
  );
  people[nickname] = d.token;
}
const dad = people['아빠'];
const daughter = people['딸'];
// 승인 대기 1건 (멤버 관리 화면용)
const grandma = await device();
await api(grandma.token, 'POST', '/notebooks/join', { code: nb.invite_code, nickname: '할머니' });

// ── 메모 (오래된 것부터 만들어서 목록 순서가 자연스럽게)
await api(dad, 'POST', `${N}/memos`, {
  kind: 'text',
  title: '관리비·공과금 날짜',
  body: '관리비 25일 자동이체\n도시가스 말일\n인터넷 요금 매달 10일',
});
await api(daughter, 'POST', `${N}/memos`, {
  kind: 'text',
  title: '학원 일정',
  body: '월·수 영어 4시\n화·목 수학 5시\n금요일은 쉬는 날',
});
const trip = await api(dad, 'POST', `${N}/memos`, {
  kind: 'checklist',
  title: '제주 여행 준비물',
  items: ['신분증', '충전기', '선크림', '상비약', '수영복'],
});
for (const i of [0, 1]) await api(dad, 'POST', `${N}/memos/${trip.id}/items/${trip.items[i].id}/check`, { checked: true });
const dinner = await api(dad, 'POST', `${N}/memos`, {
  kind: 'text',
  title: '이번 주 저녁 메뉴',
  body: '월 김치찌개\n화 닭갈비\n수 카레\n목 된장찌개\n금 외식',
});
const grocery = await api(daughter, 'POST', `${N}/memos`, {
  kind: 'checklist',
  title: '주말 장보기',
  items: ['우유 2개', '계란 한 판', '두부', '대파', '사과', '휴지'],
});
await api(dad, 'POST', `${N}/memos/${grocery.id}/items/${grocery.items[0].id}/check`, { checked: true });
await api(daughter, 'POST', `${N}/memos/${grocery.id}/items/${grocery.items[1].id}/check`, { checked: true });
await api(daughter, 'PATCH', `${N}/memos/${grocery.id}/pin`, { pinned: true });

// 01 메모 목록
await page.goto(APP);
await text('우리집 메모').waitFor({ timeout: 20_000 });
await text('우리집 메모').click();
await text('주말 장보기').waitFor({ timeout: 15_000 });
await shot('01');

// 02 체크리스트 (엄마가 하나 더 체크)
await text('주말 장보기').click();
await text('계란 한 판').waitFor({ timeout: 15_000 });
await page.getByRole('checkbox').nth(2).click();
await page.waitForTimeout(800);
await shot('02');
await back();

// 03 보는 중 표시: 아빠가 저녁 메뉴를 고치는 중
await api(dad, 'POST', `${N}/memos/${dinner.id}/presence`, { editing: true });
await text('이번 주 저녁 메뉴').click();
await text('고치고 있어요').waitFor({ timeout: 15_000 });
await shot('03');

// 04 충돌 화면: 아빠가 금요일을 바꾼 사이 엄마도 같은 줄을 고침
const cur = await api(dad, 'GET', `${N}/memos/${dinner.id}`);
await api(dad, 'PATCH', `${N}/memos/${dinner.id}`, {
  base_version: cur.version,
  title: cur.title,
  body: cur.body.replace('금 외식', '금 삼겹살 파티'),
});
const body = page.getByRole('textbox').nth(1);
await body.click();
await page.waitForTimeout(300);
await page.keyboard.press('Control+End');
await page.keyboard.insertText(' (초밥)');
await text('다른 멤버가 먼저 고쳤어요').waitFor({ timeout: 15_000 });
await page.getByRole('tab', { name: '내가 쓴 내용' }).click();
await shot('04');
await button('둘 다 남기기').click();
await page.waitForTimeout(1500);
await back();

// 05 오프라인 체크: 여행 준비물
await text('제주 여행 준비물').click();
await text('상비약').waitFor({ timeout: 15_000 });
await context.setOffline(true);
await page.getByRole('checkbox').nth(2).click();
await text('연결되면 반영돼요').waitFor({ timeout: 15_000 });
await shot('05');
await context.setOffline(false);
await page.getByText('연결되면 반영돼요').waitFor({ state: 'detached', timeout: 30_000 });
await back();

// 06 멤버 관리 (참여 요청 1건)
await page.getByRole('button', { name: '메모집 설정' }).click();
await text('멤버 관리').waitFor({ timeout: 15_000 });
await text('멤버 관리').click();
await text('할머니').waitFor({ timeout: 15_000 });
await shot('06');

await browser.close();
console.log('촬영 끝');
