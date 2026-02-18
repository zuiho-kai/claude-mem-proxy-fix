#!/usr/bin/env bash
# patch-03-zombie.sh — Add zombie worker auto-recovery (kill & respawn)
# Doc: https://github.com/zuiho-kai/claude-mem-proxy-fix/blob/main/patches/03-zombie-recovery.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Detect worker-service.cjs ---
PLUGIN_BASE="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
if [ ! -d "$PLUGIN_BASE" ]; then
  echo "❌ Patch 3: claude-mem plugin not found: $PLUGIN_BASE"
  echo "   See: ${SCRIPT_DIR}/../patches/03-zombie-recovery.md"
  exit 1
fi

VERSION_DIR=$(ls -1d "$PLUGIN_BASE"/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)
if [ -z "$VERSION_DIR" ]; then
  echo "❌ Patch 3: worker-service.cjs not found under $PLUGIN_BASE"
  echo "   See: ${SCRIPT_DIR}/../patches/03-zombie-recovery.md"
  exit 1
fi
WORKER="$VERSION_DIR"

# --- Apply ---
if grep -q 'Respawning worker after zombie kill' "$WORKER"; then
  echo "✅ Patch 3 (zombie-kill): already applied, skipping"
  exit 0
fi

node -e '
  const fs = require("fs");
  const f = process.argv[1];
  let code = fs.readFileSync(f, "utf8");
  const OLD = `C.error("SYSTEM","Port in use but worker not responding to health checks"),!1))`;
  const NEW = `C.warn("SYSTEM","Port in use but worker not responding — killing zombie"),await async function(zp){try{if(process.platform==="win32"){let zo=require("child_process").execSync("netstat -ano | findstr :"+zp+" | findstr LISTENING",{encoding:"utf8",timeout:5e3}).trim().split(/\\n/);for(let zl of zo){let zd=zl.trim().split(/\\s+/).pop();zd&&zd!=="0"&&(C.info("SYSTEM","Killing zombie PID "+zd),require("child_process").execSync("taskkill /F /PID "+zd,{timeout:5e3}))}}else{let zo=require("child_process").execSync("lsof -ti:"+zp,{encoding:"utf8",timeout:5e3}).trim().split(/\\n/);for(let zl of zo)zl&&(C.info("SYSTEM","Killing zombie PID "+zl),process.kill(Number(zl),"SIGKILL"))}let zw=Date.now();for(;Date.now()-zw<5e3;){if(!await jh(zp))return C.info("SYSTEM","Port freed after zombie kill"),!0;await new Promise(zs=>setTimeout(zs,500))}}catch(ze){C.warn("SYSTEM","Zombie kill attempt failed",{error:String(ze)})}return!1}(t)?(C.info("SYSTEM","Respawning worker after zombie kill"),_Ze(),kI(__filename,t)===void 0?(C.error("SYSTEM","Failed to spawn after zombie kill"),!1):await Nh(t)?(C.info("SYSTEM","Worker healthy after zombie recovery"),!0):(C.error("SYSTEM","Worker not healthy after zombie recovery"),!1)):!1))`;
  if (!code.includes(OLD)) {
    console.error("❌ Patch 3: match string not found — source may have changed");
    process.exit(1);
  }
  code = code.replace(OLD, NEW);
  fs.writeFileSync(f, code);
' "$WORKER"

if grep -q 'Respawning worker after zombie kill' "$WORKER"; then
  echo "✅ Patch 3 (zombie-kill): applied successfully"
else
  echo "❌ Patch 3 (zombie-kill): failed — source structure may have changed"
  echo "   Manual fix: ${SCRIPT_DIR}/../patches/03-zombie-recovery.md"
  exit 1
fi
