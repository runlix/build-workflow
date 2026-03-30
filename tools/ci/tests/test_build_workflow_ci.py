from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.ci.src.build_workflow_ci import (
    plan_build_target,
    render_release_json,
    validate_config_command,
    validate_config_payload,
    validate_release_json_file,
    validate_schema_file,
)


REPO_ROOT = Path(__file__).resolve().parents[3]


class BuildWorkflowCiTest(unittest.TestCase):
    def test_validate_schema_file_accepts_repo_schema(self) -> None:
        schema = validate_schema_file("schema/build-config.schema.json")
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(schema["title"], "Runlix Build Config")

    def test_validate_config_reports_defaults(self) -> None:
        payload = validate_config_command("test-fixtures/ci/service/.ci/build.json")
        self.assertEqual(payload["image_name"], "ghcr.io/runlix/test-service")
        self.assertEqual(payload["context_dir"], "test-fixtures/ci/service")
        self.assertEqual(payload["enabled_count"], 2)

    def test_validate_config_payload_accepts_examples(self) -> None:
        payload = validate_config_payload("examples/build-config/service-image.json")
        self.assertEqual(payload["image"], "ghcr.io/runlix/example-service")
        self.assertEqual(payload["targets"][0]["dockerfile"], "linux-amd64.Dockerfile")

    def test_plan_build_target_uses_full_refs(self) -> None:
        config = json.loads((REPO_ROOT / "test-fixtures/ci/service/.ci/build.json").read_text(encoding="utf-8"))
        stable_target = next(target for target in config["targets"] if target["name"] == "stable-amd64")

        payload = plan_build_target(
            "test-fixtures/ci/service/.ci/build.json",
            "stable-amd64",
            "pr",
            "1234567",
        )
        self.assertEqual(payload["image_tag"], "ghcr.io/runlix/test-service:pr-1234567-stable-amd64")
        self.assertEqual(payload["build_args"]["BASE_REF"], stable_target["build_args"]["BASE_REF"])
        self.assertEqual(payload["context_dir"], "test-fixtures/ci/service")

    def test_release_json_render(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            manifests_path = Path(tmp_dir) / "manifests.json"
            manifests_path.write_text(
                json.dumps(
                    [
                        {
                            "tag": "1.2.3-debug",
                            "digest": "sha256:" + ("b" * 64),
                            "platforms": ["linux/amd64"],
                        },
                        {
                            "tag": "1.2.3-stable",
                            "digest": "sha256:" + ("a" * 64),
                            "platforms": ["linux/amd64"],
                        },
                    ]
                ),
                encoding="utf-8",
            )

            payload = render_release_json(
                "test-fixtures/ci/service/.ci/build.json",
                "1234567890abcdef1234567890abcdef12345678",
                "2026-03-17T12:00:00Z",
                str(manifests_path),
            )
            self.assertEqual(payload["image"], "ghcr.io/runlix/test-service")
            self.assertEqual([item["tag"] for item in payload["manifests"]], ["1.2.3-debug", "1.2.3-stable"])

            release_json_path = Path(tmp_dir) / "release.json"
            release_json_path.write_text(json.dumps(payload), encoding="utf-8")
            validated = validate_release_json_file(str(release_json_path))
            self.assertEqual(validated["manifests"][0]["digest"], "sha256:" + ("b" * 64))

    def test_validate_release_json_fixture(self) -> None:
        payload = validate_release_json_file("test-fixtures/ci/release-json/release.json")
        self.assertEqual(payload["image"], "ghcr.io/runlix/test-service")
        self.assertEqual(len(payload["manifests"]), 2)


if __name__ == "__main__":
    unittest.main()
