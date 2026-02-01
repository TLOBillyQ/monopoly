# Eggy 适配层扩展（移动/道具/选择界面）可执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角


本任务为 Eggy 适配层补齐“移动动画、道具（导弹/怪兽/路障）表现、选择界面”三类能力，并保持核心玩法与逻辑不变。完成后玩家能看到角色按格移动的连续动画，使用导弹/怪兽/路障时有对应的表现与棋盘状态同步，选择目标时能在棋盘上看到可选格并点击确认；所有行为仍由现有 gameplay 驱动，只是适配层负责呈现与交互。验收方式是：运行现有 Lua 测试通过，并在 Demo 中完成一次移动、一次路障放置、一次导弹/怪兽选择与释放，观察动画、选择与结果一致且可复现。

## 进度


- [x] (2026-01-29 09:10Z) 创建可执行计划并梳理 Eggy 适配层与 gameplay 的交互链路。
- [x] (2026-01-29 09:20Z) 查阅 Eggy API 点击事件与 Obstacle 触摸事件位置，确认可用于棋盘选择交互。
- [ ] (2026-01-29 09:30Z) 完成点击格子的原型验证与清理，明确可行的选择交互方式。（废弃）
- [ ] (2026-01-29 09:40Z) 实现 move_anim 按 visited 逐步播放的动画链路并接入 EggyLayer。（废弃）
- [ ] (2026-01-29 09:50Z) 实现道具表现与路障渲染、选择界面流程并完成验证与复盘。（废弃）
- [x] (2026-01-30 15:36) 按用户指示废弃本计划并归档

## 意外与发现


当前 UI 只有 `choice_option1~4` 四个按钮，但道具目标选择可能超过 4 个选项，必须引入棋盘选择或滚动列表；EggyAPI 提供 `EVENT.SPEC_OBSTACLE_TOUCH_BEGIN` 事件，可用于监听棋盘单位点击。证据来自 `.github/docs/eggy/EggyAPI.lua` 与 `.github/docs/eggy/api/09_events.md` 中的事件说明。

## 决策日志


决策：按用户指示废弃本计划，不再继续实现。理由：用户明确要求终止计划。日期/作者：2026-01-30 / Codex。

决策：选择界面优先走“棋盘格子可点击 + 目标标记”的方案，并把选择状态与标记渲染归入 `eggy_layer_board.lua`。理由：目标选择与棋盘渲染天然耦合，可复用已有的 tile 缓存与单位坐标，符合单一职责且减少新增抽象。日期/作者：2026-01-29 / Codex。

决策：移动动画扩展仍放在 `src/adapters/eggy/move_anim.lua` 内，通过新增“按路径播放”的函数实现，不新建独立模块。理由：移动动画已集中在该文件，新建模块会违反“无默认抽象”。日期/作者：2026-01-29 / Codex。

## 结果与复盘


计划按用户指示废弃，未继续实现移动动画、道具表现与选择界面。已保留现状，无新增代码。

## 背景与导读


Eggy 适配层入口是 `src/adapters/eggy/eggy_runtime.lua`，主适配层是 `src/adapters/eggy/eggy_layer.lua`，UI 刷新与棋盘渲染分别在 `src/adapters/eggy/eggy_layer_ui.lua` 与 `src/adapters/eggy/eggy_layer_board.lua`。移动动画当前只实现 `src/adapters/eggy/move_anim.lua` 的单步移动，动作动画提示在 `src/adapters/eggy/action_anim.lua`。游戏侧移动路径和道具行为由 `src/gameplay/movement_service.lua`、`src/gameplay/turn_move.lua`、`src/gameplay/item_roadblock.lua`、`src/gameplay/item_demolish.lua` 等模块生成，并通过 `store.turn.move_anim` 与 `store.turn.action_anim` 传给适配层。选择需求的交互入口是 `src/adapters/core/adapter_layer.lua` 的 pending choice 逻辑，UI 节点清单在 `Data/UIManagerNodes.lua`。棋盘点击能力需参考 `.github/docs/eggy/EggyAPI.lua` 与 `.github/docs/eggy/api/09_events.md` 中的 Obstacle 点击事件。

## 工作计划


先做一个最小原型确认“棋盘格点击事件能从 tile 单位触发”，并验证能否映射到棋盘格索引；该原型只输出日志与提示，确认可行后立即清理或收敛到最终实现。接着在 `move_anim.lua` 增加“按 visited 路径播放”的能力，并在 `EggyLayer` 的 move_anim 处理里改为优先使用 visited 列表，确保角色按每一格移动，动画总时长可用于等待回调。然后扩展 `eggy_layer_board.lua`，加入路障覆盖物的渲染与清理、目标选择标记的生成/销毁、以及基于点击事件的选择提交；`eggy_layer.lua` 负责在 pending choice 为 `roadblock_target` 或 `demolish_target` 时切换到棋盘选择模式，并把选择结果映射为 `choice_select`。动作动画的可见效果由 `action_anim.lua` 保持时长与提示，必要时在 `eggy_layer_board.lua` 中补充导弹/怪兽的棋盘表现并返回更准确的持续时间；通过表驱动的 kind 映射，让新增道具仅需新增条目即可扩展，保持开闭原则。

