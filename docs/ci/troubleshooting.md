# CI Troubleshooting

## `tool-image` Validation Fails

Accepted forms are:

- `ghcr.io/runlix/build-workflow-tools@sha256:<digest>`
- `ghcr.io/runlix/build-workflow-tools:sha-<40-char git sha>`

Common causes:

- using `:ci`
- using an unpinned branch or tag
- passing a digest for a different image

Check:

- caller wrapper input
- `validate-inputs` logs

## Config Validation Fails

Common causes:

- `image` is outside `ghcr.io/runlix`
- invalid target name
- invalid manifest tag
- unsupported platform
- missing Dockerfile
- missing effective test script
- build context directory does not exist
- duplicate enabled `manifest_tag` / `platform` pair
- all targets are disabled

Check:

- `.ci/config.json`
- `schema/ci-config.schema.json`
- `build-workflow-ci validate-config`

## Build Planning Looks Wrong

Remember that effective values come from:

- `defaults.context`
- `defaults.test`
- `defaults.build_args`
- then target-level overrides

If a target gets the wrong build arg or test script, inspect both:

- `defaults`
- that target block

Use:

```bash
build-workflow-ci plan-build-target .ci/config.json --target-name <name> --mode pr --short-sha 1234567
```

to inspect the exact planned payload.

## Validate Builds but Release Publishes Nothing

Check `publish`.

If `publish: false`, the workflow intentionally skips:

- GHCR login
- push steps
- manifest creation
- `release.json` rendering
- artifact upload
- attestation
- optional main sync
- Telegram notification

That is expected in provider tests and maintainer dry runs.

## Temporary Pushes Succeed but Manifest Creation Fails

Common causes:

- one target never pushed
- manifest refs were computed from an outdated short SHA
- caller wrapper is missing `packages: write`
- GHCR auth failed in release mode

Check:

- `build-and-push` job logs
- `plan-manifests` output
- `publish` job logs

## Attestation Fails

Common causes:

- the caller wrapper did not grant `attestations: write`
- the caller wrapper did not grant `id-token: write`
- registry publication failed before the attestation job ran

Check:

- caller release wrapper permissions
- `publish` job result
- `attest` job logs

## Telegram Notification Fails

The release workflow treats Telegram as non-blocking.

If the step fails:

- the release can still succeed
- the step summary and logs will show the notification failure

Common causes:

- one Telegram secret missing
- invalid bot token
- invalid chat ID
- Telegram API error

## Sync Does Not Run

Common causes:

- `publish: false`
- `RUNLIX_APP_ID` and `RUNLIX_PRIVATE_KEY` were not both mapped
- the release workflow failed before the sync job became eligible

Check:

- release wrapper secret mapping
- `validate-inputs` outputs
- release run summary

## Sync Creates No PR

That is expected when `release.json` already matches `main`.

Current behavior:

- no commit is created
- no new PR is opened

## Sync PR Does Not Merge

Common causes:

- repository does not allow auto-merge
- merge commits are disabled
- the required main check is missing or failing
- GitHub App permissions are incomplete

Check:

- repository merge settings
- `validate-main.yml` wrapper
- branch protection / required checks on `main`
- GitHub App installation permissions

## `validate-main.yml` Does Not Run

Common causes:

- the wrapper only watches `release.json`, and the PR changed only the wrapper file
- branch protection expects a different job name than the wrapper actually emits

Use:

- `workflow_dispatch` for wrapper-only validation runs
- or add `.github/workflows/validate-main.yml` to the wrapper's own top-level `paths` list if the repository wants wrapper edits to trigger automatically

## Release JSON Validation Fails

Common causes are:

- missing `release.json`
- invalid metadata schema
- wrong planner image pin
