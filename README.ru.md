# tweb-relay

[English](README.md) | RU

Самостоятельно размещаемый [Telegram Web K](https://github.com/morethanwords/tweb),
который продолжает работать в сетях, где Telegram заблокирован.

Браузер общается только с вашим доменом: nginx отдаёт статику SPA **и**
ретранслирует MTProto-потоки (`/tgws/...`, `/tgw/...`) в Telegram, поэтому ни
страница, ни трафик протокола не обращаются к `*.web.telegram.org`.

```
браузер ──TLS──> reverse proxy ──> nginx ──TLS──> Telegram
                                  ├── /                      статический бандл
                                  ├── /tgws/<dc>[-1]/apiws ──> kws<dc>.web.telegram.org
                                  └── /tgw/<dc>[-1]/apiw1  ──> pluto|venus|aurora|vesta|flora
```

MTProto остаётся сквозь зашифрованным между браузером и Telegram: релей
пересылает байты и не может прочитать или изменить сообщения. Проксируются
только эти два префикса путей, всё остальное — статические файлы. Это не
открытый прокси.

## Что внутри

| Путь | Назначение |
|---|---|
| `Dockerfile` | клонирует upstream tweb, накладывает патч релея, собирает SPA, отдаёт через nginx |
| `patches/0001-dc-relay.patch` | учит `dcConfigurator.ts` строить адреса DC от `location.origin`, если заданы `VITE_TG_RELAY_*` |
| `nginx/conf.d/default.conf` | статика + локации релея + заголовки кеша и безопасности |
| `nginx/snippets/mtproto-*.conf` | проксирование WebSocket-upgrade / POST-транспорта |
| `scripts/assemble.mjs` | сливает `dist/` Vite в `public/` (upstream `copyPublicDir: false`) |
| `docker-compose.yml` | развёртывание за существующим Traefik |
| `docker-compose.standalone.yml` | развёртывание без reverse proxy (Caddy, автоматический TLS) |
| `.github/workflows/build.yml` | собирает и публикует `ghcr.io/<owner>/<repo>` — см. *Сборка в своём CI* |

## Требования

* Docker-хост, доступный клиентам.
* Telegram `api_id` / `api_hash` (см. ниже). Они зашиваются в JavaScript при
  сборке — приложение представляется ими, поэтому используйте собственную пару.
* Домен с DNS-записью A/AAAA, указывающей на этот хост.

## Где взять api_id / api_hash

1. Войдите на <https://my.telegram.org>.
2. Откройте **API development tools**.
3. Создайте приложение (любое название) и скопируйте **api_id** и **api_hash**.

Делается один раз; пара используется при сборке образа и никогда не покидает
ваш `.env` (а в CI — секреты репозитория).

## Быстрый старт (standalone, Caddy)

Reverse proxy не нужен: Caddy сам терминирует TLS и продлевает сертификаты.
Порты 80/443 должны быть свободны на хосте.

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env            # задать TWEB_HOST, TWEB_API_ID, TWEB_API_HASH

docker compose -f docker-compose.standalone.yml up -d
```

Первый `up` собирает образ (несколько минут: клонируется upstream tweb,
ставятся зависимости, собирается SPA). Дальше клиент отвечает на
`https://<TWEB_HOST>`.

## За Traefik

Если Traefik уже работает на внешней Docker-сети:

```sh
git clone https://github.com/fennr/tweb-relay.git
cd tweb-relay
cp .env.example .env
$EDITOR .env            # TWEB_HOST, TWEB_API_ID, TWEB_API_HASH, TRAEFIK_*

docker compose up -d
```

`TRAEFIK_NETWORK` — сеть, которую смотрит Traefik, `TRAEFIK_ENTRYPOINT` и
`TRAEFIK_CERTRESOLVER` — имена вашего entrypoint и выпускателя сертификатов.

## Проверка

```sh
curl -sI https://tg.example.com | head -1                  # 200
curl -s -o /dev/null -w '%{http_code}\n' \
  https://tg.example.com/tgws/2/apiws                      # 426 (нужен Upgrade)
```

Настоящая проверка — открыть страницу из сети, где Telegram заблокирован:
должен появиться QR-код входа. Он означает, что `auth.exportLoginToken`
прошёл через релей.

## Обновление tweb

Задайте `TWEB_REF` (ветка, тег или коммит) в `.env` и пересоберите:

```sh
docker compose up -d --build
```

Патч маленький и затрагивает только построение адресов, поэтому обычно
накладывается без конфликтов; если upstream переписал `dcConfigurator.ts`,
сборка падает на `git apply`, и патч нужно перебазировать.

## Сборка в своём CI

`.github/workflows/build.yml` собирает образ в GitHub Actions из секретов
репозитория `TWEB_API_ID` / `TWEB_API_HASH` и публикует его в
`ghcr.io/<owner>/<repo>`. В образ зашиты ваши креды, поэтому пакет должен
оставаться приватным. Локальная сборка (здесь по умолчанию) и сборка в CI дают
одинаковый результат — выбирайте, что удобнее.

## Что работает и что нет

* Вход (QR и код по телефону), чаты, медиа и загрузка файлов идут через
  MTProto — в заблокированной сети они работают, но **весь медиатрафик теперь
  расходует канал и IP сервера**.
* **Голосовые/видеозвонки** идут через WebRTC к медиасерверам Telegram по
  UDP/TCP, а не MTProto. Скорее всего, останутся заблокированными.
* **Вход по пасскею** обращается к WebAuthn-эндпоинтам Telegram; может не
  работать.
* Первый визит медленнее (холодный кеш бандла + полный DH-handshake через
  релей, ~10–20 с на медленном канале); повторные визиты рисуют QR за ~2 с.
* Диагностические флаги URL: `?http=1` принудительно включает HTTPS-транспорт,
  `?noSharedWorker=1` отключает shared worker, `?debug=1` выводит протокольный
  лог в консоль.

## Защита своего экземпляра

Кто угодно, дотянувшийся до домена, видит страницу входа Telegram. Для входа
всё равно нужны учётные данные владельца аккаунта, но если не хочется
публичной страницы входа на своём домене, поставьте перед ней ограничение
доступа (allowlist по IP или forward-auth middleware в reverse proxy). Помните
также, что медиатрафик вошедших пользователей расходует канал и IP вашего
сервера.

## Разбор проблем

* **Traefik теряет маршрут после пересоздания контейнера.** Traefik 3.1.5
  иногда пропускает событие `start` пересозданного контейнера: контейнер
  healthy, но хост отвечает голым `404 page not found` от Traefik, тогда как
  остальные сайты работают. Рестарт контейнера Traefik возвращает маршрут за
  несколько секунд.
* Первая загрузка не успевает на очень медленном канале — холодный
  DH-handshake идёт через релей; повторите попытку, дальше быстро.
* Стабильные ошибки в консоли — откройте страницу с `?debug=1` и сверьте
  протокольный лог с access-логом nginx.

## Лицензия

MIT — см. [LICENSE](LICENSE). Upstream
[Telegram Web K](https://github.com/morethanwords/tweb) живёт в своём
репозитории под собственной лицензией; этот набор патчей не связан с Telegram.
