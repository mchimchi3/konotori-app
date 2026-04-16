import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { HTTPException } from 'hono/http-exception';
import { authMiddleware } from './middleware/auth';
import { babiesRouter } from './routes/babies';
import { usersRouter } from './routes/users';
import { deviceTokensRouter } from './routes/deviceTokens';
import { notificationsRouter } from './routes/notifications';

const app = new Hono();

app.use('*', logger());
app.use('*', cors());

// ヘルスチェック
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }));

// 内部エンドポイント（pg_cronから呼ばれる）
app.route('/internal', notificationsRouter);

// 認証が必要なエンドポイント
const api = new Hono();
api.use('*', authMiddleware);
api.route('/users', usersRouter);
api.route('/babies', babiesRouter);
api.route('/device-tokens', deviceTokensRouter);
app.route('/api/v1', api);

app.onError((err, c) => {
  if (err instanceof HTTPException) return c.json({ error: err.message }, err.status);
  console.error(err);
  return c.json({ error: 'Internal Server Error' }, 500);
});

const port = Number(process.env.PORT) || 3000;
console.log(`Server running on port ${port}`);
serve({ fetch: app.fetch, port });
