// CI에서 Flutter 웹 빌드를 띄워 실제 화면을 찍는다.
// 전제: API(wrangler dev)가 127.0.0.1:8787, 웹 빌드가 localhost:8080에서 돌고 있음.
// 실행: cd e2e && node budget.mjs
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

async function newPhone(label) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    locale: 'ko-KR',
    timezoneId: 'Asia/Seoul',
  });
  const page = await context.newPage();
  page.on('console', (m) => console.log(`[${label} console:${m.type()}]`, m.text()));
  page.on('pageerror', (e) => console.log(`[${label} pageerror]`, e.message));
  return page;
}

async function shot(page, name) {
  await page.waitForTimeout(1200);
  shotNo += 1;
  const file = `${OUT}/${String(shotNo).padStart(2, '0')}-${name}.png`;
  await page.screenshot({ path: file });
  console.log('📸', file);
}

async function step(page, name, fn) {
  try {
    await fn();
    console.log('✓', name);
  } catch (e) {
    failures += 1;
    console.log('✗', name, '-', e.message.split('\n')[0]);
    await shot(page, `error-${name}`).catch(() => {});
  }
}

const button = (page, name) => page.getByRole('button', { name });

async function typeInto(page, index, text) {
  const box = page.getByRole('textbox').nth(index);
  await box.click();
  await page.waitForTimeout(300);
  await page.keyboard.insertText(text);
  await page.waitForTimeout(300);
}

async function waitForApp(page, text) {
  await page.goto(APP);
  await page.getByText(text).first().waitFor({ timeout: 60_000 });
}

// ── 방장 폰: 시작 → 가계부 만들기 → 복구코드 → 목록
const owner = await newPhone('owner');
await step(owner, 'start', async () => {
  await waitForApp(owner, '새 가계부 만들기');
  await shot(owner, 'start');
});
await step(owner, 'create', async () => {
  await button(owner, '새 가계부 만들기').click();
  await owner.getByText('가계부 이름').waitFor();
  await typeInto(owner, 0, '우리집 생활비');
  await typeInto(owner, 1, '아빠');
  await shot(owner, 'create-ledger');
  await button(owner, '만들기').click();
});
await step(owner, 'recovery-code', async () => {
  await owner.getByText('꼭 저장해 주세요').waitFor({ timeout: 15_000 });
  await shot(owner, 'recovery-code');
  await owner.getByRole('checkbox').click();
  await shot(owner, 'recovery-code-checked');
  await button(owner, '가계부 시작하기').click();
  await owner.getByText('내 가계부').waitFor({ timeout: 15_000 });
  await shot(owner, 'ledger-list-new');
});

// ── 데이터 채우기: 엄마(API로 참여 후 승인, 부방장) + 지출·수입 카테고리 + 이번 달 내역
let inviteCode = '';
await step(owner, 'seed', async () => {
  const [ledger] = sql(
    "SELECT id, invite_code, owner_member_id FROM ledgers WHERE deleted_at IS NULL AND name = '우리집 생활비' ORDER BY created_at DESC LIMIT 1",
  );
  inviteCode = ledger.invite_code;
  const mom = await api(null, 'POST', '/devices', { install_key: randomBytes(32).toString('hex') });
  await api(mom.token, 'POST', '/ledgers/join', { code: inviteCode, nickname: '엄마' });
  sql(
    `UPDATE ledger_members SET status = 'approved', role = 'co_owner', decided_at = datetime('now'), decided_by_member_id = '${ledger.owner_member_id}' WHERE device_id = '${mom.device_id}'`,
  );
  const L = `/ledgers/${ledger.id}`;
  for (const [type, name] of [['expense', '반려동물'], ['expense', '구독료'], ['income', '용돈'], ['income', '부수입']]) {
    await api(mom.token, 'POST', `${L}/categories`, { type, name });
  }
  const { categories } = await api(mom.token, 'GET', `${L}/categories`);
  const cat = (name) => categories.find((c) => c.name === name).id;
  const kst = new Date(Date.now() + 9 * 3600_000);
  const day = (d) => `${kst.toISOString().slice(0, 8)}${String(Math.min(d, kst.getUTCDate())).padStart(2, '0')}`;
  const txs = [
    { type: 'income', amount: 4200000, category_id: cat('급여'), memo: '이번 달 월급', spent_at: day(1) },
    { type: 'expense', amount: 70000, category_id: cat('교통'), memo: '주유', spent_at: day(3) },
    { type: 'expense', amount: 86400, category_id: cat('생활'), memo: '마트 장보기', spent_at: day(5) },
    { type: 'expense', amount: 35000, category_id: cat('반려동물'), memo: '고양이 사료', spent_at: day(6) },
    { type: 'expense', amount: 12000, category_id: cat('식비'), memo: '점심 식사', spent_at: day(7) },
    { type: 'income', amount: 50000, category_id: cat('용돈'), memo: '할머니 용돈', spent_at: day(8) },
    { type: 'expense', amount: 650000, category_id: cat('주거'), memo: '관리비', spent_at: day(9) },
    { type: 'expense', amount: 17000, category_id: cat('구독료'), memo: '영상 구독', spent_at: day(10) },
  ];
  for (const tx of txs) await api(mom.token, 'POST', `${L}/transactions`, tx);
});

