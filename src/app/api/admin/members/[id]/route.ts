import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import type { D1Database, R2Bucket } from '@cloudflare/workers-types';
import { buildCorsHeaders, resolveAdminUid } from '@/lib/admin-auth';
import { deleteDownloadStatsForLink } from '@/lib/downloads';


type EnvBindings = {
  DB?: D1Database;
  ['rudl-app']?: D1Database;
  R2_BUCKET?: R2Bucket;
};

type RouteParams = { id: string };

const jsonError = (error: string, status = 400, headers?: HeadersInit) =>
  NextResponse.json({ ok: false, error }, { status, headers });

export async function OPTIONS(request: Request) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
  return new Response(null, { status: 204, headers: corsHeaders });
}

const toNumberOrNull = (value: unknown): number | null => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    const parsed = Number(trimmed);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

export async function PATCH(request: Request, context: { params: Promise<RouteParams> }) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
  const { id } = await context.params;
  const memberId = (id ?? '').trim();
  if (!memberId) {
    return jsonError('INVALID_MEMBER_ID', 400, corsHeaders);
  }
  const { env } = getCloudflareContext();
  const bindings = env as EnvBindings;
  const DB = bindings.DB ?? bindings['rudl-app'];
  if (!DB) {
    return NextResponse.json({ ok: false, error: 'D1_NOT_AVAILABLE' }, { status: 500, headers: corsHeaders });
  }

  const adminUid = await resolveAdminUid(request, DB);
  if (!adminUid) {
    return NextResponse.json({ ok: false, error: 'FORBIDDEN' }, { status: 403, headers: corsHeaders });
  }

  let payload: Partial<{
    role: unknown;
    setBalance: unknown;
    adjustBalance: unknown;
  }>;
  try {
    payload = (await request.json()) as Partial<{
      role: unknown;
      setBalance: unknown;
      adjustBalance: unknown;
    }>;
  } catch {
    return jsonError('INVALID_PAYLOAD', 400, corsHeaders);
  }

  const nextRoleRaw = typeof payload.role === 'string' ? payload.role.trim().toLowerCase() : null;
  const nextRole = nextRoleRaw === 'admin' || nextRoleRaw === 'user' ? nextRoleRaw : null;
  const setBalanceValue = toNumberOrNull(payload.setBalance);
  const adjustBalanceValue = toNumberOrNull(payload.adjustBalance);

  try {
    const userRow = await DB.prepare('SELECT id, email, role FROM users WHERE id=? LIMIT 1')
      .bind(memberId)
      .first<{ id: string; email?: string | null; role?: string | null }>();
    if (!userRow) {
      return NextResponse.json({ ok: false, error: 'NOT_FOUND' }, { status: 404, headers: corsHeaders });
    }

    const balanceRow = await DB.prepare('SELECT balance FROM users WHERE id=? LIMIT 1')
      .bind(memberId)
      .first<{ balance?: number | null }>();
    const currentBalance = Number(balanceRow?.balance ?? 0);

    let workingBalance = currentBalance;
    const ledgerEntries: Array<{ delta: number; reason: string }> = [];

    if (setBalanceValue !== null) {
      const delta = setBalanceValue - workingBalance;
      if (Number.isFinite(delta) && delta !== 0) {
        ledgerEntries.push({ delta, reason: 'admin:set' });
      }
      workingBalance = setBalanceValue;
    }

    if (adjustBalanceValue !== null && adjustBalanceValue !== 0) {
      workingBalance += adjustBalanceValue;
      if (Number.isFinite(adjustBalanceValue) && adjustBalanceValue !== 0) {
        ledgerEntries.push({ delta: adjustBalanceValue, reason: 'admin:adjust' });
      }
    }

    const updates: Array<Promise<unknown>> = [];
    const now = Math.floor(Date.now() / 1000);

    if (nextRole && nextRole !== (userRow.role ?? '').toLowerCase()) {
      updates.push(DB.prepare('UPDATE users SET role=? WHERE id=?').bind(nextRole, memberId).run());
    }

    if (workingBalance !== currentBalance) {
      updates.push(DB.prepare('UPDATE users SET balance=? WHERE id=?').bind(workingBalance, memberId).run());
    }

    if (ledgerEntries.length) {
      await Promise.all(
        ledgerEntries.map(async ({ delta, reason }) => {
          const ledgerId = crypto.randomUUID();
          await DB.prepare(
            `INSERT INTO point_ledger (id, account_id, delta, reason, link_id, download_id, bucket_minute, platform, created_at)
             VALUES (?, ?, ?, ?, NULL, NULL, NULL, NULL, ?)`
          )
            .bind(ledgerId, memberId, delta, reason, now)
            .run()
            .catch(() => undefined);
        })
      );
    }

    if (updates.length) {
      await Promise.all(updates);
    }

    return NextResponse.json({
      ok: true,
      user: {
        id: memberId,
        role: nextRole ?? userRow.role ?? null,
        balance: workingBalance,
      },
    }, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ ok: false, error: message || 'UPDATE_FAILED' }, { status: 500, headers: corsHeaders });
  }
}

