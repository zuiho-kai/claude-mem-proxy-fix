#!/usr/bin/env bash
# patch-04-chroma.sh — Fix Chroma x64 Windows compatibility
# Doc: https://github.com/zuiho-kai/claude-mem-proxy-fix/blob/main/patches/04-chroma-x64.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Detect worker-service.cjs ---
PLUGIN_BASE="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
if [ ! -d "$PLUGIN_BASE" ]; then
  echo "❌ Patch 4: claude-mem plugin not found: $PLUGIN_BASE"
  echo "   See: ${SCRIPT_DIR}/../patches/04-chroma-x64.md"
  exit 1
fi

VERSION_DIR=$(ls -1d "$PLUGIN_BASE"/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)
if [ -z "$VERSION_DIR" ]; then
  echo "❌ Patch 4: worker-service.cjs not found under $PLUGIN_BASE"
  echo "   See: ${SCRIPT_DIR}/../patches/04-chroma-x64.md"
  exit 1
fi
WORKER="$VERSION_DIR"

# --- Apply ---
if grep -q 'process.arch!=="arm64"' "$WORKER"; then
  echo "✅ Patch 4 (chroma-x64): already applied, skipping"
  exit 0
fi

# Only needed on x64 Windows
if [[ "$(uname -m)" == "x86_64" ]] && [[ "$(uname -s)" == *MINGW* || "$(uname -s)" == *MSYS* || "$(uname -s)" == *CYGWIN* || "${OS:-}" == "Windows_NT" ]]; then
  # Check Python chroma CLI
  if ! command -v chroma &>/dev/null; then
    echo "⚠️  Patch 4 (chroma-x64): Python chromadb not installed, installing..."
    pip install chromadb 2>&1 | tail -3
    if ! command -v chroma &>/dev/null; then
      echo "❌ Patch 4 (chroma-x64): pip install chromadb failed"
      echo "   Install manually: pip install chromadb"
      echo "   See: ${SCRIPT_DIR}/../patches/04-chroma-x64.md"
      exit 1
    fi
  fi

  node -e '
    const fs = require("fs");
    const f = process.argv[1];
    let code = fs.readFileSync(f, "utf8");
    const OLD = `(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"`;
    const NEW = `r&&process.arch!=="arm64"?n="chroma":(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"`;
    if (!code.includes(OLD)) {
      console.error("❌ Patch 4: match string not found — source may have changed");
      process.exit(1);
    }
    code = code.replace(OLD, NEW);
    fs.writeFileSync(f, code);
  ' "$WORKER"

  if grep -q 'process.arch!=="arm64"' "$WORKER"; then
    echo "✅ Patch 4 (chroma-x64): applied (using Python chromadb)"
  else
    echo "❌ Patch 4 (chroma-x64): failed — source structure may have changed"
    echo "   Manual fix: ${SCRIPT_DIR}/../patches/04-chroma-x64.md"
    exit 1
  fi
else
  echo "✅ Patch 4 (chroma-x64): not x64 Windows, skipping"
fi
