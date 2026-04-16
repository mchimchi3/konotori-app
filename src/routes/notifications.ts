import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { supabaseAdmin } from '../lib/supabase';

export const notificationsRouter = new Hono();

// POST /internal/send-notifications  (pg_cronからのみ呼ばれる)
notificationsRouter.post('/send-notifications', async (c) => {
  const secret = c.req.header('X-Internal-Secret');
  if (secret !== process.env.INTERNAL_API_SECRET) {
    throw new HTTPException(403, { message: 'Forbidden' });
  }

  const now = new Date();
  const windowStart = new Date(now.getTime() - 30 * 60 * 1000); // 30分前
  const windowEnd = new Date(now.getTime() + 30 * 60 * 1000);   // 30分後

  // 送信対象スケジュールを取得
  const { data: schedules, error } = await supabaseAdmin
    .from('notification_schedules')
    .select(`
      id,
      baby_id,
      template_id,
      scheduled_at,
      notification_templates(title, body, content_title, content_body, is_premium_only),
      babies(user_id, name)
    `)
    .eq('status', 'pending')
    .gte('scheduled_at', windowStart.toISOString())
    .lte('scheduled_at', windowEnd.toISOString())
    .limit(100);

  if (error) return c.json({ error: error.message }, 500);
  if (!schedules || schedules.length === 0) return c.json({ sent: 0 });

  let sentCount = 0;
  const errors: string[] = [];

  for (const schedule of schedules) {
    try {
      const baby = schedule.babies as { user_id: string; name: string } | null;
      const template = schedule.notification_templates as {
        title: string; body: string; is_premium_only: boolean
      } | null;

      if (!baby || !template) continue;

      // プレミアム限定チェック
      if (template.is_premium_only) {
        const { data: user } = await supabaseAdmin
          .from('users')
          .select('is_premium')
          .eq('id', baby.user_id)
          .single();
        if (!user?.is_premium) {
          await supabaseAdmin
            .from('notification_schedules')
            .update({ status: 'skipped' })
            .eq('id', schedule.id);
          continue;
        }
      }

      // デバイストークンを取得
      const { data: tokens } = await supabaseAdmin
        .from('device_tokens')
        .select('token')
        .eq('user_id', baby.user_id)
        .eq('is_active', true);

      if (!tokens || tokens.length === 0) {
        await supabaseAdmin
          .from('notification_schedules')
          .update({ status: 'skipped' })
          .eq('id', schedule.id);
        continue;
      }

      // APNs送信
      for (const { token } of tokens) {
        await sendApnsNotification(token, template.title, template.body);
      }

      await supabaseAdmin
        .from('notification_schedules')
        .update({ status: 'sent', sent_at: new Date().toISOString() })
        .eq('id', schedule.id);

      sentCount++;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      errors.push(`schedule ${schedule.id}: ${msg}`);
      await supabaseAdmin
        .from('notification_schedules')
        .update({ status: 'failed', error_message: msg })
        .eq('id', schedule.id);
    }
  }

  return c.json({ sent: sentCount, errors });
});

async function sendApnsNotification(deviceToken: string, title: string, body: string) {
  const teamId = process.env.APNS_TEAM_ID!;
  const keyId = process.env.APNS_KEY_ID!;
  const bundleId = process.env.APNS_BUNDLE_ID!;
  const isProduction = process.env.APNS_ENV === 'production';
  const apnsHost = isProduction
    ? 'api.push.apple.com'
    : 'api.sandbox.push.apple.com';

  const jwt = await generateApnsJwt(teamId, keyId);

  const response = await fetch(
    `https://${apnsHost}/3/device/${deviceToken}`,
    {
      method: 'POST',
      headers: {
        authorization: `bearer ${jwt}`,
        'apns-topic': bundleId,
        'apns-push-type': 'alert',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        aps: { alert: { title, body }, sound: 'default' },
      }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`APNs error ${response.status}: ${text}`);
  }
}

async function generateApnsJwt(teamId: string, keyId: string): Promise<string> {
  const privateKeyPem = process.env.APNS_PRIVATE_KEY!.replace(/\\n/g, '\n');
  const pemBody = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );

  const header = btoa(JSON.stringify({ alg: 'ES256', kid: keyId }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payload = btoa(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    privateKey,
    new TextEncoder().encode(signingInput)
  );

  const sigBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  return `${signingInput}.${sigBase64}`;
}
