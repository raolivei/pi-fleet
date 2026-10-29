#!/bin/sh
# The image owns startup/migration behavior; Kubernetes supplies config and state.
set -eu
umask 077

state_dir=${OPENCLAW_STATE_DIR:-/home/node/.openclaw}
export OPENCLAW_STATE_DIR="$state_dir"
export OPENCLAW_CONFIG_PATH="$state_dir/openclaw.json"
config_source=${OPENCLAW_CONFIG_SOURCE:-/etc/openclaw-config/config.json}
policy_source=${OPENCLAW_EXEC_POLICY_SOURCE:-/etc/openclaw-defaults/exec-approvals.json}
hash_file="$state_dir/.openclaw-config.cm.sha256"
backup_dir="$state_dir/migration-backups"
mkdir -p "$state_dir/agents/main/sessions" "$state_dir/credentials" "$state_dir/workspace" "$backup_dir"
test -s "$config_source" || { echo "[openclaw] Managed config is missing: $config_source" >&2; exit 1; }

managed_hash=$(sha256sum "$config_source" | awk '{print $1}')
runtime_version=$(node -p "require('/app/package.json').version")
marker="$state_dir/.doctor-${runtime_version}-${managed_hash}"

if [ ! -s "$OPENCLAW_CONFIG_PATH" ] || [ ! -r "$hash_file" ] || [ "$(cat "$hash_file")" != "$managed_hash" ]; then
  # Snapshot the ACTUAL PVC config before seeding a new managed config. Doctor
  # also maintains its own state-store backups; this snapshot covers CM refresh.
  if [ -s "$OPENCLAW_CONFIG_PATH" ]; then
    previous_hash=$(sha256sum "$OPENCLAW_CONFIG_PATH" | awk '{print $1}')
    backup="$backup_dir/config-${previous_hash}.json"
    if [ ! -f "$backup" ]; then
      cp "$OPENCLAW_CONFIG_PATH" "$backup"
      chmod 600 "$backup"
    fi
  fi
  staged_config=$(mktemp "$state_dir/.config.XXXXXX")
  cp "$config_source" "$staged_config"
  chmod 600 "$staged_config"
  mv -f "$staged_config" "$OPENCLAW_CONFIG_PATH"
  printf '%s\n' "$managed_hash" > "$hash_file"
  echo "[openclaw] Seeded writable config from ConfigMap"
fi

if [ ! -f "$marker" ]; then
  # Preserve the input for every release/config migration, including a fresh PVC.
  backup="$backup_dir/input-${runtime_version}-${managed_hash}.json"
  if [ ! -f "$backup" ]; then
    cp "$OPENCLAW_CONFIG_PATH" "$backup"
    chmod 600 "$backup"
  fi
  doctor_log="$backup_dir/doctor-${runtime_version}-${managed_hash}.log"
  echo "[openclaw] Running Doctor for $runtime_version (timeout: 300s)"
  if ! timeout 300 node /app/dist/index.js doctor --fix --non-interactive > "$doctor_log" 2>&1; then
    echo "[openclaw] Doctor failed; diagnostic log: $doctor_log" >&2
    exit 1
  fi
  # This upstream release can report incomplete maintenance with exit code 0.
  if grep -Fq "Doctor could not complete maintenance" "$doctor_log"; then
    echo "[openclaw] Doctor reported incomplete maintenance; diagnostic log: $doctor_log" >&2
    exit 1
  fi
  node /app/dist/index.js config validate
  touch "$marker"
  echo "[openclaw] Doctor migration completed"
fi

# Validate even when the migration marker exists: persisted config may change.
node /app/dist/index.js config validate
if [ -r "$policy_source" ]; then
  cp "$policy_source" "$state_dir/exec-approvals.json"
  chmod 600 "$state_dir/exec-approvals.json"
fi

case "${1:-}" in
  --prepare-only) exit 0 ;;
  "") exec node /app/dist/index.js gateway --bind lan ;;
  *) echo "Usage: openclaw-cluster-start [--prepare-only]" >&2; exit 2 ;;
esac
