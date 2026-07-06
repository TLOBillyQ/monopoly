# SwarmForge 本地配置与上游结构对齐设计

## 目标

将本地 `swarmforge/` 从「把共享脚本/章程直接提交到仓库」的 vendored 模式，改为「`./swarm` 启动时从 `unclebob/swarm-forge/main` 拉取共享脚本」的上游标准模式。

对齐后，本地只保留项目特有的覆盖与扩展（Lua 工具链、Claude 后端、项目章程），共享脚本/章程由启动流程自动同步。

## 范围

- 改动范围：仓库根目录 `./swarm` 与 `swarmforge/` 目录。
- 不改动：`src/`、`spec/`、`tools/`、`features/` 等业务代码。

## 背景

当前本地 `swarmforge/` 存在以下与上游 `unclebob/swarm-forge` 的差异：

1. **共享脚本内嵌**：`swarmforge/scripts/` 全部提交在仓库中，且存在 `swarmforge/scripts/shared-articles/` 的 vendored 副本。
2. **脚本架构落后**：本地 `swarmforge.sh` 是 627 行的旧版 zsh 单体实现；上游 `main` 已将其拆分为 5 行 wrapper + `swarmforge.bb`。
3. **章程重复**：`swarmforge/constitution/articles/` 中同时存在本地文章与共享文章的副本。
4. **缺失协议文档**：本地没有 `swarmforge/handoff-protocol.md`。
5. **`awake` handoff 已废弃**：上游 `main` 的 `swarm_handoff.bb` 已将 `allowed-types` 从 `{awake, git_handoff, note}` 改为 `{git_handoff, note}`，本地仍在使用 `awake`。

## 设计决策

### 决策 1：移除 `awake` 类型以完全对齐上游

上游 `main` 已移除 `awake` handoff 类型。为达成「全面对齐上游结构」的目标，本地同步移除 `awake` 相关规则，不再在启动时发送 presence signal。

### 决策 2：本地保留完整覆盖的 `engineering.prompt`

本地 `engineering.prompt` 是针对 Lua 5.4 / busted / `tools/quality/` 的专用规则，与上游通用版本差异过大，不适合改为 `local-engineering.prompt` 叠加。因此继续作为完整覆盖保留。

### 决策 3：删除本地 `handoffs.prompt`，使用上游共享版

本地 `handoffs.prompt` 与上游共享版的主要差异是：

- 本地包含已废弃的 `awake` 规则（已决定移除）。
- 本地包含「不转发无功能变更 commit」规则；上游 four-pack 的 `architect.prompt` 也保留了类似规则，因此该行为由 role prompt 覆盖即可，无需在 handoffs 章程中重复。

其余接收/发送规则与上游共享版一致。因此直接删除本地 `handoffs.prompt`，由 `./swarm` 启动时从 upstream main 安装共享 `handoffs.prompt`。

> 注：upstream `main` 的共享 `handoffs.prompt` 与 `four-pack` 的 `architect.prompt` 在「无功能变更是否必须转发」上存在不一致（共享版要求链式角色必须转发，而 four-pack architect prompt 允许不转发）。这是上游自身的矛盾，本设计不做本地裁决，保持 `architect.prompt` 与 upstream four-pack 一致。

### 决策 4：`workflow.prompt` 不再本地覆盖

本地当前 `workflow.prompt` 与上游共享版一致，删除本地副本，由启动流程从 main 自动安装。

### 决策 5：保留 `constitution/tools/` 与 `tools.lock`

上游没有工具章程机制，但它是本项目 Lua 工具链的必需扩展，作为本地覆盖保留。

### 决策 6：保留 `otty.sh` 终端后端

`otty.sh` 是本地使用的终端适配器，上游没有。终端后端以新增文件方式自然扩展，保留不影响对齐。

## 目标目录结构

