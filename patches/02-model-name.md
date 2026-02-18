# Patch 2: Model Name Normalization

## Symptom

```
[INFO ] ← Response received: API Error: 503 {"error":{"code":"model_not_found",...}}
```

The worker calls the API but gets rejected because the model name is not recognized.

## Root Cause

`CLAUDE_MEM_MODEL` in `~/.claude-mem/settings.json` is set to a short alias (e.g. `claude-sonnet-4-5`). Some API proxies only accept the full model name with date suffix (e.g. `claude-sonnet-4-5-20250929`).

## Fix

Replace the short model name with the full dated version:

| Short name | Full name |
|------------|-----------|
| `claude-sonnet-4-5` | `claude-sonnet-4-5-20250929` |
| `claude-sonnet-4-5-latest` | `claude-sonnet-4-5-20250929` |
| `claude-haiku-4-5` | `claude-haiku-4-5-20251001` |
| `claude-haiku-4-5-latest` | `claude-haiku-4-5-20251001` |

Names already containing a date suffix (e.g. `*-202*`) are left unchanged.

## Manual Fix

1. Open `~/.claude-mem/settings.json` in a text editor.

2. Find the `CLAUDE_MEM_MODEL` field:
   ```json
   "CLAUDE_MEM_MODEL": "claude-sonnet-4-5"
   ```

3. Replace with the full name:
   ```json
   "CLAUDE_MEM_MODEL": "claude-sonnet-4-5-20250929"
   ```

4. Save the file.

## Verify

```bash
grep CLAUDE_MEM_MODEL ~/.claude-mem/settings.json
```

Should show a model name with a date suffix (e.g. `-20250929`).

## Tracking

- [#1163](https://github.com/thedotmack/claude-mem/issues/1163)
