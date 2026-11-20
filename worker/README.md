# MindSpark AI proxy (Cloudflare Worker)

The Flutter app talks to this worker; the worker adds the NVIDIA API key and
forwards the request to `https://integrate.api.nvidia.com/v1/chat/completions`.
The key never ships inside the app.

## Configuration

| Name       | Where                        | Value                                  |
| ---------- | ---------------------------- | -------------------------------------- |
| `BASE_URL` | `wrangler.toml` `[vars]`     | `https://integrate.api.nvidia.com/v1`  |
| `MODEL`    | `wrangler.toml` `[vars]`     | `minimaxai/minimax-m3.1-flash`         |
| `API_KEY`  | Worker secret                | `nvapi-…` (never commit)               |

Local development values live in `.dev.vars` (gitignored); copy
`.dev.vars.example` if you need to recreate it.

## Deploy

```bash
cd worker
npx wrangler login                 # one-time, interactive browser login
npx wrangler secret put API_KEY    # paste the nvapi-… key when prompted
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
