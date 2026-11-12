# Troubleshooting

## Checks

```sh
curl -sI https://tg.example.com | head -1                  # 200
curl -s -o /dev/null -w '%{http_code}\n' \
  https://tg.example.com/tgws/2/apiws                      # 426 (needs an Upgrade)
```

The real check is opening the page from a network where Telegram is blocked:
the login QR must appear — it means `auth.exportLoginToken` succeeded through
the relay.

## First page load is slow or times out

Cold bundle cache plus a full DH handshake through the relay takes ~10–20 s on
a slow link. Retry; later visits render the QR in ~2 s.

## Persistent errors in the console

Open the page with diagnostic URL flags:

- `?http=1` — force the HTTPS transport,
- `?noSharedWorker=1` — avoid the shared worker,
- `?debug=1` — print the protocol log to the console.

Compare the log with the nginx access log: `docker compose logs tweb`.
