import type { Context } from 'hono';
import type { ContentfulStatusCode } from 'hono/utils/http-status';

export class ApiError extends Error {
  constructor(
    public status: ContentfulStatusCode,
    public code: string,
    message: string,
    /** 오류 응답에 함께 실을 값 (예: 충돌 시 지금 저장된 메모) */
    public extra?: Record<string, unknown>,
  ) {
    super(message);
  }
}

export const badRequest = (code: string, message: string) => new ApiError(400, code, message);
export const forbidden = (code: string, message: string) => new ApiError(403, code, message);
export const notFound = (code: string, message: string) => new ApiError(404, code, message);
export const conflict = (code: string, message: string) => new ApiError(409, code, message);

export async function readJson(c: Context): Promise<Record<string, unknown>> {
  try {
    const body = await c.req.json();
    if (body && typeof body === 'object' && !Array.isArray(body)) return body as Record<string, unknown>;
  } catch {
    // 아래에서 처리
  }
  throw badRequest('invalid_json', '요청 본문이 올바른 JSON 객체가 아니에요.');
}

export function str(
  body: Record<string, unknown>,
  key: string,
  opts: { min?: number; max?: number; optional?: boolean } = {},
): string | undefined {
  const value = body[key];
  if (value === undefined || value === null || value === '') {
    if (opts.optional) return undefined;
    throw badRequest('missing_field', `${key} 값이 필요해요.`);
  }
  if (typeof value !== 'string') throw badRequest('invalid_field', `${key} 값은 문자열이어야 해요.`);
  const trimmed = value.trim();
  if (opts.min !== undefined && trimmed.length < opts.min) {
    throw badRequest('invalid_field', `${key} 값이 너무 짧아요.`);
  }
  if (opts.max !== undefined && trimmed.length > opts.max) {
    throw badRequest('invalid_field', `${key} 값은 ${opts.max}자 이하여야 해요.`);
  }
  return trimmed;
}

export function reqStr(body: Record<string, unknown>, key: string, opts: { min?: number; max?: number } = {}): string {
  return str(body, key, opts) as string;
}

export function oneOf<T extends string>(value: unknown, allowed: readonly T[], key: string): T {
  if (typeof value === 'string' && (allowed as readonly string[]).includes(value)) return value as T;
  throw badRequest('invalid_field', `${key} 값은 ${allowed.join(', ')} 중 하나여야 해요.`);
}

export function now(): string {
  return new Date().toISOString();
}
