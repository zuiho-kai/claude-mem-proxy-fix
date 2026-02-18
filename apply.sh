#!/usr/bin/env bash
# apply.sh — Apply all claude-mem patches (one-click)
# Each patch runs independently; one failure won't block the others.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_URL="https://github.com/zuiho-kai/claude-mem-proxy-fix/blob/main/patches"

# --- Detect worker ---
PLUGIN_BASE="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
if [ ! -d "$PLUGIN_BASE" ]; then
  echo "❌ claude-mem plugin not found: $PLUGIN_BASE"
  exit 1
fi

VERSION_DIR=$(ls -1d "$PLUGIN_BASE"/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)
if [ -z "$VERSION_DIR" ]; then
  echo "❌ worker-service.cjs not found under $PLUGIN_BASE"
  exit 1
fi
echo "📦 Detected worker: $VERSION_DIR"
echo ""

# --- Run each patch ---
PATCHES=(
  "01-no-proxy:patch-01-no-proxy.sh:01-no-proxy.md"
  "02-model-name:patch-02-model-name.sh:02-model-name.md"
  "03-zombie:patch-03-zombie.sh:03-zombie-recovery.md"
  "04-chroma:patch-04-chroma.sh:04-chroma-x64.md"
)

PASS=0
FAIL=0
FAIL_LIST=""

for entry in "${PATCHES[@]}"; do
  IFS=: read -r name script doc <<< "$entry"
  echo "--- Patch: $name ---"
  if bash "$SCRIPT_DIR/scripts/$script"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_LIST="$FAIL_LIST  ❌ $name → $REPO_URL/$doc\n"
  fi
  echo ""
done

# --- Summary ---
echo "=============================="
echo "  ✅ Passed: $PASS / ${#PATCHES[@]}"
if [ "$FAIL" -gt 0 ]; then
  echo "  ❌ Failed: $FAIL / ${#PATCHES[@]}"
  echo ""
  echo "Failed patches (see docs for manual fix):"
  echo -e "$FAIL_LIST"
fi
echo "=============================="

if [ "$PASS" -gt 0 ]; then
  echo ""
  echo "Restart the worker to apply changes:"
  echo "  taskkill /F /IM bun.exe          # Windows"
  echo "  pkill -f worker-service.cjs      # Linux/macOS"
  echo "  Then reopen Claude Code."
fi
