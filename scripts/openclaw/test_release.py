import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from release import CONTEXT, ROOT, check_version, metadata


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.context = self.root / CONTEXT
        shutil.copytree(ROOT / CONTEXT, self.context)

    def change_lock(self, update):
        path = self.context / "build.lock.json"
        lock = json.loads(path.read_text())
        update(lock)
        path.write_text(json.dumps(lock))

    def bump_patch(self):
        path = self.context / "VERSION"
        major, minor, patch = map(int, path.read_text().strip().split("."))
        path.write_text(f"{major}.{minor}.{patch + 1}\n")

    def test_missing_digest_is_rejected(self):
        self.change_lock(lambda lock: lock.update(upstreamImage="ghcr.io/openclaw/openclaw:latest"))
        with self.assertRaisesRegex(ValueError, "digest"):
            metadata(self.root)

    def test_bad_kubectl_checksum_is_rejected(self):
        self.change_lock(lambda lock: lock["kubectl"].update(sha256="bad"))
        with self.assertRaisesRegex(ValueError, "checksum"):
            metadata(self.root)

    def test_wrapper_and_upstream_versions_are_independent(self):
        (self.context / "VERSION").write_text("0.1.2\n")
        data = metadata(self.root)
        self.assertEqual(data["image_tag"], "v0.1.2")
        self.assertNotEqual(data["image_version"], data["upstream_version"])

    def test_startup_change_changes_build_identity(self):
        before = metadata(self.root)["input_hash"]
        with (self.context / "startup.sh").open("a") as output:
            output.write("\n# a real wrapper change\n")
        self.assertNotEqual(before, metadata(self.root)["input_hash"])

    def git(self, *arguments):
        return subprocess.check_output(["git", *arguments], cwd=self.root, text=True,
                                       stderr=subprocess.DEVNULL).strip()

    def init_repository(self):
        self.git("init")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "commit.gpgsign", "false")
        self.git("add", ".")
        self.git("commit", "-m", "initial")
        return self.git("rev-parse", "HEAD")

    def commit_changes(self):
        self.git("add", ".")
        self.git("commit", "-m", "change")

    def test_reusing_wrapper_version_for_changed_inputs_is_rejected(self):
        base = self.init_repository()
        with (self.context / "startup.sh").open("a") as output:
            output.write("\n# changed startup\n")
        self.commit_changes()
        with self.assertRaisesRegex(ValueError, "bump"):
            check_version(base, self.root)

    def test_upstream_upgrade_requires_new_release_line(self):
        base = self.init_repository()
        current = metadata(self.root)["upstream_version"]
        major, minor, patch = map(int, current.split("."))
        future = f"{major}.{minor}.{patch + 1}"
        self.change_lock(lambda lock: lock.update(upstreamImage=lock["upstreamImage"].replace(f":{current}@", f":{future}@")))
        self.bump_patch()
        self.commit_changes()
        with self.assertRaisesRegex(ValueError, "minor release"):
            check_version(base, self.root)

    def test_wrapper_patch_with_version_bump_is_accepted(self):
        base = self.init_repository()
        self.bump_patch()
        with (self.context / "startup.sh").open("a") as output:
            output.write("\n# wrapper fix\n")
        self.commit_changes()
        check_version(base, self.root)

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


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        docker = self.root / "docker"
        docker.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
with Path(os.environ["TEST_CALLS"]).open("a") as output:
    output.write(" ".join(sys.argv[1:]) + "\\n")
if sys.argv[1:3] == ["manifest", "inspect"]:
    mode = os.environ["TEST_REGISTRY"]
    if mode == "absent":
        print("manifest unknown", file=sys.stderr)
        sys.exit(1)
    if mode == "unavailable":
        print("connection refused", file=sys.stderr)
        sys.exit(1)
elif sys.argv[1:3] == ["image", "inspect"]:
    print(os.environ.get("TEST_HASH", "same-inputs"))
''')
        docker.chmod(0o755)
        self.calls = self.root / "calls"

    def publish(self, registry, existing_hash="same-inputs"):
        return subprocess.run(["bash", str(ROOT / "scripts/openclaw/publish.sh"), "openclaw:ci",
                               "ghcr.io/raolivei/openclaw:v0.1.0", "same-inputs"],
                              env=dict(os.environ, PATH=f"{self.root}{os.pathsep}{os.environ['PATH']}",
                                       TEST_CALLS=str(self.calls), TEST_REGISTRY=registry, TEST_HASH=existing_hash),
                              capture_output=True, text=True)

    def test_new_release_is_published(self):
        self.assertEqual(self.publish("absent").returncode, 0)
        self.assertIn("push ghcr.io/raolivei/openclaw:v0.1.0", self.calls.read_text())

    def test_identical_release_is_reused(self):
        self.assertEqual(self.publish("exists").returncode, 0)
        self.assertNotIn("push", self.calls.read_text())

    def test_existing_release_cannot_be_overwritten(self):
        self.assertNotEqual(self.publish("exists", existing_hash="other-inputs").returncode, 0)
        self.assertNotIn("push", self.calls.read_text())

    def test_registry_errors_do_not_authorize_a_push(self):
        self.assertNotEqual(self.publish("unavailable").returncode, 0)
        self.assertNotIn("push", self.calls.read_text())


if __name__ == "__main__":
    unittest.main()
