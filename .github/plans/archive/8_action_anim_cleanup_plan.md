# 动作表现去 UI 化与回调式动画计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md。

## 目的 / 全局视角


本任务把骰子 roll、路障、地雷、导弹、怪兽、清障机器人等行为从 UI 面板/弹窗中移除，改为像楼房升级那样在场景中生成表现，并像移动动画一样在表现结束后回调推进回合。完成后，基础屏不再出现 `panel_current_dice` 文本，使用上述道具不会再弹出 UI 弹窗；回合在播放对应动画期间会停在 `wait_action_anim`，动画结束后继续推进。验收时可在 Eggy 运行中触发这些行为，观察 UI 不显示这些信息、场景中有对应动画、且回合只在动画完成后继续。

## 进度


- [x] (2026-01-28 15:00Z) 创建计划初版，补齐范围、接入点与验收口径。
- [x] (2026-01-28 15:40Z) 完成 `action_anim` 通路代码接入（`composition_root`/`game`/`turn_manager`/`adapter_layer`/`eggy_layer`）。
- [x] (2026-01-28 15:40Z) 完成骰子 UI 移除与文档/审计清单同步（`ui_panel`/`eggy_layer_ui`/`.github/docs/ui`/`.github/tests/ui_nodes_audit`）。
- [x] (2026-01-28 15:40Z) 完成路障/地雷/怪兽/导弹/清障逻辑写入 `action_anim` 并移除 `push_popup`。
- [x] (2026-01-28 16:10Z) 已运行 `lua .github/tests/ui_nodes_audit.lua`、`lua .github/tests/deps_check.lua`、`lua .github/tests/regression.lua` 并通过。
- [x] (2026-01-28 16:30Z) 动作动画原型改为 `GlobalAPI.show_tips`，用于先跑通回调流程。
- [x] (2026-01-28 18:45Z) 部分完成：`Data/UIManagerNodes.lua` 已不含 `panel_current_dice`；剩余：Eggitor 侧确认资源、手工验收与截图。

## 意外与发现


- 观察：动作动画原型当前用 `GlobalAPI.show_tips` 占位，暂不依赖 Prefab。
  证据：`src/adapters/eggy/action_anim.lua` 只调用 `GlobalAPI.show_tips`。
- 观察：当前 `Data/UIManagerNodes.lua` 已不包含 `panel_current_dice`。
  证据：`rg -n "panel_current_dice" Data/UIManagerNodes.lua` 无输出。

## 决策日志


决策：新增统一的 `action_anim` 等待通路（存入 `turn.action_anim`，由 `wait_action_anim` 阶段等待 `action_anim_done`），复用移动动画的“延时回调”模式。
理由：与现有 `move_anim` 机制一致，最少改动即可实现“动画结束后回调推进”。
日期/作者：2026-01-28 / Codex

决策：骰子 roll 与指定道具不再通过 UI 文本/弹窗展示，改为场景动画 + 日志文本保留。
理由：符合“界面删除”的要求，同时保留可追溯日志。
日期/作者：2026-01-28 / Codex

决策：动画表现使用 Eggitor 导出的 Prefab group（类似楼房升级），并在 Eggy 适配层统一驱动播放与回收。
理由：与现有楼房升级效果一致，资产来源清晰，便于在 Eggitor 侧维护。
日期/作者：2026-01-28 / Codex

决策：在 `Game` 增加 `queue_action_anim`，统一生成 `action_anim_seq` 并写入 store。
理由：让规则层与适配层都能复用同一写入入口，避免重复写 seq 的逻辑。
日期/作者：2026-01-28 / Codex

决策：只有 `game.ui_port.wait_action_anim` 为真时才写入动作动画。
理由：兼容无 UI 的回合推进，避免 headless 或测试环境卡在等待阶段。
日期/作者：2026-01-28 / Codex

决策：先用 `GlobalAPI.show_tips` 实现动作动画原型，后续再接入 Prefab 动画。
理由：先验证回调链路与 UI 去除效果，降低接入成本。
日期/作者：2026-01-28 / Codex

## 结果与复盘


已完成代码改动、文档清理与自动化测试，动作动画原型使用 `GlobalAPI.show_tips`，UI 侧删除与导出仍需手工验收与截图。

## 背景与导读