// ── 삼촌 폰: 초대코드로 참여 → 승인 대기 카드
const uncle = await newPhone('uncle');
await step(uncle, 'join', async () => {
  await waitForApp(uncle, '초대코드로 참여하기');
  await button(uncle, '초대코드로 참여하기').click();
  await uncle.getByText('가족에게 받은 코드').waitFor();
  await typeInto(uncle, 0, inviteCode);
  await typeInto(uncle, 1, '삼촌');
  await shot(uncle, 'join-filled');
  await button(uncle, '참여 요청 보내기').click();
  // 배지 글자는 카드 접근성 라벨에 합쳐질 수 있어서, 카드 안의 버튼으로 기다린다
  await button(uncle, '요청 취소').waitFor({ timeout: 15_000 });
  await shot(uncle, 'pending-card');
});

// ── 다시 방장 폰: 목록(멤버·요청·지출) → 월별 내역
await step(owner, 'list-with-data', async () => {
  await waitForApp(owner, '내 가계부');
  await owner.getByText('요청 1건').waitFor({ timeout: 15_000 });
  await shot(owner, 'ledger-list');
});
await step(owner, 'ledger-home', async () => {
  await owner.getByText('우리집 생활비').first().click();
  await owner.getByText('이번 달 남은 돈').waitFor({ timeout: 15_000 });
  await owner.getByText('관리비').waitFor({ timeout: 15_000 });
  await shot(owner, 'ledger-home');
});

// ── 내역 추가 (화면에서 직접)
await step(owner, 'add-transaction', async () => {
  await button(owner, '내역 추가').click();
  await owner.getByText('카테고리').first().waitFor({ timeout: 15_000 });
  await typeInto(owner, 0, '23000');
  await button(owner, '식비').first().click();
  await typeInto(owner, 1, '저녁 장보기');
  await shot(owner, 'transaction-new');
  await owner.getByRole('button', { name: '저장', exact: true }).click();
  await owner.getByText('저녁 장보기').waitFor({ timeout: 15_000 });
  await shot(owner, 'ledger-home-added');
});

// ── 달력 보기
await step(owner, 'calendar', async () => {
  await button(owner, '달력 보기').click();
  await owner.getByText('일요일').or(owner.getByText('월요일')).or(owner.getByText('화요일')).or(owner.getByText('수요일'))
    .or(owner.getByText('목요일')).or(owner.getByText('금요일')).or(owner.getByText('토요일')).first()
    .waitFor({ timeout: 15_000 });
  await shot(owner, 'calendar');
});

// ── 카테고리 필터 (전체 화면 → 라벨)
await step(owner, 'filter', async () => {
  await owner.getByRole('button', { name: '필터', exact: true }).click();
  await owner.getByText('카테고리 필터').waitFor({ timeout: 15_000 });
  await button(owner, '식비').first().click();
  await button(owner, '반려동물').first().click();
  await button(owner, '용돈').first().click();
  await shot(owner, 'filter-screen');
  await button(owner, '필터 3개 적용').click();
  await owner.getByText('필터 합계').waitFor({ timeout: 15_000 });
  await shot(owner, 'calendar-filtered');
});

// ── 필터가 많으면 +N
await step(owner, 'filter-overflow', async () => {
  await button(owner, '필터 3개 걸림').click();
  await owner.getByText('카테고리 필터').waitFor({ timeout: 15_000 });
  await button(owner, '생활').first().click();
  await button(owner, '교통').first().click();
  await button(owner, '구독료').first().click();
  await button(owner, '필터 6개 적용').click();
  await owner.getByText('필터 합계').waitFor({ timeout: 15_000 });
  await button(owner, '목록 보기').click();
  await owner.getByText('고양이 사료').waitFor({ timeout: 15_000 });
  await shot(owner, 'list-filtered-overflow');
});

// ── 설정 → 카테고리 관리 → 카테고리 추가
await step(owner, 'categories', async () => {
  await button(owner, '가계부 설정').click();
  await owner.getByText('카테고리 관리').waitFor({ timeout: 15_000 });
  await shot(owner, 'settings');
  await owner.getByText('카테고리 관리').click();
  await owner.getByText('오른쪽 손잡이를 끌어').waitFor({ timeout: 15_000 });
  await shot(owner, 'categories');
  await owner.getByRole('button', { name: '카테고리 추가', exact: true }).click();
  await owner.getByText('라벨 미리보기').waitFor({ timeout: 15_000 });
  await button(owner, '수입').last().click();
  await typeInto(owner, 0, '이자');
  await shot(owner, 'category-add');
  await owner.getByRole('button', { name: '추가', exact: true }).click();
  await owner.getByText('이자').first().waitFor({ timeout: 15_000 });
  await shot(owner, 'categories-income');
});

await browser.close();
console.log(`\n스크린샷 ${shotNo}장, 실패 ${failures}단계`);
process.exit(failures ? 1 : 0);
