# Pi Fleet workflows

## OpenClaw

`build-openclaw-arm64.yml` follows the workspace's centralized workflow pattern:

- PRs call `raolivei/github-workflows/.github/workflows/version-check.yml@main`
  and run application-specific ARM64 config, migration and health checks.
- Main pushes and manual runs validate first, then call
  `raolivei/github-workflows/.github/workflows/docker-build.yml@main`.
- The shared builder reads the root `VERSION`, handles GHCR authentication,
  tags, caching, content hashes and image publication. Locked dependencies
  are supplied through its existing `build-args` input.
- Flux selects published full semver tags in the approved migration range and
  commits the desired image update through existing image automation.

For the initial config/schema migration, verify the branch's manual shared
build and GHCR image before merging the HelmRelease image reference, following
the existing image-before-tag convention. See the [OpenClaw release procedure](../../clusters/eldertree/openclaw/README.md#cluster-image-releases).

Shared workflow inputs and tagging behavior are documented in
[github-workflows](https://github.com/raolivei/github-workflows/blob/main/README.md).