## 具体步骤


在仓库根目录执行以下定位命令，确认当前的移动动画入口、动作动画入口与选择类型，输出应能定位到对应文件与函数：

    rg -n "move_anim" src/adapters/eggy src/gameplay
    rg -n "action_anim" src/adapters/eggy src/gameplay
    rg -n "roadblock_target|demolish_target" src/gameplay
    rg -n "SPEC_OBSTACLE_TOUCH" .github/docs/eggy

原型阶段在 `src/adapters/eggy/eggy_runtime.lua` 中为 `G.tiles` 注册 Obstacle 点击事件，点击时打印 tile 名称或索引并弹出提示；启动 Demo，点击棋盘格子应看到提示，证明可用后清理或收敛到最终实现。原型验证通过后，先在 `src/adapters/eggy/move_anim.lua` 增加按路径播放函数并更新 `src/adapters/eggy/eggy_layer.lua` 的 move_anim 调用路径；随后在 `src/adapters/eggy/eggy_layer_board.lua` 增加路障渲染缓存并根据 overlays 创建或销毁覆盖物，同时提供选择标记的生成与销毁；再在 `src/adapters/eggy/eggy_layer.lua` 中识别 `roadblock_target` 与 `demolish_target` 的 pending choice，进入棋盘选择模式并通过 `choice_select` 或 `choice_cancel` 收敛状态；最后在 `src/adapters/eggy/eggy_runtime.lua` 注册棋盘点击事件把 tile index 传给 `EggyLayer`，并按需复用 `modal_choice` 的标题与取消按钮。完成代码后同步 `.github/docs/adapters_design.md` 的 Eggy 章节。

实现完成后执行测试：

    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

预期输出应包含：

    Dependency self-check passed
    All regression checks passed

## 验证与验收


必须通过 `lua .github/tests/deps_check.lua` 与 `lua .github/tests/regression.lua`。手工验收时启动 Demo，完成以下场景：掷骰移动时角色逐格移动、移动结束位置与逻辑一致；使用路障道具时棋盘出现路障标记并阻挡下一名玩家；使用导弹/怪兽时出现相应表现并且建筑/角色状态变化与日志一致；选择目标时可看到被标记的格子并可点击选择或取消，且选择结果与 gameplay 中的选项一致。若出现无法点击、标记残留或动画错位，记录触发步骤与相关日志。

## 可重复性与恢复


移动动画与选择标记的实现应是纯运行时渲染，不修改存档数据，可重复执行而不改变结果。若原型代码引入临时日志或标记，必须在正式实现前删除。若需要回退，可撤销对 `src/adapters/eggy/` 与 `.github/docs/adapters_design.md` 的改动并重新运行测试验证基线。

## 产物与备注


产物包括：`src/adapters/eggy/move_anim.lua` 的路径播放能力、`src/adapters/eggy/eggy_layer.lua` 的选择模式分支、`src/adapters/eggy/eggy_layer_board.lua` 的路障与选择渲染、`src/adapters/eggy/eggy_runtime.lua` 的棋盘点击桥接，以及 `.github/docs/adapters_design.md` 的说明。为便于复核，可在实现完成后保留一段小型 diff 片段，例如：

    -- EggyLayer move_anim 接入 visited
    if anim.visited then
      return MoveAnim.play_path(anim.player_id, anim.visited, anim)
    end

## 接口与依赖


新增或调整的接口建议保持以下形态，避免额外抽象层并满足 SOLID 的单一职责：`src/adapters/eggy/move_anim.lua` 提供 `play_path(player_id, visited, anim)` 与原有 `one_step`；`src/adapters/eggy/eggy_layer_board.lua` 提供 `refresh_overlays(layer, view)`、`open_tile_selection(layer, choice)`、`close_tile_selection(layer)`、`handle_tile_click(layer, tile_index)`、`play_action_effect(layer, anim)`；`src/adapters/eggy/eggy_layer.lua` 在 `_open_choice_modal` 处调用选择模式，并在 `dispatch_action` 或新建的 `handle_tile_click` 中派发 `choice_select`。依赖仍限于现有模块与 Eggy API（`LuaAPI.unit_register_trigger_event`、`EVENT.SPEC_OBSTACLE_TOUCH_BEGIN`），不引入第三方库。

改动说明：创建本计划，明确移动动画、道具表现与选择界面的架构目标、验证路径与接口草案，便于后续实现按 SOLID 拆分职责。

变更说明：按用户指示废弃计划并补记进度与结果。
