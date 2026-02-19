# claude-mem-proxy-fix

[English](README.md) | [中文](README.zh-CN.md)

修复 [claude-mem](https://github.com/thedotmack/claude-mem) worker 在 Windows / 代理环境下的五个问题。

## 一键修复

```bash
git clone https://github.com/zuiho-kai/claude-mem-proxy-fix.git
bash claude-mem-proxy-fix/apply.sh
```

## 问题与补丁

| # | 问题 | 症状 | 文档 |
|---|------|------|------|
| 1 | `HTTP_PROXY` 泄漏到 CLI 子进程 | `Timed out waiting for agent pool slot after 60000ms` | [01-no-proxy.md](patches/01-no-proxy.md) |
| 2 | 短模型名被 API 代理拒绝 | `503 model_not_found` | [02-model-name.md](patches/02-model-name.md) |
| 3 | 僵尸 bun worker 阻塞启动 | Claude Code 卡死 60 秒+ | [03-zombie-recovery.md](patches/03-zombie-recovery.md) |
| 4 | Chroma CLI 仅支持 ARM64 Windows | `Unsupported Windows architecture: x64` | [04-chroma-x64.md](patches/04-chroma-x64.md) |
| 5 | `uvx.cmd` 不存在导致 chroma-mcp 启动失败 | `MCP error -32000: Connection closed` | [05-uvx-cmd.md](patches/05-uvx-cmd.md) |

## 单独应用某个补丁

```bash
bash scripts/patch-01-no-proxy.sh    # 仅 Patch 1
bash scripts/patch-02-model-name.sh  # 仅 Patch 2
bash scripts/patch-03-zombie.sh      # 仅 Patch 3
bash scripts/patch-04-chroma.sh      # 仅 Patch 4
```

### Patch 5 — uvx.cmd 转发脚本（手动）

claude-mem 通过 `uvx.cmd` 启动 chroma-mcp 子进程，但 `uv` 在 Windows 上只安装了 `uvx.exe`，没有 `uvx.cmd`，导致 MCP 搜索始终报错 Connection closed。

复制仓库里的 shim 文件：

```bash
cp uvx.cmd ~/.local/bin/uvx.cmd
```

或手动创建：

```cmd
@echo off
"%~dp0uvx.exe" %*
```

然后重启 claude-mem worker（重开 Claude Code 或调用 `/api/admin/shutdown`）。

## 注意

- 每次 claude-mem 更新后需要重新执行
- 同时修补 `cache/` 和 `marketplaces/` 两个安装路径（实际运行的是 `marketplaces/` 副本）
- 幂等，可重复执行

## 跟踪

- [#1163](https://github.com/thedotmack/claude-mem/issues/1163) — 代理绕过 + 模型名（Patch 1 & 2）
- [#1161](https://github.com/thedotmack/claude-mem/issues/1161) — 僵尸进程（Patch 3）

等作者修了就不需要这个 patch 了。
