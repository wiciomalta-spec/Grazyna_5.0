CREATE TABLE runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  executor TEXT,
  runtime TEXT,
  latency REAL,
  errors INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
