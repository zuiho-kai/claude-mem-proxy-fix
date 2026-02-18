# Patch 3: Zombie Worker Auto-Recovery

## Symptom

Claude Code hangs for 60+ seconds on startup. Every `SessionStart`, `PostToolUse`, and `UserPromptSubmit` hook blocks because the worker is unresponsive.

Running `netstat -ano | findstr :37777` shows a process LISTENING on the port, but `curl http://127.0.0.1:37777/health` gets no response.

## Root Cause

The bun worker process (`worker-service.cjs`) can become a zombie on Windows — it holds port 37777 but stops responding to health checks. Common triggers:

- Windows sleep/resume cycle
- Network interruption
- Memory leak (observed at 167MB+)
- `@chroma-core/default-embed` model loading stall

The `start` command (`Qte` function) detects the port is occupied, polls health checks, times out, and gives up:

```
Port in use → poll health check → timeout → return false
```

There's no kill-and-restart fallback.

## Fix

Replace the "give up" path with zombie auto-recovery:

1. Detect the PID holding port 37777 (`netstat` on Windows, `lsof` on Unix)
2. Kill the zombie process (`taskkill /F` on Windows, `SIGKILL` on Unix)
3. Wait for port release (up to 5 seconds)
4. Spawn a fresh worker and verify health

```
Port in use → health check FAIL → kill zombie PID → port freed → spawn new worker → health check OK
```

The patch replaces this line in `worker-service.cjs`:

```js
// Before
C.error("SYSTEM","Port in use but worker not responding to health checks"),!1))

// After
C.warn("SYSTEM","Port in use but worker not responding — killing zombie"),
  await async function(zp) {
    // ... detect PID, kill, wait for port release ...
  }(t) ? (
    // spawn new worker and verify
  ) : !1))
```

## Manual Fix

1. Find `worker-service.cjs`:
   ```bash
   ls ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs
   ```

2. Search for:
   ```
   C.error("SYSTEM","Port in use but worker not responding to health checks"),!1))
   ```

3. Replace with the zombie recovery code. This is complex — we recommend using the script:
   ```bash
   bash scripts/patch-03-zombie.sh
   ```

   If the script fails, the manual approach is:
   - When Claude Code hangs, open a terminal and run:
     ```bash
     # Windows
     netstat -ano | findstr :37777 | findstr LISTENING
     # Note the PID (last column), then:
     taskkill /F /PID <PID>

     # Linux/macOS
     lsof -ti:37777 | xargs kill -9
     ```
   - Restart Claude Code.

## Verify

```bash
grep 'Respawning worker after zombie kill' ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs
```

Should return a match.

## Tracking

- [#1161](https://github.com/thedotmack/claude-mem/issues/1161)
