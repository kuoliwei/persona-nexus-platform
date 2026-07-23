# Same-Origin Deployment Guide

Everything the browser touches is served from **one origin**. Caddy is the single
public entry point; it serves the four frontends as static files and reverse-proxies
`/api/*` to the API Gateway. Because nothing is cross-origin, CORS largely disappears.

## Path layout

| Public path | Served by | Vite `base` |
|-------------|-----------|-------------|
| `/` (and anything unmatched) | lobby frontend | `/` |
| `/login*` | auth frontend | `/login/` |
| `/character*` | character frontend | `/character/` |
| `/chat*` | chat frontend | `/chat/` |
| `/api/*` | api-gateway → backend services | — |

Backend services sit behind the gateway and are never exposed publicly:
auth-service `3001`, user-service `3002`, character-service `3003`,
chat-service `3004`, ai-service `3005`. The gateway's `/internal/*` routes are
for service-to-service calls only and are not routed by Caddy.

## Two Caddyfiles

The upstream addresses differ per mode, so there are two configs:

| File | Used by | Frontends | API upstream |
|------|---------|-----------|--------------|
| `Caddyfile.docker` | docker-compose | pre-built `dist/` served by Caddy | `gateway:8000` (Docker DNS) |
| `Caddyfile` | manual/host run | Vite dev servers (hot reload) | `localhost:8000` |

Inside the Caddy container `localhost` means the container itself, so docker mode
**must** use compose service names. On the host, Docker DNS names don't resolve, so
manual mode **must** use `localhost`. `docker-compose.yml` mounts `Caddyfile.docker`
automatically.

---

## Method 1 — Docker Compose

Frontends are **not** containers. Build them on the host; Caddy mounts each `dist/`
read-only and serves it.

```bash
# 1. Build all four frontends
for d in lobby auth character chat; do (cd ../persona-nexus-$d && npm ci && npm run build); done

# 2. Provide secrets (JWT_SECRET is required — compose fails loudly without it)
cd deploy
cp .env.example .env    # then edit
# or: export JWT_SECRET=...

# 3. Start
docker-compose up -d
```

Open http://localhost:8080.

Re-run the build step and `docker-compose restart caddy` after changing frontend code.

> **Prerequisite:** each backend project (`api-gateway`, `auth-service`, `user-service`,
> `character-service`, `chat-service`, `ai-service`) needs a `Dockerfile` in its root.
> `docker-compose config` only validates YAML — a missing Dockerfile surfaces at
> `docker-compose up --build`.

## Method 2 — Manual / host (best for development)

No Docker required, and you keep Vite hot reload. Caddy proxies to the dev servers.

```bash
# Terminal 1 — reverse proxy (uses ./Caddyfile, the localhost variant)
caddy run --config ./Caddyfile --adapter caddyfile

# Terminals 2-5 — frontends
(cd ../persona-nexus-lobby     && npm run dev)   # 5175
(cd ../persona-nexus-auth      && npm run dev)   # 5173
(cd ../persona-nexus-character && npm run dev)   # 5174
(cd ../persona-nexus-chat      && npm run dev)   # 5176

# Terminal 6 — gateway
(cd ../api-gateway && npm run dev)               # 8000

# Terminals 7+ — backend services
(cd ../auth-service && npm start)                # 3001
(cd ../user-service && npm start)                # 3002
(cd ../character-service && npm start)           # 3003
(cd ../chat-service && npm start)                # 3004
(cd ../ai-service && npm start)                  # 3005
```

Open http://localhost:8080 — the same URLs as production.

---

## Environment variables

`JWT_SECRET` is required and must match auth-service's value; the gateway verifies
tokens auth-service signs.

```bash
JWT_SECRET=<same value as auth-service>
PUBLIC_ORIGIN=http://localhost:8080   # the browser-facing origin
```

Backend upstreams are set in `docker-compose.yml` using service names and normally
need no override.

## Health checks

```bash
curl -i http://localhost:8080/                       # lobby HTML
curl -i http://localhost:8080/login/                  # auth HTML
curl -i http://localhost:8080/character/              # character HTML
curl -i http://localhost:8080/chat/                   # chat HTML
curl -i http://localhost:8080/api/config              # gateway JSON
curl -i http://localhost:8080/my-characters           # lobby SPA fallback
curl -i http://localhost:8080/character/creator-edit.html   # multi-page entry
```

Each frontend path must return **its own** bundle. If `/login/` returns lobby's
HTML, the `handle` ordering in the Caddyfile is wrong — the bare `handle` lobby
fallback must be last.

```bash
docker-compose logs -f            # all
docker-compose logs -f caddy      # routing issues
docker-compose logs -f gateway    # API issues
```

## Stopping

```bash
docker-compose down        # keep volumes
docker-compose down -v     # also drop Caddy's cert/config volumes
```

---

## Troubleshooting

**A frontend path returns the lobby page.** The lobby `handle` has no matcher, so it
catches everything; it must be the last `handle` block.

**Assets 404 under `/login`, `/character`, `/chat`.** The Vite `base` and the Caddy
path must agree. `base` must keep its trailing slash (`/login/`), and the matching
`handle` block strips the prefix (`uri strip_prefix /login`) so `/login/assets/x.js`
maps to `/srv/auth/assets/x.js`.

**Lobby loads but pages are blank.** The lobby fetches HTML partials at runtime from
`/src/*.html`. Those live in `persona-nexus-lobby/public/src/` so Vite copies them
verbatim into `dist/src/`. If they are moved back under `src/`, the dev server still
works but the production build will not contain them.

**Character create/edit iframe is blank.** The character app is multi-page. Its
`vite.config.js` must list `creator-create.html` and `creator-edit.html` in
`build.rollupOptions.input`, or Vite builds only `index.html`.

**`/api/*` returns 502.** Caddy reached the gateway upstream but the gateway is down
or unreachable. A 404 instead would mean the request never matched the `/api/*`
handle. Check `docker-compose logs gateway`.

**`docker-compose up` fails to build.** A service is missing its `Dockerfile`
(see the prerequisite note above).

**Port 8080 in use.** Change the address in both Caddyfiles and the `ports` mapping
in `docker-compose.yml`.

## Production

1. In `Caddyfile.docker`, uncomment the production block and set your domain.
2. Point the domain at the host and open ports 80/443 — Caddy provisions HTTPS via
   Let's Encrypt automatically and renews it.
3. Set `PUBLIC_ORIGIN` to `https://your-domain` and supply a real `JWT_SECRET`.

## References

- [Caddy documentation](https://caddyserver.com/docs/)
- [Platform architecture](../ARCHITECTURE.md)
