# UI Manager 覆盖测试计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本计划遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角


这项工作为 UIManager 的核心能力提供覆盖测试，保证节点构建、查询、属性绑定、事件、异步链式和计时器符合 `.github/docs/eggy/ui_manager_lib.md` 的描述。完成后，开发者可以通过自动化脚本看到明确的通过/失败结论，并在 Eggitor 里观察到 UI 显示与按钮交互正常，从而确认功能确实在工作。

## 进度


- [x] (2026-01-30 15:36) 梳理 UIManager 实现与文档对照点，记录必要差异（完成逐项对照并记录差异）
- [x] (2026-01-30 13:59) 编写并跑通 `.github/tests/ui_manager_test.lua`
- [x] (2026-01-30 15:36) 完成 Eggitor 手动测试并记录可观察结果（按用户指示视作通过）

## 意外与发现


- 观察：`Library/UIManager` 下未发现 `Promise.lua`，且 `ENode` 未提供 `wait/trigger`，文档中的 Promise 与链式/触发 API 无实现支撑。
  证据：`rg -n "Promise|wait|trigger" Library/UIManager` 仅命中注释与现有方法定义，未发现实现文件或 `ENode:wait/trigger`。
- 观察：文档中的 `UIManager.Builder(data, batch, interval)` 与 `UIManager.EVENTS.BUILDER_*` 在实现中不存在，Builder 仅支持一次性构建。
  证据：`Library/UIManager/Builder.lua` 仅定义 `Builder:init(_config_list)`；`Library/UIManager/Utils.lua` 仅有 `UIManager.EVENT.CLICK`。
- 观察：文档列出的 `UIManager.set_frame_out` 未在 UIManager 中提供，实际使用全局 `SetFrameOut`。
  证据：`rg -n "set_frame_out" Library/UIManager` 无输出；测试使用 `SetFrameOut`。
- 观察：`EInputField.text_color`、`EButton.normal_image/pressed_image` 在实现中缺失。
  证据：`Library/UIManager/EInputField.lua` 仅实现 `text`；`Library/UIManager/EButton.lua` 未实现 `normal_image/pressed_image` 相关 getter/setter。
- 观察：`.github/tests/ui_manager_test.lua` 在本次执行中仍通过。
  证据：`lua .github/tests/ui_manager_test.lua` 输出 `UIManager tests passed (36)`。

## 决策日志


- 决策：以 `.github/docs/eggy/ui_manager_lib.md` 为断言基准，若实现缺失或语义不一致导致测试失败，则在同批次补齐实现。
  理由：用户要求“依照 ui_manager_lib.md”，文档需成为质量门槛。
  日期/作者：2026-01-28 / Codex

- 决策：新增独立测试文件 `.github/tests/ui_manager_test.lua`，不并入 `.github/tests/regression.lua`。
  理由：UIManager 测试需要稳定的全局桩，避免与现有回归共享全局互相污染。
  日期/作者：2026-01-28 / Codex

- 决策：当前先覆盖已有 UIManager 模块与 Frameout 行为，不新增或模拟 Promise。
  理由：仓库内未提供 `Library/UIManager/Promise.lua`，先保证现有实现被测试。
  日期/作者：2026-01-30 / Codex

## 结果与复盘


已完成文档逐项对照并记录实现差异，`.github/tests/ui_manager_test.lua` 仍通过。Eggitor 手动测试按用户指示视作通过。

## 背景与导读


UIManager 代码位于 `UIManager/`，入口为 `UIManager/Utils.lua`，加载时依赖全局 `GameAPI`、`LuaAPI` 与 `EVENT`。节点构建由 `UIManager/Builder.lua` 完成；节点类型包括 `UIManager/ENode.lua`、`UIManager/ELabel.lua`、`UIManager/EImage.lua`、`UIManager/EButton.lua`、`UIManager/EProgressbar.lua`、`UIManager/EInputField.lua`；事件与异步由 `UIManager/Listener.lua` 与 `UIManager/Promise.lua` 实现。Eggy 运行时入口在 `src/adapters/eggy/eggy_runtime.lua` 与 `src/adapters/eggy/eggy_layer_ui.lua`，UI 节点数据来自 `Data/UIManagerNodes.lua`。本计划中的 “Role” 指可接收 UI API 调用的玩家对象，“ENode” 指 UI 节点 ID。

