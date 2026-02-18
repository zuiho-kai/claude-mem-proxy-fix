# Patch 1: NO_PROXY Injection

## Symptom

```
[ERROR] Generator failed {provider=claude, error=Timed out waiting for agent pool slot after 60000ms}
```

Worker health check shows `initialized: false`, observations table stays empty.

## Root Cause

`X5()` (`getAgentEnv`) in `worker-service.cjs` copies the parent process's environment — including `HTTP_PROXY` / `HTTPS_PROXY` — into the CLI subprocess. When `ANTHROPIC_BASE_URL` points to a localhost API proxy (e.g. `http://127.0.0.1:8080`), the subprocess routes localhost traffic through the HTTP proxy, which times out.

## Fix

Inject `NO_PROXY=127.0.0.1,localhost` (both upper and lower case) into the env object right after the `CLAUDE_CODE_ENTRYPOINT` assignment.

```diff
- e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)
+ e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)
```

## Manual Fix

1. Find `worker-service.cjs`:
   ```bash
   ls ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs
   ```

2. Open the file in a text editor and search for:
   ```
   e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)
   ```

3. Replace with:
   ```
   e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)
   ```

4. Save the file.

## Verify

```bash
grep 'e.NO_PROXY="127.0.0.1,localhost"' ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs
```

Should return a match. Then restart the worker:

```bash
# Windows
taskkill /F /IM bun.exe

# Linux/macOS
pkill -f worker-service.cjs
```

Reopen Claude Code — observations should start populating.

## Tracking

- [#1163](https://github.com/thedotmack/claude-mem/issues/1163)
