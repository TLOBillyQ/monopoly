# UI Manager 覆盖测试计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本计划遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角


这项工作为 UIManager 的核心能力提供覆盖测试，保证节点构建、查询、属性绑定、事件、异步链式和计时器符合 `docs/eggy/ui_manager_lib.md` 的描述。完成后，开发者可以通过自动化脚本看到明确的通过/失败结论，并在 Eggitor 里观察到 UI 显示与按钮交互正常，从而确认功能确实在工作。

## 进度


- [ ] (2026-01-28 17:35) 梳理 UIManager 实现与文档对照点，记录必要差异
- [ ] (2026-01-28 17:35) 编写并跑通 `tests/ui_manager_test.lua`
- [ ] (2026-01-28 17:35) 完成 Eggitor 手动测试并记录可观察结果

## 意外与发现


暂无。实施中如发现文档与实现不一致，补充现象与证据片段。

## 决策日志


- 决策：以 `docs/eggy/ui_manager_lib.md` 为断言基准，若实现缺失或语义不一致导致测试失败，则在同批次补齐实现。
  理由：用户要求“依照 ui_manager_lib.md”，文档需成为质量门槛。
  日期/作者：2026-01-28 / Codex

- 决策：新增独立测试文件 `tests/ui_manager_test.lua`，不并入 `tests/regression.lua`。
  理由：UIManager 测试需要稳定的全局桩，避免与现有回归共享全局互相污染。
  日期/作者：2026-01-28 / Codex

## 结果与复盘


完成里程碑后补充本节，说明已覆盖的功能点、剩余缺口与经验。

## 背景与导读


UIManager 代码位于 `UIManager/`，入口为 `UIManager/Utils.lua`，加载时依赖全局 `GameAPI`、`LuaAPI` 与 `EVENT`。节点构建由 `UIManager/Builder.lua` 完成；节点类型包括 `UIManager/ENode.lua`、`UIManager/ELabel.lua`、`UIManager/EImage.lua`、`UIManager/EButton.lua`、`UIManager/EProgressbar.lua`、`UIManager/EInputField.lua`；事件与异步由 `UIManager/Listener.lua` 与 `UIManager/Promise.lua` 实现。Eggy 运行时入口在 `src/adapters/eggy/eggy_runtime.lua` 与 `src/adapters/eggy/eggy_layer_ui.lua`，UI 节点数据来自 `Data/UIManagerNodes.lua`。本计划中的 “Role” 指可接收 UI API 调用的玩家对象，“ENode” 指 UI 节点 ID。

## 工作计划


先在 `tests/ui_manager_test.lua` 内搭建最小但完整的测试桩，定义全局 `GameAPI`、`LuaAPI`、`EVENT` 与 `math.tofixed`，并提供可记录调用的 Role 对象。随后 require `UIManager.Utils` 进行初始化，构造一个小型节点配置和子节点关系映射，覆盖 ELabel、EImage、EButton、EProgressbar、EInputField 以及普通 ENode。测试内容逐项对照文档：构建与查询、子节点检索、属性写入触发的引擎 API、客户端隔离、事件监听与销毁、Promise 链式与 wait/await、以及帧计时器行为。若断言暴露实现缺失，补齐对应实现后重跑测试。

## 具体步骤


在仓库根目录新增 `tests/ui_manager_test.lua`，按顺序完成桩定义、加载 UIManager、构建节点、断言与输出通过信息。完成后在以下目录执行命令并记录输出。

    cd C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly
    lua tests/ui_manager_test.lua

预期输出包含 “UIManager tests passed (N)”。

## 验证与验收


自动化验收以 `lua tests/ui_manager_test.lua` 通过为准，且覆盖 `ui_manager_lib.md` 中的初始化、查询、子节点查询、属性修改、事件监听、异步链式与计时器用法，至少包含 ELabel、EImage、EButton、EProgressbar、EInputField 的核心属性。Eggitor 手动验收按以下顺序执行：在 Eggitor 中打开仓库根目录工程，入口选择 `main.lua` 并运行，确认 UI 显示“蛋仔大富翁”标题与回合数；点击“下一回合”按钮观察回合或玩家信息变化；触发弹窗或选择面板后点击按钮确认 UI 交互生效。如果出现 “UI 节点未适配” 提示，记录节点名称并作为回归风险说明。

## 可重复性与恢复


测试文件为新增文件，可重复执行且不修改游戏数据。若需回退，删除 `tests/ui_manager_test.lua` 即可。Eggitor 手动测试不改动存档，随时可停止并重新启动工程。

## 产物与备注


新增文件为 `tests/ui_manager_test.lua`。可作为最小证据保留如下输出片段：

    UIManager tests passed (N)

## 接口与依赖


测试依赖 `UIManager/Utils.lua`、`UIManager/Builder.lua`、`UIManager/ENode.lua`、`UIManager/ELabel.lua`、`UIManager/EImage.lua`、`UIManager/EButton.lua`、`UIManager/EProgressbar.lua`、`UIManager/EInputField.lua`、`UIManager/Listener.lua`、`UIManager/Promise.lua` 与 `Utils/Frameout.lua`。测试桩需提供 `GameAPI.get_all_valid_roles`、`GameAPI.get_eui_children`、`GameAPI.get_eui_child_by_name` 与 Role 的 `set_label_text`、`set_image_color`、`set_button_text` 等 UI API；LuaAPI 需提供 `global_register_custom_event`、`global_unregister_custom_event`、`global_send_custom_event`、`global_register_trigger_event`、`global_unregister_trigger_event`；`EVENT.REPEAT_TIMEOUT` 与 `math.tofixed` 必须存在以保证 Frameout 正常运行。

变更说明：首次创建此可执行计划，用于交付 UIManager 覆盖测试的实施路径与验收方式。
