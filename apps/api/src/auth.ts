import { MiddlewareHandler } from "hono";

type Env = { Bindings: { API_SECRET: string } };

export const auth: MiddlewareHandler<Env> = async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header || header !== `Bearer ${c.env.API_SECRET}`) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  await next();
};
