#!/usr/bin/env python3
"""Read and validate OpenClaw release inputs without executing config as code."""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTEXT = Path("clusters/eldertree/openclaw/docker")
SEMVER = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
IMAGE = re.compile(rf"ghcr\.io/openclaw/openclaw:({SEMVER})@sha256:[a-f0-9]{{64}}")


def metadata(root=ROOT):
    context = root / CONTEXT
    version = (context / "VERSION").read_text().strip()
    if not re.fullmatch(SEMVER, version):
        raise ValueError("VERSION must be a stable MAJOR.MINOR.PATCH version")
    lock = json.loads((context / "build.lock.json").read_text())
    if set(lock) != {"schemaVersion", "upstreamImage", "kubectl"} or lock["schemaVersion"] != 1:
        raise ValueError("Unsupported build.lock.json schema")
    upstream = IMAGE.fullmatch(lock["upstreamImage"])
    if not upstream:
        raise ValueError("upstreamImage must name an exact OpenClaw release and sha256 digest")
    kubectl = lock["kubectl"]
    if set(kubectl) != {"version", "sha256"}:
        raise ValueError("kubectl requires version and sha256")
    if not re.fullmatch(rf"v{SEMVER}", kubectl["version"]):
        raise ValueError("kubectl.version must name an exact stable release")
    if not re.fullmatch(r"[a-f0-9]{64}", kubectl["sha256"]):
        raise ValueError("kubectl.sha256 must be the reviewed linux/arm64 checksum")
    # Include every context file. A startup-script or tool-only change needs a
    # new wrapper version even when the upstream OpenClaw release stays fixed.
    digest = hashlib.sha256()
    for path in sorted(context.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(context).as_posix().encode() + b"\0")
            digest.update(path.read_bytes() + b"\0")
    return {
        "image_version": version,
        "image_tag": f"v{version}",
        "upstream_version": upstream.group(1),
        "upstream_image": lock["upstreamImage"],
        "kubectl_version": kubectl["version"],
        "kubectl_sha256": kubectl["sha256"],
        "input_hash": digest.hexdigest(),
    }


def check_version(base, root=ROOT):
    """Reject changed image inputs that reuse a previously reviewed VERSION."""
    old = subprocess.run(
        ["git", "show", f"{base}:{CONTEXT}/VERSION"],
        cwd=root, capture_output=True, text=True, check=False,
    )
    if old.returncode:
        # The migration introduces this component's first VERSION file.
        subprocess.run(["git", "rev-parse", "--verify", f"{base}^{{commit}}"], cwd=root, check=True,
                       stdout=subprocess.DEVNULL)
        return
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", base, "HEAD", "--", str(CONTEXT)], cwd=root, text=True,
    )
    if changed and old.stdout.strip() == metadata(root)["image_version"]:
        raise ValueError("Image inputs changed: bump docker/VERSION in this PR")
    previous_lock = subprocess.check_output(
        ["git", "show", f"{base}:{CONTEXT}/build.lock.json"], cwd=root, text=True,
    )
    previous_upstream = IMAGE.fullmatch(json.loads(previous_lock)["upstreamImage"])
    current = metadata(root)
    if previous_upstream.group(1) != current["upstream_version"]:
        previous_line = old.stdout.strip().split(".")[:2]
        if previous_line == current["image_version"].split(".")[:2]:
            raise ValueError("An upstream OpenClaw upgrade requires a new wrapper minor release and Flux policy review")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--check-version-against")
    parser.add_argument("--build", action="store_true", help="Build/load openclaw:ci using the locked inputs")
    args = parser.parse_args()
    data = metadata()
    if args.check_version_against:
        check_version(args.check_version_against)
    if args.github_output:
        with args.github_output.open("a") as output:
            output.writelines(f"{key}={value}\n" for key, value in data.items())
    print(json.dumps(data, indent=2))
    if args.build:
        subprocess.run([
            "docker", "buildx", "build", "--platform", "linux/arm64", "--load", "-t", "openclaw:ci",
            "--build-arg", f"OPENCLAW_IMAGE={data['upstream_image']}",
            "--build-arg", f"KUBECTL_VERSION={data['kubectl_version']}",
            "--build-arg", f"KUBECTL_SHA256={data['kubectl_sha256']}",
            "--label", f"org.opencontainers.image.version={data['image_version']}",
            "--label", f"io.eldertree.build-inputs={data['input_hash']}", str(ROOT / CONTEXT),
        ], check=True)


if __name__ == "__main__":
    main()
