/**
 * MindSpark AI — Cloudflare Worker proxy
 *
 * Keeps the NVIDIA API key server-side. The Flutter app calls this worker,
 * and the worker forwards requests to the NVIDIA integrate API using the
 * secret API key. The key is never bundled into the app.
 *
 * Configuration:
 *   BASE_URL  (var, wrangler.toml) — https://integrate.api.nvidia.com/v1
 *   MODEL     (var, wrangler.toml) — default chat model, used when the
 *                                    app does not ask for a specific one
 *   API_KEY   (secret)             — the NVIDIA API key,
 *                                    set with `npx wrangler secret put API_KEY`
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const DEFAULT_MODEL = 'minimaxai/minimax-m3.1-flash';
const DEFAULT_BASE_URL = 'https://integrate.api.nvidia.com/v1';

// Upstream calls are capped so the app never waits forever on a stalled model.
const UPSTREAM_TIMEOUT_MS = 120_000;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed. Use POST.' }, 405);
    }

    if (!env.API_KEY) {
      return json({ error: 'Worker is missing the API_KEY secret.' }, 500);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid JSON body.' }, 400);
    }

    const messages = body?.messages;
    if (!Array.isArray(messages) || messages.length === 0) {
      return json({ error: "Body must include a non-empty 'messages' array." }, 400);
    }

    const baseUrl = (env.BASE_URL || DEFAULT_BASE_URL).replace(/\/+$/, '');
    const model =
      typeof body.model === 'string' && body.model.trim()
        ? body.model.trim()
        : env.MODEL || DEFAULT_MODEL;

    try {
      const upstream = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.API_KEY}`,
        },
        body: JSON.stringify({
          model,
          messages,
          temperature: body.temperature ?? 0.6,
          top_p: body.top_p ?? 0.9,
          max_tokens: body.max_tokens ?? 1024,
        }),
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      });

      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    } catch (err) {
      const timedOut = err?.name === 'TimeoutError' || err?.name === 'AbortError';
      if (timedOut) {
        return json(
          { error: `The AI model '${model}' did not respond within ${UPSTREAM_TIMEOUT_MS / 1000}s.` },
          504,
        );
      }
      return json({ error: `Upstream request failed: ${err?.message ?? err}` }, 502);
    }
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
