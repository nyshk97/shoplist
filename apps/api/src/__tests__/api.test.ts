import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { Miniflare } from "miniflare";
import * as path from "node:path";
import { execSync } from "node:child_process";

let mf: Miniflare;

const AUTH = { Authorization: "Bearer test-secret" };
const JSON_HEADERS = { ...AUTH, "Content-Type": "application/json" };

function buildWorker(): string {
  const outfile = path.join(__dirname, "../../dist/_test_worker.mjs");
  execSync(
    `npx esbuild src/index.ts --bundle --format=esm --outfile=${outfile} --platform=neutral`,
    { cwd: path.join(__dirname, "../..") }
  );
  return outfile;
}

async function createItem(name: string) {
  const res = await mf.dispatchFetch("http://localhost/items", {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify({ name }),
  });
  return res.json() as Promise<Record<string, unknown>>;
}

async function getItems() {
  const res = await mf.dispatchFetch("http://localhost/items", {
    headers: AUTH,
  });
  return res.json() as Promise<{ items: Record<string, unknown>[] }>;
}

async function getDb() {
  return await mf.getD1Database("DB");
}

describe("API", () => {
  beforeEach(async () => {
    const scriptPath = buildWorker();
    mf = new Miniflare({
      modules: true,
      scriptPath,
      d1Databases: { DB: "test-db" },
      bindings: { API_SECRET: "test-secret" },
      compatibilityDate: "2025-04-01",
    });

    const db = await getDb();
    await db.exec(
      "CREATE TABLE IF NOT EXISTS items (id TEXT PRIMARY KEY, name TEXT NOT NULL, purchased INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL DEFAULT 0, purchased_at TEXT, created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now')));"
    );
    await db.exec(
      "CREATE INDEX IF NOT EXISTS idx_items_purchased ON items(purchased);"
    );
    await db.exec(
      "CREATE INDEX IF NOT EXISTS idx_items_position ON items(position);"
    );
    await db.exec("DELETE FROM items");
  });

  afterEach(async () => {
    await mf.dispose();
  });

  describe("認証", () => {
    it("トークンなしで 401", async () => {
      const res = await mf.dispatchFetch("http://localhost/items");
      expect(res.status).toBe(401);
    });

    it("不正トークンで 401", async () => {
      const res = await mf.dispatchFetch("http://localhost/items", {
        headers: { Authorization: "Bearer wrong" },
      });
      expect(res.status).toBe(401);
    });

    it("正しいトークンで 200", async () => {
      const res = await mf.dispatchFetch("http://localhost/items", {
        headers: AUTH,
      });
      expect(res.status).toBe(200);
    });
  });

  describe("CRUD", () => {
    it("アイテムを追加して取得できる", async () => {
      const item = await createItem("牛乳");
      expect(item.name).toBe("牛乳");
      expect(item.purchased).toBe(false);
      expect(item.position).toBe(0);

      const data = await getItems();
      expect(data.items).toHaveLength(1);
      expect(data.items[0].name).toBe("牛乳");
    });

    it("空の name で 400", async () => {
      const res = await mf.dispatchFetch("http://localhost/items", {
        method: "POST",
        headers: JSON_HEADERS,
        body: JSON.stringify({ name: "" }),
      });
      expect(res.status).toBe(400);
    });

    it("position は追加順にインクリメントされる", async () => {
      const i1 = await createItem("1つ目");
      const i2 = await createItem("2つ目");
      expect(i1.position).toBe(0);
      expect(i2.position).toBe(1);
    });

    it("購入済みに更新できる", async () => {
      const item = await createItem("卵");
      const res = await mf.dispatchFetch(
        `http://localhost/items/${item.id}`,
        {
          method: "PATCH",
          headers: JSON_HEADERS,
          body: JSON.stringify({ purchased: true }),
        }
      );
      const updated = (await res.json()) as Record<string, unknown>;
      expect(updated.purchased).toBe(true);
      expect(updated.purchased_at).not.toBeNull();
    });

    it("購入済みを未購入に戻すと purchased_at が null になる", async () => {
      const item = await createItem("パン");
      await mf.dispatchFetch(`http://localhost/items/${item.id}`, {
        method: "PATCH",
        headers: JSON_HEADERS,
        body: JSON.stringify({ purchased: true }),
      });
      const res = await mf.dispatchFetch(
        `http://localhost/items/${item.id}`,
        {
          method: "PATCH",
          headers: JSON_HEADERS,
          body: JSON.stringify({ purchased: false }),
        }
      );
      const updated = (await res.json()) as Record<string, unknown>;
      expect(updated.purchased).toBe(false);
      expect(updated.purchased_at).toBeNull();
    });

    it("名前を更新できる", async () => {
      const item = await createItem("牛乳");
      const res = await mf.dispatchFetch(
        `http://localhost/items/${item.id}`,
        {
          method: "PATCH",
          headers: JSON_HEADERS,
          body: JSON.stringify({ name: "低脂肪牛乳" }),
        }
      );
      const updated = (await res.json()) as Record<string, unknown>;
      expect(updated.name).toBe("低脂肪牛乳");
    });

    it("削除できる", async () => {
      const item = await createItem("削除する");
      const res = await mf.dispatchFetch(
        `http://localhost/items/${item.id}`,
        { method: "DELETE", headers: AUTH }
      );
      expect(res.status).toBe(200);

      const data = await getItems();
      expect(data.items).toHaveLength(0);
    });

    it("存在しないIDで 404", async () => {
      const res = await mf.dispatchFetch(
        "http://localhost/items/nonexistent",
        { method: "DELETE", headers: AUTH }
      );
      expect(res.status).toBe(404);
    });
  });

  describe("並べ替え", () => {
    it("reorder で position を一括更新できる", async () => {
      const i1 = await createItem("A");
      const i2 = await createItem("B");
      const i3 = await createItem("C");

      await mf.dispatchFetch("http://localhost/items", {
        method: "PATCH",
        headers: JSON_HEADERS,
        body: JSON.stringify({
          items: [
            { id: i3.id, position: 0 },
            { id: i1.id, position: 1 },
            { id: i2.id, position: 2 },
          ],
        }),
      });

      const data = await getItems();
      const unpurchased = data.items.filter(
        (i) => !i.purchased
      );
      expect(unpurchased.map((i) => i.name)).toEqual(["C", "A", "B"]);
    });
  });

  describe("購入済み12時間非表示", () => {
    it("購入後12時間以内のアイテムは表示される", async () => {
      const item = await createItem("牛乳");
      await mf.dispatchFetch(`http://localhost/items/${item.id}`, {
        method: "PATCH",
        headers: JSON_HEADERS,
        body: JSON.stringify({ purchased: true }),
      });

      const data = await getItems();
      expect(data.items).toHaveLength(1);
      expect(data.items[0].purchased).toBe(true);
    });

    it("購入後12時間を超えたアイテムは表示されない", async () => {
      const db = await getDb();
      const thirteenHoursAgo = new Date(
        Date.now() - 13 * 60 * 60 * 1000
      ).toISOString();

      await db
        .prepare(
          "INSERT INTO items (id, name, purchased, position, purchased_at) VALUES (?, ?, 1, 0, ?)"
        )
        .bind("old-purchased", "古い購入済み", thirteenHoursAgo)
        .run();

      const data = await getItems();
      expect(data.items).toHaveLength(0);
    });

    it("未購入アイテムは常に表示される", async () => {
      await createItem("未購入");
      const data = await getItems();
      expect(data.items).toHaveLength(1);
      expect(data.items[0].purchased).toBe(false);
    });
  });
});
