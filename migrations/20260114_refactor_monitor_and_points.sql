CREATE TABLE IF NOT EXISTS monitor_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  mon_option TEXT NOT NULL,
  mon_detail TEXT NOT NULL,
  noti_method TEXT NOT NULL,
  noti_detail TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_monitor_records_user
  ON monitor_records (user_id);

DROP TABLE IF EXISTS point_dedupe;
DROP TABLE IF EXISTS point_accounts;
