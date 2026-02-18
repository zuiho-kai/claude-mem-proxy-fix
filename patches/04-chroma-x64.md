# Patch 4: Chroma x64 Windows Compatibility

## Symptom

```
Unsupported Windows architecture: x64
```

Vector search (ChromaDB) is unavailable. The worker falls back to SQLite FTS only — semantic search doesn't work.

## Root Cause

The `chromadb` npm package bundles a Chroma binary that only supports ARM64 on Windows. On x64 Windows (the vast majority of Windows machines), the binary selection logic fails with "Unsupported Windows architecture: x64".

The relevant code in `worker-service.cjs` picks the Chroma binary path:

```js
(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
```

On x64 Windows, none of the bundled binaries match, so it falls through to `npx.cmd` which also fails.

## Fix

On x64 Windows, skip the node-bundled binary entirely and use the Python `chroma` CLI instead.

```diff
- (0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
+ r&&process.arch!=="arm64"?n="chroma":(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
```

Logic: if Windows (`r` is true) AND not ARM64 → use `chroma` (Python CLI). Otherwise, use the original binary selection.

## Prerequisites

Install the Python ChromaDB package:

```bash
pip install chromadb   # Python 3.9+
```

Verify it's available:

```bash
chroma --version
```

## Manual Fix

1. Install Python chromadb:
   ```bash
   pip install chromadb
   ```

2. Find `worker-service.cjs`:
   ```bash
   ls ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs
   ```

3. Search for:
   ```
   (0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
   ```

4. Replace with:
   ```
   r&&process.arch!=="arm64"?n="chroma":(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
   ```

5. Save the file.

## Verify

```bash
grep 'process.arch!=="arm64"' ~/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs
```

Should return a match. Then restart the worker and check that ChromaDB starts:

```bash
# Check if chroma server is running after worker restart
curl http://127.0.0.1:8000/api/v1/heartbeat
```

## Tracking

- No upstream issue yet — the npm `chromadb` package needs to ship x64 Windows binaries.
