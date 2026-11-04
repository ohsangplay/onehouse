// 스토어용 한지붕 가계부 화면 촬영 (store-screenshots-budget.yml에서 실행)
// 전제: API(wrangler dev)가 127.0.0.1:8787, 웹 빌드가 localhost:8080에서 돌고 있음.
// 결과: OUT 폴더에 01.png ~ 06.png (1206×2622 = 402×874 논리 픽셀 × 3)
//
//  01 월별 내역  02 달력  03 카테고리 필터  04 내역 추가  05 카테고리 관리  06 멤버 관리
// 촬영하는 날짜와 상관없이 한 달이 꽉 찬 화면이 나오게 "지난달"에 내역을 채우고 지난달로 넘겨서 찍는다.
import { chromium } from 'playwright';
import { execSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const OUT = process.env.OUT ?? '../store-assets/budget/raw';
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
const button = (name, exact = false) => page.getByRole('button', { name, exact });

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

// 한국 시간 기준 지난달 (YYYY-MM)과 그 달의 날짜
const kst = new Date(Date.now() + 9 * 3600_000);
const prev = new Date(Date.UTC(kst.getUTCFullYear(), kst.getUTCMonth() - 1, 1));
const prevMonth = prev.toISOString().slice(0, 7);
const lastDay = new Date(Date.UTC(prev.getUTCFullYear(), prev.getUTCMonth() + 1, 0)).getUTCDate();
const day = (d) => `${prevMonth}-${String(Math.min(d, lastDay)).padStart(2, '0')}`;

let failed = false;
try {
  // ── 아빠(이 화면)가 가계부를 만든다
  await page.goto(APP);
  await text('새 가계부 만들기').waitFor({ timeout: 60_000 });
  await button('새 가계부 만들기').click();
  await text('가계부 이름').waitFor();
  await typeInto(0, '우리집 생활비');
  await typeInto(1, '아빠');
  await button('만들기', true).click();
  await text('꼭 저장해 주세요').waitFor({ timeout: 15_000 });
  await page.getByRole('checkbox').click();
  await button('가계부 시작하기').click();
  await text('내 가계부').waitFor({ timeout: 15_000 });

  // ── 엄마(부방장)·첫째는 API로 참여, 승인은 DB로. 삼촌은 승인 대기
  const [lg] = sql(
    "SELECT id, invite_code, owner_member_id FROM ledgers WHERE kind = 'budget' AND deleted_at IS NULL AND name = '우리집 생활비' ORDER BY created_at DESC LIMIT 1",
  );
  const L = `/ledgers/${lg.id}`;
  const people = {};
  for (const [nickname, role] of [['엄마', 'co_owner'], ['첫째', 'member']]) {
    const d = await device();
    await api(d.token, 'POST', '/ledgers/join', { code: lg.invite_code, nickname });
    sql(
      `UPDATE ledger_members SET status = 'approved', role = '${role}', decided_at = datetime('now'), decided_by_member_id = '${lg.owner_member_id}' WHERE device_id = '${d.device_id}'`,
    );
    people[nickname] = d.token;
  }
  const mom = people['엄마'];
  const kid = people['첫째'];
  const uncle = await device();
  await api(uncle.token, 'POST', '/ledgers/join', { code: lg.invite_code, nickname: '삼촌' });

  // ── 카테고리 + 지난달 내역
  for (const [type, name] of [['expense', '반려동물'], ['expense', '구독료'], ['income', '용돈'], ['income', '부수입']]) {
    await api(mom, 'POST', `${L}/categories`, { type, name });
  }
  const { categories } = await api(mom, 'GET', `${L}/categories`);
  const cat = (name) => categories.find((c) => c.name === name).id;
  const rows = [
    [mom, 'income', 4200000, '급여', '월급', 1],
    [mom, 'expense', 650000, '주거', '관리비', 2],
    [mom, 'expense', 70000, '교통', '주유', 3],
    [mom, 'expense', 86400, '생활', '마트 장보기', 5],
    [kid, 'expense', 12000, '식비', '학교 앞 떡볶이', 6],
    [mom, 'expense', 35000, '반려동물', '고양이 사료', 8],
    [mom, 'expense', 17000, '구독료', '영상 구독', 10],
    [mom, 'expense', 120000, '교육', '영어 학원', 12],
    [mom, 'expense', 43000, '식비', '외식', 14],
    [mom, 'income', 50000, '용돈', '할머니 용돈', 15],
    [kid, 'expense', 9000, '식비', '편의점', 16],
    [mom, 'expense', 58000, '의료', '치과', 18],
    [mom, 'expense', 100000, '경조사', '친구 결혼식', 20],
    [mom, 'expense', 64000, '생활', '생필품', 21],
    [mom, 'income', 300000, '부수입', '중고 거래', 22],
    [mom, 'expense', 28000, '식비', '배달 치킨', 24],
    [mom, 'expense', 15000, '반려동물', '모래', 25],
    [mom, 'expense', 92000, '생활', '주말 장보기', 27],
    [mom, 'expense', 32000, '식비', '점심 식사', 28],
  ];
  for (const [token, type, amount, c, memo, d] of rows) {
    await api(token, 'POST', `${L}/transactions`, { type, amount, category_id: cat(c), memo, spent_at: day(d) });
  }

  // 01 월별 내역 (지난달)
  await page.goto(APP);
  await text('우리집 생활비').waitFor({ timeout: 20_000 });
  await text('우리집 생활비').click();
  await text('남은 돈').waitFor({ timeout: 15_000 });
  await button('이전 달').click();
  await text('점심 식사').waitFor({ timeout: 15_000 });
  await shot('01');

  // 02 달력: 지출이 많은 날을 골라 둔다
  await button('달력 보기').click();
  await button('27일', false).first().click();
  await text('주말 장보기').waitFor({ timeout: 15_000 });
  await shot('02');

  // 03 카테고리 필터 (전체 화면)
  await button('필터', true).click();
  await text('카테고리 필터').waitFor({ timeout: 15_000 });
  await button('식비').first().click();
  await button('반려동물').first().click();
  await button('용돈').first().click();
  await shot('03');
  await button('필터 3개 적용').click();
  await text('필터 합계').waitFor({ timeout: 15_000 });

  // 04 내역 추가
  await button('목록 보기').click();
  await button('내역 추가').click();
  await text('카테고리').waitFor({ timeout: 15_000 });
  await typeInto(0, '23000');
  await button('식비').first().click();
  await typeInto(1, '저녁 장보기');
  await page.keyboard.press('Tab');
  await shot('04');
  await button('닫기').click();
  await page.waitForTimeout(800);

  // 05 카테고리 관리 (지출 탭)
  await button('가계부 설정').click();
  await text('카테고리 관리').waitFor({ timeout: 15_000 });
  await text('카테고리 관리').click();
  await text('오른쪽 손잡이를 끌어').waitFor({ timeout: 15_000 });
  await button('지출 2').click();
  await text('반려동물').waitFor({ timeout: 15_000 });
  await shot('05');
  await back();

  // 06 멤버 관리 (참여 요청 1건)
  await text('멤버 관리').click();
  await text('참여 요청 1').waitFor({ timeout: 15_000 });
  await shot('06');
} catch (e) {
  failed = true;
  console.log('✗ 촬영 실패:', e.message.split('\n')[0]);
  await page.screenshot({ path: `${OUT}/error.png` }).catch(() => {});
}
await browser.close();
console.log(failed ? '촬영 실패' : '촬영 끝');
process.exit(failed ? 1 : 0);
