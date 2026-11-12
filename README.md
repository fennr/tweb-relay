# tweb-relay

EN | [Русский](README.ru.md)

Self-hosted [Telegram Web K](https://github.com/morethanwords/tweb)
for networks where Telegram is blocked: nginx serves the web client and
relays MTProto to Telegram from your own domain, so neither the page nor
the traffic touches `*.web.telegram.org`. MTProto is end-to-end encrypted —
the service cannot read your traffic.

## Quick start

You need Docker, a domain with a DNS record pointing at the host, free ports
80/443 and your api_id/api_hash — get them once at <https://my.telegram.org>
(API development tools).

```sh
curl -fsSL https://raw.githubusercontent.com/fennr/tweb-relay/main/scripts/install.sh | sh
cd tweb-relay
$EDITOR .env    # TWEB_HOST, TWEB_API_ID, TWEB_API_HASH

docker compose -f docker-compose.standalone.yml up -d
```

Or clone the repository:
`git clone --depth 1 https://github.com/fennr/tweb-relay.git`.

TLS certificates are issued and renewed automatically via Caddy in
`docker-compose.standalone.yml`. 

Already running Traefik? Take
`docker-compose.yml` — [docs/traefik.md](docs/traefik.md).

## Limitations

- Voice/video calls (WebRTC, not MTProto) are not supported.
- All media of logged-in users goes through your server.
- First visit is slow (full DH handshake through the relay); repeat visits
  are fast.
- Passkey login may not work.

## Documentation

- [How it works](docs/how-it-works.md) — relay paths, repository layout
- [Behind Traefik](docs/traefik.md)
- [Troubleshooting](docs/troubleshooting.md) — checks, diagnostic flags
- [Own CI build and updating tweb](docs/ci.md)

## License

MIT — see [LICENSE](LICENSE). Upstream
[Telegram Web K](https://github.com/morethanwords/tweb) keeps its own license;
this project is not affiliated with Telegram.
