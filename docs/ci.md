# Own CI build and updating tweb

## Building in your own CI

`.github/workflows/build.yml` builds the image in GitHub Actions from the
`TWEB_API_ID` / `TWEB_API_HASH` repository secrets and pushes it to
`ghcr.io/<owner>/<repo>`:

```sh
gh secret set TWEB_API_ID  --body '<your-api-id>'
gh secret set TWEB_API_HASH --body '<your-api-hash>'
```

The image contains the bundled credentials, so keep the package private.
Local build (the default here) and CI build produce the same result — pick
whichever suits you.

## Updating tweb

Set `TWEB_REF` (branch, tag or commit) in `.env` and rebuild:

```sh
docker compose up -d --build
```

The patch only touches endpoint construction, so it usually applies cleanly;
if upstream refactors `dcConfigurator.ts`, the build fails at `git apply` and
the patch needs a rebase.
