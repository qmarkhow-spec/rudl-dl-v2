import type { D1Database } from '@cloudflare/workers-types';

const DATE_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'UTC',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const formatDate = (date: Date) => DATE_FORMATTER.format(date);

const STATS_TABLE = 'link_download_stats';
let statsTableEnsured = false;

const ensureStatsTable = async (DB: D1Database) => {
  if (statsTableEnsured) return;
  await DB.prepare(
    `CREATE TABLE IF NOT EXISTS ${STATS_TABLE} (
      link_id TEXT NOT NULL,
      date TEXT NOT NULL,
      apk_dl INTEGER NOT NULL DEFAULT 0,
      ipa_dl INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (link_id, date)
    )`
  ).run();
  await DB.prepare(
    `CREATE INDEX IF NOT EXISTS idx_${STATS_TABLE}_link_date
     ON ${STATS_TABLE} (link_id, date)`
  ).run();
  statsTableEnsured = true;
};

const toNumber = (value: unknown): number => {
  const numeric = Number(value ?? 0);
  return Number.isFinite(numeric) ? numeric : 0;
};

type LinkStatsColumnKey =
  | 'todayApk'
  | 'todayIpa'
  | 'todayTotal'
  | 'totalApk'
  | 'totalIpa'
  | 'totalTotal';

type LinkStatsColumnMap = Partial<Record<LinkStatsColumnKey, string>>;

const LINK_STATS_COLUMN_CANDIDATES: Record<LinkStatsColumnKey, readonly string[]> = {
  todayApk: ['today_apk_dl', 'today_apk_d', 'today_apk'],
  todayIpa: ['today_ipa_dl', 'today_ipa_d', 'today_ipa'],
  todayTotal: ['today_total_dl', 'today_total_d', 'today_total'],
  totalApk: ['total_apk_dl', 'total_apk_d', 'total_apk'],
  totalIpa: ['total_ipa_dl', 'total_ipa_d', 'total_ipa'],
  totalTotal: ['total_total_dl', 'total_total_d', 'total_total'],
};

let cachedLinkStatsColumns: Promise<LinkStatsColumnMap> | null = null;

const getLinkStatsColumns = (DB: D1Database): Promise<LinkStatsColumnMap> => {
  if (!cachedLinkStatsColumns) {
    cachedLinkStatsColumns = (async () => {
      try {
        const response = await DB.prepare('PRAGMA table_info(links)').all<{ name?: string }>();
        const rows = (response?.results as Array<{ name?: string }> | undefined) ?? [];
        const knownColumns = new Set(rows.map((row) => row.name).filter((name): name is string => Boolean(name)));
        const resolved: LinkStatsColumnMap = {};
        (Object.keys(LINK_STATS_COLUMN_CANDIDATES) as LinkStatsColumnKey[]).forEach((key) => {
          const match = LINK_STATS_COLUMN_CANDIDATES[key].find((candidate) => knownColumns.has(candidate));
          if (match) resolved[key] = match;
        });
        return resolved;
      } catch (error) {
        console.warn('[downloads] unable to inspect links table columns', error);
        return {};
      }
    })();
  }
  return cachedLinkStatsColumns;
};

const updateLinkDownloadColumns = async (
  DB: D1Database,
  linkId: string,
  totals: DownloadTotals
) => {
  const columns = await getLinkStatsColumns(DB);
  const assignments: string[] = [];
  const values: number[] = [];

  const pushColumn = (key: LinkStatsColumnKey, value: number) => {
    const column = columns[key];
    if (!column) return;
    assignments.push(`${column}=?`);
    values.push(value);
  };

  pushColumn('todayApk', totals.todayApk);
  pushColumn('todayIpa', totals.todayIpa);
  pushColumn('todayTotal', totals.todayTotal);
  pushColumn('totalApk', totals.totalApk);
  pushColumn('totalIpa', totals.totalIpa);
  pushColumn('totalTotal', totals.totalTotal);

  if (!assignments.length) return;

  try {
    await DB.prepare(`UPDATE links SET ${assignments.join(', ')} WHERE id=?`)
      .bind(...values, linkId)
      .run();
  } catch (error) {
    console.warn('[downloads] unable to update link download totals', error);
  }
};

export type DownloadTotals = {
  todayApk: number;
  todayIpa: number;
  todayTotal: number;
  totalApk: number;
  totalIpa: number;
  totalTotal: number;
};

export async function ensureDownloadStatsTable(DB: D1Database, linkId?: string) {
  if (!linkId) return;
  await ensureStatsTable(DB);
}

export async function deleteDownloadStatsForLink(DB: D1Database, linkId: string) {
  await ensureStatsTable(DB);
  await DB.prepare(`DELETE FROM ${STATS_TABLE} WHERE link_id=?`).bind(linkId).run();
}

export async function recordDownload(
  DB: D1Database,
  linkId: string,
  platform: 'apk' | 'ipa',
  now: Date = new Date()
): Promise<DownloadTotals> {
  await ensureStatsTable(DB);

  const today = formatDate(now);

  const insertRow = DB.prepare(
    `INSERT OR IGNORE INTO ${STATS_TABLE} (link_id, date, apk_dl, ipa_dl) VALUES (?, ?, 0, 0)`
  ).bind(linkId, today);

  const updateColumn = platform === 'apk' ? 'apk_dl' : 'ipa_dl';
  const updateRow = DB.prepare(
    `UPDATE ${STATS_TABLE} SET ${updateColumn} = ${updateColumn} + 1 WHERE link_id=? AND date=?`
  ).bind(linkId, today);

  await DB.batch([insertRow, updateRow]);

  const todayRow =
    (await DB.prepare(
      `SELECT apk_dl, ipa_dl FROM ${STATS_TABLE} WHERE link_id=? AND date=?`
    )
      .bind(linkId, today)
      .first<{ apk_dl?: number | string | null; ipa_dl?: number | string | null }>()) ?? {
      apk_dl: 0,
      ipa_dl: 0,
    };

  const totals =
    (await DB.prepare(
      `SELECT SUM(apk_dl) AS apkSum, SUM(ipa_dl) AS ipaSum FROM ${STATS_TABLE} WHERE link_id=?`
    )
      .bind(linkId)
      .first<{ apkSum?: number | string | null; ipaSum?: number | string | null }>()) ?? {};

  const todayApk = toNumber(todayRow.apk_dl);
  const todayIpa = toNumber(todayRow.ipa_dl);
  const totalApk = toNumber(totals.apkSum);
  const totalIpa = toNumber(totals.ipaSum);

  const totalsPayload: DownloadTotals = {
    todayApk,
    todayIpa,
    todayTotal: todayApk + todayIpa,
    totalApk,
    totalIpa,
    totalTotal: totalApk + totalIpa,
  };

  await updateLinkDownloadColumns(DB, linkId, totalsPayload);

  return totalsPayload;
}

export type DownloadStatsRow = {
  date: string;
  apk_dl: number | string | null;
  ipa_dl: number | string | null;
};

export async function fetchDownloadStatsRange(
  DB: D1Database,
  linkId: string,
  startDate: string,
  endDate: string
) {
  await ensureStatsTable(DB);
  const result = await DB.prepare(
    `SELECT date, apk_dl, ipa_dl
     FROM ${STATS_TABLE}
     WHERE link_id=?
       AND date BETWEEN ? AND ?
     ORDER BY date ASC`
  )
    .bind(linkId, startDate, endDate)
    .all<DownloadStatsRow>();
  return (result?.results as DownloadStatsRow[] | undefined) ?? [];
}
