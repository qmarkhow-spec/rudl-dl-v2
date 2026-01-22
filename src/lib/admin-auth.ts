import type { D1Database } from '@cloudflare/workers-types';
import { fetchAdminUser } from '@/lib/admin';

const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7; // 7 days
const SESSION_TABLE = 'admin_sessions';
let sessionTableEnsured = false;

const ensureSessionTable = async (DB: D1Database) => {
  if (sessionTableEnsured) return;
  await DB.prepare(
    `CREATE TABLE IF NOT EXISTS ${SESSION_TABLE} (
      token TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL
    )`
  ).run();
  await DB.prepare(
    `CREATE INDEX IF NOT EXISTS idx_${SESSION_TABLE}_account
     ON ${SESSION_TABLE} (account_id)`
  ).run();
  sessionTableEnsured = true;
};

const randomToken = (): string => {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  const base = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `adm_${crypto.randomUUID()}_${base}`;
};

export async function createAdminToken(DB: D1Database, uid: string): Promise<string> {
  await ensureSessionTable(DB);
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + TOKEN_TTL_SECONDS;
  const token = randomToken();
  await DB.prepare(
    `INSERT INTO ${SESSION_TABLE} (token, account_id, created_at, expires_at)
     VALUES (?, ?, ?, ?)`
  )
    .bind(token, uid, now, expiresAt)
    .run();
  return token;
}

export async function verifyAdminToken(DB: D1Database, token: string): Promise<string | null> {
  await ensureSessionTable(DB);
  const row = await DB.prepare(
    `SELECT account_id, expires_at FROM ${SESSION_TABLE} WHERE token=? LIMIT 1`
  )
    .bind(token)
    .first<{ account_id?: string | null; expires_at?: number | null }>()
    .catch(() => null);
  if (!row?.account_id || !row.expires_at) return null;
  const now = Math.floor(Date.now() / 1000);
  if (row.expires_at <= now) return null;
  return row.account_id;
}

const parseUidCookie = (cookieHeader: string | null): string | null => {
  if (!cookieHeader) return null;
  const pair = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith('uid='));
  if (!pair) return null;
  const value = pair.slice(4);
  return value || null;
};

export async function resolveAdminUid(request: Request, DB: D1Database): Promise<string | null> {
  const authHeader = request.headers.get('authorization') ?? '';
  if (authHeader.toLowerCase().startsWith('bearer ')) {
    const token = authHeader.slice(7).trim();
    const uid = await verifyAdminToken(DB, token);
    if (uid) {
      const admin = await fetchAdminUser(DB, uid);
      if (admin) return uid;
    }
  }

  const cookieUid = parseUidCookie(request.headers.get('cookie'));
  if (!cookieUid) return null;
  const adminUser = await fetchAdminUser(DB, cookieUid);
  if (!adminUser) return null;
  return cookieUid;
}

const isAllowedOrigin = (origin: string | null): string | null => {
  if (!origin) return null;
  try {
    const url = new URL(origin);
    const host = url.hostname.toLowerCase();
    if (host === 'localhost' || host === '127.0.0.1') return origin;
    if (host === 'mycowbay.com' || host.endsWith('.mycowbay.com')) return origin;
  } catch {
    return null;
  }
  return null;
};

export const buildCorsHeaders = (origin: string | null): HeadersInit => {
  const allowed = isAllowedOrigin(origin);
  if (!allowed) return {};
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE',
    'Access-Control-Allow-Headers': 'content-type, authorization',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
};
