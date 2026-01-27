# ECA 迁移与安装可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角

本改动的目标是把 eca.lua 从仓库根目录迁移到 Eggy 适配层中，并在适配层启动时统一安装。这样可以确保“事件转发与引擎侧桥接接口”属于适配层职责，避免在 init.lua 里散落硬编码入口。完成后，启动时仍能正常触发 UI 转发与载具转发事件，现有用法不变。验证方式是运行 Demo，确认 UIManager.forward_eca_event 与 VehicleManager.forward_eca_event_* 的调用仍能让引擎侧收到事件，同时 Lua 测试保持通过。

## 进度

- [x] (2026-01-27 21:26Z) 创建可执行计划文件，明确迁移目标与验证方式。
- [ ] (2026-01-27 21:26Z) 设计新的文件位置与安装入口，并确定 init.lua 的职责边界。
- [ ] (2026-01-27 21:26Z) 实施 eca.lua 迁移与启动安装改造，保持 API 行为一致。
- [ ] (2026-01-27 21:26Z) 执行测试与手工验收，记录观察结果并更新文档。

## 意外与发现

当前尚无意外与发现。执行过程中如发现引擎侧依赖 eca.lua 的加载顺序或全局变量约束，需要在此记录并附证据片段。

## 决策日志

- 决策：将 eca.lua 归入 Eggy 适配层，由 runtime 启动时安装。
  理由：该文件职责是转发事件与补齐引擎接口，属于平台适配层范围，集中入口更易维护。
  日期/作者：2026-01-27 Codex

## 结果与复盘

尚未实施，待完成后填写实际达成情况、残留问题与验证结果。

## 背景与导读

当前 eca.lua 位于仓库根目录，提供 UIManager.forward_eca_event 与 VehicleManager.forward_eca_event_* 等全局函数，依赖 macro.lua 中定义的 FORWARD_EVENT_* 常量。refs.lua 用于初始化 G.refs（资源键映射），同样位于仓库根目录，常在 init.lua 中加载。eca.lua 目前在 init.lua 中通过 require "eca" 被加载，同时 init.lua 负责场景索引与 UIManager.Builder 初始化，并在结尾驱动 move.lua 的演示逻辑。Eggy 运行入口在 src/adapters/eggy/eggy_runtime.lua，负责安装运行时逻辑。改造需要把 eca.lua 移入 src/adapters/eggy/，并由 EggyRuntime.install 负责加载，同时梳理 macro.lua、refs.lua、init.lua、move.lua 在启动链路中的位置，确保常量、资源映射与示例调用可用。

## 工作计划

先在 src/adapters/eggy 下为 eca.lua 选择新位置（例如 src/adapters/eggy/eca.lua），并确认其内部依赖（macro.lua、refs.lua、UIManager.Utils、LuaAPI、GameAPI）在运行时可用。然后修改 EggyRuntime.install，确保在 install_ui_manager 之前或之后加载 eca.lua，使 UIManager.forward_eca_event 与 VehicleManager.forward_eca_event_* 可用。随后更新 init.lua，移除对根目录 eca.lua 的直接 require，并改为只保留场景/资源初始化职责，同时确认 macro.lua 与 refs.lua 仍在合适的位置加载，move.lua 的示例调用路径不被打断。最后删除或清空根目录 eca.lua，避免双路径加载。

## 具体步骤

在工作目录 c:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly 下完成以下操作。先将 eca.lua 迁移到 src/adapters/eggy/eca.lua，保持函数与全局变量不变，只修正 require 路径（如需）与模块入口风格。再在 src/adapters/eggy/eggy_runtime.lua 的 install 过程中 require 新路径，确保启动时安装。最后更新 init.lua 去掉 require "eca"，避免重复加载与职责混杂，同时复核 macro.lua 与 refs.lua 的加载时机是否仍满足依赖关系，并检查 init.lua 里对 move.lua 的调用是否需要调整引用路径或时序。若 macro.lua 的常量依赖需要更早初始化，确保在引入 eca 之前已有 require "macro"，若 refs.lua 需要在 UI 初始化或场景索引前准备，也要保持原有加载顺序。

## 验证与验收

运行 Lua 测试验证无回归，命令在仓库根目录执行：
    lua tests/deps_check.lua
    lua tests/regression.lua
预期输出包含 “Dependency self-check passed” 与 “All regression checks passed”。然后运行 bin/windows/Game.exe，观察启动后执行 UIManager.forward_eca_event 的调用仍能让引擎侧收到转发事件（可通过已有日志或可视效果确认）。若载具事件相关逻辑启用，调用 VehicleManager.forward_eca_event_enter/exit/move/stop 仍应生效。

## 可重复性与恢复

迁移是可逆的。若出现加载顺序问题，可临时保留根目录 eca.lua 并在 init.lua 里继续 require，同时在决策日志里记录原因。需要回退时，恢复原始 eca.lua 位置并撤销 EggyRuntime.install 中的 require 即可。

## 产物与备注

产物包括新位置的 eca.lua、Eggy runtime 的加载入口调整，以及 init.lua 的依赖清理。执行完成后应保留简短的测试输出片段作为证据。

## 接口与依赖

eca.lua 中的函数签名必须保持不变，包括 get_vehicle_player/get_vehicle_move_direction/get_vehicle_move_time/get_spawn_vehicle_id/get_forward_ui_event 以及 UIManager.forward_eca_event、VehicleManager.forward_eca_event_*。依赖的全局常量 FORWARD_EVENT_* 仍由 macro.lua 提供；refs.lua 的资源映射初始化路径保持不变，只调整加载位置时需确保 G.refs 可用。init.lua 仍负责场景索引与演示入口，move.lua 的接口调用保持一致（例如 move.one_step）。EggyRuntime.install 必须负责加载该模块，并保证 UIManager 与 LuaAPI 可用。

改动说明：补充了 init.lua 与 move.lua 在迁移计划中的位置与依赖关系说明，原因是它们与启动链路和演示调用路径有关，必须在计划中明确。
