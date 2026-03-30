from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[3]
SCHEMA_DIR = REPO_ROOT / "schema"

IMAGE_PATTERN = re.compile(r"^ghcr\.io/runlix/[a-z0-9]+([._-][a-z0-9]+)*$")
NAME_PATTERN = re.compile(r"^[a-z0-9-]+$")
TAG_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
DIGEST_PATTERN = re.compile(r"^sha256:[a-f0-9]{64}$")
PLATFORM_RUNNERS = {
    "linux/amd64": "ubuntu-24.04",
    "linux/arm64": "ubuntu-24.04-arm",
}


class CliError(RuntimeError):
    pass


@dataclass(frozen=True)
class Defaults:
    context: str = "."
    test: str | None = None
    build_args: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Target:
    name: str
    manifest_tag: str
    platform: str
    dockerfile: str
    build_args: dict[str, str] = field(default_factory=dict)
    test: str | None = None
    enabled: bool = True


@dataclass(frozen=True)
class Config:
    image: str
    version: str | None
    defaults: Defaults
    targets: list[Target]

    @property
    def enabled_targets(self) -> list[Target]:
        return [target for target in self.targets if target.enabled]


@dataclass(frozen=True)
class Manifest:
    tag: str
    digest: str
    platforms: tuple[str, ...]


def read_json(path: str | Path) -> Any:
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(payload: Any) -> None:
    print(json.dumps(payload, indent=2))


def require_file(path: str | Path) -> Path:
    resolved = Path(path)
    if not resolved.is_file():
        raise CliError(f"File not found: {path}")
    return resolved


def repo_schema(name: str) -> dict[str, Any]:
    return read_json(SCHEMA_DIR / name)


def validate_schema_file(path: str) -> dict[str, Any]:
    schema = read_json(require_file(path))
    Draft202012Validator.check_schema(schema)
    return schema


def validate_schema(payload: Any, schema_name: str) -> None:
    schema = repo_schema(schema_name)
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(payload), key=lambda error: list(error.absolute_path))
    if not errors:
        return

    formatted = []
    for error in errors:
        location = ".".join(str(part) for part in error.absolute_path)
        formatted.append(f"{location or '$'}: {error.message}")
    raise CliError("Schema validation failed:\n" + "\n".join(formatted))


def validate_config_payload(config_path: str) -> dict[str, Any]:
    require_file(config_path)
    payload = read_json(config_path)
    validate_schema(payload, "ci-config.schema.json")
    return payload


def load_config(config_path: str) -> Config:
    payload = validate_config_payload(config_path)

    defaults_payload = payload.get("defaults", {})
    defaults = Defaults(
        context=defaults_payload.get("context", "."),
        test=defaults_payload.get("test"),
        build_args=defaults_payload.get("build_args", {}),
    )

    targets = [
        Target(
            name=item["name"],
            manifest_tag=item["manifest_tag"],
            platform=item["platform"],
            dockerfile=item["dockerfile"],
            build_args=item.get("build_args", {}),
            test=item.get("test"),
            enabled=item.get("enabled", True),
        )
        for item in payload["targets"]
    ]
    config = Config(
        image=payload["image"],
        version=payload.get("version"),
        defaults=defaults,
        targets=targets,
    )
    validate_config_model(config)
    return config


def validate_config_model(config: Config) -> None:
    if not IMAGE_PATTERN.match(config.image):
        raise CliError(f"Unsupported image name: {config.image}")

    duplicate_names = sorted({target.name for target in config.targets if [item.name for item in config.targets].count(target.name) > 1})
    if duplicate_names:
        raise CliError("Duplicate target names detected:\n" + "\n".join(duplicate_names))

    enabled_targets = config.enabled_targets
    if not enabled_targets:
        raise CliError("At least one target must be enabled")

    duplicate_tag_platforms = []
    seen_pairs: set[tuple[str, str]] = set()
    for target in enabled_targets:
        pair = (target.manifest_tag, target.platform)
        if pair in seen_pairs:
            duplicate_tag_platforms.append(f"{target.manifest_tag}\t{target.platform}")
        seen_pairs.add(pair)
    if duplicate_tag_platforms:
        raise CliError("Duplicate enabled manifest_tag/platform pairs detected:\n" + "\n".join(sorted(set(duplicate_tag_platforms))))

    context_path = Path(config.defaults.context)
    if not context_path.is_dir():
        raise CliError(f"Build context directory not found: {config.defaults.context}")

    for target in enabled_targets:
        if not NAME_PATTERN.match(target.name):
            raise CliError(f"Invalid target name: {target.name}")
        if not TAG_PATTERN.match(target.manifest_tag):
            raise CliError(f"Invalid manifest tag: {target.manifest_tag}")
        if target.platform not in PLATFORM_RUNNERS:
            raise CliError(f"Unsupported platform: {target.platform}")
        if not Path(target.dockerfile).is_file():
            raise CliError(f"Target '{target.name}' references a missing Dockerfile: {target.dockerfile}")
        test_path = effective_test(config, target)
        if test_path and not Path(test_path).is_file():
            raise CliError(f"Target '{target.name}' references a missing test script: {test_path}")


