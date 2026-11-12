# tweb-relay

EN | [Русский](README.ru.md)

Self-hosted [Telegram Web K](https://github.com/morethanwords/tweb) for
networks where Telegram is blocked: nginx serves the web client and relays
MTProto to Telegram from your own domain, so nothing touches
`*.web.telegram.org`. MTProto stays end-to-end encrypted — the relay forwards
bytes, it is not a proxy and cannot read messages.

## Quick start

You need Docker, a domain with a DNS record pointing at the host, free ports
80/443, and your Telegram api_id/api_hash — get it once at
<https://my.telegram.org> (API development tools); the image ships without
any credentials, they are injected when the container starts.

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env    # TWEB_HOST, TWEB_API_ID, TWEB_API_HASH

docker compose -f docker-compose.standalone.yml up -d
```

TLS certificates are issued and renewed automatically (Caddy). The
credentials live only in your `.env` and in the running container, never in
the image.

Already running Traefik? Use `docker-compose.yml` instead —
[docs/traefik.md](docs/traefik.md).

## Limitations

- Voice/video calls (WebRTC, not MTProto) will most likely stay blocked.
- All media of logged-in users consumes the server's bandwidth and IP.
- First visit is slow (full DH handshake through the relay); later visits
  are fast.
- Passkey login may not work.

## Documentation

- [How it works](docs/how-it-works.md) — relay paths, repository layout,
  protecting your instance
- [Behind Traefik](docs/traefik.md)
- [Troubleshooting](docs/troubleshooting.md) — checks, diagnostic flags
- [Own CI build and updating tweb](docs/ci.md)

## License

MIT — see [LICENSE](LICENSE). Upstream
[Telegram Web K](https://github.com/morethanwords/tweb) keeps its own license;
this project is not affiliated with Telegram.
