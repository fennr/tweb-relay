# tweb-relay

Self-hosted [Telegram Web K](https://github.com/morethanwords/tweb) that keeps
working on networks where Telegram is blocked.

The browser only ever talks to your own domain. nginx serves the SPA **and**
relays the MTProto streams (`/tgws/...`, `/tgw/...`) to Telegram, so neither the
page nor the protocol traffic ever goes to `*.web.telegram.org`.

```
browser ──TLS──> Traefik ──> nginx ──TLS──> Telegram
                            ├── /                       static bundle
                            ├── /tgws/<dc>[-1]/apiws ──> kws<dc>.web.telegram.org
                            └── /tgw/<dc>[-1]/apiw1  ──> pluto|venus|aurora|vesta|flora
```

MTProto stays end-to-end encrypted between the browser and Telegram: the relay
forwards bytes and cannot read or modify messages. Only those two path prefixes
are proxied; everything else is static files. It is not an open proxy.

## What is in here

| Path | Purpose |
|---|---|
| `Dockerfile` | clones upstream tweb, applies the relay patch, builds the SPA, serves it from nginx |
| `patches/0001-dc-relay.patch` | makes `dcConfigurator.ts` build DC endpoints from `location.origin` when `VITE_TG_RELAY_*` is set |
| `nginx/conf.d/default.conf` | static site + relay locations + cache/security headers |
| `nginx/snippets/mtproto-*.conf` | WebSocket upgrade / POST transport proxying |
| `scripts/assemble.mjs` | merges Vite's `dist/` into `public/` (upstream `copyPublicDir: false`) |
| `docker-compose.yml` | run the published image behind Traefik |
| `docker-compose.build.yml` | override to build locally instead of pulling |
| `.github/workflows/build.yml` | builds and pushes `ghcr.io/<owner>/<repo>` on every push to `main` |

## Requirements

* Telegram `api_id` / `api_hash` from <https://my.telegram.org> (API development
  tools). They are baked into the JavaScript at build time — the app identifies
  itself with them, so use your own pair.
* A Docker host reachable from the clients, with Traefik already running on an
  external network (the default here is `traefik`).
* A DNS A record for the hostname pointing at that host.

## Build (CI)

Push to `main`. The workflow expects two repository secrets:

```sh
gh secret set TWEB_API_ID  --body '<your-api-id>'
gh secret set TWEB_API_HASH --body '<your-api-hash>'
```

It publishes `ghcr.io/<owner>/<repo>:latest` plus `sha-<commit>` and tag refs.
The package stays private (it contains the bundled credentials).

## Deploy

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env            # set TWEB_HOST at least

# private registry: one-time login on the server, token needs read:packages
echo "$GHCR_PAT" | docker login ghcr.io -u <owner> --password-stdin

docker compose up -d
docker compose logs -f
```

Then point the DNS record at the host. Traefik issues the certificate on the
first request.

Verify:

```sh
curl -sI https://tg.example.com | head -1                  # 200
curl -s -o /dev/null -w '%{http_code}\n' \
  https://tg.example.com/tgws/2/apiws                      # 426 (needs an Upgrade)
```

The real check is opening the page from a network where Telegram is blocked: the
login QR must appear. Its presence means `auth.exportLoginToken` succeeded
through the relay.

## Build locally instead of CI

```sh
TWEB_API_ID=... TWEB_API_HASH=... \
  docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --build
```

## Switching an existing bind-mount deployment

An earlier setup may serve a prebuilt `site/` directory from `./nginx`. The
image is a drop-in replacement: point `TWEB_IMAGE` at the published tag, remove
the `site`/`nginx` volume mounts, and recreate.

```sh
docker compose down
docker compose up -d          # pulls the image instead of mounting ./site
```

The relay paths (`/tgws`, `/tgw`) are inside the image, so nothing else changes.

## Updating tweb

Bump `TWEB_REF` (branch, tag or commit) in the workflow:

```sh
gh workflow run build-and-publish -f ref=v2.2.0   # or edit TWEB_REF default
docker compose pull && docker compose up -d
```

The patch is small and only touches endpoint construction, so it usually applies
cleanly; if upstream refactors `dcConfigurator.ts` the CI build fails at
`git apply` and the patch needs a rebase.

## What works and what does not

* Login (QR and phone code), chats, media and file uploads go through MTProto —
  they work on a blocked network, but **all media traffic now uses the server's
  bandwidth and IP**.
* **Voice/video calls** use WebRTC against Telegram's media servers over
  UDP/TCP, not MTProto. They will most likely still be blocked.
* **Passkey login** talks to Telegram's WebAuthn endpoints; may not work.
* First visit is slower (cold bundle cache + full DH handshake through the
  relay, ~10–20 s on a slow link); later visits render the QR in ~2 s.
* Diagnostic URL flags: `?http=1` forces the HTTPS transport, `?noSharedWorker=1`
  avoids the shared worker, `?debug=1` prints the protocol log to the console.

## Known quirk: Traefik loses the route after a container recreate

Traefik 3.1.5 occasionally misses the `start` event of a recreated container:
the container is healthy, but the host returns Traefik's plain-text
`404 page not found` while every other site keeps working.

```sh
curl -sI https://tg.example.com | head -1   # after --force-recreate
docker restart traefik-reverse-proxy-1     # if 404, a few seconds of downtime
```
