import type { Context } from 'hono';
import type { AppEnv } from '../types';
import { ApiError } from './http';

/**
 * 고정 윈도우 방식의 시도 횟수 제한. 코드 입력 API(초대·복구·이전)에 쓴다.
 * key 예: `join:<ip>`
 */
export async function rateLimit(
  c: Context<AppEnv>,
  scope: string,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const ip = c.req.header('CF-Connecting-IP') ?? 'local';
  const key = `${scope}:${ip}`;
  const nowSec = Math.floor(Date.now() / 1000);
  const windowStart = nowSec - (nowSec % windowSeconds);

  const row = await c.env.DB.prepare(
    `INSERT INTO rate_limits (key, count, window_start) VALUES (?1, 1, ?2)
     ON CONFLICT(key) DO UPDATE SET
       count = CASE WHEN rate_limits.window_start = ?2 THEN rate_limits.count + 1 ELSE 1 END,
       window_start = ?2
     RETURNING count`,
  )
    .bind(key, windowStart)
    .first<{ count: number }>();

  if (row && row.count > limit) {
    throw new ApiError(429, 'too_many_attempts', '시도 횟수가 너무 많아요. 잠시 후 다시 시도해 주세요.');
  }
}
