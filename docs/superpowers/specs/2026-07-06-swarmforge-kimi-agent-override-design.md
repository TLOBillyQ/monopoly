# SwarmForge 支持 Kimi 后端与 CLI Agent 覆盖设计

## 目标

让本地 `./swarm` 启动命令支持两种新能力：

1. **Kimi 作为 agent 后端**：`swarmforge.conf` 可以把 role 的 agent 字段设为 `kimi`，启动后该 role 在 tmux pane 中运行 Kimi Code CLI。
2. **CLI 全局覆盖 agent**：通过 `./swarm [agent] [directory]` 一次性把所有 role 的 agent 临时替换为指定后端，不改写 `swarmforge.conf`。

## 范围

- 改动范围：`swarmforge/scripts/swarmforge.bb`、`swarmforge/scripts/kimi-prompt-injector.sh`（新增）、`swarmforge/README.md`。
- 不改动：`swarmforge.conf`、`swarmforge/roles/*.prompt`、handoff 协议、终端后端适配器、业务代码。

## 背景

当前 `swarmforge/scripts/swarmforge.bb` 的 agent 白名单只有 `claude`、`codex`、`copilot`、`grok`（第 169 行）。`launch-command` 也为这四种后端各写死了一个分支。Kimi 不在支持列表中，因此即使把 `swarmforge.conf` 改成 `kimi`，启动时也会报 `Unsupported agent`。

同时，`-main` 目前只把第一个位置参数当作项目根目录，没有提供临时切换 agent 的 CLI 方式。用户若想测试 Kimi，必须手动修改 `swarmforge.conf`，测试完再改回。

## 设计决策

### 决策 1：采用交互式 Kimi + Prompt Injector 模式

Kimi CLI 没有类似 Claude 的 `--append-system-prompt-file` 参数来持续加载系统提示。参考 `/Users/billyq/Dev/work/MiliastraAuto/swarmforge/scripts/swarmforge.bb` 的验证方案，采用：

- 在 tmux pane 中启动交互式 `kimi --yolo --add-dir <worktree>`。
- 通过独立的 `kimi-prompt-injector.sh` 脚本，在 TUI 就绪后把 `prompts/<role>.md` 内容作为第一条用户消息发送进去。

这种方式不依赖 Kimi 提供系统提示接口，与现有参考实现一致。

### 决策 2：CLI 参数解析采用 agent 白名单识别

新的调用语法为：

```bash
./swarm [agent] [directory]
```

解析规则：

1. 已知 agent 白名单：`#{"claude" "codex" "copilot" "grok" "kimi"}`。
2. 如果第一个位置参数在白名单里，它就是全局 agent 覆盖；否则仍视为项目根目录。
3. 若第一个参数是 agent，第二个参数（若存在）是项目目录；无第二个参数时目录为当前目录。
4. 无参数时保持现有行为：按 `swarmforge.conf` 启动，目录为当前目录。

覆盖传播机制：`-main` 解析出可选的 `agent-override` 后，把它传给 `run-main!`；`run-main!` 在 `parse-config` 得到 roles 后，用 `(map #(assoc % :agent agent-override) (:roles ctx))` 统一替换每个 role 的 `:agent` 字段，再进入后续启动流程。CLI 覆盖仅影响本次启动，不会写回 `swarmforge.conf`。

### 决策 3：不引入显式 `--agent` 选项

为保持 CLI 的简洁性，不增加 `--agent kimi` 这类选项。agent 名与目录名冲突是已知边界情况，通过文档说明即可。

### 决策 4：最小内联扩展而非适配器抽象

直接把 Kimi 逻辑加入 `swarmforge.bb`，不抽象出通用 agent adapter 层。当前需求只有新增一个后端加一个 CLI 覆盖，抽象适配器的收益不足以抵消重构现有四个 agent 分支的成本。

## CLI 参数解析规则

| 命令 | 含义 |
| --- | --- |
| `./swarm` | 按 `swarmforge.conf` 启动，目录为当前目录 |
| `./swarm claude` | 所有 role 用 claude，目录为当前目录 |
| `./swarm kimi /path/to/project` | 所有 role 用 kimi，目录为 `/path/to/project` |
| `./swarm /path/to/project` | 按 conf 启动，目录为 `/path/to/project` |

边界情况：

- 若第一个参数是白名单外的字符串，按项目目录处理。
- 若用户真的有一个名为 `kimi` 的目录，执行 `./swarm kimi` 会被识别为 agent。此时可改用 `./swarm /absolute/path/to/kimi` 或 `cd kimi && ../swarm`。

## Kimi 后端集成

### `launch-command` 的 Kimi 分支

```clojure
"kimi" (str "kimi --yolo --add-dir " (sq (str role-worktree))
            (when (seq (:extra-args row)) (str " " (:extra-args row))))
```

说明：

