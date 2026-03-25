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
- artifact upload
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

## Sync Refuses to Run

The sync reusable workflow is strict about provenance.

It will fail if:

- the triggering workflow is not `Release`
- the triggering branch is not `release`
- the triggering repository does not match the caller repo
- the workflow run did not succeed

Check:

- caller `workflow_run` wrapper
- source workflow name
- source branch

## Sync Cannot Download `release-record`

Common causes:

- release wrapper ran with `publish: false`
- the release workflow failed before artifact upload
- the artifact name drifted away from `release-record`

Check:

- release run summary
- `Upload release record` step
- artifact list on the triggering run

## Sync Rejects the Record SHA

This means:

- `release-record.json.sha`
- and `github.event.workflow_run.head_sha`

do not match.

Treat that as a real provenance failure. Do not bypass it by editing the sync workflow contract.

## Sync Creates No PR

That is expected when `release.json` already matches `main`.

Current behavior:

- no commit is created
- no new PR is opened
- any stale open sync PR on `automation/sync-release-record` is closed

## Sync PR Does Not Merge

Common causes:

- repository does not allow auto-merge
- merge commits are disabled
- required main check such as `validate-main-summary` is missing or failing
- GitHub App permissions are incomplete

Check:

- repository merge settings
- `validate-main.yml` wrapper
- branch protection / required checks on `main`
- GitHub App installation permissions

## Wrapper Validator Fails

For `validate-sync-wrapper.yml`, common causes are:

- extra steps or `runs-on` added to the wrapper
- missing concurrency block
- wrong permissions
- unpinned `uses:`
- wrong secret mapping
- non-digest tool image

For `validate-release-json.yml`, common causes are:

- missing `release.json`
- invalid record schema
- wrong planner image pin
