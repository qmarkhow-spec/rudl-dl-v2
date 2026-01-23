import type { D1Database } from '@cloudflare/workers-types';
import { normalizeLanguageCode, type LangCode } from '@/lib/language';
import { normalizeNetworkArea, type NetworkArea } from './network-area';
import { getTableInfo, hasColumn } from './distribution';

const DATE_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'UTC',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const formatDate = (date: Date) => DATE_FORMATTER.format(date);

const ensureStatsTable = async (DB: D1Database) => {
  await DB.prepare(
    `CREATE TABLE IF NOT EXISTS link_download_stats (
      link_id TEXT NOT NULL,
      date TEXT NOT NULL,
      apk_dl INTEGER NOT NULL DEFAULT 0,
      ipa_dl INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (link_id, date)
    )`
  ).run();
  await DB.prepare(
    `CREATE INDEX IF NOT EXISTS idx_link_download_stats_link_date
     ON link_download_stats (link_id, date)`
  ).run();
};

export type DashboardFile = {
  id: string;
  platform: string;
  title: string | null;
  bundleId: string | null;
  version: string | null;
  size: number | null;
  createdAt: number;
};

export type DashboardLink = {
  id: string;
  code: string;
  title: string | null;
  bundleId: string | null;
  apkVersion: string | null;
  ipaVersion: string | null;
  platform: string;
  isActive: boolean;
  createdAt: number;
  language: LangCode;
  todayApkDl: number;
  todayIpaDl: number;
  todayTotalDl: number;
  totalApkDl: number;
  totalIpaDl: number;
  totalTotalDl: number;
  networkArea: NetworkArea;
  files: DashboardFile[];
};

export type DashboardPage = {
  page: number;
  pageSize: number;
  total: number;
  balance: number;
  links: DashboardLink[];
};

type LinkRow = {
  id: string;
  code: string;
  title: string | null;
  bundle_id: string | null;
  apk_version: string | null;
  ipa_version: string | null;
  platform: string;
  is_active: number | string | null;
  created_at: number | string | null;
  lang?: string | null;
  today_apk_dl?: number | string | null;
  today_ipa_dl?: number | string | null;
  today_total_dl?: number | string | null;
  total_apk_dl?: number | string | null;
  total_ipa_dl?: number | string | null;
  total_total_dl?: number | string | null;
  network_area?: string | null;
};

type FileRow = {
  id: string;
  platform: string;
  title: string | null;
  bundle_id: string | null;
  version: string | null;
  size: number | null;
  created_at: number | string | null;
};

const toNumber = (value: number | string | null | undefined): number => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
      return numeric;
    }
  }
  return 0;
};

const toEpochSeconds = (value: number | string | null | undefined): number => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
      return numeric;
    }
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) {
      return Math.floor(parsed / 1000);
    }
  }
  return 0;
};

type LinksPageResult = {
  page: number;
  pageSize: number;
  total: number;
  links: DashboardLink[];
};