- `--yolo`：让 Kimi 自动执行动作，无需每次确认，等价于 Claude 的 `--permission-mode acceptEdits`。
- `--add-dir <worktree>`：把 role 对应的工作目录加入 Kimi workspace。
- `extra-args`：保留 `swarmforge.conf` 里 window 行尾部的额外参数能力，例如 `window coder kimi coder --model k1.5`。
- 不用 `kimi -p` 非交互模式，因为 swarm 需要 agent 持续在 tmux pane 中等待 handoff。

### `kimi-prompt-injector.sh`

新增可执行脚本 `swarmforge/scripts/kimi-prompt-injector.sh`：

```zsh
#!/usr/bin/env zsh
set -euo pipefail

TMUX_SOCKET="$1"
TARGET="$2"
PROMPT_FILE="$3"
DELAY_SECONDS="${4:-3}"

sleep "$DELAY_SECONDS"
tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" -l -- "$(< "$PROMPT_FILE")"
sleep 0.15
tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" C-m
sleep 0.05
tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" C-j
```

`launch-role!` 在启动 Kimi 后调度 injector，延迟按 role index 递增（第 0 个 role 等 1 秒，第 1 个等 2 秒，依此类推），避免多个 pane 同时注入导致 `tmux send-keys` 混乱。

### 依赖检查

`check-backend-dependencies!` 会检查 `kimi` 命令是否存在。若 CLI 覆盖为 kimi 但本机未安装，启动前直接报错退出。

## 文件变更清单

### 修改

- `swarmforge/scripts/swarmforge.bb`
  - agent 白名单加入 `"kimi"`。
  - `launch-command` 增加 `"kimi"` 分支。
  - `launch-role!` 增加 Kimi prompt injector 调度。
  - `-main` 增加 `[agent] [directory]` 解析。
  - `required-helpers` 加入 `"kimi-prompt-injector.sh"`。
- `swarmforge/README.md`
  - 更新启动命令说明，补充 agent 覆盖示例。

### 新增

- `swarmforge/scripts/kimi-prompt-injector.sh`（可执行）。

### 不变

- `swarmforge.conf`：CLI 覆盖不会改写它。
- 现有 `claude`/`codex`/`copilot`/`grok` 的 `launch-command` 分支。
- 终端后端、handoff 协议、role prompt。

## 错误处理与边界

- **未安装 Kimi / 未识别后端**：若覆盖为 kimi 但 `command -v kimi` 失败，启动前报错；若 `swarmforge.conf` 里写了白名单外的 agent，解析时报 `Unsupported agent`。
- **CLI 参数被误识别为目录**：如存在名为 `kimi` 的目录，执行 `./swarm kimi` 会被识别为 agent。文档中说明 workaround。
- **agent 名与目录名冲突**：如存在名为 `kimi` 的目录，`./swarm kimi` 会被识别为 agent。文档中说明 workaround。
- **注入失败**：injector 以 detached `nohup` 方式运行，失败不会阻塞主启动流程；本设计不单独收集 injector 日志。

## 验证计划

1. **启动命令格式验证**：
   ```bash
   bb swarmforge/scripts/swarmforge.bb --test-launch-command kimi
   ```
   检查生成的 Kimi 启动命令包含 `--yolo` 和 `--add-dir`。

2. **配置解析验证**：
   ```bash
   bb swarmforge/scripts/swarmforge.bb --test-parse
   ```
   临时把 `swarmforge.conf` 中某 role 的 agent 改为 `kimi`，确认白名单通过。

3. **端到端验证**：
   - 确认本机已安装 `kimi`。
   - 执行 `./swarm kimi`。
   - 确认 4 个 tmux session 都启动了 Kimi TUI。
   - 确认 injector 把 `prompts/<role>.md` 内容注入为第一条消息。
   - 执行 `./swarm claude` 确认覆盖生效，所有 pane 回到 claude。
   - 执行 `./swarm` 无参数，确认仍按 `swarmforge.conf`（当前为 claude）启动。

4. **回归验证**：`./swarm` 无参数时现有 Claude 启动流程不被破坏。

## 非目标

- 不改写 `swarmforge.conf` 的持久化 agent 切换。
- 不支持 per-role 的 CLI agent 覆盖。
- 不抽象通用 agent adapter 层。
- 不修改 Kimi CLI 本身。
- 不处理 Kimi 的模型选择、provider 管理等额外能力（这些可通过 `swarmforge.conf` 的 `extra-args` 由用户自行配置）。

## 风险与回滚

- **injector 时序脆弱**：prompt 注入依赖固定延时，若 Kimi TUI 启动较慢，可能出现注入时机不对。可通过调整 delay 或按 index 递增缓解。
- **Kimi CLI 行为变化**：`--yolo`、`--add-dir` 等参数若在未来版本变更，需要同步调整。`extra-args` 机制已给用户留出自定义空间。
- **回滚方式**：改动集中在 `swarmforge/scripts/` 和 `./swarm` 不直接相关，可通过 `git checkout HEAD -- swarmforge/scripts/swarmforge.bb swarmforge/README.md` 回退，并删除新增的 `kimi-prompt-injector.sh`。
