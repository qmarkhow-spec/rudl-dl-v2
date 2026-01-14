CREATE TABLE IF NOT EXISTS link_download_stats (
  link_id TEXT NOT NULL,
  date TEXT NOT NULL,
  apk_dl INTEGER NOT NULL DEFAULT 0,
  ipa_dl INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (link_id, date)
);

CREATE INDEX IF NOT EXISTS idx_link_download_stats_link_date
  ON link_download_stats (link_id, date);
