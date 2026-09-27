#!/usr/bin/env bash
# Refresh sources.json from the OpenCode v2 CLI release API and verify the
# package still builds. No argument = latest stable. See README.md.
#
# Standalone Linux binaries are published at
# https://opencode.ai/files/bin/<version>/opencode-linux-{x64,arm64}.tar.gz
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_FILE="$SCRIPT_DIR/sources.json"

prefetch() {
  local url="$1"
  nix store prefetch-file --json --hash-type sha256 "$url"
}

CURRENT_VERSION=$(jq -r '.version' "$SOURCES_FILE")

META=$(curl -fsSL "https://opencode.ai/update/api/latest/cli/npm")
NEW_VERSION=$(jq -r '.version' <<< "$META")

if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "null" ]; then
  echo "Could not parse the OpenCode CLI release API response." >&2
  exit 1
fi

if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date (${CURRENT_VERSION})."
  exit 0
fi

X64_URL="https://opencode.ai/files/bin/${NEW_VERSION}/opencode-linux-x64.tar.gz"
ARM_URL="https://opencode.ai/files/bin/${NEW_VERSION}/opencode-linux-arm64.tar.gz"

echo "Updating opencode: ${CURRENT_VERSION} -> ${NEW_VERSION}"
echo "  x86_64-linux: ${X64_URL}"
echo "  aarch64-linux: ${ARM_URL}"

echo "Prefetching x86_64 tarball..."
X64_JSON=$(prefetch "$X64_URL")
X64_HASH=$(jq -r '.hash' <<< "$X64_JSON")

echo "Prefetching aarch64 tarball..."
ARM_JSON=$(prefetch "$ARM_URL")
ARM_HASH=$(jq -r '.hash' <<< "$ARM_JSON")

if [ -z "$X64_HASH" ] || [ "$X64_HASH" = "null" ] || [ -z "$ARM_HASH" ] || [ "$ARM_HASH" = "null" ]; then
  echo "Prefetch did not return a hash for both architectures." >&2
  exit 1
fi

jq -n \
  --arg version "$NEW_VERSION" \
  --arg x64_url "$X64_URL" \
  --arg x64_hash "$X64_HASH" \
  --arg arm_url "$ARM_URL" \
  --arg arm_hash "$ARM_HASH" \
  '{
    version: $version,
    sources: {
      "x86_64-linux": { url: $x64_url, hash: $x64_hash },
      "aarch64-linux": { url: $arm_url, hash: $arm_hash }
    }
  }' > "$SOURCES_FILE"

echo "Wrote ${SOURCES_FILE}"
echo "Building package to verify..."
RESULT_PATH=$(nix build "${SCRIPT_DIR}#default" --no-link --print-out-paths)
echo "Built: ${RESULT_PATH}"
echo
echo "sources.json now points at ${NEW_VERSION}. Review the diff before committing:"
echo "  git -C \"${SCRIPT_DIR}\" diff sources.json"
