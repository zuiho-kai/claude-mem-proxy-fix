#!/usr/bin/env bash
# patch-01-no-proxy.sh — Inject NO_PROXY into X5() getAgentEnv
# Doc: https://github.com/zuiho-kai/claude-mem-proxy-fix/blob/main/patches/01-no-proxy.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_find-workers.sh"

# --- Apply to each worker ---
APPLIED=0
for WORKER in "${WORKERS[@]}"; do
  if grep -q 'CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY=' "$WORKER"; then
    echo "✅ Patch 1 (NO_PROXY): already applied — $(basename "$(dirname "$(dirname "$WORKER")")")"
    APPLIED=$((APPLIED + 1))
    continue
  fi

  sed -i 's/e\.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)/e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)/g' "$WORKER"

  if grep -q 'e.NO_PROXY="127.0.0.1,localhost"' "$WORKER"; then
    echo "✅ Patch 1 (NO_PROXY): applied — $(basename "$(dirname "$(dirname "$WORKER")")")"
    APPLIED=$((APPLIED + 1))
  else
    echo "❌ Patch 1 (NO_PROXY): failed — $(basename "$(dirname "$(dirname "$WORKER")")")"
    echo "   Manual fix: ${SCRIPT_DIR}/../patches/01-no-proxy.md"
  fi
done

[ "$APPLIED" -eq 0 ] && exit 1 || exit 0
