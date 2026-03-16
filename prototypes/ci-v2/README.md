# CI v2 Prototype

This directory contains an isolated prototype of a simpler CI design.

It is intentionally not wired into the current reusable workflow. The goal is to make the proposed v2 easy to inspect without changing production behavior.

## Layout

- `schema/`: draft schema for `.ci/config.json`
- `scripts/`: shared bash tooling called by workflows
- `sabnzbd/release/`: proposed `release` branch surface for the pilot service
- `sabnzbd/main/`: proposed `main` branch surface for metadata sync

## Design Rules

- workflow YAML only orchestrates jobs
- build logic lives in scripts
- one target equals one build unit
- `release` emits release metadata
- `main` consumes release metadata and writes `releases.json`

## Prototype Scope

The prototype covers:

- config validation
- matrix planning
- build and push command construction
- manifest creation
- release metadata generation
- `main` branch metadata sync

The prototype does not include:

- PR comments
- Telegram notifications
- dependency caching
- vulnerability scanning

Those can be layered on later as separate, optional workflows.
