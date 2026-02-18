# claude-mem-proxy-fix

[English](README.md) | [中文](README.zh-CN.md)

Patches for [claude-mem](https://github.com/thedotmack/claude-mem) worker issues on Windows / proxy environments.

## Problems

| # | Issue | Symptom |
|---|-------|---------|
| 1 | `HTTP_PROXY` leaks into CLI subprocess | `Timed out waiting for agent pool slot after 60000ms` |
| 2 | Short model name rejected by API proxy | `503 model_not_found` |
| 3 | Zombie bun worker blocks startup | Claude Code hangs 60s+, worker silently non-functional |
| 4 | Chroma CLI only supports ARM64 on Windows | `Unsupported Windows architecture: x64` — vector search unavailable |

## Fix

```bash
# Download and run
curl -fsSL https://raw.githubusercontent.com/zuiho-kai/claude-mem-proxy-fix/main/patch-claude-mem.sh | bash

# Or clone and run
git clone https://github.com/zuiho-kai/claude-mem-proxy-fix.git
bash claude-mem-proxy-fix/patch-claude-mem.sh
```

## What it does

### Patch 1: NO_PROXY injection

Injects `NO_PROXY=127.0.0.1,localhost` into the env returned by `X5()` in `worker-service.cjs`, so the CLI subprocess connects directly to localhost without going through the proxy.

```diff
- e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)
+ e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)
```

### Patch 2: Model name normalization

Auto-completes short model names in `~/.claude-mem/settings.json` with date suffixes:

| Short name | Normalized to |
|------------|---------------|
| `claude-sonnet-4-5` | `claude-sonnet-4-5-20250929` |
| `claude-haiku-4-5` | `claude-haiku-4-5-20251001` |

### Patch 3: Zombie worker auto-recovery

When the `start` command detects port 37777 is occupied but the worker fails health checks (zombie process), the original code just gives up. This patch adds self-healing:

1. Detect PID holding the port (`netstat` on Windows, `lsof` on Unix)
2. Kill the zombie process
3. Wait for port release (up to 5s)
4. Spawn a fresh worker and verify health

```
Port in use → health check FAIL → kill zombie PID → port freed → spawn new worker → health check OK
```

### Patch 4: Chroma x64 Windows compatibility

The `chromadb` npm package bundles a Chroma binary that only supports ARM64 on Windows. On x64 Windows, it fails with `Unsupported Windows architecture: x64`.

This patch skips the node-bundled binary and uses the Python `chroma` CLI instead (requires `pip install chromadb`).

```diff
- (0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
+ r&&process.arch!=="arm64"?n="chroma":(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
```

Prerequisites for Patch 4:
```bash
pip install chromadb   # Python 3.9+
```

## Notes

- Re-run the patch script after each claude-mem update
- Auto-detects claude-mem version, no manual path needed
- Idempotent — safe to re-run

## Tracking

- [#1163](https://github.com/thedotmack/claude-mem/issues/1163) — Proxy bypass + model name (Patch 1 & 2)
- [#1161](https://github.com/thedotmack/claude-mem/issues/1161) — Zombie worker (Patch 3)

This patch is no longer needed once the upstream fixes are merged.
