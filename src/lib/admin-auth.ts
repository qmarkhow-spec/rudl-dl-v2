import type { D1Database } from '@cloudflare/workers-types';
import { fetchAdminUser } from '@/lib/admin';

const TOKEN_TTL_SECONDS = 60 * 60 * 12; // 12 hours

const toBase64Url = (input: string): string => {
  if (typeof btoa === 'function') {
    return btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  // Node fallback
  return Buffer.from(input, 'utf-8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
};

const fromBase64Url = (input: string): string => {
  const padded = input.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(input.length / 4) * 4, '=');
  if (typeof atob === 'function') {
    return atob(padded);
  }
  return Buffer.from(padded, 'base64').toString('utf-8');
};

const bytesToBase64Url = (bytes: Uint8Array): string =>
  toBase64Url(String.fromCharCode(...bytes));

const timingSafeEqual = (a: string, b: string): boolean => {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
};

const getSecret = (): string | null => {
  const value = process.env.ADMIN_APP_SECRET;
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
};

const signPayload = async (payload: string, secret: string): Promise<string> => {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload));
  return bytesToBase64Url(new Uint8Array(signature));
};

export async function createAdminToken(uid: string): Promise<string | null> {
  const secret = getSecret();
  if (!secret) return null;
  const exp = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
  const payload = `${uid}.${exp}`;
  const sig = await signPayload(payload, secret);
  return `${toBase64Url(uid)}.${exp}.${sig}`;
}

export async function verifyAdminToken(token: string): Promise<string | null> {
  const secret = getSecret();
  if (!secret) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [uidB64, expRaw, sig] = parts;
  const exp = Number(expRaw);
  if (!Number.isFinite(exp) || exp <= Math.floor(Date.now() / 1000)) {
    return null;
  }
  let uid = '';
  try {
    uid = fromBase64Url(uidB64);
  } catch {
    return null;
  }
  if (!uid) return null;
  const payload = `${uid}.${expRaw}`;
  const expectedSig = await signPayload(payload, secret);
  if (!timingSafeEqual(expectedSig, sig)) return null;
  return uid;
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
    const uid = await verifyAdminToken(token);
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
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'content-type, authorization',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
};
