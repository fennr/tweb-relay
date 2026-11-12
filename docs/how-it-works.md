# How it works

The browser only ever talks to your own domain. nginx serves the SPA **and**
relays the MTProto streams to Telegram, so neither the page nor the protocol
traffic ever goes to `*.web.telegram.org`.

```
browser ──TLS──> reverse proxy ──> nginx ──TLS──> Telegram
                                  ├── /                      static bundle
                                  ├── /tgws/<dc>[-1]/apiws ──> kws<dc>.web.telegram.org
                                  └── /tgw/<dc>[-1]/apiw1  ──> pluto|venus|aurora|vesta|flora
```

MTProto stays end-to-end encrypted between the browser and Telegram: the relay
forwards bytes and cannot read or modify messages. Only two path prefixes are
proxied; everything else is static files. It is not an open proxy.

| Prefix | Transport | Upstream |
|---|---|---|
| `/tgws/<dc>[-1]/apiws[_premium]` | WebSocket | `kws<dc>.web.telegram.org` |
| `/tgw/<dc>[-1]/apiw1` | HTTPS POST | `<dc>.web.telegram.org` |

DC1=pluto, DC2=venus, DC3=aurora, DC4=vesta, DC5=flora.

## Repository layout

| Path | Purpose |
|---|---|
| `Dockerfile` | clones upstream tweb, applies the relay patch, builds the SPA with placeholder credentials, serves it from nginx |
| `entrypoint/30-inject-credentials.sh` | injects the real api_id/api_hash from the `API_ID`/`API_HASH` environment into the bundle at container start |
| `patches/0001-dc-relay.patch` | teaches `dcConfigurator.ts` to build DC endpoints from `location.origin` when `VITE_TG_RELAY_*` is set |
| `nginx/conf.d/default.conf` | static site + relay locations + cache/security headers |
| `nginx/snippets/mtproto-*.conf` | WebSocket upgrade / POST transport proxying |
| `scripts/assemble.mjs` | merges Vite's `dist/` into `public/` (upstream `copyPublicDir: false`) |
| `docker-compose.yml` | deploy behind an existing Traefik |
| `docker-compose.standalone.yml` | deploy without a reverse proxy (Caddy, automatic TLS) |

The patch is small and only touches endpoint construction, so it usually
applies cleanly across upstream updates; if upstream refactors
`dcConfigurator.ts`, the build fails at `git apply` and the patch needs a
rebase.

## Protecting your instance

Anyone who can reach the domain sees the Telegram login page; logging in still
requires the account owner's credentials. If you do not want a public login
page on your domain, put an access control in front of it (IP allowlist or
forward-auth middleware in your reverse proxy). Media traffic of logged-in
users consumes the server's bandwidth and IP.
