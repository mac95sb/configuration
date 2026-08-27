import assert from "node:assert/strict";
import test from "node:test";

import { check } from "./worker.mjs";

function environment(initial) {
  let state = initial;
  return {
    NTFY_URL: "https://notify.invalid/topic",
    PROBE_URL: "https://status.invalid",
    STATE: {
      get: async () => state,
      put: async (_key, value) => {
        state = value;
      },
    },
    value: () => state,
  };
}

test("alerts once on failure and resolves once on recovery", async (context) => {
  const env = environment("up");
  const notifications = [];
  let status = 503;

  context.mock.method(globalThis, "fetch", async (url, options) => {
    if (url === env.PROBE_URL) return new Response("", { status });
    notifications.push({ url, ...options });
    return new Response("", { status: 200 });
  });

  assert.equal((await check(env)).current, "down");
  assert.equal(env.value(), "down");
  assert.equal(notifications.length, 1);

  await check(env);
  assert.equal(notifications.length, 1);

  status = 200;
  assert.equal((await check(env)).current, "up");
  assert.equal(env.value(), "up");
  assert.equal(notifications.length, 2);
});