回合推进由 `src/gameplay/turn_manager.lua` 驱动，当前只支持 `wait_choice` 与 `wait_move_anim` 等待状态；移动动画在 `src/gameplay/turn_move.lua` 里写入 `turn.move_anim`，`AdapterLayer.step_move_anim` 在 Eggy Tick 内派发 `move_anim_done` 回调。道具使用在 `src/gameplay/item_executor.lua`、`src/gameplay/choice_handlers/item_choice_handler.lua`、`src/gameplay/item_post_effects.lua` 与 `src/gameplay/item_demolish.lua` 中完成，部分行为通过 `IntentDispatcher` 触发 `push_popup` 弹窗。骰子 roll 的 UI 文本由 `src/adapters/core/ui_panel.lua` 生成并在 `src/adapters/eggy/eggy_layer_ui.lua` 中写入 `panel_current_dice`。楼房升级效果是规则层调用 `ui_port:on_tile_upgraded`，适配层在 `src/adapters/eggy/building_effects.lua` 中用 `Data.Prefab` 生成组单位。新方案将参照楼房升级：以场景单位呈现，并通过新增的 `action_anim` 等待通路在动画完成后回调推进回合。

## 里程碑


里程碑一：建立 `action_anim` 等待通路。完成后，回合可以在 `wait_action_anim` 阶段暂停，Eggy Tick 能触发动画并在完成后回调 `action_anim_done`，用最小的示例（例如骰子 roll）验证通路可用。

里程碑二：把骰子 roll、路障、地雷、导弹、怪兽、清障机器人迁移到场景动画。完成后，UI 不再显示这些行为相关文本或弹窗，场景中能看到相应动画，回合会在动画结束后继续。

## 工作计划


先在规则层和回合流里增加统一的动作动画等待通路：在 `CompositionRoot` 的初始状态里加入 `turn.action_anim_seq` 与 `turn.action_anim`，在 `TurnManager` 增加 `wait_action_anim` 状态并识别 `action_anim_done` 回调，逻辑结构与 `wait_move_anim` 对齐；在 `AdapterLayer` 增加 `step_action_anim`，以 `turn.phase == "wait_action_anim"` 作为判据，仅在 `action_anim.seq` 变化时触发一次动画回调并派发 `action_anim_done`。Eggy 侧在 `EggyLayer:tick` 调用新步骤，并在适配层实现 `on_action_anim` 分发到具体动画播放函数。

随后改骰子 roll：在 `src/gameplay/turn_roll.lua` 里计算出 `rolls/total` 后，如果 `game.ui_port` 标记支持 `wait_action_anim`，写入 `turn.action_anim`（kind=roll，包含玩家与点数信息），返回 `wait_action_anim` 并保留 `resume_state` 与 `resume_args`；同时删除 `ui_panel.lua` 里 `dice_text` 的构建与 `eggy_layer_ui.lua` 里对 `panel_current_dice` 的写入，更新 `.github/docs/ui/02_base_screen.md`、`.github/docs/ui/01_canvas_inventory.md`、`.github/docs/ui/ui_naming_list.md` 与 `.github/tests/ui_nodes_audit.lua` 去除该节点。

再处理道具：在 `item_roadblock.lua`、`item_post_effects.lua`（地雷、清障机器人）与 `item_demolish.lua`（怪兽/导弹）中，在逻辑效果已生效后构造 `action_anim` 数据（包含 player_id、目标 tile_index、清障清单等），并移除 `push_popup` 弹窗 intent，仅保留日志文本。为使人类玩家使用道具也进入等待，调整 `TurnManager` 的 `wait_choice`：当选择完成且 `turn.action_anim` 已写入时，改为返回 `wait_action_anim` 而不是直接恢复原阶段。AI 使用道具的路径仍会写入 `action_anim`，并通过 `ItemPhase.run` 返回 `wait_action_anim` 标识，让调用者在 `turn_start/turn_roll/turn_post` 中优先进入等待阶段。

在 Eggy 侧新增或扩展动画播放模块，例如 `src/adapters/eggy/action_anim.lua`，根据 `kind` 选择 Prefab 组并在对应 tile 或玩家位置生成场景单位，返回动画时长用于回调延迟；生成的临时单位在动画结束后销毁。Prefabs 通过 Eggitor 配置并导出到 `Data/Prefab.lua`（例如 `dice_roll`、`roadblock_place`、`mine_place`、`missile_hit`、`monster_hit`、`clear_robot`），播放位置优先使用 `G.tiles` 或 `layer.tile_positions`。

最后补齐文档与资源更新：UI 节点移除后在 Eggitor 中删除 `panel_current_dice` 并重新导出 `Data/UIManagerNodes.lua`；新增动画 Prefab 后重新导出 `Data/Prefab.lua`；更新 `.github/docs/adapters_design.md` 描述 `action_anim` 通路与新增动画模块，确保新手能理解与复现。

## 具体步骤


在仓库根目录先定位涉及骰子与道具展示的代码和文档：

    rg -n "panel_current_dice|dice_text|push_popup|roadblock|mine|missile|monster|clear_obstacles" src .github/docs .github/tests Data -S

