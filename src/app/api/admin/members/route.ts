import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import type { D1Database } from '@cloudflare/workers-types';
import { fetchAdminUser } from '@/lib/admin';
import { fetchMembers } from '@/lib/members';

type Env = {
  DB?: D1Database;
  ['rudl-app']?: D1Database;
};

const parseUid = (cookieHeader: string | null): string | null => {
  if (!cookieHeader) return null;
  const pair = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith('uid='));
  if (!pair) return null;
  const value = pair.slice(4);
  return value || null;
};

export async function GET(request: Request) {
  try {
    const uid = parseUid(request.headers.get('cookie'));
    if (!uid) {
      return NextResponse.json({ ok: false, error: 'UNAUTHENTICATED' }, { status: 401 });
    }

    const { env } = getCloudflareContext();
    const bindings = env as Env;
    const DB = bindings.DB ?? bindings['rudl-app'];
    if (!DB) {
      return NextResponse.json({ ok: false, error: 'D1 binding DB is missing' }, { status: 500 });
    }

    const adminUser = await fetchAdminUser(DB, uid);
    if (!adminUser) {
      return NextResponse.json({ ok: false, error: 'FORBIDDEN' }, { status: 403 });
    }

    const members = await fetchMembers(DB);
    return NextResponse.json({ ok: true, members });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ ok: false, error: message }, { status: 500 });
  }
}
