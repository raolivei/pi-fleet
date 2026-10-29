import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from build_inputs import CONTEXT, ROOT, metadata


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.context = self.root / CONTEXT
        shutil.copytree(ROOT / CONTEXT, self.context)
        shutil.copy(ROOT / "VERSION", self.root / "VERSION")

    def change_lock(self, update):
        path = self.context / "build.lock.json"
        lock = json.loads(path.read_text())
        update(lock)
        path.write_text(json.dumps(lock))

    def test_missing_digest_is_rejected(self):
        self.change_lock(lambda lock: lock.update(upstreamImage="ghcr.io/openclaw/openclaw:latest"))
        with self.assertRaisesRegex(ValueError, "digest"):
            metadata(self.root)

    def test_bad_kubectl_checksum_is_rejected(self):
        self.change_lock(lambda lock: lock["kubectl"].update(sha256="bad"))
        with self.assertRaisesRegex(ValueError, "checksum"):
            metadata(self.root)

    def test_root_version_matches_the_shared_builder(self):
        (self.root / "VERSION").write_text("1.3.3\n")
        self.assertEqual(metadata(self.root)["image_tag"], "v1.3.3")

    def test_invalid_root_version_is_rejected(self):
        (self.root / "VERSION").write_text("latest\n")
        with self.assertRaisesRegex(ValueError, "Root VERSION"):
            metadata(self.root)

    def test_publication_is_owned_by_the_shared_workflow(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/build-openclaw-arm64.yml").read_text())
        builder = workflow["jobs"]["build"]
        self.assertEqual(builder["uses"], "raolivei/github-workflows/.github/workflows/docker-build.yml@main")
        self.assertEqual(builder["needs"], ["validate", "version-check"])
        self.assertEqual(builder["with"]["context"], str(CONTEXT))
        self.assertEqual(builder["with"]["push"], "${{ github.event_name != 'pull_request' }}")
        self.assertNotIn("steps", builder)
        self.assertEqual(workflow["jobs"]["version-check"]["uses"],
                         "raolivei/github-workflows/.github/workflows/version-check.yml@main")
        self.assertFalse((ROOT / "scripts/openclaw/publish.sh").exists())

    def test_deployment_is_inside_the_reviewed_release_gate(self):
        manifest = yaml.safe_load((ROOT / "clusters/eldertree/openclaw/helmrelease.yaml").read_text())
        component = manifest["spec"]["values"]["components"]["openclaw"]
        policy = yaml.safe_load((ROOT / "clusters/eldertree/openclaw/openclaw-image-policy.yaml").read_text())
        lower, upper = policy["spec"]["policy"]["semver"]["range"].split()
        version = tuple(map(int, metadata()["image_version"].split(".")))
        self.assertLessEqual(tuple(map(int, lower[2:].split("."))), version)
        self.assertLess(version, tuple(map(int, upper[1:].split("."))))
        self.assertEqual(component["image"]["tag"], metadata()["image_tag"])
        self.assertEqual(component["command"], ["/usr/local/bin/openclaw-cluster-start"])
        self.assertGreater(component["probes"]["liveness"]["initialDelaySeconds"], 300)


FAKE_NODE = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
if sys.argv[1] == "-p":
    print(os.environ.get("TEST_RUNTIME", "2026.9.5"))
    sys.exit(0)
state = Path(os.environ["OPENCLAW_STATE_DIR"])
config = Path(os.environ["OPENCLAW_CONFIG_PATH"])
if sys.argv[2] == "doctor":
    counter = state / "doctor-count"
    counter.write_text(str(int(counter.read_text()) + 1) if counter.exists() else "1")
    mode = os.environ.get("TEST_DOCTOR", "success")
    if mode == "failure":
        sys.exit(2)
    if mode == "zero-failure":
        print("Doctor could not complete maintenance")
        sys.exit(0)
    data = json.loads(config.read_text())
    data["doctor-repaired"] = True
    config.write_text(json.dumps(data))
elif sys.argv[2:4] == ["config", "validate"]:
    json.loads(config.read_text())
    if os.environ.get("TEST_INVALID"):
        sys.exit(1)
else:
    raise RuntimeError(sys.argv)
'''


class StartupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.state = self.root / "state"
        self.state.mkdir()
        self.source = self.root / "config.json"
        self.source.write_text('{"managed": true}')
        bindir = self.root / "bin"
        bindir.mkdir()
        node = bindir / "node"
        node.write_text(FAKE_NODE)
        node.chmod(0o755)
        # macOS lacks GNU timeout; the image test exercises the actual binary.
        if not shutil.which("timeout"):
            timeout = bindir / "timeout"
            timeout.write_text("#!/usr/bin/env python3\nimport subprocess,sys\nsys.exit(subprocess.run(sys.argv[2:], timeout=int(sys.argv[1])).returncode)\n")
            timeout.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bindir}{os.pathsep}{os.environ['PATH']}",
                        OPENCLAW_STATE_DIR=str(self.state), OPENCLAW_CONFIG_SOURCE=str(self.source),
                        OPENCLAW_EXEC_POLICY_SOURCE=str(self.root / "absent.json"))

    def start(self, **variables):
        return subprocess.run(["sh", str(ROOT / CONTEXT / "startup.sh"), "--prepare-only"],
                              env=dict(self.env, **variables), capture_output=True, text=True)

    def test_existing_pvc_config_is_saved_before_replacement(self):
        original = b'{"original": "preserve me"}'
        (self.state / "openclaw.json").write_bytes(original)
        result = self.start()
        self.assertEqual(result.returncode, 0, result.stderr)
        backup = self.state / "migration-backups" / f"config-{hashlib.sha256(original).hexdigest()}.json"
        self.assertEqual(backup.read_bytes(), original)
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)

    def test_restart_keeps_repaired_config_and_skips_doctor(self):
        self.assertEqual(self.start().returncode, 0)
        before = (self.state / "openclaw.json").read_bytes()
        self.assertEqual(self.start().returncode, 0)
        self.assertEqual((self.state / "openclaw.json").read_bytes(), before)
        self.assertEqual((self.state / "doctor-count").read_text(), "1")

    def test_migration_failure_is_retried_without_success_marker(self):
        for mode in ["failure", "zero-failure"]:
            self.assertNotEqual(self.start(TEST_DOCTOR=mode).returncode, 0)
            self.assertEqual(list(self.state.glob(".doctor-*")), [])
        self.assertEqual(self.start().returncode, 0)
        self.assertEqual(len(list(self.state.glob(".doctor-*"))), 1)

    def test_invalid_config_is_rejected_even_with_existing_marker(self):
        self.assertEqual(self.start().returncode, 0)
        self.assertNotEqual(self.start(TEST_INVALID="1").returncode, 0)

    def test_changed_managed_config_and_runtime_run_new_migration(self):
        self.assertEqual(self.start().returncode, 0)
        self.source.write_text('{"new-managed": true}')
        self.assertEqual(self.start().returncode, 0)
        self.assertEqual(self.start(TEST_RUNTIME="2026.10.5").returncode, 0)
        self.assertEqual((self.state / "doctor-count").read_text(), "3")


if __name__ == "__main__":
    unittest.main()
