# claude-mem-proxy-fix

[English](README.md) | [中文](README.zh-CN.md)

Fix [claude-mem](https://github.com/thedotmack/claude-mem) plugin CLI subprocess timeout in proxy environments.

## Problem

When `HTTP_PROXY`/`HTTPS_PROXY` is set (e.g. clash, v2ray) and `ANTHROPIC_BASE_URL` points to a localhost API proxy, claude-mem's observation extraction fails:

1. **Subprocess timeout** — `X5()` (getAgentEnv) passes `HTTP_PROXY` to the spawned Claude CLI subprocess, which then routes requests to `127.0.0.1` through the HTTP proxy → timeout
2. **Model name mismatch** — `CLAUDE_MEM_MODEL` set to short name (e.g. `claude-sonnet-4-5`), but some API proxies only accept full names with date suffix → `503 model_not_found`

## Symptoms

```
[ERROR] Generator failed {provider=claude, error=Timed out waiting for agent pool slot after 60000ms}
[INFO ] ← Response received: API Error: 503 {"error":{"code":"model_not_found",...}}
```

Worker health check shows `initialized: false`, observations table stays empty.

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

## Notes

- Re-run the patch script after each claude-mem update
- Auto-detects claude-mem version, no manual path needed
- Idempotent — safe to re-run

## Tracking

Upstream issue: https://github.com/thedotmack/claude-mem/issues/1163

This patch is no longer needed once the upstream fix is merged.
