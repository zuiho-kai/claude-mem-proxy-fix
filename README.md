# claude-mem-proxy-fix

修复 [claude-mem](https://github.com/thedotmack/claude-mem) 插件在代理环境下 CLI 子进程超时的问题。

## 问题

当系统设置了 `HTTP_PROXY`/`HTTPS_PROXY`（如 clash、v2ray 等），且 `ANTHROPIC_BASE_URL` 指向 localhost 的 API 代理时，claude-mem 的 observation 提取功能会失败：

1. **子进程超时** — `X5()` (getAgentEnv) 把 `HTTP_PROXY` 传给 Claude CLI 子进程，子进程访问 `127.0.0.1` 的 API 代理时走了 HTTP 代理 → 超时
2. **模型名不匹配** — `CLAUDE_MEM_MODEL` 设为短名（如 `claude-sonnet-4-5`），部分 API 代理只认带日期后缀的完整名 → `503 model_not_found`

## 症状

```
[ERROR] Generator failed {provider=claude, error=Timed out waiting for agent pool slot after 60000ms}
[INFO ] ← Response received: API Error: 503 {"error":{"code":"model_not_found",...}}
```

Worker health check 显示 `initialized: false`，observations 表始终为空。

## 修复

```bash
# 下载并执行
curl -fsSL https://raw.githubusercontent.com/zuiho-kai/claude-mem-proxy-fix/main/patch-claude-mem.sh | bash

# 或者 clone 后执行
git clone https://github.com/zuiho-kai/claude-mem-proxy-fix.git
bash claude-mem-proxy-fix/patch-claude-mem.sh
```

## 修复内容

### Patch 1: NO_PROXY 注入

在 `worker-service.cjs` 的 `X5()` 函数中注入 `NO_PROXY=127.0.0.1,localhost`，让 CLI 子进程直连 localhost 不走代理。

```diff
- e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",t)
+ e.CLAUDE_CODE_ENTRYPOINT="sdk-ts",e.NO_PROXY="127.0.0.1,localhost",e.no_proxy="127.0.0.1,localhost",t)
```

### Patch 2: 模型名补全

将 `~/.claude-mem/settings.json` 中的短模型名自动补全为带日期后缀的完整名：

| 短名 | 补全为 |
|------|--------|
| `claude-sonnet-4-5` | `claude-sonnet-4-5-20250929` |
| `claude-haiku-4-5` | `claude-haiku-4-5-20251001` |

## 注意

- 每次 claude-mem 更新后需要重新执行 patch 脚本
- 脚本会自动检测 claude-mem 版本，无需手动指定路径
- 已应用的 patch 不会重复应用（幂等）

## 跟踪

上游 issue: https://github.com/thedotmack/claude-mem/issues/1163

等作者修了就不需要这个 patch 了。
