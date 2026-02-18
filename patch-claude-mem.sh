#!/usr/bin/env bash
# patch-claude-mem.sh — 修复 claude-mem worker 三个已知问题
#
# Patch 1: 代理环境子进程超时 — X5() 注入 NO_PROXY
# Patch 2: 模型名不匹配 — 短名自动补全日期后缀
# Patch 3: 僵尸进程自愈 — health check 失败后自动杀僵尸 PID 并重启 worker
#
# 跟踪：
#   https://github.com/thedotmack/claude-mem/issues/1163 (Patch 1 & 2)
#   https://github.com/thedotmack/claude-mem/issues/1161 (Patch 3)
#
# 用法：bash patch-claude-mem.sh
# 每次 claude-mem 更新后需要重新执行

set -euo pipefail

# --- 自动检测 claude-mem 版本 ---
PLUGIN_BASE="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
if [ ! -d "$PLUGIN_BASE" ]; then
  echo "❌ claude-mem plugin not found: $PLUGIN_BASE"
  exit 1
fi

# 取最新版本目录
VERSION_DIR=$(ls -1d "$PLUGIN_BASE"/*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)
if [ -z "$VERSION_DIR" ]; then
  echo "❌ worker-service.cjs not found under $PLUGIN_BASE"
  exit 1
fi
WORKER="$VERSION_DIR"
echo "📦 检测到 worker: $WORKER"

SETTINGS="$HOME/.claude-mem/settings.json"

# --- Patch 1: X5() 注入 NO_PROXY ---
if grep -q 'CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY=' "$WORKER"; then
  echo "✅ Patch 1 (NO_PROXY): 已应用，跳过"
else
  sed -i 's/e\.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)/e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)/g' "$WORKER"
  if grep -q 'e.NO_PROXY="127.0.0.1,localhost"' "$WORKER"; then
    echo "✅ Patch 1 (NO_PROXY): 应用成功"
  else
    echo "❌ Patch 1 (NO_PROXY): 应用失败，源码结构可能已变"
    echo "   请手动在 X5() 函数中 CLAUDE_CODE_ENTRYPOINT 赋值后添加："
    echo '   e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost"'
    exit 1
  fi
fi

# --- Patch 2: 修正模型名 ---
if [ ! -f "$SETTINGS" ]; then
  echo "⚠️  settings.json not found: $SETTINGS，跳过模型名修正"
else
  CURRENT_MODEL=$(grep -oP '"CLAUDE_MEM_MODEL"\s*:\s*"\K[^"]+' "$SETTINGS" || echo "")
  case "$CURRENT_MODEL" in
    claude-sonnet-4-5|claude-sonnet-4-5-latest)
      sed -i "s/\"CLAUDE_MEM_MODEL\": \"$CURRENT_MODEL\"/\"CLAUDE_MEM_MODEL\": \"claude-sonnet-4-5-20250929\"/" "$SETTINGS"
      echo "✅ Patch 2 (model): $CURRENT_MODEL → claude-sonnet-4-5-20250929"
      ;;
    claude-haiku-4-5|claude-haiku-4-5-latest)
      sed -i "s/\"CLAUDE_MEM_MODEL\": \"$CURRENT_MODEL\"/\"CLAUDE_MEM_MODEL\": \"claude-haiku-4-5-20251001\"/" "$SETTINGS"
      echo "✅ Patch 2 (model): $CURRENT_MODEL → claude-haiku-4-5-20251001"
      ;;
    claude-opus-4-6|claude-opus-4-6-latest)
      echo "✅ Patch 2 (model): 已是完整模型名 ($CURRENT_MODEL)，跳过"
      ;;
    *-202[0-9]*)
      echo "✅ Patch 2 (model): 已是完整模型名 ($CURRENT_MODEL)，跳过"
      ;;
    "")
      echo "⚠️  Patch 2 (model): CLAUDE_MEM_MODEL 未设置，跳过"
      ;;
    *)
      echo "⚠️  Patch 2 (model): 未知模型名 '$CURRENT_MODEL'，请手动检查 $SETTINGS"
      ;;
  esac
fi

# --- Patch 3: 僵尸进程自愈 ---
# 原逻辑：端口被占 + health check 失败 → 返回 false（放弃）
# 新逻辑：端口被占 + health check 失败 → 杀僵尸 PID → 端口释放 → spawn 新 worker
if grep -q 'Respawning worker after zombie kill' "$WORKER"; then
  echo "✅ Patch 3 (zombie-kill): 已应用，跳过"
else
  # Use node for reliable string replacement (avoids shell/sed/perl escaping hell)
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
    echo "✅ Patch 3 (zombie-kill): 应用成功"
  else
    echo "❌ Patch 3 (zombie-kill): 应用失败，源码结构可能已变"
    echo "   请参考 README 手动应用"
    exit 1
  fi
fi

echo ""
echo "✅ 全部完成。如果 worker 正在运行，需要重启："
echo "   taskkill /F /IM bun.exe          # Windows"
echo "   pkill -f worker-service.cjs      # Linux/macOS"
echo "   然后重新启动 Claude Code 即可"
