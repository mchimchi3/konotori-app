import { Hono } from 'hono';
import { z } from 'zod';
import { supabaseAdmin } from '../lib/supabase';

type Variables = { userId: string };
export const deviceTokensRouter = new Hono<{ Variables: Variables }>();

const tokenSchema = z.object({ token: z.string().min(1) });

// POST /api/v1/device-tokens
deviceTokensRouter.post('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const parsed = tokenSchema.safeParse(body);
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);

  const { error } = await supabaseAdmin
    .from('device_tokens')
    .upsert({ user_id: userId, token: parsed.data.token, is_active: true });

  if (error) return c.json({ error: error.message }, 500);
  return c.json({ success: true }, 201);
});

// DELETE /api/v1/device-tokens  (ログアウト時に無効化)
deviceTokensRouter.delete('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const parsed = tokenSchema.safeParse(body);
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);

  await supabaseAdmin
    .from('device_tokens')
    .update({ is_active: false })
    .eq('user_id', userId)
    .eq('token', parsed.data.token);

  return c.json({ success: true });
});
