// 3방향 병합 단위 테스트: npm run test:unit
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { merge3, mergeValue } from '../src/lib/merge.ts';

const lines = (...xs: string[]) => xs.join('\n');

test('한쪽만 바뀌면 그쪽', () => {
  const base = lines('우유', '계란');
  assert.deepEqual(merge3(base, base, lines('우유', '계란', '두부')), { ok: true, text: lines('우유', '계란', '두부') });
  assert.deepEqual(merge3(base, lines('우유'), base), { ok: true, text: lines('우유') });
});

test('서로 다른 줄을 고치면 둘 다 반영', () => {
  const base = lines('우유', '두부 1모', '대파', '양파');
  const mine = lines('우유', '두부 2모', '대파', '양파');
  const theirs = lines('우유', '두부 1모', '대파', '양파 2개');
  assert.deepEqual(merge3(base, mine, theirs), { ok: true, text: lines('우유', '두부 2모', '대파', '양파 2개') });
});

test('바로 옆 줄을 각자 고쳐도 둘 다 반영', () => {
  const base = lines('a', 'b', 'c', 'd');
  const mine = lines('a', 'B', 'c', 'd');
  const theirs = lines('a', 'b', 'C', 'd');
  assert.deepEqual(merge3(base, mine, theirs), { ok: true, text: lines('a', 'B', 'C', 'd') });
});

test('한 사람은 위에 추가, 한 사람은 아래에 추가', () => {
  const base = lines('제목', '본문');
  const mine = lines('맨 위', '제목', '본문');
  const theirs = lines('제목', '본문', '맨 아래');
  assert.deepEqual(merge3(base, mine, theirs), { ok: true, text: lines('맨 위', '제목', '본문', '맨 아래') });
});

test('같은 줄을 서로 다르게 고치면 충돌', () => {
  const base = lines('우유', '두부 1모', '대파');
  assert.deepEqual(merge3(base, lines('우유', '두부 2모', '대파'), lines('우유', '두부 3모', '대파')), { ok: false });
});

test('같은 줄을 똑같이 고치면 충돌 아님', () => {
  const base = lines('a', 'b', 'c');
  const both = lines('a', 'B', 'c');
  assert.deepEqual(merge3(base, lines('a', 'B', 'c', 'd'), both), { ok: true, text: lines('a', 'B', 'c', 'd') });
});

test('한 사람은 줄을 지우고 다른 사람은 다른 줄을 고침', () => {
  const base = lines('1', '2', '3', '4', '5');
  const mine = lines('1', '3', '4', '5');
  const theirs = lines('1', '2', '3', '4', '오');
  assert.deepEqual(merge3(base, mine, theirs), { ok: true, text: lines('1', '3', '4', '오') });
});

test('지운 줄을 다른 사람이 고쳤으면 충돌', () => {
  const base = lines('1', '2', '3');
  assert.deepEqual(merge3(base, lines('1', '3'), lines('1', '이', '3')), { ok: false });
});

test('같은 자리에 서로 다른 줄을 끼워 넣으면 충돌', () => {
  const base = lines('1', '2');
  assert.deepEqual(merge3(base, lines('1', 'x', '2'), lines('1', 'y', '2')), { ok: false });
});

test('빈 메모에서 시작', () => {
  assert.deepEqual(merge3('', 'a', ''), { ok: true, text: 'a' });
  assert.deepEqual(merge3('', 'a', 'b'), { ok: false });
});

test('제목은 통째로 비교', () => {
  assert.deepEqual(mergeValue('장보기', '장보기', '주말 장보기'), { ok: true, text: '주말 장보기' });
  assert.deepEqual(mergeValue('장보기', '마트', '장보기'), { ok: true, text: '마트' });
  assert.deepEqual(mergeValue('장보기', '마트', '시장'), { ok: false });
});
