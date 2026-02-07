# 载具管理器实现计划


本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。本文件遵循 `.agents/PLANS.md`。

## 目的 / 全局视角


新增载具管理器，使用 RuntimeECA 接口与 ECA 自定义事件生成载具；玩家进入载具后不隐藏玩家模型，移动动画与棋盘同步由载具单位承担；退出载具时不手动销毁载具，仅清理 Lua 引用等待引擎自动销毁并恢复玩家移动动画。Prefab 按载具 ID 字符串查找，缺失回退到 `4012`，并将 `RuntimeECA.get_spawn_vehicle_id()` 默认值同步为 `4012`。可见结果是进入载具会生成对应模型，回合移动时载具移动，退出载具后玩家恢复原移动表现。

## 进度


- [x] (2026-02-07 04:47Z) 清空旧 `PLAN_CURRENT.md` 并改为载具管理器任务。
- [x] (2026-02-07 04:47Z) 新增 `src/ui/VehicleManager.lua` 并完成 ECA 事件处理、载具生成与状态维护。
- [x] (2026-02-07 04:47Z) 修改 `src/ui/UIEventHandlers.lua` 安装载具管理器。
- [x] (2026-02-07 04:47Z) 修改 `src/ui/MoveAnim.lua` 优先驱动载具单位移动。
- [x] (2026-02-07 04:47Z) 修改 `src/ui/BoardView.lua` 载具位置同步与清理无效载具引用。
- [x] (2026-02-07 04:47Z) 修改 `src/core/RuntimeECA.lua` 默认载具 ID 为 `4012`。
- [x] (2026-02-07 04:47Z) 运行 `lua .agents/tests/all.lua` 并记录结果。

## 意外与发现


暂无。

## 决策日志


- 决策：不隐藏玩家模型，不手动销毁载具。
  理由：用户明确要求 enter 后绑定载具，exit 自动销毁。
  日期/作者：2026-02-07 / Codex。
- 决策：移动动画优先驱动载具单位。
  理由：用户要求“使用载具移动”。
  日期/作者：2026-02-07 / Codex。
- 决策：Prefab 按载具 ID 查找，缺失回退 `4012`，并同步 RuntimeECA 默认值。
  理由：用户已更新 Prefab 结构并指定缺省。
  日期/作者：2026-02-07 / Codex。

## 结果与复盘


已完成载具管理器与相关改动，并完成全量测试。测试通过后功能已具备验收条件。

## 背景与导读


与本任务相关的主要文件：

- `src/ui/VehicleManager.lua`：新增载具管理器，负责 ECA 事件处理与载具单位引用。
- `src/ui/MoveAnim.lua`：移动动画执行入口，需优先驱动载具单位。
- `src/ui/BoardView.lua`：棋盘刷新与位置同步，需在有载具时同步载具位置。
- `src/ui/UIEventHandlers.lua`：UI 事件安装入口，需注册载具管理器。
- `src/core/RuntimeECA.lua`：RuntimeECA 接口默认值调整。
- `Data/Prefab.lua`：载具 ID 到 Prefab 的映射。

## 工作计划


先新增载具管理器模块，按 ECA 事件生成载具并维护玩家到载具的引用，不做销毁与隐藏。然后在 UI 事件安装时注册载具管理器。再调整移动动画与棋盘刷新：移动动画优先驱动载具单位，棋盘刷新在载具存在时更新载具位置并跳过玩家单位移动。最后调整 RuntimeECA 默认载具 ID 与测试验证。

## 具体步骤


在仓库根目录执行：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .agents/tests/all.lua

预期输出包含 `All tests passed`。若失败，按输出定位并修复，再重复运行。

## 验证与验收


必须满足以下行为：

进入载具后，载具模型生成且玩家模型仍显示；回合移动时载具移动；退出载具后载具自动销毁，玩家恢复原移动动画。自动测试需通过 `lua .agents/tests/all.lua`。

## 可重复性与恢复


本次改动可重复执行；若载具 Prefab 缺失会回退 `4012` 并提示，不影响其它流程。若需要回退，撤销 `src/ui/VehicleManager.lua` 与相关改动即可恢复原行为。

## 产物与备注


新增与修改的文件如下：

- `src/ui/VehicleManager.lua`
- `src/ui/UIEventHandlers.lua`
- `src/ui/MoveAnim.lua`
- `src/ui/BoardView.lua`
- `src/core/RuntimeECA.lua`

测试证据：

    All regression checks passed (36)
    Contract intent_dispatcher passed
    Contract turn_choice_protocol passed
    Contract ui_router_resilience passed
    Contract bankruptcy_idempotent passed
    Contract board_determinism passed
    Contract runtime_context_boot passed
    All tests passed

## 接口与依赖


新增接口：`src/ui/VehicleManager.lua` 提供 `install`、`sync_vehicle`、`prune_missing`。依赖 RuntimeECA 导出的 `get_vehicle_player`、`get_spawn_vehicle_id`、`get_vehicle_move_direction`、`get_vehicle_move_time`，以及 `Config/RuntimeConstants.lua` 中的 `eca_event.vehicle.*` 事件名。Prefab 依赖 `Data/Prefab.lua` 中载具 ID 字符串映射。

## 计划变更说明


2026-02-07 04:47Z 本次更新清空旧计划，改为载具管理器实现计划，原因是用户切换任务目标并要求直接落地该功能。
