import { Hono } from 'hono';
import type { AppEnv, DeviceRow } from '../types';
import { newId, normalizeCode, randomCode, randomToken, sha256 } from '../lib/crypto';
import { conflict, notFound, now, readJson, reqStr } from '../lib/http';
import { rateLimit } from '../lib/rateLimit';
import { requireDevice } from '../middleware/auth';

const TRANSFER_CODE_MINUTES = 10;

export const devices = new Hono<AppEnv>();

/** 최초 실행: 앱이 만든 설치 키로 기기 계정 생성 */
devices.post('/', async (c) => {
  const body = await readJson(c);
  const installKey = reqStr(body, 'install_key', { min: 32, max: 256 });
  const installKeyHash = await sha256(installKey);

  const existing = await c.env.DB.prepare('SELECT id FROM devices WHERE install_key_hash = ?')
    .bind(installKeyHash)
    .first();
  if (existing) throw conflict('device_exists', '이미 등록된 기기예요. /devices/restore 를 사용해 주세요.');

  const id = newId();
  const token = randomToken();
  const ts = now();
  await c.env.DB.prepare(
    'INSERT INTO devices (id, install_key_hash, token_hash, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?)',
  )
    .bind(id, installKeyHash, await sha256(token), ts, ts)
    .run();

  return c.json({ device_id: id, token }, 201);
});

/** 같은 폰 재설치: Keychain/Block Store에 남아 있던 설치 키로 기존 계정에 다시 붙는다 */
devices.post('/restore', async (c) => {
  await rateLimit(c, 'restore', 20, 3600);
  const body = await readJson(c);
  const installKey = reqStr(body, 'install_key', { min: 32, max: 256 });

  const device = await c.env.DB.prepare('SELECT * FROM devices WHERE install_key_hash = ?')
    .bind(await sha256(installKey))
    .first<DeviceRow>();
  if (!device) throw notFound('device_not_found', '등록된 기기를 찾을 수 없어요.');

  const token = randomToken();
  await c.env.DB.prepare('UPDATE devices SET token_hash = ?, last_seen_at = ? WHERE id = ?')
    .bind(await sha256(token), now(), device.id)
    .run();

  return c.json({ device_id: device.id, token });
});

/** 이전 폰에서: 1회용 기기 이전 코드 발급 (10분) */
devices.post('/transfer-codes', requireDevice, async (c) => {
  const device = c.var.device;
  const code = randomCode(2);
  const expiresAt = new Date(Date.now() + TRANSFER_CODE_MINUTES * 60_000).toISOString();

  await c.env.DB.batch([
    // 아직 안 쓴 이전 코드는 하나만 유효하게
    c.env.DB.prepare('DELETE FROM device_transfer_codes WHERE device_id = ? AND used_at IS NULL').bind(device.id),
    c.env.DB.prepare(
      'INSERT INTO device_transfer_codes (id, device_id, code_hash, expires_at) VALUES (?, ?, ?, ?)',
    ).bind(newId(), device.id, await sha256(code), expiresAt),
  ]);

  return c.json({ code, expires_at: expiresAt }, 201);
});

/**
 * 새 폰에서: 이전 코드 + 새 폰의 설치 키 → 같은 기기 계정에 새 토큰.
 * 이전 폰 토큰은 즉시 무효가 되고, 모든 가계부·권한이 그대로 따라온다.
 */
devices.post('/transfer', async (c) => {
  await rateLimit(c, 'transfer', 10, 600);
  const body = await readJson(c);
  const code = normalizeCode(reqStr(body, 'code', { max: 20 }));
  const installKey = reqStr(body, 'install_key', { min: 32, max: 256 });

  const row = await c.env.DB.prepare(
    `SELECT * FROM device_transfer_codes
     WHERE code_hash = ? AND used_at IS NULL AND expires_at > ?`,
  )
    .bind(await sha256(code), now())
    .first<{ id: string; device_id: string }>();
  if (!row) throw notFound('invalid_transfer_code', '이전 코드가 맞지 않거나 만료됐어요.');

  const newInstallKeyHash = await sha256(installKey);
  const taken = await c.env.DB.prepare('SELECT id FROM devices WHERE install_key_hash = ? AND id != ?')
    .bind(newInstallKeyHash, row.device_id)
    .first<{ id: string }>();

  const token = randomToken();
  const ts = now();
  const stmts: D1PreparedStatement[] = [];
  if (taken) {
    // 새 폰에서 앱을 먼저 실행해 빈 기기 계정이 생긴 경우: 그 계정이 아무 가계부에도 없을 때만 정리
    const used = await c.env.DB.prepare('SELECT 1 FROM ledger_members WHERE device_id = ? LIMIT 1')
      .bind(taken.id)
      .first();
    if (used) throw conflict('device_in_use', '이 폰은 이미 다른 가계부를 쓰고 있어서 이전할 수 없어요.');
    stmts.push(c.env.DB.prepare('DELETE FROM device_transfer_codes WHERE device_id = ?').bind(taken.id));
    stmts.push(c.env.DB.prepare('DELETE FROM devices WHERE id = ?').bind(taken.id));
  }
  stmts.push(
    c.env.DB.prepare('UPDATE device_transfer_codes SET used_at = ? WHERE id = ?').bind(ts, row.id),
    c.env.DB.prepare(
      'UPDATE devices SET install_key_hash = ?, token_hash = ?, last_seen_at = ? WHERE id = ?',
    ).bind(newInstallKeyHash, await sha256(token), ts, row.device_id),
  );
  await c.env.DB.batch(stmts);

  return c.json({ device_id: row.device_id, token });
});
