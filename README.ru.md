# tweb-relay

[English](README.md) | RU

Self-hosted [Telegram Web K](https://github.com/morethanwords/tweb)
для сетей, где Telegram заблокирован: nginx отдаёт веб-клиент и ретранслирует
MTProto в Telegram с вашего домена, поэтому ни страница, ни трафик
не обращаются к `*.web.telegram.org`. MTProto зашифрован сквозным образом —
сервис не может прочитать ваш трафик.

## Быстрый старт

Нужны Docker, домен с DNS-записью на хост, свободные порты 80/443 и ваши
api_id/api_hash от Telegram — получить один раз на <https://my.telegram.org>
(API development tools).

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env    # TWEB_HOST, TWEB_API_ID, TWEB_API_HASH

docker compose -f docker-compose.standalone.yml up -d
```

Сертификаты TLS выпускаются и продлеваются автоматически через Caddy в
`docker-compose.standalone.yml`. Если используете Traefik, берите
`docker-compose.yml` — [docs/traefik.md](docs/traefik.md).

## Ограничения

- Голосовые/видеозвонки (WebRTC, не MTProto) не поддерживаются
- Весь медиатрафик вошедших пользователей идёт через ваш сервер
- Первый визит медленный (полный DH-handshake через релей); повторные —
  быстрые.
- Вход по пасскею может не работать.

## Документация

- [Как это работает](docs/how-it-works.md) — пути, состав репозитория
- [Про Traefik](docs/traefik.md)
- [Разбор проблем](docs/troubleshooting.md) — проверки, диагностические флаги
- [Сборка в своём CI и обновление tweb](docs/ci.md)

## Лицензия

MIT — см. [LICENSE](LICENSE). Upstream
[Telegram Web K](https://github.com/morethanwords/tweb) живёт в своём
репозитории под собственной лицензией; проект не связан с Telegram.
