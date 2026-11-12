#!/bin/sh
# Replaces the placeholder api_id/api_hash baked at build time with the real
# values from the API_ID / API_HASH environment. Without them the client
# cannot connect to Telegram, so a missing variable aborts the start.
#
# The placeholders (id 1112223331, 32 hex zeros) occur in the minified bundle
# only inside the credential object ({id:<id>,hash:`<hash>`}) — once per js
# chunk — so plain digit replacement is unambiguous.

set -e

: "${API_ID:?API_ID is required}"
: "${API_HASH:?API_HASH is required}"

case "$API_ID" in '' | *[!0-9]*) echo 'API_ID must be numeric' >&2; exit 1;; esac
case "$API_HASH" in '' | *[!0-9a-f]*) echo 'API_HASH must be hex' >&2; exit 1;; esac
[ "${#API_HASH}" = 32 ] || { echo 'API_HASH must be 32 hex chars' >&2; exit 1; }

for f in /usr/share/nginx/html/*.js; do
	[ -f "$f" ] || continue
	sed -i "s|1112223331|${API_ID}|g; s|00000000000000000000000000000000|${API_HASH}|g" "$f"
	if grep -qF '1112223331' "$f" || grep -qF '00000000000000000000000000000000' "$f"; then
		echo "credentials injection failed: placeholder remains in ${f##*/}" >&2
		exit 1
	fi
done
