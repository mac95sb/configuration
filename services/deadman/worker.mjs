const stateKey = "status";

async function notify(env, title, body, tags) {
  const response = await fetch(env.NTFY_URL, {
    method: "POST",
    headers: { Title: title, Tags: tags },
    body,
  });
  if (!response.ok) throw new Error(`notification failed: ${response.status}`);
}

export async function check(env) {
  let healthy = false;
  let detail;

  try {
    const response = await fetch(env.PROBE_URL, {
      headers: { "User-Agent": "home-deadman/1" },
      redirect: "manual",
    });
    healthy = response.status === 200;
    detail = `HTTP ${response.status}`;
  } catch (error) {
    detail = error instanceof Error ? error.message : String(error);
  }

  const previous = await env.STATE.get(stateKey);
  const current = healthy ? "up" : "down";

  if (current !== previous) {
    if (healthy && previous === "down") {
      await notify(env, "Homelab recovered", `${env.PROBE_URL} is reachable again.`, "white_check_mark");
    } else if (!healthy) {
      await notify(env, "Homelab unavailable", `${env.PROBE_URL} failed: ${detail}.`, "rotating_light");
    }
    await env.STATE.put(stateKey, current);
  }

  return { current, detail, previous };
}

export default {
  async scheduled(_controller, env, context) {
    context.waitUntil(check(env));
  },
};
