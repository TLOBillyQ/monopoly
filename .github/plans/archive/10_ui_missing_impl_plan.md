# UI 节点缺失实现梳理与缺省提示计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md。

## 目的 / 全局视角


目标是以 Data/UIManagerNodes.lua 为唯一事实来源，列出适配层对 UI 节点的缺失实现，并在缺失时用 GlobalAPI.show_tips 给出明确提示，避免界面静默失败。完成后，开发者能看到一份“缺失实现清单”，运行时对未适配节点会弹出缺省提示，验证方式是：执行审计脚本输出清单、点击未适配节点可看到 show_tips 提示、现有 UI 功能不回退。

## 进度


- [x] (2026-01-28 17:10Z) 创建计划初版，确认对比口径与目标。
- [x] (2026-01-28 19:05Z) 生成 UI 节点缺失实现清单并落盘（`.github/docs/ui/ui_missing_impl.md`）。
- [x] (2026-01-28 19:05Z) 补上缺省提示逻辑并回归验证（新增 `.github/tests/ui_missing_impl_audit.lua`）。

## 意外与发现


- 观察：`ui_missing_impl_audit` 已无 “MissingInUiData” 项。
  证据：`lua .github/tests/ui_missing_impl_audit.lua` 输出 `MissingInUiData:` 为空。

## 决策日志


- 决策：以 ui_data 作为 UI 节点真源，适配层以“对齐名称 + 缺省提示”为第一优先。
  理由：资源侧导出的名称是运行时真实节点，先对齐能减少无效排查。
  日期/作者：2026-01-28 / Codex

## 结果与复盘


已生成缺失清单并补齐缺省提示逻辑：缺失节点会在访问或点击时提示一次，未绑定按钮也会被绑定默认提示。当前 ui_data 缺失项已清零，仅剩“适配未使用”的装饰节点清单供参考。

## 背景与导读


UI 节点由 Eggitor 导出到 Data/UIManagerNodes.lua，适配层主要在 src/adapters/eggy/eggy_layer_ui.lua、src/adapters/eggy/eggy_runtime.lua、src/adapters/eggy/market_ui.lua 和 src/adapters/eggy/eggy_layer_market.lua 中读取并更新。当前存在明显命名差异与缺失：ui_data 中的 choice_option1~4 与适配层使用的 choice_option_1~4 不一致，market_item_button1~10 与适配层的 market_item_button_1~10 不一致；适配层写入的 panel_current_title、panel_current_name、panel_current_role、panel_current_phase、panel_players_title、panel_log_title、panel_log_body、btn_restart、popup_confirm_alt、btn_auto_label、panel_item_slots、overlay_mask、background_rect 等在 ui_data 中未出现；ui_data 中还包含 market_item_containter、market_panel_backgroud、backgroud_rect_base、backgroud_loading 等拼写与文档不一致的节点，以及若干中文节点未被适配层使用。以上均属于“可能缺失实现”的候选，需要通过脚本正式确认并落盘。

## 里程碑


里程碑一：生成 UI 缺失实现清单。完成后将产出一个文档或脚本输出，包含“ui_data 有但适配未使用”的节点与“适配使用但 ui_data 不存在”的节点，并给出建议修复方式。

里程碑二：补上缺省提示。完成后，点击未适配的可交互节点会显示 GlobalAPI.show_tips 提示，且已适配节点保持正常行为。

## 工作计划


先实现一个可重复的扫描流程：从 Data/UIManagerNodes.lua 读出节点名与类型，从适配层配置与显式字符串收集“已使用节点”。将二者做差集，形成“缺失实现清单”，并落到 .github/docs/ui/ui_missing_impl.md（或 .github/tests 输出）中，保证可追踪。清单需区分“ui_data 有但适配未使用”和“适配使用但 ui_data 不存在”两类，并标注可能的别名映射（例如 choice_option1 vs choice_option_1、market_item_button1 vs market_item_button_1）。

