import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import type { D1Database } from '@cloudflare/workers-types';
import { decodePasswordRecord, hashPassword } from '@/lib/pw';
import { buildCorsHeaders, createAdminToken } from '@/lib/admin-auth';

type Env = {
  DB?: D1Database;
  ['rudl-app']?: D1Database;
};

type LoginPayload = {
  email?: string;
  password?: string;
};

export async function OPTIONS(request: Request) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
  return new Response(null, { status: 204, headers: corsHeaders });
}

export async function POST(request: Request) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
  const { env } = getCloudflareContext();
  const bindings = env as Env;
  const DB = bindings.DB ?? bindings['rudl-app'];
  if (!DB) {
    return NextResponse.json({ ok: false, error: 'D1 binding DB is missing' }, { status: 500, headers: corsHeaders });
  }

  const body = (await request.json().catch(() => ({}))) as LoginPayload;
  const email = typeof body.email === 'string' ? body.email.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!email || !password) {
    return NextResponse.json({ ok: false, error: 'INVALID_CREDENTIALS' }, { status: 400, headers: corsHeaders });
  }

  try {
    const user = await DB.prepare('SELECT id, pw_hash, role FROM users WHERE email=? LIMIT 1')
      .bind(email)
      .first<{ id: string; pw_hash: string; role?: string | null }>();

    if (!user || (user.role ?? '').toLowerCase() !== 'admin') {
      return NextResponse.json({ ok: false, error: 'FORBIDDEN' }, { status: 403, headers: corsHeaders });
    }

    const parsed = decodePasswordRecord(user.pw_hash);
    if (!parsed?.saltHex) {
      return NextResponse.json({ ok: false, error: 'INVALID_CREDENTIALS' }, { status: 401, headers: corsHeaders });
    }

    const derived = await hashPassword(password, parsed.saltHex);
    if (derived !== parsed.hashHex) {
      return NextResponse.json({ ok: false, error: 'INVALID_CREDENTIALS' }, { status: 401, headers: corsHeaders });
    }

    const token = await createAdminToken(DB, user.id);

    return NextResponse.json({ ok: true, token, uid: user.id }, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ ok: false, error: message }, { status: 500, headers: corsHeaders });
  }
}