## 工作计划


先在 `.github/tests/ui_manager_test.lua` 内搭建最小但完整的测试桩，定义全局 `GameAPI`、`LuaAPI`、`EVENT` 与 `math.tofixed`，并提供可记录调用的 Role 对象。随后 require `UIManager.Utils` 进行初始化，构造一个小型节点配置和子节点关系映射，覆盖 ELabel、EImage、EButton、EProgressbar、EInputField 以及普通 ENode。测试内容逐项对照文档：构建与查询、子节点检索、属性写入触发的引擎 API、客户端隔离、事件监听与销毁、Promise 链式与 wait/await、以及帧计时器行为。若断言暴露实现缺失，补齐对应实现后重跑测试。

## 具体步骤


在仓库根目录新增 `.github/tests/ui_manager_test.lua`，按顺序完成桩定义、加载 UIManager、构建节点、断言与输出通过信息。完成后在以下目录执行命令并记录输出。

    cd C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly
    lua .github/tests/ui_manager_test.lua

预期输出包含 “UIManager tests passed (N)”。

## 验证与验收


自动化验收以 `lua .github/tests/ui_manager_test.lua` 通过为准，且覆盖 `ui_manager_lib.md` 中的初始化、查询、子节点查询、属性修改、事件监听、异步链式与计时器用法，至少包含 ELabel、EImage、EButton、EProgressbar、EInputField 的核心属性。Eggitor 手动验收按以下顺序执行：在 Eggitor 中打开仓库根目录工程，入口选择 `main.lua` 并运行，确认 UI 显示“蛋仔大富翁”标题与回合数；点击“下一回合”按钮观察回合或玩家信息变化；触发弹窗或选择面板后点击按钮确认 UI 交互生效。如果出现 “UI 节点未适配” 提示，记录节点名称并作为回归风险说明。

## 可重复性与恢复


测试文件为新增文件，可重复执行且不修改游戏数据。若需回退，删除 `.github/tests/ui_manager_test.lua` 即可。Eggitor 手动测试不改动存档，随时可停止并重新启动工程。

## 产物与备注


新增文件为 `.github/tests/ui_manager_test.lua`。可作为最小证据保留如下输出片段：

    UIManager tests passed (36)

## 接口与依赖


测试依赖 `UIManager/Utils.lua`、`UIManager/Builder.lua`、`UIManager/ENode.lua`、`UIManager/ELabel.lua`、`UIManager/EImage.lua`、`UIManager/EButton.lua`、`UIManager/EProgressbar.lua`、`UIManager/EInputField.lua`、`UIManager/Listener.lua`、`UIManager/Promise.lua` 与 `Utils/Frameout.lua`。测试桩需提供 `GameAPI.get_all_valid_roles`、`GameAPI.get_eui_children`、`GameAPI.get_eui_child_by_name` 与 Role 的 `set_label_text`、`set_image_color`、`set_button_text` 等 UI API；LuaAPI 需提供 `global_register_custom_event`、`global_unregister_custom_event`、`global_send_custom_event`、`global_register_trigger_event`、`global_unregister_trigger_event`；`EVENT.REPEAT_TIMEOUT` 与 `math.tofixed` 必须存在以保证 Frameout 正常运行。

变更说明：首次创建此可执行计划，用于交付 UIManager 覆盖测试的实施路径与验收方式。

2026-01-30 更新：新增 `.github/tests/ui_manager_test.lua` 并跑通，记录缺失 Promise 模块的发现与测试覆盖调整。原因是计划需反映实际仓库现状。

变更说明：按用户指示将 Eggitor 手动验收视作通过，并更新进度与结果。
