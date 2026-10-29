#!/usr/bin/env python3
"""Exercise the actual ARM64 runtime, managed config and restart path in isolation."""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

from release import ROOT, metadata


def main():
    release = metadata()
    source = ROOT / "clusters/eldertree/openclaw/configmap.yaml"
    documents = list(yaml.safe_load_all(source.read_text()))
    config = json.loads(next(doc["data"]["config.json"] for doc in documents
                             if doc["metadata"]["name"] == "openclaw-config-file"))
    with tempfile.TemporaryDirectory(prefix="openclaw-smoke-") as directory:
        fixtures = Path(directory)
        fixtures.chmod(0o755)
        (fixtures / "config.json").write_text(json.dumps(config))
        # Validate the exact production config, then disable Telegram for the
        # isolated Doctor/gateway test. CI never polls the production bot.
        config["channels"]["telegram"]["enabled"] = False
        (fixtures / "smoke.json").write_text(json.dumps(config))
        for path in fixtures.iterdir():
            path.chmod(0o644)
        command = [
            "docker", "run", "--rm", "--platform", "linux/arm64",
            "--tmpfs", "/home/node/.openclaw:uid=1000,gid=1000,mode=0700",
            "--mount", f"type=bind,src={directory},dst=/fixtures,readonly",
            "--entrypoint", "/bin/sh",
        ]
        values = {
            "OPENCLAW_GATEWAY_TOKEN": "ci-placeholder-token",
            "TELEGRAM_BOT_TOKEN": "123456789:ci-placeholder-token",
            "OPENROUTER_API_KEY": "ci-placeholder-key",
            "GROQ_API_KEY": "ci-placeholder-key",
            "OPENCLAW_CONFIG_SOURCE": "/fixtures/smoke.json",
            "OPENCLAW_EXEC_POLICY_SOURCE": "/fixtures/absent-policy.json",
            "EXPECTED_OPENCLAW_VERSION": release["upstream_version"],
            "EXPECTED_KUBECTL_VERSION": release["kubectl_version"],
        }
        for key, value in values.items():
            command.extend(["--env", f"{key}={value}"])
        command.extend([sys.argv[1], "-eu", "-c", r'''
diagnostics() {
  status=$?
  if [ "$status" -ne 0 ]; then
    find /home/node/.openclaw/migration-backups -name '*.log' -exec tail -n 100 {} \; 2>/dev/null || true
  fi
  if [ -n "${gateway_pid:-}" ]; then kill "$gateway_pid" 2>/dev/null || true; fi
}
trap diagnostics EXIT
test "$(id -u)" = 1000
node -e 'if (require("/app/package.json").version !== process.env.EXPECTED_OPENCLAW_VERSION) process.exit(1)'
node /app/dist/index.js --version
kubectl version --client=true -o json | node -e 'let s="";process.stdin.on("data",x=>s+=x);process.stdin.on("end",()=>{if(JSON.parse(s).clientVersion.gitVersion!==process.env.EXPECTED_KUBECTL_VERSION)process.exit(1)})'
OPENCLAW_CONFIG_PATH=/fixtures/config.json node /app/dist/index.js config validate

# Simulate an existing PVC, then exercise the real migration and repeat startup.
printf '%s\n' '{"gateway":{"mode":"local"}}' > /home/node/.openclaw/openclaw.json
original_hash=$(sha256sum /home/node/.openclaw/openclaw.json | cut -d' ' -f1)
/usr/local/bin/openclaw-cluster-start --prepare-only
test -s "/home/node/.openclaw/migration-backups/config-${original_hash}.json"
test "$(find /home/node/.openclaw -maxdepth 1 -name '.doctor-*' | wc -l)" -eq 1
before=$(sha256sum /home/node/.openclaw/openclaw.json)
/usr/local/bin/openclaw-cluster-start --prepare-only
test "$before" = "$(sha256sum /home/node/.openclaw/openclaw.json)"

/usr/local/bin/openclaw-cluster-start > /tmp/gateway.log 2>&1 &
gateway_pid=$!
if ! node -e 'const end=Date.now()+120000; (async()=>{while(Date.now()<end){try{const r=await fetch("http://127.0.0.1:18789/health");if(r.ok)process.exit(0)}catch{} await new Promise(r=>setTimeout(r,1000))}process.exit(1)})()'; then
  cat /tmp/gateway.log
  exit 1
fi
echo "OpenClaw ARM64 config, migration, restart and gateway smoke tests passed"
'''])
        subprocess.run(command, check=True, timeout=780, env=os.environ)


if __name__ == "__main__":
    main()
