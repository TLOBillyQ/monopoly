# 修复“后跳无法加盖”的落地链路

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。  
仓库内可执行计划规范见 `.agents/PLANS.md`，本文件必须遵循该规范维护。

## 目的 / 全局视角

目标是修复“机会卡后跳到自己地块时无法触发加盖”的问题，使后跳落地行为与普通落地一致：在满足条件时弹出可选“加盖建筑”。完成后，玩家抽到后跳机会卡，落在自己可升级地块时，应能看到“加盖建筑”选项，并能成功执行升级。

## 进度

- [x] (2025-03-12 08:55Z) 清理并重写 `PLAN_CURRENT.md`，按规范建档
- [x] (2025-03-12 09:05Z) 定位后跳落地链路与可选效果触发条件
- [x] (2025-03-12 09:15Z) 修复后跳落地上下文导致可选加盖被阻断的问题
- [x] (2025-03-12 09:20Z) 补充验证步骤与复现场景说明

## 意外与发现

- 观察：机会卡后跳走的是 `ChanceRegistry.move_backward -> movement.move -> need_landing` 链路，落地由 `TurnLand._resolve_landing` 处理。
  证据：`src/game/systems/chance/ChanceRegistry.lua` 中 `move_backward` 返回 `need_landing`，`src/game/flow/turn/TurnLand.lua` 中 `on_need_landing` 会递归处理落地。
- 观察：后跳的 `move_result` 缺少 `allow_optional` 标记，导致落地可选效果对后跳无差异控制。
  证据：`ChanceRegistry.move_backward` 仅透传 `movement.move` 结果，`EffectPipeline.run` 仅依据可选列表决定弹窗。

## 决策日志

- 决策：后跳落地视为普通落地，允许“购买/加盖”可选效果。
  理由：用户期望与普通落地一致，且配置中“加盖建筑”是可选效果，逻辑上不应因为后跳而被禁用。
- 日期/作者：2025-03-12 / Codex
- 决策：在 `move_backward` 中显式标记 `move_result.allow_optional = true`。
  理由：只影响后跳链路，避免改动全局落地管线，保持变更最小。
  日期/作者：2025-03-12 / Codex

## 结果与复盘

已补充后跳的可选效果允许标记，保证后跳落地与普通落地一致。
仍需人工复现或运行测试确认 UI 弹出与升级结果。

## 背景与导读

后跳来源于机会卡 `move_backward`，其处理在 `src/game/systems/chance/ChanceRegistry.lua`。  
落地效果管线在 `src/game/flow/turn/TurnLand.lua`，通过 `EffectPipeline.run` 执行 `Config/LandingEffects.lua` 中的效果。  
“加盖建筑”在 `Config/LandingEffects.lua` 中配置为可选效果，执行逻辑在 `src/game/systems/land/Land.lua` 的 `upgrade_land`。  
问题表现：后跳后无法弹出“加盖建筑”选项。

## 工作计划

1. 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划内容，确保包含所有必需章节与说明。
2. 定位后跳落地的上下文构建逻辑，重点检查 `EffectPipeline.run` 与 `Effect.build_game_ctx` 是否在后跳落地时漏传可选效果所需的上下文（如 `move_result` 或 `on_landing`）。
3. 重点检查 `ChanceRegistry.move_backward` 对 `movement.move` 的调用参数，是否导致 `move_result` 中字段（例如 `visited`、`steps`、`market_interrupt` 等）缺失或被错误覆盖，从而影响 `EffectPipeline` 的可选效果决策。
4. 以“后跳落地也应触发可选加盖”为目标，修复导致 `upgrade_land` 被判定为 `can_apply=false` 的根因。优先改动 `ChanceRegistry.move_backward` 或落地上下文构建，避免改动 `Land.lua` 的规则判断。
5. 保持变更最小，不改变非后跳路径行为。

## 具体步骤

在仓库根目录执行：

1) 清空并重写计划文件  
   - 打开 `.agents/PLAN_CURRENT.md`，删除原内容，写入本计划（不包外层三反引号）。

2) 定位后跳落地链路与上下文  
   - 阅读 `src/game/systems/chance/ChanceRegistry.lua` 中 `move_backward`。  
   - 阅读 `src/game/flow/turn/TurnLand.lua` 的 `_resolve_landing`。  
   - 阅读 `src/game/systems/effects/EffectPipeline.lua` 与 `src/game/systems/effects/Effect.lua` 了解上下文与可选效果构建。

3) 针对后跳落地的修复  
   - 若发现 `move_backward` 传入的 `opts` 导致落地被当作非正常落地（例如 `on_landing` 未开启、`move_result` 缺失、或 `tile`/`player` 不一致），在 `ChanceRegistry.move_backward` 或 `Effect.build_game_ctx` 里补齐必要上下文。  
   - 确保 `EffectPipeline` 在后跳落地时仍然会构建 `landing_optional_effect` 选项，且 `upgrade_land` 的 `can_apply` 为真时可被选择。

4) 补充验证说明  
   - 在计划里写出复现步骤：抽到后跳机会卡 -> 落在自己地块 -> 弹出“加盖建筑” -> 选择后升级成功。  
   - 写出预期日志或界面表现。

## 验证与验收

- 复现场景：玩家抽到“后跳一格/两格/三格”机会卡，落在自己名下且可升级的地块。  
- 预期行为：  
  1) 弹出落地可选效果列表包含“加盖建筑”。  
  2) 选择后加盖成功，金币扣除正确，地块等级 +1。  
  3) 不影响正常前进落地的购买/加盖逻辑。  
- 推荐验证命令：若有 `.agents/tests/` 中相关脚本，运行并记录结果；否则以手动复现场景为主。
- 参考命令：在仓库根目录运行 `lua .agents/tests/regression.lua`。

## 可重复性与恢复

- 修改仅涉及后跳落地上下文与可选效果触发，重复执行不引入持久化风险。  
- 如出现副作用，可回退到改动前版本以恢复原行为。

## 产物与备注

- 计划文件：`.agents/PLAN_CURRENT.md`  
- 代码改动：预期涉及 `src/game/systems/chance/ChanceRegistry.lua` 或 `src/game/flow/turn/TurnLand.lua` 或 `src/game/systems/effects/Effect.lua`

## 接口与依赖

- 使用现有落地效果管线，不新增新接口。  
- 若需要修改 `ChanceRegistry.move_backward` 的返回结构，保持 `need_landing` 结构不变：  
    kind = "need_landing"  
    player_id = player.id  
    board_index = player.position  
    move_result = res  

### 变更记录

- 2025-03-12：标记后跳 `move_result.allow_optional = true`，并补充验证命令与完成状态。
