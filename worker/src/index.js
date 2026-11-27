/**
 * MindSpark AI — Cloudflare Worker proxy
 *
 * Keeps the OpenRouter API key server-side. The Flutter app calls this worker,
 * and the worker forwards requests to the OpenRouter API using the secret
 * API key. The key is never bundled into the app.
 *
 * Configuration:
 *   BASE_URL         (var, wrangler.toml) — https://openrouter.ai/api/v1
 *   MODEL            (var, wrangler.toml) — primary model, used when the
 *                                           app does not ask for a specific one
 *   FALLBACK_MODELS  (var, wrangler.toml) — comma-separated models tried, in
 *                                           order, when the primary one errors
 *   API_KEY          (secret)             — the OpenRouter key (sk-or-v1-…),
 *                                           set with `npx wrangler secret put API_KEY`
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const DEFAULT_MODEL = 'google/gemma-4-26b-a4b-it:free';
const DEFAULT_BASE_URL = 'https://openrouter.ai/api/v1';

// Google's free Gemma pool is often rate-limited (429), so the request carries
// a chain instead of a single model: `route: 'fallback'` makes OpenRouter move
// to the next entry only when a model actually fails. Gemma 4 stays the model
// that answers whenever the free pool has room.
const DEFAULT_FALLBACK_MODELS = [
  'particle-ai/particle-1:free',
  'recursive/flint-v1.0:free',
];

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
    const models = resolveModelChain(body, env);

    try {
      const upstream = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.API_KEY}`,
        },
        body: JSON.stringify({
          models,
          route: 'fallback',
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
          { error: `The AI model '${models[0]}' did not respond within ${UPSTREAM_TIMEOUT_MS / 1000}s.` },
          504,
        );
      }
      return json({ error: `Upstream request failed: ${err?.message ?? err}` }, 502);
    }
  },
};

/**
 * Builds the ordered model list: the model the app asked for first, then the
 * configured fallbacks, without duplicates.
 */
function resolveModelChain(body, env) {
  const requested = Array.isArray(body?.models)
    ? body.models.find((m) => typeof m === 'string' && m.trim())?.trim()
    : typeof body?.model === 'string' && body.model.trim()
      ? body.model.trim()
      : undefined;

  const primary = requested || env.MODEL || DEFAULT_MODEL;

  const fallbacks = (env.FALLBACK_MODELS ?? DEFAULT_FALLBACK_MODELS.join(','))
    .split(',')
    .map((m) => m.trim())
    .filter(Boolean);

  return [primary, ...fallbacks.filter((m) => m !== primary)];
}

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
