import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import { fetchDashboardPage } from '@/lib/dashboard';
import { buildCorsHeaders } from '@/lib/cors';


type Env = {
  DB?: D1Database;
  ['rudl-app']?: D1Database;
};

export async function GET(req: Request) {
  const corsHeaders = buildCorsHeaders(req.headers.get('origin'), { allowCredentials: true });
  try {
    const cookieHeader = req.headers.get('cookie') ?? '';
    const uid =
      cookieHeader
        .split(';')
        .map((part) => part.trim())
        .find((part) => part.startsWith('uid='))?.split('=')[1] ?? null;
    if (!uid) {
      return NextResponse.json(
        { ok: false, error: 'UNAUTHENTICATED' },
        { status: 401, headers: corsHeaders }
      );
    }

    const { searchParams } = new URL(req.url);
    const page = Number(searchParams.get('page') ?? '1');
    const pageSize = Number(searchParams.get('pageSize') ?? '10');

    const { env } = getCloudflareContext();
    const bindings = env as Env;
    const DB = bindings.DB ?? bindings['rudl-app'];
    if (!DB) {
      return NextResponse.json(
        { ok: false, error: 'D1 binding DB is missing' },
        { status: 500, headers: corsHeaders }
      );
    }

    const data = await fetchDashboardPage(DB, uid, page, pageSize);
    return NextResponse.json({ ok: true, ...data }, { headers: corsHeaders });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ ok: false, error: message }, { status: 500, headers: corsHeaders });
  }
}

export async function OPTIONS(request: Request) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'), { allowCredentials: true });
  return new NextResponse(null, { status: 204, headers: corsHeaders });
}
