// 한지붕 메모 스모크 테스트: `npm run dev` 실행 후 `npm run test:smoke:memo`
// 메모집 공유 → 메모 동시 수정(자동 병합·충돌) → 체크리스트(항목별 저장·체크·충돌) → 보는 중 표시 → 휴지통 → 종류 분리
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';

const BASE = process.env.BASE ?? 'http://127.0.0.1:8787';
let step = 0;

async function call(token, method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}

function ok(name, cond, detail) {
  step += 1;
  assert.ok(cond, `${step}. ${name} 실패: ${JSON.stringify(detail)}`);
  console.log(`  ✓ ${step}. ${name}`);
}

async function newDevice() {
  const r = await call(null, 'POST', '/devices', { install_key: randomBytes(32).toString('hex') });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  return r.json.token;
}

console.log(`메모 스모크 테스트 → ${BASE}`);

const dad = await newDevice();
const mom = await newDevice();
const kid = await newDevice();

// 메모집 만들기·참여
let r = await call(dad, 'POST', '/notebooks', { name: '우리집 메모', nickname: '아빠' });
ok('메모집 생성 + 초대코드·복구코드', r.status === 201 && r.json.recovery_code.length === 14, r);
const N = `/notebooks/${r.json.ledger.id}`;
const invite = r.json.ledger.invite_code;

r = await call(dad, 'GET', `${N}/categories`);
ok('메모집에는 가계부 카테고리 API가 없음', r.status === 404, r);
r = await call(dad, 'GET', `/ledgers/${N.split('/')[2]}`);
ok('가계부 API로 메모집을 열 수 없음', r.status === 404, r);
r = await call(dad, 'GET', '/ledgers');
ok('가계부 목록에는 메모집이 안 보임', r.json.ledgers.length === 0, r);

r = await call(mom, 'POST', '/notebooks/join', { code: invite, nickname: '엄마' });
ok('초대코드로 참여 요청', r.json.status === 'pending', r);
r = await call(kid, 'POST', '/ledgers/join', { code: invite, nickname: '아이' });
ok('메모집 코드를 가계부 앱에 넣으면 404', r.status === 404, r);
await call(kid, 'POST', '/notebooks/join', { code: invite, nickname: '아이' });
r = await call(dad, 'GET', `${N}/members`);
for (const p of r.json.pending) await call(dad, 'POST', `${N}/members/${p.id}/approve`);
r = await call(mom, 'GET', '/notebooks');
ok('승인 후 메모집 목록', r.json.notebooks.length === 1 && r.json.notebooks[0].role === 'member' && r.json.notebooks[0].memo_count === 0, r);
const momMemberId = r.json.notebooks[0].member_id;

// 글 메모
r = await call(dad, 'POST', `${N}/memos`, { kind: 'text', title: '장보기', body: '우유\n두부 1모\n대파\n양파' });
ok('글 메모 작성 (버전 1)', r.status === 201 && r.json.version === 1 && r.json.created_by.nickname === '아빠', r);
const memoId = r.json.id;
const M = `${N}/memos/${memoId}`;

r = await call(mom, 'PATCH', M, { base_version: 1, title: '장보기', body: '우유\n두부 2모\n대파\n양파' });
ok('엄마가 고침 → 버전 2', r.status === 200 && r.json.memo.version === 2 && r.json.merged === false && r.json.memo.updated_by.nickname === '엄마', r);

r = await call(dad, 'PATCH', M, { base_version: 1, title: '장보기', body: '우유\n두부 1모\n대파\n양파 2개' });
ok('아빠가 버전 1 기준으로 다른 줄 고침 → 자동 병합', r.status === 200 && r.json.merged === true && r.json.memo.version === 3 && r.json.memo.body === '우유\n두부 2모\n대파\n양파 2개', r);

r = await call(dad, 'PATCH', M, { base_version: 3, title: '장보기', body: '우유\n두부 2모\n대파\n양파 2개' });
ok('바뀐 게 없으면 버전 그대로', r.status === 200 && r.json.memo.version === 3, r);

