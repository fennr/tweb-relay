# syntax=docker/dockerfile:1

# Telegram Web K (tweb) with a same-origin MTProto relay.
#
#   1. clone upstream tweb, apply the DC-relay patch
#   2. build the SPA with the given api_id/api_hash and relay prefixes
#   3. merge dist/ into public/ (Vite uses copyPublicDir: false)
#   4. serve the result from nginx, which also relays /tgws and /tgw
#
# The relay endpoints are served by the same nginx (see nginx/conf.d/default.conf),
# so a browser only ever talks to this container's host.

ARG NODE_IMAGE=node:24-bookworm-slim

FROM ${NODE_IMAGE} AS build

ARG TWEB_REPO=https://github.com/morethanwords/tweb.git
ARG TWEB_REF=master
ARG API_ID
ARG API_HASH

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 --branch "${TWEB_REF}" "${TWEB_REPO}" . \
 && git rev-parse --short HEAD > /tmp/tweb-revision

COPY patches/ /tmp/patches/
RUN git apply --verbose /tmp/patches/0001-dc-relay.patch

RUN corepack enable && pnpm install --frozen-lockfile

# Credentials and relay prefixes are baked into the bundle at build time.
RUN test -n "$API_ID" && test -n "$API_HASH" \
 && sed -i "s|^VITE_API_ID=.*|VITE_API_ID=${API_ID}|; s|^VITE_API_HASH=.*|VITE_API_HASH=${API_HASH}|" .env \
 && printf 'VITE_TG_RELAY_WS=/tgws\nVITE_TG_RELAY_HTTP=/tgw\n' >> .env

RUN pnpm exec vite build

COPY scripts/assemble.mjs /tmp/assemble.mjs
RUN node /tmp/assemble.mjs \
 && grep -q '/tgws' public/index.worker-*.js \
 && ! grep -rq 'kws2.web.telegram.org' public/app-*.js


FROM nginx:1.27-alpine AS runtime

RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/snippets/ /etc/nginx/snippets/
COPY --from=build /src/public/ /usr/share/nginx/html/
COPY --from=build /tmp/tweb-revision /usr/share/nginx/tweb-revision

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