```text
swarm
swarmforge/
  README.md
  swarmforge.conf
  constitution.prompt
  handoff-protocol.md
  constitution/
    articles/
      project.prompt
      engineering.prompt        # 本地完整覆盖
    tools/
      mutate4lua.prompt
      dry4lua.prompt
      crap4lua.prompt
      arch_view.prompt
      acceptance4lua.prompt
  scripts/                      # 启动时由 ./swarm 从 upstream main 拉取
    swarmforge.sh               # 5 行 wrapper
    swarmforge.bb
    handoff_lib.bb
    handoffd.bb
    swarm_handoff.bb
    swarm-window-watchdog.bb
    stop_handoff_daemon.bb
    stop_handoff_daemon.sh
    ...
    terminal-adapters/
      ghostty.sh
      iterm2.sh
      none.sh
      terminal-app.sh
      windows-terminal.sh
      otty.sh                   # 本地扩展
```

## 具体变更清单

### 删除

- `swarmforge/scripts/shared-articles/` 整个目录。
- `swarmforge/scripts/handoff-lib.sh`。
- `swarmforge/scripts/swarm-window-watchdog.sh`。
- `swarmforge/constitution/articles/workflow.prompt`。
- `swarmforge/constitution/articles/handoffs.prompt`（由 upstream main 的共享版替代）。

### 新增或替换为 upstream main 版本

- `swarmforge/scripts/swarmforge.sh` → 5 行 wrapper。
- `swarmforge/scripts/swarmforge.bb`。
- `swarmforge/scripts/handoff_lib.bb`。
- `swarmforge/scripts/handoffd.bb`。
- `swarmforge/scripts/swarm_handoff.bb`。
- `swarmforge/scripts/swarm-window-watchdog.bb`。
- `swarmforge/scripts/stop_handoff_daemon.bb`。
- `swarmforge/scripts/stop_handoff_daemon.sh`。
- `swarmforge/scripts/terminal-adapters/iterm2.sh`。
- `swarmforge/handoff-protocol.md`。
- `swarmforge/README.md`（项目级说明，非 upstream 平台 README）。

### 保留并改写

- `swarmforge/constitution/articles/project.prompt`：内容不变。
- `swarmforge/constitution/articles/engineering.prompt`：保留 Lua 专用规则，继续作为完整覆盖。
- `swarmforge/constitution/tools/` 与 `swarmforge/tools.lock`：保留。
- `swarmforge/scripts/terminal-adapters/otty.sh`：保留。

## 对各 role prompt 的影响

- `swarmforge/roles/specifier.prompt`：无 `awake` 规则，无需改动。
- `swarmforge/roles/coder.prompt`：无 `awake` 规则，无需改动。
- `swarmforge/roles/refactorer.prompt`：无 `awake` 规则，无需改动。
- `swarmforge/roles/architect.prompt`：无 `awake` 规则，且与 upstream four-pack 的 `architect.prompt` 一致，无需改动。

本地 `constitution/articles/handoffs.prompt` 中原有「启动后发送 awake 给 specifier」规则，随该文件删除而移除。后续由 upstream main 的共享 `handoffs.prompt` 提供手递手规则。

## 验证计划

1. 在干净目录或临时 clone 中执行 `./swarm`，确认它能从 `unclebob/swarm-forge/main` 下载共享脚本。
2. 确认 `.swarmforge/` 下生成 `roles.tsv`、`tmux-socket`、`daemon/` 等状态。
3. 确认各 role worktree 下同步了 `swarmforge/scripts/`。
4. 确认 `swarmforge/constitution/articles/` 由启动流程补齐共享章程，且本地覆盖文件未被覆盖。
5. 使用 `swarm_handoff.sh` 提交一个测试 `git_handoff` 草稿，确认校验通过并被投递。
6. 关闭第一个窗口（cleanup window），确认 tmux 会话与终端窗口正常清理。

## 风险与回滚

- **Babashka 依赖**：新脚本架构依赖 `bb`。当前 `.busted` 与项目工具链已使用 Babashka，风险较低，但仍需验证版本兼容性。
- **启动失败风险**：若 upstream main 脚本与本地的 `swarmforge.conf` 或工具章程不兼容，可能导致 `./swarm` 启动失败。
- **回滚方式**：改动全部集中在 `swarmforge/` 与 `./swarm`，可通过 `git checkout HEAD -- swarmforge/ swarm` 一键回退。建议在独立分支上实施。

## 非目标

- 不更改 agent 后端（保持 `claude`）。
- 不更改项目语言与测试框架（保持 Lua 5.4 / busted）。
- 不重构 `tools/quality/`、`tools/acceptance/` 等本地工具实现。
- 不修改业务代码或现有测试。
