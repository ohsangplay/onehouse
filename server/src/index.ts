import { Hono } from 'hono';
import type { AppEnv } from './types';
import { ApiError } from './lib/http';
import { devices } from './routes/devices';
import { ledgers } from './routes/ledgers';
import { members } from './routes/members';
import { categories } from './routes/categories';
import { transactions } from './routes/transactions';

const app = new Hono<AppEnv>();

app.get('/', (c) => c.json({ name: 'onehouse-api', ok: true }));

app.route('/devices', devices);
// 하위 경로를 먼저 등록해야 /ledgers/:ledgerId 와 겹치지 않는다
app.route('/ledgers/:ledgerId/members', members);
app.route('/ledgers/:ledgerId/categories', categories);
app.route('/ledgers/:ledgerId/transactions', transactions);
app.route('/ledgers', ledgers);

app.notFound((c) => c.json({ error: { code: 'not_found', message: '없는 경로예요.' } }, 404));

app.onError((err, c) => {
  if (err instanceof ApiError) {
    return c.json({ error: { code: err.code, message: err.message } }, err.status);
  }
  console.error(err);
  return c.json({ error: { code: 'internal', message: '서버 오류가 발생했어요.' } }, 500);
});

export default app;
