#!/usr/bin/env python3
"""Check the locked fallback's ARM64 server API without downloading a model."""

import json
import subprocess
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

import yaml

ROOT = Path(__file__).resolve().parents[2]


def main():
    documents = yaml.safe_load_all((ROOT / "clusters/eldertree/openclaw/ollama-fallback.yaml").read_text())
    deployment = next(doc for doc in documents if doc and doc["kind"] == "Deployment")
    image = deployment["spec"]["template"]["spec"]["containers"][0]["image"]
    expected = image.split(":", 1)[1].split("@", 1)[0]
    container = subprocess.check_output([
        "docker", "run", "--rm", "--detach", "--platform", "linux/arm64",
        "--memory", "1g", "--cpus", "1", "--publish", "127.0.0.1::11434",
        "--tmpfs", "/root/.ollama", "--env", "OLLAMA_HOST=0.0.0.0:11434", image, "serve",
    ], text=True).strip()
    try:
        endpoint = subprocess.check_output(["docker", "port", container, "11434/tcp"], text=True).strip()
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            try:
                with urlopen(f"http://{endpoint}/api/version", timeout=3) as response:
                    actual = json.load(response)["version"]
                if actual != expected:
                    raise ValueError(f"Expected Ollama {expected}, got {actual}")
                with urlopen(f"http://{endpoint}/api/tags", timeout=3) as response:
                    if json.load(response)["models"]:
                        raise ValueError("Disposable Ollama unexpectedly contains models")
                print(f"Ollama {actual} ARM64 server/version/model-list smoke test passed")
                return
            except (URLError, TimeoutError):
                time.sleep(1)
        raise TimeoutError("Ollama did not become ready within 60 seconds")
    finally:
        subprocess.run(["docker", "logs", "--tail", "30", container], check=False)
        subprocess.run(["docker", "stop", "--time", "5", container], check=False)


if __name__ == "__main__":
    main()
