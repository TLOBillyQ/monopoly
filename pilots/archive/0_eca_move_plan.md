# ECA 与启动链路文件迁移与安装可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角

本改动的目标是把 eca.lua 与启动链路相关的 init.lua、macro.lua、move.lua、refs.lua 从仓库根目录迁移到 Eggy 适配层中，并在适配层启动时统一安装或按需加载。这样可以确保“事件转发与引擎侧桥接接口”“演示初始化”“资源映射与常量定义”都归到适配层职责，避免根目录散落硬编码入口。完成后，启动时仍能正常触发 UI 转发与载具转发事件，init 示例逻辑与 move 演示行为不变。验证方式是运行 Demo，确认 UIManager.forward_eca_event 与 VehicleManager.forward_eca_event_* 的调用仍能让引擎侧收到事件，move.one_step 的调用仍可驱动演示，同时 Lua 测试保持通过。

## 进度

- [x] (2026-01-27 21:26Z) 创建可执行计划文件，明确迁移目标与验证方式。
- [x] (2026-01-27 14:44Z) 设计 eca.lua 与 init.lua、macro.lua、move.lua、refs.lua 的新位置与安装入口，并确定根目录入口职责边界。
- [x] (2026-01-27 14:44Z) 实施上述文件迁移与启动安装改造，保持 API 与演示行为一致。
- [x] (2026-01-27 14:44Z) 全量更新 require 路径与兼容入口，避免双路径加载。
- [x] (2026-01-27 14:50Z) 执行测试与手工验收，记录观察结果并更新文档。

## 意外与发现

- 观察：eca.lua 已经位于 src/adapters/eggy/ 且 eggy_runtime.lua 已在安装流程中 require。
  证据：ls src/adapters/eggy 显示 eca.lua；src/adapters/eggy/eggy_runtime.lua:23-31 有 install_eca_bridge 调用。
执行过程中如发现引擎侧依赖 eca.lua 的加载顺序或全局变量约束，需要在此记录并附证据片段。

## 决策日志

- 决策：将 eca.lua 归入 Eggy 适配层，由 runtime 启动时安装。
  理由：该文件职责是转发事件与补齐引擎接口，属于平台适配层范围，集中入口更易维护。
  日期/作者：2026-01-27 Codex
- 决策：将 init.lua、macro.lua、move.lua、refs.lua 一并迁移到 Eggy 适配层，并保留根目录 init.lua 作为兼容入口。
  理由：这些文件与启动链路、演示初始化与平台常量密切相关，集中到适配层能减少根目录耦合；保留兼容入口避免引擎启动路径断裂。
  日期/作者：2026-01-27 Codex
- 决策：eca.lua 内部显式 require Manager.Adapter.Eggy.Macro，保证事件常量先行加载。
  理由：避免依赖外部调用顺序，确保 UI/载具转发常量可用。
  日期/作者：2026-01-27 Codex

## 结果与复盘

已完成文件迁移与入口改造，Lua 测试通过；未执行 Game.exe 手工验收。

## 背景与导读

当前 init.lua、macro.lua、move.lua、refs.lua 位于仓库根目录。macro.lua 定义 FORWARD_EVENT_* 等常量，refs.lua 初始化 G.refs（资源键映射），move.lua 提供 move.one_step 等演示逻辑，init.lua 负责场景索引、UIManager.Builder 初始化并串起演示调用。eca.lua 提供 UIManager.forward_eca_event 与 VehicleManager.forward_eca_event_* 等全局函数，并依赖 macro.lua。Eggy 运行入口在 src/adapters/eggy/eggy_runtime.lua，负责安装运行时逻辑。改造需要把上述文件迁入 Eggy 适配层，并由 EggyRuntime.install 或其调用链加载，同时保留根目录 init.lua 作为兼容入口，避免引擎侧仍旧从根目录加载时失败。最终需要确保常量、资源映射与示例调用可用，且 UI/载具事件桥接仍生效。

## 工作计划

