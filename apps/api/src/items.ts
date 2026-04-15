import { Hono } from "hono";

type Bindings = {
  DB: D1Database;
  API_SECRET: string;
};

const items = new Hono<{ Bindings: Bindings }>();

const PURCHASED_EXPIRY_HOURS = 12;

function formatRow(row: Record<string, unknown>) {
  return {
    id: row.id,
    name: row.name,
    purchased: row.purchased === 1,
    position: row.position,
    purchased_at: row.purchased_at ?? null,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

// GET /items — 未購入 + 購入後12時間以内のアイテムを返す
items.get("/", async (c) => {
  const expiryThreshold = new Date(
    Date.now() - PURCHASED_EXPIRY_HOURS * 60 * 60 * 1000
  ).toISOString();

  const result = await c.env.DB
    .prepare(
      `SELECT * FROM items
       WHERE purchased = 0
          OR (purchased = 1 AND purchased_at > ?)
       ORDER BY purchased ASC, position ASC`
    )
    .bind(expiryThreshold)
    .all();

  return c.json({
    items: result.results.map((row: Record<string, unknown>) => formatRow(row)),
  });
});

// POST /items
items.post("/", async (c) => {
  const body = await c.req.json<{ name: string }>();
  if (!body.name || body.name.trim() === "") {
    return c.json({ error: "name is required" }, 400);
  }

  const id = crypto.randomUUID();

  // 現在の最大 position を取得
  const max = await c.env.DB
    .prepare("SELECT MAX(position) as max_pos FROM items WHERE purchased = 0")
    .first<{ max_pos: number | null }>();
  const position = (max?.max_pos ?? -1) + 1;

  await c.env.DB
    .prepare("INSERT INTO items (id, name, position) VALUES (?, ?, ?)")
    .bind(id, body.name.trim(), position)
    .run();

  const item = await c.env.DB
    .prepare("SELECT * FROM items WHERE id = ?")
    .bind(id)
    .first();

  return c.json(formatRow(item as Record<string, unknown>), 201);
});

// PATCH /items/:id
items.patch("/:id", async (c) => {
  const id = c.req.param("id");
  const item = await c.env.DB
    .prepare("SELECT * FROM items WHERE id = ?")
    .bind(id)
    .first<Record<string, unknown>>();

  if (!item) return c.json({ error: "Not found" }, 404);

  const body = await c.req.json<{
    name?: string;
    purchased?: boolean;
    position?: number;
  }>();

  const updates: string[] = [];
  const values: unknown[] = [];

  if (body.name !== undefined) {
    updates.push("name = ?");
    values.push(body.name.trim());
  }
  if (body.purchased !== undefined) {
    updates.push("purchased = ?");
    values.push(body.purchased ? 1 : 0);
    if (body.purchased) {
      updates.push("purchased_at = ?");
      values.push(new Date().toISOString());
    } else {
      updates.push("purchased_at = NULL");
    }
  }
  if (body.position !== undefined) {
    updates.push("position = ?");
    values.push(body.position);
  }

  if (updates.length === 0) {
    return c.json({ error: "No fields to update" }, 400);
  }

  updates.push("updated_at = datetime('now')");
  values.push(id);

  await c.env.DB
    .prepare(`UPDATE items SET ${updates.join(", ")} WHERE id = ?`)
    .bind(...values)
    .run();

  const updated = await c.env.DB
    .prepare("SELECT * FROM items WHERE id = ?")
    .bind(id)
    .first();

  return c.json(formatRow(updated as Record<string, unknown>));
});

// DELETE /items/:id
items.delete("/:id", async (c) => {
  const id = c.req.param("id");
  const item = await c.env.DB
    .prepare("SELECT * FROM items WHERE id = ?")
    .bind(id)
    .first();

  if (!item) return c.json({ error: "Not found" }, 404);

  await c.env.DB.prepare("DELETE FROM items WHERE id = ?").bind(id).run();
  return c.json({ ok: true });
});

// PATCH /items — 一括並び替え
items.patch("/", async (c) => {
  const body = await c.req.json<{
    items: { id: string; position: number }[];
  }>();

  if (!body.items || body.items.length === 0) {
    return c.json({ error: "items is required" }, 400);
  }

  const stmt = c.env.DB.prepare(
    "UPDATE items SET position = ?, updated_at = datetime('now') WHERE id = ?"
  );
  const batch = body.items.map((item) => stmt.bind(item.position, item.id));
  await c.env.DB.batch(batch);

  return c.json({ ok: true });
});

export { items };
