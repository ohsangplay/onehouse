// 광고 미리보기(ad-preview.yml)용 데이터 채우기.
// 에뮬레이터 앱이 영문 이름으로 만든 메모집을 한글 이름으로 바꾸고, 다른 멤버를 넣어 메모를 채운다.
// 전제: API(wrangler dev)가 127.0.0.1:8787
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

const [nb] = sql(
  "SELECT id, invite_code, owner_member_id FROM ledgers WHERE kind = 'memo' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1",
);
if (!nb) throw new Error('앱이 만든 메모집이 없어요');
sql(`UPDATE ledgers SET name = '우리집 메모' WHERE id = '${nb.id}'`);
sql(`UPDATE ledger_members SET nickname = '엄마' WHERE id = '${nb.owner_member_id}'`);
const N = `/notebooks/${nb.id}`;

const people = {};
for (const nickname of ['아빠', '딸']) {
  const d = await api(null, 'POST', '/devices', { install_key: randomBytes(32).toString('hex') });
  await api(d.token, 'POST', '/notebooks/join', { code: nb.invite_code, nickname });
  sql(
    `UPDATE ledger_members SET status = 'approved', decided_at = datetime('now'), decided_by_member_id = '${nb.owner_member_id}' WHERE device_id = '${d.device_id}'`,
  );
  people[nickname] = d.token;
}
const dad = people['아빠'];
const daughter = people['딸'];

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
await api(dad, 'POST', `${N}/memos`, {
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
await api(daughter, 'PATCH', `${N}/memos/${grocery.id}/pin`, { pinned: true });

// 휴지통 화면용
const old = await api(daughter, 'POST', `${N}/memos`, { kind: 'text', title: '지난주 장보기', body: '우유\n식빵' });
await api(daughter, 'DELETE', `${N}/memos/${old.id}`);

console.log('데이터 채움:', nb.id);
