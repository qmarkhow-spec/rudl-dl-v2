import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import type { D1Database } from '@cloudflare/workers-types';
import { buildCorsHeaders, resolveAdminUid } from '@/lib/admin-auth';
import { fetchMembers } from '@/lib/members';

type Env = {
  DB?: D1Database;
  ['rudl-app']?: D1Database;
};

export async function OPTIONS(request: Request) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
  return new Response(null, { status: 204, headers: corsHeaders });
}

export async function GET(request: Request) {
  try {
    const corsHeaders = buildCorsHeaders(request.headers.get('origin'));

    const { env } = getCloudflareContext();
    const bindings = env as Env;
    const DB = bindings.DB ?? bindings['rudl-app'];
    if (!DB) {
      return NextResponse.json({ ok: false, error: 'D1 binding DB is missing' }, { status: 500, headers: corsHeaders });
    }

    const adminUid = await resolveAdminUid(request, DB);
    if (!adminUid) {
      return NextResponse.json({ ok: false, error: 'FORBIDDEN' }, { status: 403, headers: corsHeaders });
    }

    const members = await fetchMembers(DB);
    return NextResponse.json({ ok: true, members }, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
    return NextResponse.json({ ok: false, error: message }, { status: 500, headers: corsHeaders });
  }
}