async function fetchLinksPage(
  DB: D1Database,
  page: number,
  pageSize: number,
  ownerId?: string | null
): Promise<LinksPageResult> {
  const safePage = Number.isFinite(page) && page > 0 ? Math.floor(page) : 1;
  const safePageSize = Number.isFinite(pageSize) && pageSize > 0 ? Math.floor(pageSize) : 10;
  const offset = (safePage - 1) * safePageSize;

  let linksInfo = await getTableInfo(DB, 'links');
  if (!hasColumn(linksInfo, 'lang')) {
    linksInfo = await getTableInfo(DB, 'links', true);
  }
  const hasLangColumn = hasColumn(linksInfo, 'lang');
  const hasNetworkAreaColumn = hasColumn(linksInfo, 'network_area');

  const totalRow = ownerId
    ? await DB.prepare('SELECT COUNT(*) as count FROM links WHERE owner_id=?')
        .bind(ownerId)
        .first<{ count: number }>()
    : await DB.prepare('SELECT COUNT(*) as count FROM links').first<{ count: number }>();

  const selectColumns = [
    'id',
    'code',
    'title',
    'bundle_id',
    'apk_version',
    'ipa_version',
    'platform',
    'is_active',
    'created_at',
    hasLangColumn ? 'lang' : null,
    hasNetworkAreaColumn ? 'network_area' : null,
    'today_apk_dl',
    'today_ipa_dl',
    'today_total_dl',
    'total_apk_dl',
    'total_ipa_dl',
    'total_total_dl',
  ].filter((column): column is string => Boolean(column));

  const baseQuery = `SELECT ${selectColumns.join(', ')} FROM links ${
    ownerId ? 'WHERE owner_id=? ' : ''
  }ORDER BY created_at DESC LIMIT ? OFFSET ?`;
  const statement = ownerId
    ? DB.prepare(baseQuery).bind(ownerId, safePageSize, offset)
    : DB.prepare(baseQuery).bind(safePageSize, offset);

  const linksResult = await statement.all();

  const linkRows = (linksResult.results as LinkRow[] | undefined) ?? [];

  const links: DashboardLink[] = [];
  const todayStats = new Map<string, { apk: number; ipa: number }>();

  if (linkRows.length) {
    try {
      await ensureStatsTable(DB);
      const today = formatDate(new Date());
      const ids = linkRows.map((row) => row.id);
      const placeholders = ids.map(() => '?').join(', ');
      const result = await DB.prepare(
        `SELECT link_id, apk_dl, ipa_dl FROM link_download_stats WHERE date=? AND link_id IN (${placeholders})`
      )
        .bind(today, ...ids)
        .all<{ link_id: string; apk_dl?: number | string | null; ipa_dl?: number | string | null }>();
      const rows = (result?.results as Array<{ link_id?: string; apk_dl?: number | string | null; ipa_dl?: number | string | null }> | undefined) ?? [];
      rows.forEach((row) => {
        if (!row.link_id) return;
        todayStats.set(String(row.link_id), {
          apk: toNumber(row.apk_dl),
          ipa: toNumber(row.ipa_dl),
        });
      });
    } catch {
      // ignore and fallback to zeros
    }
  }
  for (const link of linkRows) {
    const fileRows = await DB.prepare(
      `SELECT id, platform, title, bundle_id, version, size, created_at
       FROM files
       WHERE link_id=?
       ORDER BY created_at DESC`
    )
      .bind(link.id)
      .all();

    const files: DashboardFile[] =
      (fileRows.results as FileRow[] | undefined)?.map((file) => ({
        id: file.id,
        platform: file.platform,
        title: file.title,
        bundleId: file.bundle_id,
        version: file.version,
        size: file.size ?? null,
        createdAt: toEpochSeconds(file.created_at),
      })) ?? [];

    const todayRow = todayStats.get(link.id) ?? { apk: 0, ipa: 0 };
    const todayApkDl = todayRow.apk;
    const todayIpaDl = todayRow.ipa;
    const todayTotalDl = todayApkDl + todayIpaDl;

    links.push({
      id: link.id,
      code: link.code,
      title: link.title,
      bundleId: link.bundle_id,
      apkVersion: link.apk_version,
      ipaVersion: link.ipa_version,
      platform: link.platform,
      isActive: Boolean(
        typeof link.is_active === 'string'
          ? Number(link.is_active)
          : Number(link.is_active ?? 0)
      ),
      createdAt: toEpochSeconds(link.created_at),
      language: hasLangColumn ? normalizeLanguageCode(link.lang) : 'en',
      networkArea: normalizeNetworkArea(
        hasNetworkAreaColumn ? ((link.network_area ?? null) as string | null) : null
      ),
      todayApkDl,
      todayIpaDl,
      todayTotalDl,
      totalApkDl: toNumber(link.total_apk_dl),
      totalIpaDl: toNumber(link.total_ipa_dl),
      totalTotalDl: toNumber(link.total_total_dl),
      files,
    });
  }

  return {
    page: safePage,
    pageSize: safePageSize,
    total: totalRow?.count ?? 0,
    links,
  };
}

export async function fetchDashboardPage(
  DB: D1Database,
  ownerId: string,
  page: number,
  pageSize: number
): Promise<DashboardPage> {
  const result = await fetchLinksPage(DB, page, pageSize, ownerId);
  const balanceRow = await DB.prepare('SELECT balance FROM users WHERE id=? LIMIT 1')
    .bind(ownerId)
    .first<{ balance: number }>();

  return {
    ...result,
    balance: balanceRow?.balance ?? 0,
  };
}

export async function fetchAdminLinksPage(
  DB: D1Database,
  page: number,
  pageSize: number
): Promise<DashboardPage> {
  const result = await fetchLinksPage(DB, page, pageSize);
  return {
    ...result,
    balance: 0,
  };
}






