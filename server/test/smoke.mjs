// 로컬 스모크 테스트: `npm run db:migrate:local && npm run dev` 실행 후 `npm run test:smoke`
// 설계서의 주요 흐름(생성 → 참여 요청 → 승인 → 권한 → 차단/재요청 → 기기 이전 → 방장 복구 → 기존 멤버 연결 → 방장 양도)을 끝까지 돌린다.
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';

const BASE = process.env.BASE ?? 'http://127.0.0.1:8787';
let step = 0;

async function call(token, method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

function ok(name, cond, detail) {
  step += 1;
  assert.ok(cond, `${step}. ${name} 실패: ${JSON.stringify(detail)}`);
  console.log(`  ✓ ${step}. ${name}`);
}

const installKey = () => randomBytes(32).toString('hex');

async function newDevice() {
  const key = installKey();
  const r = await call(null, 'POST', '/devices', { install_key: key });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  return { key, token: r.json.token, id: r.json.device_id };
}

console.log(`스모크 테스트 → ${BASE}`);

// 기기 등록·재설치 복구
const owner = await newDevice();
const b = await newDevice();
const c = await newDevice();
let r = await call(null, 'POST', '/devices', { install_key: owner.key });
ok('같은 설치 키로 재등록하면 409', r.status === 409, r);
r = await call(null, 'POST', '/devices/restore', { install_key: owner.key });
ok('설치 키로 재설치 복구', r.status === 200 && r.json.device_id === owner.id, r);
owner.token = r.json.token;

// 가계부 생성
r = await call(owner.token, 'POST', '/ledgers', { name: '우리집 생활비', nickname: '아빠' });
ok('가계부 생성 + 초대코드·복구코드', r.status === 201 && /^[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(r.json.ledger.invite_code) && r.json.recovery_code.length === 14, r);
const ledgerId = r.json.ledger.id;
const invite = r.json.ledger.invite_code;
let recovery = r.json.recovery_code;
const L = `/ledgers/${ledgerId}`;

// 참여 요청 → 승인
r = await call(b.token, 'POST', '/ledgers/join', { code: invite.toLowerCase().replace('-', ' '), nickname: '엄마' });
ok('초대코드 입력(소문자·공백 허용) → 승인 대기', r.status === 200 && r.json.status === 'pending', r);
r = await call(b.token, 'GET', '/ledgers');
ok('대기 중 목록에서는 역할·금액 숨김', r.json.ledgers[0].status === 'pending' && r.json.ledgers[0].role === null, r);
r = await call(b.token, 'GET', L);
ok('승인 전에는 가계부 접근 403', r.status === 403, r);
r = await call(owner.token, 'GET', `${L}/members`);
ok('방장이 대기 목록 확인', r.json.pending.length === 1 && r.json.pending[0].nickname === '엄마', r);
const bMemberId = r.json.pending[0].id;
r = await call(owner.token, 'POST', `${L}/members/${bMemberId}/approve`);
ok('방장이 승인', r.status === 200, r);
r = await call(b.token, 'GET', L);
ok('승인 후 접근 가능, 멤버는 초대코드 안 보임', r.status === 200 && r.json.invite_code === null && r.json.member.role === 'member', r);

// 카테고리·내역
r = await call(b.token, 'GET', `${L}/categories`);
const food = r.json.categories.find((x) => x.name === '식비');
ok('기본 공통 카테고리 9개', r.json.categories.length === 9 && food.type === 'common', r);
r = await call(b.token, 'POST', `${L}/categories`, { type: 'income', name: '용돈' });
ok('멤버는 카테고리 추가 403', r.status === 403, r);
r = await call(owner.token, 'POST', `${L}/categories`, { type: 'income', name: '용돈' });
ok('방장이 수입 카테고리 추가', r.status === 201 && r.json.type === 'income', r);
const allowance = r.json;
r = await call(owner.token, 'POST', `${L}/categories`, { type: 'expense', name: '식비' });
ok('공통과 같은 이름의 지출 카테고리는 409', r.status === 409, r);

const month = new Date(Date.now() + 9 * 3600_000).toISOString().slice(0, 7);
const today = `${month}-01`;
r = await call(b.token, 'POST', `${L}/transactions`, { type: 'expense', amount: 86400, category_id: food.id, memo: '마트 장보기', spent_at: today });
ok('멤버가 지출 작성', r.status === 201 && r.json.member_nickname === '엄마' && r.json.category_name === '식비', r);
const txId = r.json.id;
r = await call(b.token, 'POST', `${L}/transactions`, { type: 'expense', amount: 1000, category_id: allowance.id, spent_at: today });
ok('지출에 수입 카테고리 쓰면 400', r.status === 400, r);
r = await call(owner.token, 'POST', `${L}/transactions`, { type: 'income', amount: 50000, category_id: allowance.id, spent_at: today });
ok('수입 작성', r.status === 201, r);
r = await call(owner.token, 'GET', `${L}/transactions?month=${month}`);
ok('월별 합계', r.json.summary.expense === 86400 && r.json.summary.income === 50000 && r.json.transactions.length === 2, r);
r = await call(owner.token, 'GET', `${L}/transactions?month=${month}&category_ids=${allowance.id}`);
ok('카테고리 필터', r.json.transactions.length === 1 && r.json.summary.expense === 0, r);
r = await call(owner.token, 'PATCH', `${L}/transactions/${txId}`, { amount: 90000 });
ok('다른 사람 내역 수정', r.status === 200 && r.json.amount === 90000 && r.json.member_nickname === '엄마', r);

// 이름 수정 권한
r = await call(b.token, 'PATCH', L, { name: '해킹' });
ok('멤버는 가계부 이름 수정 403', r.status === 403, r);
r = await call(owner.token, 'PATCH', L, { name: '우리집 가계부' });
ok('방장은 이름 수정', r.status === 200, r);

// 부방장
r = await call(owner.token, 'PATCH', `${L}/members/${bMemberId}/role`, { role: 'co_owner' });
ok('부방장 지정', r.status === 200, r);
r = await call(b.token, 'GET', L);
ok('부방장은 초대코드 보임', r.json.invite_code === invite, r);
r = await call(b.token, 'POST', `${L}/invite-code`);
ok('부방장은 초대코드 재발급 403', r.status === 403, r);

// 차단 → 재요청
r = await call(c.token, 'POST', '/ledgers/join', { code: invite, nickname: '삼촌' });
r = await call(owner.token, 'GET', `${L}/members`);
const cMemberId = r.json.pending[0].id;
await call(b.token, 'POST', `${L}/members/${cMemberId}/approve`);
r = await call(c.token, 'GET', L);
ok('부방장이 승인한 멤버 접근 가능', r.status === 200, r);
r = await call(b.token, 'POST', `${L}/members/${cMemberId}/revoke`);
ok('부방장이 일반 멤버 차단', r.status === 200, r);
r = await call(c.token, 'GET', `${L}/transactions?month=${month}`);
ok('차단된 기기는 즉시 403', r.status === 403, r);
r = await call(c.token, 'POST', '/ledgers/join', { code: invite, nickname: '삼촌' });
r = await call(owner.token, 'GET', `${L}/members`);
ok('재요청은 같은 행이 대기로, "이전에 차단한 멤버" 표시', r.json.pending.length === 1 && r.json.pending[0].id === cMemberId && r.json.pending[0].was_revoked === true, r);
r = await call(b.token, 'POST', `${L}/members/${(await call(owner.token, 'GET', `${L}/members`)).json.members[0].id}/revoke`);
ok('부방장은 방장 차단 403', r.status === 403, r);
await call(owner.token, 'POST', `${L}/members/${cMemberId}/reject`);

// 기기 이전 (이전 폰 있음)
r = await call(b.token, 'POST', '/devices/transfer-codes');
ok('기기 이전 코드 발급', r.status === 201 && r.json.code.length === 9, r);
const transferCode = r.json.code;
const bNew = await newDevice(); // 새 폰에서 앱을 먼저 실행한 상황
r = await call(null, 'POST', '/devices/transfer', { code: transferCode, install_key: bNew.key });
ok('새 폰에서 이전 코드 입력', r.status === 200 && r.json.device_id === b.id, r);
const bNewToken = r.json.token;
r = await call(b.token, 'GET', '/ledgers');
ok('이전 폰 토큰은 401', r.status === 401, r);
r = await call(bNewToken, 'GET', L);
ok('새 폰에서 부방장 권한 그대로', r.status === 200 && r.json.member.role === 'co_owner', r);
r = await call(null, 'POST', '/devices/transfer', { code: transferCode, install_key: installKey() });
ok('이전 코드는 1회용', r.status === 404, r);

// 방장 복구 (이전 폰·코드 모두 없음 → 복구코드)
const ownerNew = await newDevice();
r = await call(ownerNew.token, 'POST', '/ledgers/recover', { code: recovery });
ok('복구코드로 방장 권한 가져오기 + 새 복구코드', r.status === 200 && r.json.recovery_code !== recovery, r);
const oldRecovery = recovery;
recovery = r.json.recovery_code;
r = await call(owner.token, 'GET', L);
ok('이전 방장 기기는 끊김', r.status === 403, r);
r = await call(ownerNew.token, 'GET', L);
ok('새 기기가 방장', r.status === 200 && r.json.member.role === 'owner', r);
r = await call((await newDevice()).token, 'POST', '/ledgers/recover', { code: oldRecovery });
ok('사용한 복구코드는 무효', r.status === 404, r);

// 기존 멤버로 연결 (부방장 폰 분실 → 초대코드 재요청 → 방장이 연결)
const bThird = await newDevice();
await call(bThird.token, 'POST', '/ledgers/join', { code: invite, nickname: '엄마 새폰' });
r = await call(ownerNew.token, 'GET', `${L}/members`);
const reqId = r.json.pending.find((x) => x.nickname === '엄마 새폰').id;
r = await call(ownerNew.token, 'POST', `${L}/members/${reqId}/approve`, { link_to_member_id: bMemberId });
ok('대기 요청을 기존 멤버로 연결', r.status === 200 && r.json.linked === true && r.json.member_id === bMemberId, r);
r = await call(bThird.token, 'GET', L);
ok('새 기기가 기존 멤버(부방장)로 이어짐', r.status === 200 && r.json.member.id === bMemberId && r.json.member.role === 'co_owner', r);
r = await call(bNewToken, 'GET', L);
ok('연결 전 기기는 끊김', r.status === 403, r);

// 방장 양도
r = await call(ownerNew.token, 'POST', `${L}/transfer-owner`, { member_id: bMemberId });
ok('방장 양도 → 기존 방장은 부방장', r.status === 200 && r.json.my_role === 'co_owner', r);
r = await call(bThird.token, 'GET', L);
ok('새 방장에게 복구코드 발급 안내', r.json.member.role === 'owner' && r.json.needs_recovery_code === true, r);
r = await call(bThird.token, 'POST', `${L}/recovery-code`);
ok('새 방장이 복구코드 발급', r.status === 200 && r.json.recovery_code.length === 14, r);
r = await call(bThird.token, 'POST', `${L}/leave`);
ok('방장은 나가기 403', r.status === 403, r);

// 카테고리 삭제 → 미분류
r = await call(bThird.token, 'DELETE', `${L}/categories/${allowance.id}`);
r = await call(bThird.token, 'GET', `${L}/transactions?month=${month}&uncategorized=1`);
ok('카테고리 삭제 시 내역은 미분류로 남음', r.json.transactions.length === 1 && r.json.transactions[0].category_id === null, r);

// 관리 이력
r = await call(bThird.token, 'GET', `${L}/events`);
ok('관리 이력 기록', r.status === 200 && r.json.events.some((e) => e.type === 'link') && r.json.events.some((e) => e.type === 'recover'), r);

// 삭제
r = await call(bThird.token, 'DELETE', L, { confirm_name: '틀린 이름' });
ok('이름이 다르면 삭제 400', r.status === 400, r);
r = await call(bThird.token, 'DELETE', L, { confirm_name: '우리집 가계부' });
ok('가계부 삭제', r.status === 200, r);
r = await call(ownerNew.token, 'GET', L);
ok('삭제된 가계부는 404', r.status === 404, r);

console.log(`\n모든 단계 통과 (${step}개)`);
