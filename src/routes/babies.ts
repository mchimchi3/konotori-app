import { Hono } from 'hono';
import { z } from 'zod';
import { supabaseAdmin } from '../lib/supabase';

type Variables = { userId: string };
export const babiesRouter = new Hono<{ Variables: Variables }>();

const babySchema = z.object({
  name: z.string().min(1),
  nickname: z.string().optional(),
  due_date: z.string().optional(),   // ISO date string
  birth_date: z.string().optional(),
  gender: z.enum(['male', 'female', 'unknown']).default('unknown'),
  status: z.enum(['prenatal', 'born']).default('prenatal'),
});

// GET /api/v1/babies
babiesRouter.get('/', async (c) => {
  const userId = c.get('userId');
  const { data, error } = await supabaseAdmin
    .from('babies')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) return c.json({ error: error.message }, 500);
  return c.json(data);
});

// POST /api/v1/babies
babiesRouter.post('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json();
  const parsed = babySchema.safeParse(body);
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);

  const { data: baby, error } = await supabaseAdmin
    .from('babies')
    .insert({ ...parsed.data, user_id: userId })
    .select()
    .single();

  if (error) return c.json({ error: error.message }, 500);

  // 通知スケジュールを生成
  await generateNotificationSchedules(baby.id, parsed.data.due_date, parsed.data.birth_date);

  return c.json(baby, 201);
});

// PUT /api/v1/babies/:id
babiesRouter.put('/:id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('id');
  const body = await c.req.json();
  const parsed = babySchema.partial().safeParse(body);
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);

  // 所有者確認
  const { data: existing } = await supabaseAdmin
    .from('babies')
    .select('id')
    .eq('id', babyId)
    .eq('user_id', userId)
    .single();

  if (!existing) return c.json({ error: 'Baby not found' }, 404);

  const { data, error } = await supabaseAdmin
    .from('babies')
    .update({ ...parsed.data, updated_at: new Date().toISOString() })
    .eq('id', babyId)
    .select()
    .single();

  if (error) return c.json({ error: error.message }, 500);

  // スケジュール再生成
  await supabaseAdmin
    .from('notification_schedules')
    .update({ status: 'cancelled' })
    .eq('baby_id', babyId)
    .eq('status', 'pending');

  await generateNotificationSchedules(babyId, parsed.data.due_date, parsed.data.birth_date);

  return c.json(data);
});

// DELETE /api/v1/babies/:id
babiesRouter.delete('/:id', async (c) => {
  const userId = c.get('userId');
  const babyId = c.req.param('id');

  const { error } = await supabaseAdmin
    .from('babies')
    .delete()
    .eq('id', babyId)
    .eq('user_id', userId);

  if (error) return c.json({ error: error.message }, 500);
  return c.json({ success: true });
});

async function generateNotificationSchedules(
  babyId: string,
  dueDate?: string,
  birthDate?: string
) {
  const { data: templates } = await supabaseAdmin
    .from('notification_templates')
    .select('id, trigger_type, trigger_days, trigger_direction');

  if (!templates) return;

  const schedules = templates
    .map((t) => {
      const baseDate = t.trigger_type === 'due_date' ? dueDate : birthDate;
      if (!baseDate) return null;

      const base = new Date(baseDate);
      const offsetDays = t.trigger_direction === 'before' ? -t.trigger_days : t.trigger_days;
      const scheduledAt = new Date(base);
      scheduledAt.setDate(scheduledAt.getDate() + offsetDays);
      scheduledAt.setHours(9, 0, 0, 0); // 朝9時固定

      if (scheduledAt < new Date()) return null; // 過去はスキップ

      return { baby_id: babyId, template_id: t.id, scheduled_at: scheduledAt.toISOString() };
    })
    .filter(Boolean);

  if (schedules.length > 0) {
    await supabaseAdmin.from('notification_schedules').insert(schedules);
  }
}