按工作计划新增 `action_anim` 通路，并在 `turn_manager.lua` 与 `adapter_layer.lua` 中对齐 `wait_move_anim` 的结构；在 `turn_roll.lua` 写入 roll 的 action_anim，并同步移除 UI 面板的骰子字段。修改道具效果文件，让 roadblock、mine、missile、monster、clear_obstacles 在效果落地后写入 `turn.action_anim`，并移除对应的 `push_popup`。在 `TurnManager.wait_choice` 与 `ItemPhase.run` 中插入“检测 action_anim 并进入 wait_action_anim”的分支，避免选择完成后直接跳过动画。

在 Eggitor 中删除 `panel_current_dice` 并导出 `Data/UIManagerNodes.lua`。动作动画目前用 `GlobalAPI.show_tips` 占位，待后续需要时再补 Prefab 组。

已执行测试（仓库根目录）：

    lua .github/tests/ui_nodes_audit.lua
    [ui-audit] ok: all required nodes/events are present (directly or via mapping)

    lua .github/tests/deps_check.lua
    Dependency self-check passed

    lua .github/tests/regression.lua
    ..............................
    All regression checks passed (30)

## 验证与验收


自动化验证：在仓库根目录执行 `lua .github/tests/ui_nodes_audit.lua`，确认 UI 节点清单不再包含 `panel_current_dice` 且审计通过；然后执行 `lua .github/tests/deps_check.lua` 与 `lua .github/tests/regression.lua`，预期全部通过。

手工验收：启动 Eggy 运行入口（Eggitor 打开仓库根目录，入口为 `main.lua`），触发骰子 roll 与路障/地雷/导弹/怪兽/清障机器人使用，确认 UI 不显示这些提示或弹窗；`GlobalAPI.show_tips` 有短暂提示且回合在提示结束后继续推进，逻辑结果生效（路障/地雷存在或被清除，导弹/怪兽破坏生效）。

## 可重复性与恢复


代码改动仅涉及 Lua 与文档，重复执行不会引入数据迁移。UI 与 Prefab 资源改动需要在 Eggitor 中完成，可在导出前备份现有 UI 与 Prefab 资源；若需要回退，恢复 `Data/UIManagerNodes.lua` 与 `Data/Prefab.lua` 并撤销代码中 `action_anim` 相关改动即可。

## 产物与备注


预计修改文件覆盖：`src/gameplay/turn_manager.lua`、`src/gameplay/turn_roll.lua`、`src/gameplay/item_post_effects.lua`、`src/gameplay/item_demolish.lua`、`src/gameplay/item_roadblock.lua`、`src/gameplay/item_phase.lua`、`src/adapters/core/adapter_layer.lua`、`src/adapters/eggy/eggy_layer.lua`、`src/adapters/eggy/eggy_layer_ui.lua`、`src/adapters/eggy/action_anim.lua`、`src/adapters/core/ui_panel.lua`、`.github/tests/ui_nodes_audit.lua`、`.github/docs/ui/02_base_screen.md`、`.github/docs/ui/01_canvas_inventory.md`、`.github/docs/ui/ui_naming_list.md`、`.github/docs/adapters_design.md`，以及 Eggitor 导出的 `Data/UIManagerNodes.lua`。产物中应包含新的 `turn.action_anim` 数据结构与动作动画原型逻辑。

## 接口与依赖


新增或扩展的关键接口与状态如下，需保持命名稳定：

    -- store.turn 新增字段
    action_anim_seq: integer
    action_anim: {
      seq: integer,
      kind: "roll" | "roadblock" | "mine" | "missile" | "monster" | "clear_obstacles",
      player_id: integer,
      tile_index?: integer,
      rolls?: integer[],
      total?: integer,
      cleared_indices?: integer[],
      item_id?: integer
    }

    -- TurnManager 额外等待状态
    wait_action_anim(args) -> "wait_action_anim" | args.resume_state

    -- AdapterLayer 新增动画步骤
    AdapterLayer.step_action_anim(layer, { on_action_anim = function(layer, anim) return duration_seconds end })

    -- Eggy Layer 新增动画分发
    EggyLayer.on_action_anim(anim)  -- 在 Eggy 层内部调用 action_anim 模块

    -- Game dispatch 动作
    { type = "action_anim_done", seq = anim.seq }

以上接口需与现有 `move_anim` 的使用方式保持一致，并在 `.github/docs/adapters_design.md` 中同步说明。

本次更新：补齐 `action_anim` 通路与道具动画触发、移除骰子 UI 文本、同步文档与审计清单，并记录仍需 Eggitor 导出的资源与手工验收项。

本次更新：记录测试执行结果并更新进度，方便后续对照 Eggitor 导出与手工验收状态。

本次更新：动作动画原型改用 `GlobalAPI.show_tips`，移除 Prefab 命名对照并同步文档。
本次更新：补充 `panel_current_dice` 的当前状态，明确仍需 Eggitor 侧确认与手工验收。

改动说明：同步 UI 资源现状与待办，避免后续误判未完成事项。
