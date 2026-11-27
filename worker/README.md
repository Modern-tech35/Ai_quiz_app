# MindSpark AI proxy (Cloudflare Worker)

Keeps the OpenRouter API key server-side. The worker adds the key and forwards
the request to `https://openrouter.ai/api/v1/chat/completions`, so the key never
ships inside the app: the Flutter app only knows the worker URL (`kProxyUrl` in
`lib/chat_screen.dart`, `lib/info_screen.dart` and `lib/quiz_screen.dart`).

## Configuration

| Name              | Where                    | Value                                                        |
| ----------------- | ------------------------ | ------------------------------------------------------------ |
| `BASE_URL`        | `wrangler.toml` `[vars]` | `https://openrouter.ai/api/v1`                               |
| `MODEL`           | `wrangler.toml` `[vars]` | `google/gemma-4-26b-a4b-it:free`                             |
| `FALLBACK_MODELS` | `wrangler.toml` `[vars]` | `particle-ai/particle-1:free,recursive/flint-v1.0:free`      |
| `API_KEY`         | Worker secret            | `sk-or-v1-…` (never commit)                                  |

The worker always sends an ordered `models` list with `route: "fallback"`, so
OpenRouter only moves to the next model when the previous one errors. Google's
free Gemma 4 pool is frequently rate-limited (`429`), and this keeps the app
answering without giving up Gemma 4 as the primary model.

Local development values live in `.dev.vars` (gitignored); copy
`.dev.vars.example` if you need to recreate it.

## Deploy

```bash
cd worker
npx wrangler login                 # one-time, interactive browser login
npx wrangler secret put API_KEY    # paste the sk-or-v1-… key when prompted
npx wrangler deploy                # publishes vars + code
```

After rotating the key, run `npx wrangler secret put API_KEY` again — no app
rebuild is needed.

## Local run

```bash
cd worker
npx wrangler dev
```

Then point the `kProxyUrl` constants in `lib/chat_screen.dart`,
`lib/info_screen.dart` and `lib/quiz_screen.dart` at
`http://localhost:8787` while testing locally.
