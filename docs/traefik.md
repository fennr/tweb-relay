# Behind Traefik

`docker-compose.yml` expects Traefik already running on an external Docker
network and issuing certificates:

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env

docker compose up -d
```

Besides `TWEB_HOST`, `TWEB_API_ID` and `TWEB_API_HASH`, the `.env` carries:

| Variable | Meaning | Default |
|---|---|---|
| `TRAEFIK_NETWORK` | external Docker network Traefik watches | `traefik` |
| `TRAEFIK_ENTRYPOINT` | Traefik entrypoint serving TLS | `https` |
| `TRAEFIK_CERTRESOLVER` | certificate resolver name | `le` |
| `TWEB_ROUTER` | Traefik router / service name | `tweb` |
| `TWEB_CONTAINER` | container name | `tweb` |

Host rule, TLS and cert-resolver labels are already in the compose file —
nothing to edit there.

## Known quirk: route lost after a container recreate

Traefik 3.1.5 occasionally misses the `start` event of a recreated container:
the container is healthy, but the host returns Traefik's plain-text
`404 page not found` while every other site keeps working. Restarting the
Traefik container restores the route in a few seconds.
