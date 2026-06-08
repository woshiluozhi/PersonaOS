# CI Handoff

This directory contains CI templates that are safe to commit with the current GitHub credentials.

## GitHub Pages

`ci/deploy-pages.workflow.yml` is the desired GitHub Pages workflow for publishing `docs/`.

The current local OAuth credential was rejected by GitHub when trying to push an active workflow file under `.github/workflows/` because it does not have the `workflow` scope. To activate the workflow, the repository owner should use GitHub web UI, `gh` with a token that has workflow scope, or another authorized Git client to copy:

```sh
ci/deploy-pages.workflow.yml
```

to:

```sh
.github/workflows/deploy-pages.yml
```

Then enable Pages with Source set to GitHub Actions and run:

```sh
scripts/verify_app_store_readiness.sh --with-public-pages
```
