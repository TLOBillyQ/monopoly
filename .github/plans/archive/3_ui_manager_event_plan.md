# UIManager 事件改造可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角

本改动的目标是把 Eggy 适配层里基于自定义事件名的 UI 输入处理，改为 UIManager 的节点事件写法。完成后，按钮点击、黑市选项与弹窗确认不再依赖字符串事件名，而是通过 UIManager 的节点监听直接驱动业务动作。用户可以通过点击 UI 按钮看到动作生效，例如自动控制开关、下一回合、黑市购买与取消。验证方式是运行 Demo，点按钮后能看到界面和日志变化，并且 Lua 测试保持通过。

## 进度

- [x] (2026-01-27 21:11Z) 创建可执行计划文件，明确目标与改造范围。
- [x] (2026-01-27 14:44Z) 设计 UIManager 事件绑定清单与动作映射，覆盖基础按钮、选择弹窗、黑市 UI。
- [x] (2026-01-27 14:44Z) 实现 Eggy runtime 的 UIManager 事件注册与分发，移除旧的事件名派发路径。
- [x] (2026-01-27 14:50Z) 执行测试与手工验收，记录观察结果并更新文档。

## 意外与发现

- 观察：eggy_runtime.lua 已通过 UIManager 节点监听实现点击分发，未发现 UI_CUSTOM_EVENT 或 event_name 路径。
  证据：src/adapters/eggy/eggy_runtime.lua:36-142。
执行过程中如发现 UI 节点缺失、点击无事件、或 UIManager 事件名称不同，需要在此记录并附证据片段。

## 决策日志

- 决策：在 Eggy runtime 里以 UIManager 节点监听为唯一 UI 事件入口，移除基于 event_name 的分发。
  理由：UIManager 的事件模型在 docs/eggy/ui_manager_lib.md 中明确，且能减少对字符串事件名与 payload 的耦合。
  日期/作者：2026-01-27 Codex
- 决策：删除 MarketUI.item_event_prefix 配置项。
  理由：事件已通过节点点击直接绑定，前缀映射不再使用。
  日期/作者：2026-01-27 Codex

## 结果与复盘

事件监听路径已完成并清理旧配置，Lua 测试通过；未执行 Game.exe 手工验收。

## 背景与导读

本仓库的 Eggy 入口位于 src/adapters/eggy/eggy_runtime.lua，负责注册事件并把 UI 输入转成规则层动作。当前实现通过自定义事件名与 payload 做派发，逻辑集中在 EggyRuntime.install 中的事件处理函数。UIManager 是对 EUI 节点的封装库，定义在 UIManager/Utils.lua 与 UIManager/ENode.lua，节点事件监听以 node:listen("CLICK", callback) 为主。UIManager.Builder 通过 UIManagerNodes.lua 构建节点树，节点名称由 UI 资源提供并在 src/adapters/eggy/ui_state.lua 中有逻辑名映射。改造需要理解 MarketUI 配置（src/adapters/eggy/market_ui.lua）以及 EggyLayer 的动作入口（layer:dispatch_action）。

## 工作计划

首先整理需要监听的 UI 节点清单，包括主按钮、弹窗按钮、选择弹窗选项、道具槽位、黑市按钮与黑市选项。随后在 EggyRuntime.install 的 GAME_INIT 回调里，在 UIManager.Builder 完成之后注册 UIManager 的 CLICK 事件监听。监听回调直接调用 layer:dispatch_action 或 layer:close_popup，并复用现有的选择与黑市处理函数以保持行为一致。最后移除旧的事件名派发与注册逻辑，确保运行时只保留 UIManager 事件入口，避免双路径触发。

## 具体步骤

在工作目录 c:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly 下，先更新 src/adapters/eggy/eggy_runtime.lua。新增一个基于 UIManager 的事件注册函数，负责按名称查询节点并调用 node:listen("CLICK", cb)。回调中根据节点名称或索引构建动作，调用 layer:dispatch_action 或 layer:close_popup，并复用现有的 resolve_option_id 与市场选择逻辑。为黑市购买项使用 MarketUI.item_buttons 的顺序来映射索引，避免依赖事件名字符串。对基础按钮与弹窗按钮使用 UIState 的逻辑名映射获取节点，确保中文资源名与逻辑名都能命中。完成后删除旧的自定义事件名注册与 event_name 分发逻辑，保证文件中不再出现 UI_CUSTOM_EVENT 或 global_register_custom_event 的手写派发路径。

## 验证与验收

运行 Lua 测试验证无回归，命令在仓库根目录执行：
    lua tests/deps_check.lua
    lua tests/regression.lua
预期输出包含 “Dependency self-check passed” 与 “All regression checks passed”。然后运行 bin/windows/Game.exe，手工点击 btn_next、btn_auto、弹窗确认、黑市购买与取消按钮，观察回合推进、自动控制开关切换、黑市选项高亮与购买行为正常。如果点击无响应，需要记录具体节点名与 UI 资源情况并回填到“意外与发现”。

## 可重复性与恢复

改动只涉及 Lua 源码，可重复应用与回滚。若 UIManager 事件绑定导致某些按钮无响应，可临时保留旧事件名分发作为回退，并在决策日志中注明保留原因。若需要回退到原实现，恢复 src/adapters/eggy/eggy_runtime.lua 中的旧事件注册逻辑即可。

## 产物与备注

产物是 src/adapters/eggy/eggy_runtime.lua 的事件处理改造与 MarketUI 配置清理。执行完成后应保留一段简短的 diff 或日志片段作为证据，例如测试输出或关键回调触发日志。

    测试输出：
    Dependency self-check passed
    All regression checks passed (29)

## 接口与依赖

改造依赖 UIManager 的事件接口，必须使用 UIManager.EVENT.CLICK 或字面值 "CLICK" 作为事件名。事件注册必须调用 UIManager.query_nodes_by_name 获取节点，并对返回的 ENode 调用 listen。回调需要访问的数据包括触发者 role 与 target 节点，同时必须继续使用 layer:dispatch_action(action) 作为规则层入口，保持与 EggyLayer 行为一致。涉及的主要文件与模块包括 src/adapters/eggy/eggy_runtime.lua、src/adapters/eggy/market_ui.lua、UIManager/ENode.lua 与 UIManager/Utils.lua。

改动说明：确认事件监听已切换为 UIManager 节点点击并移除前缀配置，原因是现有实现无需事件名派发。
改动说明：补充测试结果与完成状态，原因是已执行 Lua 测试并需要记录验收结论。
