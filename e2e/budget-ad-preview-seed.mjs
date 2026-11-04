// 에뮬레이터 광고 미리보기용 데이터 (budget-ad-preview.yml → scripts/budget_ad_preview.sh에서 실행)
// 앱이 처음 실행되며 만든 기기 계정(devices 첫 줄)을 "아빠(방장)"로 만들고, 이번 달 내역을 채운다.
import { execSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const API = process.env.API ?? 'http://127.0.0.1:8787';

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

// 앱 기기 = 가장 먼저 만들어진 기기 (이 스크립트보다 먼저 앱을 띄운다)
const [appDevice] = sql('SELECT id FROM devices ORDER BY created_at LIMIT 1');
if (!appDevice) throw new Error('앱 기기 계정이 아직 없어요');

const owner = await device();
const { ledger, member } = await api(owner.token, 'POST', '/ledgers', { name: '우리집 생활비', nickname: '아빠' });
const L = `/ledgers/${ledger.id}`;
const mom = await device();
await api(mom.token, 'POST', '/ledgers/join', { code: ledger.invite_code, nickname: '엄마' });
sql(`UPDATE ledger_members SET status = 'approved', role = 'co_owner', decided_at = datetime('now'), decided_by_member_id = '${member.id}' WHERE device_id = '${mom.device_id}'`);

const { categories } = await api(owner.token, 'GET', `${L}/categories`);
const cat = (name) => categories.find((c) => c.name === name)?.id ?? null;
const kst = new Date(Date.now() + 9 * 3600_000);
const month = kst.toISOString().slice(0, 7);
const today = kst.getUTCDate();
const day = (d) => `${month}-${String(Math.max(1, Math.min(d, today))).padStart(2, '0')}`;
const rows = [
  [mom, 'income', 4200000, '급여', '월급', 1],
  [mom, 'expense', 650000, '주거', '관리비', 2],
  [owner, 'expense', 70000, '교통', '주유', 2],
  [mom, 'expense', 86400, '생활', '마트 장보기', 3],
  [owner, 'expense', 43000, '식비', '외식', 3],
  [mom, 'expense', 120000, '교육', '영어 학원', 4],
  [owner, 'expense', 28000, '식비', '배달 치킨', 4],
  [mom, 'expense', 32000, '식비', '점심 식사', 5],
];
for (const [who, type, amount, c, memo, d] of rows) {
  await api(who.token, 'POST', `${L}/transactions`, { type, amount, category_id: cat(c), memo, spent_at: day(d) });
}

// 방장 자리를 앱 기기로 옮긴다
sql(`UPDATE ledger_members SET device_id = '${appDevice.id}' WHERE id = '${member.id}'`);
console.log('준비 완료:', ledger.name, '→ 앱 기기', appDevice.id);
