CREATE TABLE items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  purchased INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0,
  purchased_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_items_purchased ON items(purchased);
CREATE INDEX idx_items_position ON items(position);
