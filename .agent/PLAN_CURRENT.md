# 参数精简与命名调整（内部函数）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角


这次改动只做内部函数的参数精简与不合理命名清理，保证行为和输出完全不变。完成后可以通过回归脚本与游戏烟测验证，外部调用不受影响。

## 进度


- [x] (2026-02-03 14:31) 已重写 `PLAN_CURRENT.md`，记录可执行计划
- [x] (2026-02-03 14:34) 调整内部函数签名并同步调用点
- [x] (2026-02-03 14:34) 运行 `lua .agent/tests/regression.lua` 回归验证
- [ ] (2026-02-03 14:31) 必要时进行一次游戏烟测验证

## 意外与发现


目前无意外与发现。

## 决策日志


决策：仅调整仓库内部函数与调用点，保持外部回调与 `vendor/` 不变。理由：避免破坏对接与第三方代码，保证兼容性。日期/作者：2026-02-03 / Codex。

## 结果与复盘


待完成后补充实现结果与回顾。

## 背景与导读


本次变更集中在内部函数的签名与调用，涉及的文件包括 `src/game/board/Board.lua`、`src/game/movement/MovementManager.lua`、`src/game/item/ItemRoadblock.lua`、`src/game/item/ItemPhase.lua`、`src/game/turn/GameplayLoop.lua`、`src/game/item/ItemInventory.lua`、`src/game/land/Landing.lua`、`src/ui/ActionAnim.lua`。这些文件承载棋盘移动、道具流程、回合推进与动作动画等逻辑，且当前存在未使用的参数或占位符形参。

## 工作计划


先清理 `Board.step_backward_by_facing` 的冗余参数，并在移动与道具模块中同步调整对应的调用。随后精简 `ItemPhase.is_enabled` 与 `GameplayLoop.step_turn` 的签名及调用。再处理 `ItemInventory.draw_random` 与 `draw_and_give` 的无用参数，并同步 `Landing` 中的调用。最后修正 `ActionAnim.play` 的占位符参数并更新 `GameplayLoop` 中的调用。所有修改都保持行为不变，只去掉无意义传参。

## 具体步骤


在仓库根目录依次编辑上述文件，严格按当前函数语义删除未使用参数并更新调用点。完成代码修改后，在 `c:\Users\Lzx_8\Desktop\dev\monopoly` 执行 `lua .agent/tests/regression.lua`。如需要烟测，在编辑器内启动游戏，观察回合推进、动作动画、路障与地雷移动流程无异常。

## 验证与验收


回归脚本需要全部通过，且输出包含 `All regression checks passed`。烟测需确认核心交互与动画流程无回归，并且没有 Lua 报错或断言失败。

## 可重复性与恢复


本次修改可重复执行且不会引入破坏性变更。如需回退，可将上述文件恢复到修改前版本。

## 产物与备注


预期回归输出示例（节选）：

  ....
  All regression checks passed (N)

## 接口与依赖


不新增依赖，不改变公共接口。内部函数签名的调整需要同步所有调用点，确保 Lua 调用参数一致。

变更记录：2026-02-03 14:31 新建并填充可执行计划，原因是进入实现阶段需完整记录步骤与验收方式。
变更记录：2026-02-03 14:34 更新进度并记录回归已通过，原因是代码修改与测试已完成。
