#!/bin/sh
# Скачивает файлы, нужные для standalone-развёртывания tweb-relay: compose, Caddyfile и .env.
#
#   curl -fsSL https://raw.githubusercontent.com/fennr/tweb-relay/main/scripts/install.sh | sh
set -eu

BASE=https://raw.githubusercontent.com/fennr/tweb-relay/main
DIR=${1:-tweb-relay}

command -v curl >/dev/null 2>&1 || { echo 'нужен curl' >&2; exit 1; }

mkdir -p "$DIR/standalone"
curl -fsSLo "$DIR/docker-compose.standalone.yml" "$BASE/docker-compose.standalone.yml"
curl -fsSLo "$DIR/standalone/Caddyfile" "$BASE/standalone/Caddyfile"

if [ ! -f "$DIR/.env" ]; then
	curl -fsSLo "$DIR/.env" "$BASE/.env.example"
	echo "создан $DIR/.env — заполните TWEB_HOST, TWEB_API_ID, TWEB_API_HASH"
else
	echo "$DIR/.env уже есть, не трогаю"
fi

echo "Готово. Дальше:"
echo "  cd $DIR && \$EDITOR .env    # TWEB_HOST, TWEB_API_ID, TWEB_API_HASH"
echo "  docker compose -f docker-compose.standalone.yml up -d"
