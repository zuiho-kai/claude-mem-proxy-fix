#!/usr/bin/env bash
# _find-workers.sh — Shared worker discovery for all patch scripts
# Sources into caller; sets WORKERS array with all worker-service.cjs paths.
#
# claude-mem has two install locations:
#   cache/thedotmack/claude-mem/<version>/scripts/  — downloaded package
#   marketplaces/thedotmack/plugin/scripts/         — active runtime copy
# Both must be patched; the marketplaces copy is what actually runs.

WORKERS=()
_CACHE_BASE="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
_MARKET_BASE="$HOME/.claude/plugins/marketplaces/thedotmack/plugin"

for _w in \
  $(ls -1d "$_CACHE_BASE"/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1) \
  "$_MARKET_BASE/scripts/worker-service.cjs"; do
  [ -f "$_w" ] && WORKERS+=("$_w")
done

if [ ${#WORKERS[@]} -eq 0 ]; then
  echo "❌ worker-service.cjs not found in cache/ or marketplaces/"
  exit 1
fi