def effective_build_args(config: Config, target: Target) -> dict[str, str]:
    merged = dict(config.defaults.build_args)
    merged.update(target.build_args)
    return merged


def effective_test(config: Config, target: Target) -> str:
    return target.test or config.defaults.test or ""


def arch_from_platform(platform: str) -> str:
    return platform.rsplit("/", 1)[1]


def short_sha(source_sha: str) -> str:
    return source_sha[:7]


def release_temp_tag(target: Target, build_short_sha: str) -> str:
    return f"{target.manifest_tag}-{arch_from_platform(target.platform)}-{build_short_sha}"


def validate_config_command(config_path: str) -> dict[str, Any]:
    config = load_config(config_path)
    manifest_tags = sorted({target.manifest_tag for target in config.enabled_targets})
    return {
        "image_name": config.image,
        "version": config.version,
        "enabled_count": len(config.enabled_targets),
        "manifest_tags": manifest_tags,
        "context_dir": config.defaults.context,
    }


def plan_matrix(config_path: str, build_short_sha: str) -> list[dict[str, Any]]:
    config = load_config(config_path)
    matrix = []
    for target in config.enabled_targets:
        arch = arch_from_platform(target.platform)
        matrix.append(
            {
                "name": target.name,
                "image": config.image,
                "version": config.version,
                "manifest_tag": target.manifest_tag,
                "arch": arch,
                "platform": target.platform,
                "runner": PLATFORM_RUNNERS[target.platform],
                "dockerfile": target.dockerfile,
                "context_dir": config.defaults.context,
                "test": effective_test(config, target),
                "build_args": effective_build_args(config, target),
                "pr_local_tag": f"pr-{build_short_sha}-{target.name}",
                "release_temp_tag": release_temp_tag(target, build_short_sha),
            }
        )
    return matrix


def plan_build_target(config_path: str, target_name: str, mode: str, build_short_sha: str) -> dict[str, Any]:
    if mode not in {"pr", "release"}:
        raise CliError("Mode must be 'pr' or 'release'")

    config = load_config(config_path)
    try:
        target = next(item for item in config.enabled_targets if item.name == target_name)
    except StopIteration as exc:
        raise CliError(f"Enabled target not found: {target_name}") from exc

    image_tag = (
        f"{config.image}:pr-{build_short_sha}-{target.name}"
        if mode == "pr"
        else f"{config.image}:{release_temp_tag(target, build_short_sha)}"
    )

    labels = {
        "org.opencontainers.image.created": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "org.opencontainers.image.revision": os.environ.get("GITHUB_SHA", "local"),
        "org.opencontainers.image.source": f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{os.environ.get('GITHUB_REPOSITORY', 'local/repository')}",
    }
    if config.version:
        labels["org.opencontainers.image.version"] = config.version

    return {
        "name": target.name,
        "image_name": config.image,
        "version": config.version,
        "manifest_tag": target.manifest_tag,
        "arch": arch_from_platform(target.platform),
        "platform": target.platform,
        "dockerfile": target.dockerfile,
        "context_dir": config.defaults.context,
        "test": effective_test(config, target),
        "image_tag": image_tag,
        "release_temp_tag": release_temp_tag(target, build_short_sha),
        "build_args": effective_build_args(config, target),
        "labels": labels,
    }


def plan_manifests(config_path: str, build_short_sha: str) -> list[dict[str, Any]]:
    config = load_config(config_path)
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for target in config.enabled_targets:
        groups[target.manifest_tag].append(
            {
                "platform": target.platform,
                "ref": f"{config.image}:{release_temp_tag(target, build_short_sha)}",
            }
        )
    return [
        {
            "image_name": config.image,
            "tag": manifest_tag,
            "platforms": sorted(item["platform"] for item in entries),
            "refs": sorted(item["ref"] for item in entries),
        }
        for manifest_tag, entries in sorted(groups.items())
    ]


