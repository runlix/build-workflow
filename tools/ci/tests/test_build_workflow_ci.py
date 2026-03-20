from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.ci.src.build_workflow_ci import (
    plan_build_target,
    render_release_record,
    render_telegram_notification,
    validate_config_command,
    validate_config_payload,
    validate_schema_file,
    write_release_json,
)


REPO_ROOT = Path(__file__).resolve().parents[3]


class BuildWorkflowCiTest(unittest.TestCase):
    def test_validate_schema_file_accepts_repo_schema(self) -> None:
        schema = validate_schema_file("schema/ci-config.schema.json")
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")

    def test_validate_config_reports_defaults(self) -> None:
        payload = validate_config_command("test-fixtures/ci/service/.ci/config.json")
        self.assertEqual(payload["image_name"], "ghcr.io/runlix/test-service")
        self.assertEqual(payload["context_dir"], "test-fixtures/ci/service")
        self.assertEqual(payload["enabled_count"], 2)

    def test_validate_config_payload_accepts_examples(self) -> None:
        payload = validate_config_payload("examples/ci/service-config.json")
        self.assertEqual(payload["image"], "ghcr.io/runlix/example-service")
        self.assertEqual(payload["targets"][0]["dockerfile"], "linux-amd64.Dockerfile")

    def test_plan_build_target_uses_full_refs(self) -> None:
        payload = plan_build_target(
            "test-fixtures/ci/service/.ci/config.json",
            "stable-amd64",
            "pr",
            "1234567",
        )
        self.assertEqual(payload["image_tag"], "ghcr.io/runlix/test-service:pr-1234567-stable-amd64")
        self.assertEqual(
            payload["build_args"]["BASE_REF"],
            "gcr.io/distroless/base-debian12:latest-amd64@sha256:d5f7dca58e3db53d1de502bd1a747ecb1110cf6b0773af129f951ee11e2e3ed4",
        )
        self.assertEqual(payload["context_dir"], "test-fixtures/ci/service")

    def test_release_record_and_telegram_render(self) -> None:
        payload = render_release_record(
            "test-fixtures/ci/service/.ci/config.json",
            "1234567890abcdef1234567890abcdef12345678",
            "2026-03-17T12:00:00Z",
        )
        self.assertEqual(payload["tags"], ["1.2.3-debug", "1.2.3-stable"])

        with tempfile.TemporaryDirectory() as tmp_dir:
            record_path = Path(tmp_dir) / "release-record.json"
            record_path.write_text(json.dumps(payload), encoding="utf-8")
            message = render_telegram_notification(
                str(record_path),
                "ghcr.io/runlix/test-service",
                "runlix/test-service",
                "https://github.com",
                "123456",
            )
            self.assertIn("*Service:* `test-service`", message)
            self.assertIn("*Version:* `1.2.3`", message)

    def test_write_release_json_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "release.json"
            write_release_json("test-fixtures/ci/release-record/release-record.json", str(output_path))
            self.assertEqual(
                json.loads(output_path.read_text(encoding="utf-8")),
                json.loads((REPO_ROOT / "test-fixtures/ci/release-record/release.expected.json").read_text(encoding="utf-8")),
            )


if __name__ == "__main__":
    unittest.main()