export async function DELETE(request: Request, context: { params: Promise<RouteParams> }) {
  const corsHeaders = buildCorsHeaders(request.headers.get('origin'));
  const { id } = await context.params;
  const memberId = (id ?? '').trim();
  if (!memberId) {
    return jsonError('INVALID_MEMBER_ID', 400, corsHeaders);
  }
  const { env } = getCloudflareContext();
  const bindings = env as EnvBindings;
  const DB = bindings.DB ?? bindings['rudl-app'];
  const R2 = bindings.R2_BUCKET;
  if (!DB || !R2) {
    return NextResponse.json({ ok: false, error: 'MISSING_BINDINGS' }, { status: 500, headers: corsHeaders });
  }

  const adminUid = await resolveAdminUid(request, DB);
  if (!adminUid) {
    return NextResponse.json({ ok: false, error: 'FORBIDDEN' }, { status: 403, headers: corsHeaders });
  }
  if (adminUid === memberId) {
    return NextResponse.json({ ok: false, error: 'CANNOT_DELETE_SELF' }, { status: 400, headers: corsHeaders });
  }

  try {
    const memberExists = await DB.prepare('SELECT id FROM users WHERE id=? LIMIT 1')
      .bind(memberId)
      .first<{ id: string }>();
    if (!memberExists) {
      return NextResponse.json({ ok: false, error: 'NOT_FOUND' }, { status: 404, headers: corsHeaders });
    }

    const linkRows = await DB.prepare('SELECT id FROM links WHERE owner_id=?').bind(memberId).all();
    const linkIds = ((linkRows.results as Array<{ id?: string }> | undefined) ?? [])
      .map((row) => (row.id ? String(row.id) : null))
      .filter((value): value is string => Boolean(value));

    const r2Keys: string[] = [];
    for (const linkId of linkIds) {
      const fileRows = await DB.prepare('SELECT r2_key FROM files WHERE link_id=?')
        .bind(linkId)
        .all();
      const keys = ((fileRows.results as Array<{ r2_key?: string | null }> | undefined) ?? [])
        .map((row) => (row.r2_key ? String(row.r2_key) : null))
        .filter((value): value is string => Boolean(value));
      r2Keys.push(...keys);
    }

    const deleteStatements: D1PreparedStatement[] = [];
    for (const linkId of linkIds) {
      deleteStatements.push(DB.prepare('DELETE FROM files WHERE link_id=?').bind(linkId));
      deleteStatements.push(DB.prepare('DELETE FROM links WHERE id=?').bind(linkId));
    }
    deleteStatements.push(DB.prepare('DELETE FROM users WHERE id=?').bind(memberId));
    await DB.batch(deleteStatements);

    await Promise.all(
      linkIds.map(async (linkId) => {
        try {
          await deleteDownloadStatsForLink(DB, linkId);
        } catch {
          // ignore failures while cleaning up stats
        }
      })
    );

    await DB.prepare('DELETE FROM point_ledger WHERE account_id=?')
      .bind(memberId)
      .run()
      .catch(() => undefined);

    if (r2Keys.length) {
      await Promise.all(
        r2Keys.map(async (key) => {
          try {
            await R2.delete(key);
          } catch {
            // ignore individual deletion errors
          }
        })
      );
    }

    return NextResponse.json({ ok: true, deleted: memberId }, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ ok: false, error: message || 'DELETE_FAILED' }, { status: 500, headers: corsHeaders });
  }
}
