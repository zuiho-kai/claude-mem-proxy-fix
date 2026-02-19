# claude-mem-proxy-fix

[English](README.md) | [中文](README.zh-CN.md)

Patches for [claude-mem](https://github.com/thedotmack/claude-mem) worker issues on Windows / proxy environments.

## Quick Fix

```bash
git clone https://github.com/zuiho-kai/claude-mem-proxy-fix.git
bash claude-mem-proxy-fix/apply.sh
```

## Problems & Patches

| # | Issue | Symptom | Doc |
|---|-------|---------|-----|
| 1 | `HTTP_PROXY` leaks into CLI subprocess | `Timed out waiting for agent pool slot after 60000ms` | [01-no-proxy.md](patches/01-no-proxy.md) |
| 2 | Short model name rejected by API proxy | `503 model_not_found` | [02-model-name.md](patches/02-model-name.md) |
| 3 | Zombie bun worker blocks startup | Claude Code hangs 60s+ | [03-zombie-recovery.md](patches/03-zombie-recovery.md) |
| 4 | Chroma CLI only supports ARM64 on Windows | `Unsupported Windows architecture: x64` | [04-chroma-x64.md](patches/04-chroma-x64.md) |
| 5 | `uvx.cmd` not found — chroma-mcp fails to start | `MCP error -32000: Connection closed` | [05-uvx-cmd.md](patches/05-uvx-cmd.md) |

## Apply a Single Patch

```bash
bash scripts/patch-01-no-proxy.sh    # Patch 1 only
bash scripts/patch-02-model-name.sh  # Patch 2 only
bash scripts/patch-03-zombie.sh      # Patch 3 only
bash scripts/patch-04-chroma.sh      # Patch 4 only
```

### Patch 5 — uvx.cmd shim (manual)

claude-mem starts chroma-mcp via `uvx.cmd`, but `uv` only installs `uvx.exe` on Windows. Copy the shim:

```bash
cp uvx.cmd ~/.local/bin/uvx.cmd
```

Or create it manually:

```cmd
@echo off
"%~dp0uvx.exe" %*
```

Then restart claude-mem worker (reopen Claude Code or call `/api/admin/shutdown`).

## Notes

- Re-run after each claude-mem update
- Patches both `cache/` and `marketplaces/` install paths (the runtime copy lives in `marketplaces/`)
- Idempotent — safe to re-run

## Tracking

- [#1163](https://github.com/thedotmack/claude-mem/issues/1163) — Proxy bypass + model name (Patch 1 & 2)
- [#1161](https://github.com/thedotmack/claude-mem/issues/1161) — Zombie worker (Patch 3)

No longer needed once upstream fixes are merged.
