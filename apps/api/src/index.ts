import { Hono } from "hono";
import { auth } from "./auth";
import { items } from "./items";

type Bindings = {
  DB: D1Database;
  API_SECRET: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.get("/", (c) => c.json({ status: "ok" }));

app.use("/items/*", auth);
app.use("/items", auth);
app.route("/items", items);

export default app;