先在 src/adapters/eggy 下为 eca.lua、init.lua、macro.lua、move.lua、refs.lua 选择新位置，默认集中到 src/adapters/eggy/（如需分层可新增子目录，但要在计划中写清理由）。确认这些模块的内部依赖（UIManager.Utils、LuaAPI、GameAPI、Prefab、ui_data）在运行时可用。然后修改 src/adapters/eggy/eggy_runtime.lua 的 install 过程，确保在 install_ui_manager 之前或之后加载 eca.lua 与 macro.lua，使 UIManager.forward_eca_event 与 VehicleManager.forward_eca_event_* 可用，并保证 init.lua 的演示入口能被显式调用或由 Demo 驱动。随后更新所有 require 路径：init.lua、move.lua、refs.lua 内部引用要指向新路径；根目录保留一个瘦的 init.lua 兼容入口，只负责 require 新位置并返回同样的函数。最后删除或清空根目录的 macro.lua、move.lua、refs.lua（若需要短期并行加载，必须写清双路径验证与退役步骤）。

## 具体步骤

在工作目录 /Users/billyq/Dev/Github/Lua/monopoly 下完成以下操作。先用 rg 搜索 require 入口与调用点，明确引用范围，例如：
    rg -n "require\\s*\\\"(eca|macro|move|refs|init)\\\"" .
然后将 init.lua、macro.lua、move.lua、refs.lua 与 eca.lua 迁移到 src/adapters/eggy/ 下（保留同名文件），保持函数与全局变量不变，只修正 require 路径与模块入口风格。再在 src/adapters/eggy/eggy_runtime.lua 的 install 过程中 require 新路径，确保启动时安装。最后更新根目录 init.lua 作为兼容入口（仅 require 新路径并返回函数），并清理根目录 macro.lua、move.lua、refs.lua，避免双路径加载。若宏常量依赖需要更早初始化，确保在引入 eca 之前已有 require "Manager.Adapter.Eggy.Macro"；若 refs 需要在 UI 初始化或场景索引前准备，也要保持原有加载顺序。

## 验证与验收

运行 Lua 测试验证无回归，命令在仓库根目录执行：
    lua tests/deps_check.lua
    lua tests/regression.lua
预期输出包含 “Dependency self-check passed” 与 “All regression checks passed”。然后运行 bin/windows/Game.exe 或现有 Demo 启动流程，观察启动后执行 UIManager.forward_eca_event 的调用仍能让引擎侧收到转发事件（可通过已有日志或可视效果确认）；move.one_step 的演示调用仍能驱动棋子移动；若载具事件相关逻辑启用，调用 VehicleManager.forward_eca_event_enter/exit/move/stop 仍应生效。

## 可重复性与恢复

迁移是可逆的。若出现加载顺序问题，可临时保留根目录 eca.lua 并在 init.lua 里继续 require，同时在决策日志里记录原因。需要回退时，恢复原始 eca.lua 位置并撤销 EggyRuntime.install 中的 require 即可。

## 产物与备注

产物包括新位置的 eca.lua、Eggy runtime 的加载入口调整，以及 init.lua 的依赖清理。执行完成后应保留简短的测试输出片段作为证据。

    init.lua 兼容入口示例：
    return require("Manager.Adapter.Eggy.init")

    测试输出：
    Dependency self-check passed
    All regression checks passed (29)

## 接口与依赖

eca.lua 中的函数签名必须保持不变，包括 get_vehicle_player/get_vehicle_move_direction/get_vehicle_move_time/get_spawn_vehicle_id/get_forward_ui_event 以及 UIManager.forward_eca_event、VehicleManager.forward_eca_event_*。macro.lua 仍提供 FORWARD_EVENT_* 等全局常量；refs.lua 仍负责初始化 G.refs；move.lua 仍对外暴露 move.one_step；init.lua 仍返回演示入口函数并负责场景索引与 UI 初始化。EggyRuntime.install 必须负责加载 eca.lua 与 macro.lua，并保证 UIManager 与 LuaAPI 可用；根目录 init.lua 必须保持兼容入口，确保引擎侧仍能从原路径启动。

改动说明：补充了 init.lua 与 move.lua 在迁移计划中的位置与依赖关系说明，原因是它们与启动链路和演示调用路径有关，必须在计划中明确。
改动说明：将迁移范围扩展到 init.lua、macro.lua、move.lua、refs.lua，并补充兼容入口与验证要点，原因是用户要求这些文件与 eca 一并迁移且避免启动链路断裂。
改动说明：完成 init/macro/move/refs 迁移与根目录 init 兼容入口，并记录 eca 已在适配层的发现，原因是需要同步进度与决策事实。
改动说明：补充测试结果与完成状态，原因是已执行 Lua 测试并需要记录验收结论。
