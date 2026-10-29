#!/bin/bash
# Publish only a previously tested, loaded image. Version tags are write-once.
set -euo pipefail
local_image=$1
release_image=$2
expected_hash=$3

if manifest=$(docker manifest inspect "$release_image" 2>&1); then
  docker pull --platform linux/arm64 "$release_image"
  actual_hash=$(docker image inspect "$release_image" --format '{{index .Config.Labels "io.eldertree.build-inputs"}}')
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo "Release $release_image already exists with different inputs; bump docker/VERSION" >&2
    exit 1
  fi
  echo "Release already published with identical inputs: $release_image"
elif [[ "$manifest" == *"manifest unknown"* || "$manifest" == *"no such manifest"* ]]; then
  docker tag "$local_image" "$release_image"
  docker push "$release_image"
else
  # Registry authentication/network errors are not evidence that a tag is free.
  printf '%s\n' "$manifest" >&2
  exit 1
fi
