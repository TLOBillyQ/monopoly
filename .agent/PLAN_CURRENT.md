# ECA Helper 迁出与纯 Export 保持

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角

完成后，`src/runtime/ECA.lua` 仅保留 `@export` 函数，`vehicle_helper`、`camera_helper` 及 `forward_eca_event_*` 迁移到 `src/runtime/Globals.lua`，且运行行为不变。验收方式为运行回归脚本并确保游戏回合切换时相机跟随仍正常触发。

## 进度

- [x] (2026-02-03 17:41) 清空并重写 `PLAN_CURRENT.md`，切换到 ECA helper 迁移任务
- [x] (2026-02-03 17:42) 在 `src/runtime/Globals.lua` 中迁入 `vehicle_helper`、`camera_helper` 与 `forward_eca_event_*`
- [x] (2026-02-03 17:42) 在 `src/runtime/ECA.lua` 中删除 helper 定义，仅保留 `@export` 函数
- [x] (2026-02-03 17:42) 运行 `lua .agent/tests/regression.lua` 并确认无报错

## 意外与发现

暂无。

## 决策日志

- 决策：将 helper 迁移到 `src/runtime/Globals.lua`，并保持全局名称不变。
  理由：遵守“ECA 仅保留 export”目标，同时不影响现有调用点。
  日期/作者：2026-02-03 / Codex。

- 决策：保留 `src/runtime/ECA.lua` 顶部 `require "src.runtime.Macro"`。
  理由：保持 ECA 单独加载时对常量依赖的一致性。
  日期/作者：2026-02-03 / Codex。

## 结果与复盘

已完成 helper 迁移与 ECA 清理，回归脚本通过，目标达成。未发现额外风险点。

## 背景与导读

`src/runtime/ECA.lua` 当前同时包含 `@export` 接口与用于 ECA 事件转发的 helper 表。`src/runtime/Globals.lua` 是运行时全局初始化入口，负责注册全局函数与常量。`src/game/turn/GameplayLoop.lua` 通过全局 `camera_helper` 触发相机跟随事件，因此 helper 的全局名必须保持一致。

## 工作计划

先在 `Globals.lua` 中加入 helper 表与事件转发函数，确保依赖 `eca_event` 与 `TriggerCustomEvent` 的逻辑不变。随后清理 `ECA.lua` 中的 helper 定义，仅保留导出的查询函数。最后运行回归脚本验证无行为变化。

## 具体步骤

在仓库根目录执行以下修改与验证：

    1) 编辑 src/runtime/Globals.lua，加入 vehicle_helper、camera_helper 及 forward_eca_event_*。
    2) 编辑 src/runtime/ECA.lua，删除 helper 定义，仅保留 @export 函数。
    3) 运行 lua .agent/tests/regression.lua，确保脚本通过。

## 验证与验收

回归脚本应输出包含 `All regression checks passed`。手动验收时，回合切换触发的相机跟随仍能按当前玩家更新（依赖 `camera_helper.target_role_id` 与 `eca_event.camera.follow`）。

## 可重复性与恢复

本修改可重复执行。若需回退，恢复 `src/runtime/ECA.lua` 与 `src/runtime/Globals.lua` 到修改前版本即可。

## 产物与备注

产物为两个 Lua 文件的局部迁移，无新增文件与接口。回归输出示例：

    All regression checks passed (34)

## 接口与依赖

需要保持以下全局名称与调用方式不变：`vehicle_helper.forward_eca_event_*`、`camera_helper.target_role_id`、`get_vehicle_*`、`get_camera_target`。依赖 `eca_event`、`TriggerCustomEvent` 与 `GameAPI.get_role`，保持签名与默认值一致。

变更记录：2026-02-03 17:41 初始化本计划，原因是开始执行 ECA helper 迁移任务。
变更记录：2026-02-03 17:42 更新进度与验收记录，原因是完成迁移并通过回归脚本。