随后在运行时补上缺省提示：在 Eggy 适配层增加“节点别名解析 + 缺省提示”能力。当代码访问节点名时，优先解析别名到 ui_data 中真实存在的名称；仍找不到时，用 GlobalAPI.show_tips 输出一次性提示（避免每帧刷屏，可缓存已提示过的节点）。对于可点击节点，EggyRuntime 在注册点击事件后额外扫描 ui_data 中的 EButton 节点，如果未被任何已注册事件覆盖，则绑定一个默认点击回调，调用 GlobalAPI.show_tips 提醒“未实现”。这样既能覆盖命名不一致，又能让未适配按钮可见。

## 具体步骤


在仓库根目录确认 ui_data 现状与 UI 命名口径：

    type Data\UIManagerNodes.lua
    type .github\\docs\\ui\\ui_naming_list.md

创建审计脚本（建议 .github/tests/ui_missing_impl_audit.lua），读取 Data.UIManagerNodes 的节点集合与类型，整理适配层已使用节点集合（来源包括 EggyLayerUI.build_ui_state、MarketUI、EggyRuntime 注册的点击节点、EggyLayerMarket 设置的节点）。脚本输出两组差异并返回非零退出码，输出格式固定为“MissingInAdapter: … / MissingInUiData: …”。

在 src/adapters/eggy/eggy_layer_ui.lua 中添加别名解析函数，例如当传入 choice_option_1 时优先尝试 choice_option1，market_item_button_1 对应 market_item_button1。该映射只覆盖已确认的 ui_data 实际名称，不引入新命名。若最终仍找不到节点，调用 GlobalAPI.show_tips 显示一次性提示。

在 src/adapters/eggy/eggy_runtime.lua 中扩展 register_ui_manager_events：注册完已知节点后，读取 Data.UIManagerNodes，筛出 EButton 或具备点击行为的节点，剔除已注册节点，对剩余节点绑定默认点击回调并 show_tips。提示文本需短小，例如“UI 节点未适配：<name>”。

根据审计输出决定是否需要同步 .github/docs/ui/ui_naming_list.md，确保文档与实际一致。若仅补缺省提示而不修复命名，以审计输出作为短期兜底，不擅自改 Eggitor 资源。

## 验证与验收


在仓库根目录执行：

    lua .github/tests/ui_missing_impl_audit.lua
    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

验收标准是：审计脚本输出清单且在修复后只剩允许的别名项或为空；点击未适配的按钮会弹出 GlobalAPI.show_tips；既有 UI 操作（例如选择弹窗与黑市交互）仍可用。

## 可重复性与恢复


审计脚本只读，可重复执行。缺省提示仅在找不到节点或未绑定点击时触发，不影响既有逻辑。若提示过于频繁，可通过缓存表关闭重复提示；如需回退，移除新增提示与别名映射即可。

## 产物与备注


产物包含：缺失实现清单文档（建议 .github/docs/ui/ui_missing_impl.md）、审计脚本 .github/tests/ui_missing_impl_audit.lua、以及适配层缺省提示与别名映射代码。

## 接口与依赖


默认提示使用 GlobalAPI.show_tips。审计脚本只依赖 Data.UIManagerNodes 与适配层模块，不新增外部依赖或动态文件读取；适配层新增的别名映射需限制在 ui_data 已存在的名称。

本次更新：创建 UI 节点缺失实现梳理与缺省提示计划，列出已发现的命名差异与缺失节点，明确审计与修复流程。
本次更新：补齐缺失清单、审计脚本与缺省提示逻辑，记录 ui_data 仍缺少的节点与后续待办。

改动说明：补充审计产物与执行结果，更新进度与复盘，明确仍需 Eggitor 补齐节点。
改动说明：记录 ui_data 缺失项已清零的现状，更新意外与复盘描述。
改动说明：同步背景描述中已补齐的节点信息，避免后续误判缺失项。
