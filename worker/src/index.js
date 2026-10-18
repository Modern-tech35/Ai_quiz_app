/**
 * MindSpark AI — Cloudflare Worker proxy
 *
 * Keeps the NVIDIA API key server-side. The Flutter app calls this worker,
 * and the worker forwards requests to the NVIDIA integrate API using the
 * secret API key. The key is never bundled into the app.
 *
 * Secrets (set via `wrangler secret put`):
 *   BASE_URL — e.g. https://integrate.api.nvidia.com/v1
 *   API_KEY  — the NVIDIA API key
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed. Use POST.' }, 405);
    }

    if (!env.BASE_URL || !env.API_KEY) {
      return json({ error: 'Worker is missing BASE_URL or API_KEY secrets.' }, 500);
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

    const model = typeof body.model === 'string' ? body.model : 'meta/llama-3.2-11b-vision-instruct';

    try {
      const upstream = await fetch(`${env.BASE_URL}/chat/completions`, {
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
      });

      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    } catch (err) {
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
