#!/usr/bin/env bash
# patch-02-model-name.sh — Normalize short model names to full dated versions
# Doc: https://github.com/zuiho-kai/claude-mem-proxy-fix/blob/main/patches/02-model-name.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude-mem/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "⚠️  Patch 2 (model): settings.json not found: $SETTINGS, skipping"
  exit 0
fi

CURRENT_MODEL=$(grep -oP '"CLAUDE_MEM_MODEL"\s*:\s*"\K[^"]+' "$SETTINGS" || echo "")

case "$CURRENT_MODEL" in
  claude-sonnet-4-5|claude-sonnet-4-5-latest)
    sed -i "s/\"CLAUDE_MEM_MODEL\": \"$CURRENT_MODEL\"/\"CLAUDE_MEM_MODEL\": \"claude-sonnet-4-5-20250929\"/" "$SETTINGS"
    echo "✅ Patch 2 (model): $CURRENT_MODEL → claude-sonnet-4-5-20250929"
    ;;
  claude-haiku-4-5|claude-haiku-4-5-latest)
    sed -i "s/\"CLAUDE_MEM_MODEL\": \"$CURRENT_MODEL\"/\"CLAUDE_MEM_MODEL\": \"claude-haiku-4-5-20251001\"/" "$SETTINGS"
    echo "✅ Patch 2 (model): $CURRENT_MODEL → claude-haiku-4-5-20251001"
    ;;
  claude-opus-4-6|claude-opus-4-6-latest)
    echo "✅ Patch 2 (model): already full name ($CURRENT_MODEL), skipping"
    ;;
  *-202[0-9]*)
    echo "✅ Patch 2 (model): already full name ($CURRENT_MODEL), skipping"
    ;;
  "")
    echo "⚠️  Patch 2 (model): CLAUDE_MEM_MODEL not set, skipping"
    ;;
  *)
    echo "⚠️  Patch 2 (model): unknown model '$CURRENT_MODEL', check $SETTINGS manually"
    echo "   See: ${SCRIPT_DIR}/../patches/02-model-name.md"
    ;;
esac
