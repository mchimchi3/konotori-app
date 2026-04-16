import { createMiddleware } from 'hono/factory';
import { HTTPException } from 'hono/http-exception';
import { createClient } from '@supabase/supabase-js';

type AuthVariables = { userId: string; accessToken: string };

export const authMiddleware = createMiddleware<{ Variables: AuthVariables }>(
  async (c, next) => {
    const authHeader = c.req.header('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      throw new HTTPException(401, { message: 'Authorization header is missing' });
    }

    const accessToken = authHeader.replace('Bearer ', '');
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!,
      { global: { headers: { Authorization: `Bearer ${accessToken}` } } }
    );

    const { data: { user }, error } = await supabase.auth.getUser(accessToken);
    if (error || !user) {
      throw new HTTPException(401, { message: 'Invalid or expired token' });
    }

    c.set('userId', user.id);
    c.set('accessToken', accessToken);
    await next();
  }
);
