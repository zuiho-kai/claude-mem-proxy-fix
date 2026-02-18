# claude-mem-proxy-fix

[English](README.md) | [中文](README.zh-CN.md)

修复 [claude-mem](https://github.com/thedotmack/claude-mem) worker 在 Windows / 代理环境下的四个问题。

## 问题

| # | 问题 | 症状 |
|---|------|------|
| 1 | `HTTP_PROXY` 泄漏到 CLI 子进程 | `Timed out waiting for agent pool slot after 60000ms` |
| 2 | 短模型名被 API 代理拒绝 | `503 model_not_found` |
| 3 | 僵尸 bun worker 阻塞启动 | Claude Code 卡死 60 秒+，worker 静默失效 |
| 4 | Chroma CLI 仅支持 ARM64 Windows | `Unsupported Windows architecture: x64` — 向量搜索不可用 |

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

### Patch 3: 僵尸进程自愈

原逻辑：`start` 检测到端口 37777 被占用但 health check 不通时，直接放弃。本 patch 加入自愈：

1. 检测占用端口的 PID（Windows 用 `netstat`，Unix 用 `lsof`）
2. 杀掉僵尸进程
3. 等待端口释放（最多 5 秒）
4. 启动新 worker 并验证 health check

```
端口被占 → health check 失败 → 杀僵尸 PID → 端口释放 → spawn 新 worker → health check 通过
```

### Patch 4: Chroma x64 Windows 兼容

`chromadb` npm 包自带的 Chroma 二进制只支持 ARM64 Windows，x64 上报 `Unsupported Windows architecture: x64`。

本 patch 在 x64 Windows 上跳过 node 版 binary，改用 Python 版 `chroma` CLI。

```diff
- (0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
+ r&&process.arch!=="arm64"?n="chroma":(0,io.existsSync)(c)?n=c:(0,io.existsSync)(l)?n=l:n=r?"npx.cmd":"npx"
```

Patch 4 前置条件：
```bash
pip install chromadb   # Python 3.9+
```

## 注意

- 每次 claude-mem 更新后需要重新执行 patch 脚本
- 脚本会自动检测 claude-mem 版本，无需手动指定路径
- 已应用的 patch 不会重复应用（幂等）

## 跟踪

- [#1163](https://github.com/thedotmack/claude-mem/issues/1163) — 代理绕过 + 模型名（Patch 1 & 2）
- [#1161](https://github.com/thedotmack/claude-mem/issues/1161) — 僵尸进程（Patch 3）

等作者修了就不需要这个 patch 了。
