# CI and building locally

## CI

`.github/workflows/build.yml` builds and pushes `ghcr.io/<owner>/<repo>` on
every push to `main` (and on tags or manual runs with a specific tweb ref).
No repository secrets are needed: the image carries placeholder credentials
only, and the real api_id/api_hash are injected from the environment when a
container starts. Making the package public is therefore safe (it starts
private; change the visibility in the package settings if you want).

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

then `docker compose pull && docker compose up -d`. The patch only touches
endpoint construction, so it usually applies cleanly; if upstream refactors
`dcConfigurator.ts`, the build fails at `git apply` and the patch needs a
rebase.
