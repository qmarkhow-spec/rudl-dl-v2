import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import { triggerPointMonitors } from '@/lib/monitor';
import { fetchDistributionById } from '@/lib/distribution';
import { isRegionalNetworkArea } from '@/lib/network-area';


type Env = {
  DB: D1Database;
  ['rudl-app']?: D1Database;
};
type DeductRequestBody = {
  account_id?: string;
  link_id?: string;
  platform?: string;
};

export async function POST(req: Request) {
  const { env } = getCloudflareContext() as { env: Env };
  const legacyDB = env['rudl-app'];
  const DB = env.DB ?? legacyDB;
  if (!DB) {
    return NextResponse.json({ ok: false, error: 'D1 binding DB is missing' }, { status: 500 });
  }

  const body = (await req.json().catch(() => ({}))) as DeductRequestBody;
  const { account_id, link_id, platform } = body;
  if (!account_id || !link_id || !platform) {
    return NextResponse.json({ ok: false, error: 'bad request' }, { status: 400 });
  }

  const link = await fetchDistributionById(DB, link_id).catch(() => null);
  const isRegionalDownload = link ? isRegionalNetworkArea(link.networkArea) : false;
  const cost =
    platform === 'ipa' ? (isRegionalDownload ? 30 : 5) : isRegionalDownload ? 10 : 3;

  try {
    const acct = await DB.prepare('SELECT balance FROM users WHERE id=? LIMIT 1')
      .bind(account_id)
      .first<{ balance: number }>();
    if (!acct) {
      return NextResponse.json({ ok: false, error: 'ACCOUNT_NOT_FOUND' }, { status: 404 });
    }
    const bal = Number(acct.balance ?? 0);
    if (bal < cost) {
      return NextResponse.json({ ok: false, error: 'INSUFFICIENT_POINTS' }, { status: 402 });
    }

    await DB.prepare('UPDATE users SET balance = balance - ? WHERE id=?')
      .bind(cost, account_id)
      .run();

    try {
      await triggerPointMonitors(DB, {
        ownerId: account_id,
        previousBalance: bal,
        currentBalance: bal - cost,
      });
    } catch (error) {
      console.error('[monitor] point trigger failed', error);
    }

    return NextResponse.json({ ok: true, cost });
  } catch (e: unknown) {
    const error = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ ok: false, error }, { status: 500 });
  }
}
