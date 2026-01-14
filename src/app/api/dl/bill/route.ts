import { NextResponse } from 'next/server';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import { triggerDownloadMonitors, triggerPointMonitors } from '@/lib/monitor';
import { fetchDistributionById } from '@/lib/distribution';
import { recordDownload } from '@/lib/downloads';
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

const THROTTLE_SECONDS = 30;

const buildThrottleKey = (accountId: string, linkId: string, platform: string) =>
  `dl-bill:${accountId}:${linkId}:${platform}`;

const buildThrottleRequest = (key: string) =>
  new Request(`https://cache.mycowbay/${encodeURIComponent(key)}`, { method: 'GET' });

const getThrottleCache = async (): Promise<Cache | null> => {
  const storage = globalThis.caches;
  if (!storage) return null;
  return storage.open('dl-bill-throttle');
};

const isThrottled = async (key: string): Promise<boolean> => {
  const cache = await getThrottleCache();
  if (!cache) return false;
  const hit = await cache.match(buildThrottleRequest(key));
  return Boolean(hit);
};

const markThrottled = async (key: string): Promise<void> => {
  const cache = await getThrottleCache();
  if (!cache) return;
  const response = new Response('1', {
    headers: { 'cache-control': `max-age=${THROTTLE_SECONDS}` },
  });
  await cache.put(buildThrottleRequest(key), response);
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

  const normalizedPlatform = platform.toLowerCase();
  if (normalizedPlatform !== 'apk' && normalizedPlatform !== 'ipa') {
    return NextResponse.json({ ok: false, error: 'INVALID_PLATFORM' }, { status: 400 });
  }
  const platformKey = normalizedPlatform as 'apk' | 'ipa';

  const throttleKey = buildThrottleKey(account_id, link_id, normalizedPlatform);
  if (await isThrottled(throttleKey)) {
    return NextResponse.json({ ok: true, cost: 0, deduped: true });
  }

  const link = await fetchDistributionById(DB, link_id).catch(() => null);
  if (!link) {
    return NextResponse.json({ ok: false, error: 'LINK_NOT_FOUND' }, { status: 404 });
  }
  const isRegionalDownload = isRegionalNetworkArea(link.networkArea);
  const cost = normalizedPlatform === 'ipa'
    ? (isRegionalDownload ? 30 : 5)
    : isRegionalDownload ? 10 : 3;

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
      const totals = await recordDownload(DB, link.id, platformKey);
      const ownerId = (link.ownerId ?? account_id).trim();
      if (totals && ownerId) {
        await triggerDownloadMonitors(DB, {
          ownerId,
          linkCode: link.code,
          platform: platformKey,
          totals,
        });
      }
    } catch (error) {
      console.error('[download] record failed', error);
    }

    try {
      await triggerPointMonitors(DB, {
        ownerId: account_id,
        previousBalance: bal,
        currentBalance: bal - cost,
      });
    } catch (error) {
      console.error('[monitor] point trigger failed', error);
    }

    await markThrottled(throttleKey);

    return NextResponse.json({ ok: true, cost });
  } catch (e: unknown) {
    const error = e instanceof Error ? e.message : String(e);
    return NextResponse.json({ ok: false, error }, { status: 500 });
  }
}