def load_manifest_entries(manifests_path: str) -> list[Manifest]:
    require_file(manifests_path)
    payload = read_json(manifests_path)
    if not isinstance(payload, list):
        raise CliError("Manifest payload must be a JSON array")

    manifests: list[Manifest] = []
    for item in payload:
        if not isinstance(item, dict):
            raise CliError("Each manifest entry must be an object")

        tag = item.get("tag")
        digest = item.get("digest")
        platforms = item.get("platforms")

        if not isinstance(tag, str) or not TAG_PATTERN.match(tag):
            raise CliError(f"Invalid manifest tag: {tag}")
        if not isinstance(digest, str) or not DIGEST_PATTERN.match(digest):
            raise CliError(f"Invalid manifest digest for tag {tag}: {digest}")
        if not isinstance(platforms, list) or not platforms:
            raise CliError(f"Manifest {tag} must declare one or more platforms")
        if any(not isinstance(platform, str) for platform in platforms):
            raise CliError(f"Manifest {tag} has a non-string platform entry")

        normalized_platforms = tuple(sorted(set(platforms)))
        if len(normalized_platforms) != len(platforms):
            raise CliError(f"Manifest {tag} contains duplicate platforms")
        for platform in normalized_platforms:
            if platform not in PLATFORM_RUNNERS:
                raise CliError(f"Manifest {tag} uses unsupported platform: {platform}")

        manifests.append(Manifest(tag=tag, digest=digest, platforms=normalized_platforms))

    duplicate_tags = sorted({manifest.tag for manifest in manifests if [item.tag for item in manifests].count(manifest.tag) > 1})
    if duplicate_tags:
        raise CliError("Duplicate manifest tags detected:\n" + "\n".join(duplicate_tags))

    duplicate_digests = sorted({manifest.digest for manifest in manifests if [item.digest for item in manifests].count(manifest.digest) > 1})
    if duplicate_digests:
        raise CliError("Duplicate manifest digests detected:\n" + "\n".join(duplicate_digests))

    return sorted(manifests, key=lambda item: item.tag)


def validate_manifest_entries(config: Config, manifests: list[Manifest]) -> None:
    expected = {
        manifest_tag: sorted({target.platform for target in config.enabled_targets if target.manifest_tag == manifest_tag})
        for manifest_tag in sorted({target.manifest_tag for target in config.enabled_targets})
    }
    actual = {manifest.tag: list(manifest.platforms) for manifest in manifests}

    if sorted(expected) != sorted(actual):
        raise CliError(
            "Rendered manifests do not match enabled config tags:\n"
            f"expected={', '.join(sorted(expected))}\n"
            f"actual={', '.join(sorted(actual))}"
        )

    for tag, expected_platforms in expected.items():
        actual_platforms = actual[tag]
        if actual_platforms != expected_platforms:
            raise CliError(
                f"Rendered manifest platforms do not match config for {tag}: "
                f"expected {', '.join(expected_platforms)}; got {', '.join(actual_platforms)}"
            )


def render_release_json(config_path: str, source_sha: str, published_at: str, manifests_path: str) -> dict[str, Any]:
    config = load_config(config_path)
    manifests = load_manifest_entries(manifests_path)
    validate_manifest_entries(config, manifests)
    payload = {
        "image": config.image,
        "version": config.version,
        "sha": source_sha,
        "short_sha": short_sha(source_sha),
        "published_at": published_at,
        "manifests": [
            {
                "tag": manifest.tag,
                "digest": manifest.digest,
                "platforms": list(manifest.platforms),
            }
            for manifest in manifests
        ],
    }
    return validate_release_json_payload(payload)


def validate_release_json_payload(payload: Any) -> dict[str, Any]:
    validate_schema(payload, "release-json.schema.json")

    image = payload["image"]
    if not IMAGE_PATTERN.match(image):
        raise CliError(f"Unsupported image name: {image}")

    seen_tags: set[str] = set()
    seen_digests: set[str] = set()
    for manifest in payload["manifests"]:
        tag = manifest["tag"]
        digest = manifest["digest"]
        platforms = manifest["platforms"]

        if tag in seen_tags:
            raise CliError(f"Duplicate manifest tag: {tag}")
        if digest in seen_digests:
            raise CliError(f"Duplicate manifest digest: {digest}")
        if platforms != sorted(platforms):
            raise CliError(f"Manifest {tag} platforms must be sorted")
        if len(platforms) != len(set(platforms)):
            raise CliError(f"Manifest {tag} platforms must be unique")
        for platform in platforms:
            if platform not in PLATFORM_RUNNERS:
                raise CliError(f"Manifest {tag} uses unsupported platform: {platform}")
        seen_tags.add(tag)
        seen_digests.add(digest)

    return payload


