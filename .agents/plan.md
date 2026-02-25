# 架构复杂度治理执行计划（精简版）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md`。输入依据：`.agents/research.md`（2026-02-25）。


## 目的 / 全局视角

本轮只做两件事：修复依赖规则检查可信度（P0），以及收敛 `GameplayLoop.tick` 职责（P1）。不重写架构，不变更功能语义。

用户可见结果是：

1. `dep_rules` 在 Windows/Linux 都能稳定运行，不再出现报错后仍显示通过。
2. `GameplayLoop.tick` 从“职责堆叠”变成“编排函数 + 私有步骤函数”，回归结果不退化。


## 进度

- [x] (2026-02-25 05:05Z) 复核 `research` 与当前代码现状。
- [x] (2026-02-25 05:33Z) 按标注收敛范围：本轮仅 P0/P1。
- [x] (2026-02-25 05:40Z) 里程碑 P0：完成 `dep_rules.lua` 跨平台与失败语义修复。
- [x] (2026-02-25 05:41Z) 里程碑 P1：完成 `GameplayLoop.tick` 私有步骤拆分，行为保持不变。
- [x] (2026-02-25 05:42Z) 验证：完成反向注入测试与全量回归。


## 意外与发现

- 观察：`dep_rules` 已消除 Windows 下 `[` 命令报错，正常路径仅输出 `dep_rules ok`。
  证据：

    lua tests/internal/dep_rules.lua
    dep_rules ok

- 观察：当前回归基线是 154，通过状态可用于增量重构验证。
  证据：

    lua tests/regression.lua
    All regression checks passed (154)
    dep_rules ok
    tick ok

- 观察：反向注入违规依赖时，`dep_rules` 会正确失败并报告具体文件与行号。
  证据：

    dep_rules violation: C:\Users\Lzx_8\Desktop\dev\monopoly\src\presentation\interaction\__dep_rules_probe.lua:1 contains src.game.
    local _ = require("src.game.flow.turn.TurnDispatch")


## 决策日志

- 决策：本轮只执行 P0/P1，P2/P3 延后。
  理由：先修验收门槛可信度，再做热点重构，回归风险最小。
  日期/作者：2026-02-25 / agent。

- 决策：保留 `TurnActionPort` 边界，不在本轮触碰 UI->game 依赖边界。
  理由：本轮目标是“可信度 + 可读性”，不是链路重构。
  日期/作者：2026-02-25 / agent。


## 结果与复盘

本轮已执行完成，P0/P1 均达成。`dep_rules` 跨平台噪音问题已修复，且通过注入测试验证“违规即失败”。`GameplayLoop.tick` 已重构为编排入口，横切职责下沉到私有步骤函数，回归结果保持 154。

剩余风险与后续建议：P2/P3（UI 链路减层与防反弹机制）仍未执行，建议作为下一轮独立计划推进。


## 背景与导读

`tests/internal/dep_rules.lua` 负责检查 `src/presentation/interaction` 中是否出现 `src.game.*` 依赖。当前实现依赖 Unix shell 命令，跨平台不可靠。

`src/game/flow/turn/GameplayLoop.lua` 中 `tick(game, state, dt)` 是每帧主协调函数，当前同时处理输入锁、自动执行、超时、动画、脏刷新和 debug 同步，职责集中。

本轮只改上述两个文件，目标是“测试可信 + 职责清晰”，行为保持一致。


## 工作计划

### 里程碑 P0：修复依赖规则检查可信度

在 `tests/internal/dep_rules.lua` 中移除 `ls` 与 `[ -d ]` 等平台相关调用，改为按操作系统分支的文件列表命令。扫描规则保持不变：只要 `interaction` 目录中的 Lua 文件包含 `src.game.` 前缀即失败。增加失败保护：文件列表为空、文件不可读、列表命令失败都直接退出非 0。

完成证明包含两条：正常路径通过；故障注入路径失败。

### 里程碑 P1：拆分 `GameplayLoop.tick` 职责（行为不变）

在 `src/game/flow/turn/GameplayLoop.lua` 中把 `tick` 的大块逻辑拆成私有函数，保留原调用顺序与条件分支。`tick` 最终只负责编排：前置同步 -> 自动执行 -> 超时处理 -> 阶段动画同步 -> dirty 刷新与 debug。

完成证明是回归保持 154，且 `tick` 主体明显缩短并具备可读职责边界。


## 具体步骤

工作目录：`c:\Users\Lzx_8\Desktop\dev\monopoly`

P0：

1. 修改 `tests/internal/dep_rules.lua`。
2. 运行：

    lua tests/internal/dep_rules.lua

3. 注入一条违规 require 做反向验证，预期脚本失败退出。
4. 清理注入文件，再次运行 `dep_rules`，恢复通过。

P1：

1. 修改 `src/game/flow/turn/GameplayLoop.lua`，拆分 `tick` 私有步骤函数。
2. 运行：

    lua tests/internal/gameplay_loop_no_ui.lua
    lua tests/regression.lua


## 验证与验收

必须同时满足：

1. `lua tests/internal/dep_rules.lua` 仅输出 `dep_rules ok`，不再出现 `[` 命令报错。
2. 注入违规依赖时，`dep_rules` 必须返回非 0 并打印 violation。
3. `lua tests/internal/gameplay_loop_no_ui.lua` 输出 `tick ok`。
4. `lua tests/regression.lua` 输出 `All regression checks passed (154)`。
5. `GameplayLoop.tick` 主体成为编排函数，职责下沉到私有步骤函数。


## 可重复性与恢复

每个里程碑独立可回滚。若 P0 或 P1 失败，只回退对应文件：

1. `tests/internal/dep_rules.lua`
2. `src/game/flow/turn/GameplayLoop.lua`

回归命令可重复执行，属于幂等验证步骤。


## 产物与备注

执行前基线：

    lua tests/internal/dep_rules.lua
    '[' is not recognized as an internal or external command,
    operable program or batch file.
    dep_rules ok

    lua tests/regression.lua
    All regression checks passed (154)
    dep_rules ok
    tick ok

执行后结果：

    lua tests/internal/dep_rules.lua
    dep_rules ok

    lua tests/internal/dep_rules.lua   (with injected probe)
    dep_rules violation: C:\Users\Lzx_8\Desktop\dev\monopoly\src\presentation\interaction\__dep_rules_probe.lua:1 contains src.game.
    local _ = require("src.game.flow.turn.TurnDispatch")

    lua tests/internal/gameplay_loop_no_ui.lua
    tick ok

    lua tests/regression.lua
    All regression checks passed (154)
    dep_rules ok
    tick ok


## 接口与依赖

本轮不新增依赖，不改公开接口。

1. `GameplayLoop` 仍导出 `tick/new_game/set_game`。
2. `dep_rules` 仍通过 `lua tests/internal/dep_rules.lua` 运行。
3. 依赖方向规则仍为：`src/presentation/interaction` 不允许引用 `src.game.*`。


## 本次更新说明

2026-02-25：按标注将计划精简为仅执行 P0/P1，并保留完整验收与回滚说明。P2/P3 不纳入本轮交付。

2026-02-25：已按精简计划执行到底并回填证据；P0/P1 完成，验证通过。