r = await call(kid, 'PATCH', M, { base_version: 1, title: '장보기', body: '우유\n두부 5모\n대파\n양파' });
ok('같은 줄을 다르게 고치면 409 + 지금 저장된 메모', r.status === 409 && r.json.error.code === 'edit_conflict' && r.json.current.version === 3 && r.json.current.body.includes('두부 2모'), r);

r = await call(kid, 'PATCH', M, { base_version: r.json.current.version, title: '장보기', body: '우유\n두부 5모\n대파\n양파' });
ok('"내 내용으로 저장" = 지금 버전 기준으로 다시 저장', r.status === 200 && r.json.memo.version === 4 && r.json.memo.body.includes('두부 5모'), r);

r = await call(mom, 'PATCH', M, { base_version: 4, title: '주말 장보기' });
ok('제목만 고침', r.status === 200 && r.json.memo.title === '주말 장보기' && r.json.memo.body.includes('두부 5모'), r);
r = await call(dad, 'PATCH', M, { base_version: 4, title: '마트' });
ok('제목을 서로 다르게 고치면 충돌', r.status === 409, r);

r = await call(dad, 'PATCH', M, { base_version: 9, body: 'x' });
ok('없는 버전 기준이면 400', r.status === 400, r);

// 고정·목록
await call(dad, 'POST', `${N}/memos`, { kind: 'text', title: '와이파이', body: '비밀번호 1234' });
r = await call(mom, 'PATCH', `${M}/pin`, { pinned: true });
ok('고정', r.status === 200, r);
r = await call(kid, 'GET', `${N}/memos`);
ok('고정한 메모가 먼저', r.json.memos.length === 2 && r.json.memos[0].id === memoId && r.json.memos[0].pinned === true, r);

// 체크리스트
r = await call(mom, 'POST', `${N}/memos`, { kind: 'checklist', title: '여행 준비물', items: ['여권', '충전기', '우산'] });
ok('체크리스트 작성 + 첫 항목', r.status === 201 && r.json.items.length === 3 && r.json.body === '', r);
const C = `${N}/memos/${r.json.id}`;
const [passport, charger, umbrella] = r.json.items;

r = await call(dad, 'POST', `${C}/items/${passport.id}/check`, { checked: true });
ok('아빠가 여권 체크', r.json.checked === true && r.json.checked_by === '아빠', r);
r = await call(kid, 'POST', `${C}/items`, { text: '선크림' });
ok('동시에 아이가 항목 추가 (충돌 없음)', r.status === 201 && r.json.sort_order === 3, r);
r = await call(mom, 'PATCH', `${C}/items/${charger.id}`, { base_version: 1, text: '충전기 2개' });
ok('엄마가 항목 글자 고침', r.status === 200 && r.json.version === 2, r);
r = await call(dad, 'PATCH', `${C}/items/${charger.id}`, { base_version: 1, text: '보조배터리' });
ok('같은 항목을 다르게 고치면 409 + 지금 항목', r.status === 409 && r.json.error.code === 'item_conflict' && r.json.current.text === '충전기 2개', r);
r = await call(dad, 'PATCH', `${C}/items/${charger.id}`, { base_version: 1, text: '충전기 2개' });
ok('같은 글자로 고치면 충돌 아님', r.status === 200, r);
r = await call(dad, 'POST', `${C}/items/${charger.id}/check`, { checked: true });
r = await call(mom, 'POST', `${C}/items/${charger.id}/check`, { checked: false });
ok('체크는 마지막 요청이 이김', r.json.checked === false && r.json.checked_by === null, r);
r = await call(mom, 'DELETE', `${C}/items/${umbrella.id}`);
r = await call(dad, 'POST', `${C}/items/${umbrella.id}/check`, { checked: true });
ok('지운 항목을 체크하면 404 (오프라인 체크 재전송 시 버림)', r.status === 404 && r.json.error.code === 'item_deleted', r);
r = await call(dad, 'GET', C);
ok('체크리스트 조회: 항목·체크 상태', r.json.items.length === 3 && r.json.items[0].checked === true && r.json.updated_by.nickname === '엄마', r);
r = await call(kid, 'PUT', `${C}/items/order`, { ids: [r.json.items[2].id, r.json.items[0].id] });
ok('순서 바꾸기 (목록에 없는 항목은 뒤로)', r.json.items.map((i) => i.text).join(',') === '선크림,여권,충전기 2개', r);
r = await call(dad, 'POST', `${C}/items/clear-checked`);
ok('체크한 항목 지우기', r.json.removed === 1, r);
r = await call(dad, 'GET', `${N}/memos`);
const cl = r.json.memos.find((m) => m.kind === 'checklist');
ok('목록에 체크리스트 미리보기·개수', cl.item_count === 2 && cl.checked_count === 0 && cl.preview.startsWith('선크림'), cl);

