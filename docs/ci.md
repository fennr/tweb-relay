# CI and building locally

## CI

`.github/workflows/build.yml` builds and pushes `ghcr.io/<owner>/<repo>` on
every push to `main` (and on tags or manual runs with a specific tweb ref).
No repository secrets are needed: the image carries placeholder credentials
only, and the real api_id/api_hash are injected from the environment when a
container starts. Making the package public is therefore safe (it starts
private; change the visibility in the package settings if you want).

## Versions

Images follow the project's SemVer. A release is a git tag:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

The workflow publishes `1.0.0`, `1.0`, `1` and `sha-<commit>` for it; `latest`
tracks `main`. Pin `TWEB_IMAGE` to a version tag in `.env` to avoid implicit
updates via `latest`. The exact upstream tweb revision built into the image
is written to `/usr/share/nginx/tweb-revision` and is reachable at
`https://<host>/tweb-revision`.

## Building locally

```sh
docker build -t tweb-relay:local .
```

No build arguments are needed. Point `TWEB_IMAGE=tweb-relay:local` in `.env`
at it.

## Updating tweb

Run the workflow against another ref (or change the `TWEB_REF` default):

```sh
gh workflow run build-and-publish -f ref=v2.2.0
```

then `docker compose pull && docker compose up -d` and bump the project tag
(`vX.Y.Z`) so the update gets a pinned version. The patch only touches
endpoint construction, so it usually applies cleanly; if upstream refactors
`dcConfigurator.ts`, the build fails at `git apply` and the patch needs a
rebase.
