#!/usr/bin/env bash
# patch-01-no-proxy.sh — Inject NO_PROXY into X5() getAgentEnv
# Doc: https://github.com/zuiho-kai/claude-mem-proxy-fix/blob/main/patches/01-no-proxy.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Detect worker-service.cjs ---
PLUGIN_BASE="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
if [ ! -d "$PLUGIN_BASE" ]; then
  echo "❌ Patch 1: claude-mem plugin not found: $PLUGIN_BASE"
  echo "   See: ${SCRIPT_DIR}/../patches/01-no-proxy.md"
  exit 1
fi

VERSION_DIR=$(ls -1d "$PLUGIN_BASE"/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)
if [ -z "$VERSION_DIR" ]; then
  echo "❌ Patch 1: worker-service.cjs not found under $PLUGIN_BASE"
  echo "   See: ${SCRIPT_DIR}/../patches/01-no-proxy.md"
  exit 1
fi
WORKER="$VERSION_DIR"

# --- Apply ---
if grep -q 'CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY=' "$WORKER"; then
  echo "✅ Patch 1 (NO_PROXY): already applied, skipping"
  exit 0
fi

sed -i 's/e\.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)/e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)/g' "$WORKER"

if grep -q 'e.NO_PROXY="127.0.0.1,localhost"' "$WORKER"; then
  echo "✅ Patch 1 (NO_PROXY): applied successfully"
else
  echo "❌ Patch 1 (NO_PROXY): failed — source structure may have changed"
  echo "   Manual fix: ${SCRIPT_DIR}/../patches/01-no-proxy.md"
  exit 1
fi
