#!/usr/bin/env bash
# patch-claude-mem.sh — 修复 claude-mem worker 在代理环境下子进程超时的问题
#
# 问题1：X5() (getAgentEnv) 把 HTTP_PROXY/HTTPS_PROXY 传给 CLI 子进程，
#        当 ANTHROPIC_BASE_URL 指向 localhost 时，子进程走代理访问 localhost → 超时
# 修复1：在 X5() 返回的 env 中注入 NO_PROXY=127.0.0.1,localhost
#
# 问题2：CLAUDE_MEM_MODEL 设置为短名（如 claude-sonnet-4-5），
#        部分 API 代理只认带日期后缀的完整模型名 → 503 model_not_found
# 修复2：自动补全模型名日期后缀
#
# 跟踪：https://github.com/thedotmack/claude-mem/issues/1163
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
  # 匹配 X5() 中设置 ENTRYPOINT 的位置，在其后注入 NO_PROXY
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
      sed -i "s/\"CLAUDE_MEM_MODEL\": \"$CURRENT_MODEL\"/\"CLAUDE_MEM_MODEL\": \"claude-opus-4-6\"/" "$SETTINGS"
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

echo ""
echo "✅ 完成。如果 worker 正在运行，需要重启："
echo "   taskkill /F /IM bun.exe          # Windows"
echo "   pkill -f worker-service.cjs      # Linux/macOS"
echo "   然后重新启动 Claude Code 即可"