// 보는 중 표시
r = await call(mom, 'POST', `${M}/presence`, { editing: true });
ok('엄마 presence (다른 사람 없음)', r.status === 200 && r.json.viewers.length === 0 && r.json.version === 5, r);
r = await call(dad, 'POST', `${M}/presence`, {});
ok('아빠 화면에 "엄마가 고치는 중"', r.json.viewers.length === 1 && r.json.viewers[0].nickname === '엄마' && r.json.viewers[0].editing === true, r);
r = await call(kid, 'GET', M);
ok('메모 조회에도 보는 사람 포함', r.json.viewers.length === 2, r);
await call(mom, 'DELETE', `${M}/presence`);
r = await call(dad, 'POST', `${M}/presence`, {});
ok('엄마가 나가면 사라짐', r.json.viewers.length === 0, r);

// 삭제·휴지통
r = await call(kid, 'DELETE', M);
ok('남이 쓴 메모는 일반 멤버가 못 지움', r.status === 403, r);
r = await call(dad, 'PATCH', `${N}/members/${momMemberId}/role`, { role: 'co_owner' });
ok('엄마를 부방장으로', r.status === 200, r);
r = await call(mom, 'DELETE', M);
ok('부방장은 지울 수 있음 → 휴지통', r.status === 200 && r.json.trash_days === 30, r);
r = await call(kid, 'PATCH', M, { base_version: 5, body: '새 내용' });
ok('지워진 메모를 저장하면 404 memo_deleted', r.status === 404 && r.json.error.code === 'memo_deleted', r);
r = await call(kid, 'GET', `${N}/memos/trash`);
ok('휴지통 목록', r.json.memos.length === 1 && r.json.memos[0].deleted_by === '엄마' && r.json.memos[0].can_restore === false, r);
r = await call(dad, 'POST', `${M}/restore`);
ok('쓴 사람이 되살림', r.status === 200 && r.json.deleted_at === null && r.json.version === 5, r);

// 멤버 상세 통계, 목록
r = await call(dad, 'GET', `${N}/members/${momMemberId}`);
ok('멤버 상세: 쓴 메모·고친 횟수', r.json.memo_count === 1 && r.json.edit_count >= 2 && r.json.month_expense === undefined, r);
r = await call(dad, 'GET', '/notebooks');
ok('목록에 메모 개수', r.json.notebooks[0].memo_count === 3 && r.json.notebooks[0].last_updated_at !== null, r);

// 차단되면 바로 못 봄
r = await call(dad, 'GET', `${N}/members`);
const kidId = r.json.members.find((m) => m.nickname === '아이').id;
await call(dad, 'POST', `${N}/members/${kidId}/revoke`);
r = await call(kid, 'GET', `${N}/memos`);
ok('차단된 기기는 메모 403', r.status === 403, r);

console.log(`\n모든 단계 통과 (${step}개)`);