def validate_release_json_file(json_path: str) -> dict[str, Any]:
    require_file(json_path)
    payload = read_json(json_path)
    return validate_release_json_payload(payload)


def render_telegram_notification(
    release_json_path: str,
    repository: str,
    server_url: str,
    run_id: str,
) -> str:
    payload = validate_release_json_file(release_json_path)
    service_name = payload["image"].rsplit("/", 1)[1]
    commit_url = f"{server_url}/{repository}/commit/{payload['sha']}"
    run_url = f"{server_url}/{repository}/actions/runs/{run_id}"
    if payload["version"]:
        version_line = f"*Version:* `{payload['version']}`"
    else:
        version_line = f"*Version:* `{payload['short_sha']}` (SHA-based)"
    tags_text = ", ".join(manifest["tag"] for manifest in payload["manifests"])
    return (
        "🎉 *Docker Release Complete*\n\n"
        f"*Service:* `{service_name}`\n"
        f"{version_line}\n"
        f"*Commit:* [`{payload['short_sha']}`]({commit_url})\n\n"
        "*Manifests Created:*\n"
        f"`{tags_text}`\n\n"
        "*Registry:*\n"
        f"`{payload['image']}`\n\n"
        f"[View Workflow Run]({run_url})"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="build-workflow-ci")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate-config")
    validate_parser.add_argument("config_path")

    validate_payload_parser = subparsers.add_parser("validate-config-payload")
    validate_payload_parser.add_argument("config_path")

    matrix_parser = subparsers.add_parser("plan-matrix")
    matrix_parser.add_argument("config_path")
    matrix_parser.add_argument("--short-sha", required=True)

    target_parser = subparsers.add_parser("plan-build-target")
    target_parser.add_argument("config_path")
    target_parser.add_argument("--target-name", required=True)
    target_parser.add_argument("--mode", required=True, choices=["pr", "release"])
    target_parser.add_argument("--short-sha", required=True)

    manifests_parser = subparsers.add_parser("plan-manifests")
    manifests_parser.add_argument("config_path")
    manifests_parser.add_argument("--short-sha", required=True)

    release_json_parser = subparsers.add_parser("render-release-json")
    release_json_parser.add_argument("config_path")
    release_json_parser.add_argument("--source-sha", required=True)
    release_json_parser.add_argument("--published-at", required=True)
    release_json_parser.add_argument("--manifests-path", required=True)

    telegram_parser = subparsers.add_parser("render-telegram-notification")
    telegram_parser.add_argument("release_json_path")
    telegram_parser.add_argument("--repository", required=True)
    telegram_parser.add_argument("--server-url", required=True)
    telegram_parser.add_argument("--run-id", required=True)

    validate_schema_parser = subparsers.add_parser("validate-schema-file")
    validate_schema_parser.add_argument("schema_path")

    validate_release_json_parser = subparsers.add_parser("validate-release-json")
    validate_release_json_parser.add_argument("json_path")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "validate-config":
            write_json(validate_config_command(args.config_path))
        elif args.command == "validate-config-payload":
            validate_config_payload(args.config_path)
        elif args.command == "plan-matrix":
            write_json(plan_matrix(args.config_path, args.short_sha))
        elif args.command == "plan-build-target":
            write_json(plan_build_target(args.config_path, args.target_name, args.mode, args.short_sha))
        elif args.command == "plan-manifests":
            write_json(plan_manifests(args.config_path, args.short_sha))
        elif args.command == "render-release-json":
            write_json(render_release_json(args.config_path, args.source_sha, args.published_at, args.manifests_path))
        elif args.command == "render-telegram-notification":
            print(
                render_telegram_notification(
                    args.release_json_path,
                    args.repository,
                    args.server_url,
                    args.run_id,
                )
            )
        elif args.command == "validate-schema-file":
            validate_schema_file(args.schema_path)
        elif args.command == "validate-release-json":
            validate_release_json_file(args.json_path)
        else:
            parser.error(f"Unknown command: {args.command}")
    except CliError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0
