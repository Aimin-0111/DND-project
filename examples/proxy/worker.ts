/**
 * Brasswake DM proxy — Cloudflare Worker (static example, not deployed).
 *
 * Why it exists: the game can't contain our API key (anyone can unpack a game
 * and read it). The Worker keeps the key as a secret, adds the DM rules, picks
 * the model, and forwards only game-shaped requests to Claude.
 *
 * Setup later (needs Node.js):
 *   npm create cloudflare@latest brasswake-dm
 *   npm install @anthropic-ai/sdk
 *   npx wrangler secret put ANTHROPIC_API_KEY
 *   npx wrangler deploy
 *
 * Routes:
 *   POST /turn     one DM turn      -> Claude Sonnet 5.5, effort "low", prompt caching
 *   POST /summary  refresh summary  -> Claude Haiku 5.5 (cheap)
 *
 * Free plan: 100,000 requests/day. Time spent waiting for Claude doesn't count
 * toward the Worker's CPU limit.
 */
import Anthropic from "@anthropic-ai/sdk";

export interface Env {
  ANTHROPIC_API_KEY: string; // secret, never in the code or the game
  GAME_TOKEN: string; // same value as ProxyAdapter.game_token (stops casual abuse only)
  ALLOWED_ORIGINS: string; // comma-separated, e.g. the itch.io page origins
}

// Stable text first: it is identical on every turn, so prompt caching makes
// it much cheaper after the first call. In the real project this is generated
// from content/writing/dm-rules.md so the game (copy-paste mode) and the
// Worker always use the same rules.
const DM_RULES = `You are the Dungeon Master of Brasswake Reach, a solo tabletop RPG.
Write 2-3 short paragraphs of narration in the second person.
The game owns all rules and dice: never decide the result of a roll yourself; ask for one with request_roll.
You may mark up to 4 words with effect tags: [burn] [freeze] [shock] [poison] [whisper] [holy].
After the narration write a line <<STATE>> and then ONE JSON object:
{"commands": [...], "state": {...}}
Only use ids listed in ALLOWED IDS.`;

const MAX_FIELD_CHARS = 60_000; // refuse oversized requests

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const cors = corsHeaders(request, env);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: cors ? 204 : 403, headers: cors ?? {} });
    }
    if (!cors) return new Response("Forbidden", { status: 403 });
    if (request.method !== "POST") return json({ message: "POST only" }, 405, cors);

    let body: any;
    try {
      body = await request.json();
    } catch {
      return json({ message: "Body must be JSON" }, 400, cors);
    }

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
    const path = new URL(request.url).pathname;
    try {
      if (path === "/turn") return await handleTurn(client, body, cors);
      if (path === "/summary") return await handleSummary(client, body, cors);
      return json({ message: "Not found" }, 404, cors);
    } catch (err) {
      if (err instanceof Anthropic.RateLimitError) {
        return json({ message: "Too many players right now. Try again in a minute." }, 429, cors);
      }
      if (err instanceof Anthropic.APIError) {
        return json({ message: "The AI service failed." }, 502, cors);
      }
      throw err;
    }
  },
};

async function handleTurn(client: Anthropic, body: any, cors: Record<string, string>) {
  const fields = ["codex", "summary", "action"] as const;
  for (const f of fields) {
    if (typeof body[f] !== "string" || body[f].length > MAX_FIELD_CHARS) {
      return json({ message: `Bad field: ${f}` }, 400, cors);
    }
  }

  const response = await client.beta.messages.create({
    model: "claude-sonnet-5-5",
    max_tokens: 8000, // cost cap for one turn; replies are short
    output_config: { effort: "low" },
    // If Claude declines, the API retries on another model by itself.
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    system: [
      // 1. never changes -> cached
      { type: "text", text: DM_RULES, cache_control: { type: "ephemeral" } },
      // 2. changes rarely (per campaign) -> cached
      { type: "text", text: `=== CODEX ===\n${body.codex}`, cache_control: { type: "ephemeral" } },
    ],
    messages: [
      {
        // 3-5. change every turn -> after the cached part
        role: "user",
        content: [
          `=== STORY SO FAR ===\n${body.summary}`,
          `=== STATE ===\n${JSON.stringify(body.state)}`,
          `=== ALLOWED IDS ===\n${JSON.stringify(body.allowed)}`,
          `=== PLAYER ACTION ===\n${body.action}`,
        ].join("\n\n"),
      },
    ],
  });

  // Check WHY the reply stopped before reading it.
  if (response.stop_reason === "refusal") {
    return json({ message: "The DM can't narrate that. Try another action." }, 422, cors);
  }
  const text = response.content
    .filter((block) => block.type === "text")
    .map((block) => (block.type === "text" ? block.text : ""))
    .join("");

  return json(
    {
      text,
      truncated: response.stop_reason === "max_tokens",
      // Lets us show/track cost. cache_read > 0 means caching works.
      usage: {
        input: response.usage.input_tokens,
        cache_read: response.usage.cache_read_input_tokens,
        output: response.usage.output_tokens,
      },
    },
    200,
    cors,
  );
}

async function handleSummary(client: Anthropic, body: any, cors: Record<string, string>) {
  if (typeof body.summary !== "string" || typeof body.recent !== "string") {
    return json({ message: "Need summary and recent" }, 400, cors);
  }
  // Haiku 5.5: cheap and good enough for summarising. (No server-side
  // fallback exists for Haiku, so the parameter is not sent.)
  const response = await client.messages.create({
    model: "claude-haiku-5-5",
    max_tokens: 2000,
    output_config: { effort: "low" },
    system:
      "Update the story summary of a solo RPG campaign. Keep names, promises, debts, injuries, " +
      "open quests and clues. Under 300 words. Reply with the summary only.",
    messages: [
      {
        role: "user",
        content: `CURRENT SUMMARY:\n${body.summary}\n\nNEW EVENTS:\n${body.recent}`,
      },
    ],
  });
  if (response.stop_reason === "refusal") {
    return json({ summary: body.summary }, 200, cors); // keep the old one
  }
  const summary = response.content.map((b) => (b.type === "text" ? b.text : "")).join("");
  return json({ summary }, 200, cors);
}

/**
 * Who may call the Worker:
 * - the web build, from the origins in ALLOWED_ORIGINS (check the real
 *   Origin of the itch.io page in the browser's network tab);
 * - the desktop build, which sends no Origin, with the X-Game-Token header.
 * The token is in the game files, so it only stops casual use. Before going
 * public, add Cloudflare rate limiting per IP address.
 */
function corsHeaders(request: Request, env: Env): Record<string, string> | null {
  const origin = request.headers.get("Origin");
  const allowed = env.ALLOWED_ORIGINS.split(",").map((s) => s.trim());
  const base = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-Game-Token",
  };
  if (origin && allowed.includes(origin)) {
    return { ...base, "Access-Control-Allow-Origin": origin };
  }
  if (!origin && request.headers.get("X-Game-Token") === env.GAME_TOKEN) {
    return base;
  }
  return null;
}

function json(data: unknown, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
