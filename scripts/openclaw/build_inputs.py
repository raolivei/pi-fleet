#!/usr/bin/env python3
"""Validate locked dependencies and pass arguments to the shared Docker workflow."""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTEXT = Path("clusters/eldertree/openclaw/docker")
SEMVER = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
IMAGE = re.compile(rf"ghcr\.io/openclaw/openclaw:({SEMVER})@sha256:[a-f0-9]{{64}}")


def metadata(root=ROOT):
    # Match docker-build.yml: pi-fleet's root VERSION owns the published tag.
    version = (root / "VERSION").read_text().strip()
    if not re.fullmatch(SEMVER, version):
        raise ValueError("Root VERSION must be a stable MAJOR.MINOR.PATCH version")
    lock = json.loads((root / CONTEXT / "build.lock.json").read_text())
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
    return {
        "image_version": version,
        "image_tag": f"v{version}",
        "upstream_version": upstream.group(1),
        "upstream_image": lock["upstreamImage"],
        "kubectl_version": kubectl["version"],
        "kubectl_sha256": kubectl["sha256"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    data = metadata()
    if args.github_output:
        with args.github_output.open("a") as output:
            output.writelines(f"{key}={value}\n" for key, value in data.items())
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
