# tweb-relay

EN | [Русский](README.ru.md)

Self-hosted [Telegram Web K](https://github.com/morethanwords/tweb) that keeps
working on networks where Telegram is blocked.

The browser only ever talks to your own domain: nginx serves the SPA **and**
relays the MTProto streams (`/tgws/...`, `/tgw/...`) to Telegram, so neither
the page nor the protocol traffic ever goes to `*.web.telegram.org`.

```
browser ──TLS──> reverse proxy ──> nginx ──TLS──> Telegram
                                  ├── /                      static bundle
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
| `docker-compose.yml` | deploy behind an existing Traefik |
| `docker-compose.standalone.yml` | deploy without a reverse proxy (Caddy, automatic TLS) |
| `.github/workflows/build.yml` | builds and pushes `ghcr.io/<owner>/<repo>` — see *Building in your own CI* |

## Requirements

* A Docker host reachable from the clients.
* Telegram `api_id` / `api_hash` (see below). They are baked into the
  JavaScript at build time — the app identifies itself with them, so use your
  own pair.
* A domain with a DNS A/AAAA record pointing at that host.

## Getting api_id / api_hash

1. Log in at <https://my.telegram.org>.
2. Open **API development tools**.
3. Create an application (any title will do) and copy **api_id** and
   **api_hash**.

You only do this once; the pair is used at image build time and never leaves
your `.env` (and, in CI, your repository secrets).

## Quick start (standalone, Caddy)

No reverse proxy needed: Caddy terminates TLS and renews certificates
automatically. Ports 80/443 must be free on the host.

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env            # set TWEB_HOST, TWEB_API_ID, TWEB_API_HASH

docker compose -f docker-compose.standalone.yml up -d
```

The first `up` builds the image (several minutes: clones upstream tweb,
installs dependencies, builds the SPA). The web client then answers on
`https://<TWEB_HOST>`.

## Behind Traefik

If Traefik already runs on an external Docker network:

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env            # TWEB_HOST, TWEB_API_ID, TWEB_API_HASH, TRAEFIK_*

docker compose up -d
```

`TRAEFIK_NETWORK` must be the network Traefik watches, `TRAEFIK_ENTRYPOINT`
and `TRAEFIK_CERTRESOLVER` — your entrypoint and certificate resolver names.

## Verify

```sh
curl -sI https://tg.example.com | head -1                  # 200
curl -s -o /dev/null -w '%{http_code}\n' \
  https://tg.example.com/tgws/2/apiws                      # 426 (needs an Upgrade)
```

The real check is opening the page from a network where Telegram is blocked:
the login QR must appear. Its presence means `auth.exportLoginToken` succeeded
through the relay.

## Updating tweb

Set `TWEB_REF` (branch, tag or commit) in `.env` and rebuild:

```sh
docker compose up -d --build
```

The patch is small and only touches endpoint construction, so it usually
applies cleanly; if upstream refactors `dcConfigurator.ts` the build fails at
`git apply` and the patch needs a rebase.

## Building in your own CI

`.github/workflows/build.yml` builds the image in GitHub Actions from the
`TWEB_API_ID` / `TWEB_API_HASH` repository secrets and pushes it to
`ghcr.io/<owner>/<repo>`. The image contains the bundled credentials, so keep
the package private. Building locally (the default here) and building in CI
produce the same result — pick whichever suits you.

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

## Protecting your instance

Anyone who can reach the domain sees the Telegram login page. Logging in still
requires the account owner's credentials, but if you do not want a public
login page on your domain, put an access control in front of it (IP allowlist
or forward-auth middleware in your reverse proxy). Remember also that media
traffic of logged-in users consumes your server's bandwidth and IP.

## Troubleshooting

* **Traefik loses the route after a container recreate.** Traefik 3.1.5
  occasionally misses the `start` event of a recreated container: the container
  is healthy, but the host returns Traefik's plain-text `404 page not found`
  while every other site keeps working. Restarting the Traefik container
  restores the route in a few seconds.
* First page load times out on a very slow link — the cold DH handshake goes
  through the relay; try again, later visits are fast.
* Persistent errors in the console — open the page with `?debug=1` and compare
  the transport log against the nginx access log.

## License

MIT — see [LICENSE](LICENSE). Upstream
[Telegram Web K](https://github.com/morethanwords/tweb) keeps its own license
and its own repository; this patch set is not affiliated with Telegram.
