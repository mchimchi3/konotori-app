import { Hono } from 'hono';
import { z } from 'zod';
import { supabaseAdmin } from '../lib/supabase';

type Variables = { userId: string };
export const usersRouter = new Hono<{ Variables: Variables }>();

const upsertSchema = z.object({
  display_name: z.string().optional(),
  locale: z.string().default('ja'),
  timezone: z.string().default('Asia/Tokyo'),
});

// GET /api/v1/users/me
usersRouter.get('/me', async (c) => {
  const userId = c.get('userId');
  const { data, error } = await supabaseAdmin
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) return c.json({ error: error.message }, 500);
  if (!data) return c.json({ error: 'User not found' }, 404);
  return c.json(data);
});

// POST /api/v1/users/me  (upsert on first login)
usersRouter.post('/me', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const parsed = upsertSchema.safeParse(body);
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);

  const { data, error } = await supabaseAdmin
    .from('users')
    .upsert({ id: userId, ...parsed.data, updated_at: new Date().toISOString() })
    .select()
    .single();

  if (error) return c.json({ error: error.message }, 500);
  return c.json(data, 201);
});

// PUT /api/v1/users/me
usersRouter.put('/me', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const parsed = upsertSchema.safeParse(body);
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);

  const { data, error } = await supabaseAdmin
    .from('users')
    .update({ ...parsed.data, updated_at: new Date().toISOString() })
    .eq('id', userId)
    .select()
    .single();

  if (error) return c.json({ error: error.message }, 500);
  return c.json(data);
});
