-- Initial D1 schema for fresh deployments.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  pw_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  balance INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  telegram_api_id TEXT,
  telegram_api_hash TEXT,
  telegram_bot_token TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email
  ON users (email);

CREATE TABLE IF NOT EXISTS links (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  owner_id TEXT,
  title TEXT,
  bundle_id TEXT,
  apk_version TEXT,
  ipa_version TEXT,
  platform TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER,
  updated_at INTEGER,
  lang TEXT DEFAULT 'en',
  file_id TEXT,
  network_area TEXT DEFAULT 'global',
  today_apk_dl INTEGER NOT NULL DEFAULT 0,
  today_ipa_dl INTEGER NOT NULL DEFAULT 0,
  today_total_dl INTEGER NOT NULL DEFAULT 0,
  total_apk_dl INTEGER NOT NULL DEFAULT 0,
  total_ipa_dl INTEGER NOT NULL DEFAULT 0,
  total_total_dl INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_links_code
  ON links (code);

CREATE INDEX IF NOT EXISTS idx_links_owner
  ON links (owner_id);

CREATE TABLE IF NOT EXISTS files (
  id TEXT PRIMARY KEY,
  link_id TEXT NOT NULL,
  owner_id TEXT,
  platform TEXT,
  title TEXT,
  bundle_id TEXT,
  version TEXT,
  size INTEGER,
  r2_key TEXT,
  sha256 TEXT,
  content_type TEXT,
  created_at INTEGER,
  updated_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_files_link
  ON files (link_id);

CREATE INDEX IF NOT EXISTS idx_files_owner
  ON files (owner_id);

CREATE TABLE IF NOT EXISTS link_download_stats (
  link_id TEXT NOT NULL,
  date TEXT NOT NULL,
  apk_dl INTEGER NOT NULL DEFAULT 0,
  ipa_dl INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (link_id, date)
);

CREATE INDEX IF NOT EXISTS idx_link_download_stats_link_date
  ON link_download_stats (link_id, date);

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

CREATE TABLE IF NOT EXISTS point_ledger (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  link_id TEXT,
  download_id TEXT,
  bucket_minute INTEGER,
  platform TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_point_ledger_account
  ON point_ledger (account_id);

CREATE INDEX IF NOT EXISTS idx_point_ledger_created_at
  ON point_ledger (created_at);

CREATE TABLE IF NOT EXISTS ecpay_orders (
  merchant_trade_no TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  points INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'TWD',
  status TEXT NOT NULL DEFAULT 'PENDING',
  description TEXT,
  item_name TEXT,
  custom_field1 TEXT,
  custom_field2 TEXT,
  custom_field3 TEXT,
  rtn_code TEXT,
  rtn_msg TEXT,
  payment_type TEXT,
  payment_method TEXT,
  trade_no TEXT,
  trade_amt INTEGER,
  payment_date TEXT,
  ledger_id TEXT,
  balance_after REAL,
  raw_notify TEXT,
  raw_payment_info TEXT,
  created_at INTEGER,
  updated_at INTEGER,
  paid_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_ecpay_orders_account
  ON ecpay_orders (account_id);
