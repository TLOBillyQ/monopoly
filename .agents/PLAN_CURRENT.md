# 执行计划：UI 交互节点配置收敛（倒计时/行动日志链路）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次改造要解决“UI 节点重命名后多处散落硬编码导致回归”的结构性问题。完成后，用户可以只在一个地方（`src/presentation/shared/UINodes.lua`）维护调试开关目标节点与关键点击节点清单，`UIEventRouter` 与启动校验自动使用该配置，不再分别手写。可见结果是：节点重命名后，启动不会因漏改校验清单报错，行动日志开关也不会因漏改路由失效。

## 进度

- [x] (2026-02-13 18:20Z) 读取 `.agents/PLANS.md` 与当前架构上下文，确认采用“先收敛配置源，再替换调用方”的增量策略。
- [x] (2026-02-13 18:22Z) 重建 `PLAN_CURRENT.md` 为本任务活文档。
- [x] (2026-02-13 18:26Z) 在 `src/presentation/shared/UINodes.lua` 增加统一配置导出：`debug.toggle_targets` 与 `required_click_nodes(opts)`。
- [x] (2026-02-13 18:27Z) `src/presentation/interaction/UIEventRouter.lua` 改为消费 `UINodes.debug.toggle_targets`。
- [x] (2026-02-13 18:28Z) `src/app/init.lua` 改为消费 `UINodes.required_click_nodes({ extra = market_ui.item_buttons })`。
- [x] (2026-02-13 18:30Z) 运行 `lua .agents/tests/regression.lua` 并通过：`All regression checks passed (129)`。
- [x] (2026-02-13 18:36Z) 启动下一阶段：输入锁/触控策略收敛，更新可执行计划并进入实施。
- [x] (2026-02-13 18:41Z) 抽取统一触控策略模块：新增 `src/presentation/interaction/UITouchPolicy.lua`。
- [x] (2026-02-13 18:42Z) 替换旧触控设置路径，`UIPanelPresenter`/`UIInputLockPolicy` 改为共用 `UITouchPolicy`。
- [x] (2026-02-13 18:44Z) 运行全量回归并通过：`All regression checks passed (129)`。
- [x] (2026-02-13 18:50Z) 收敛 `UIEventBindings.enable_debug_toggle_touch` 的节点级触控写入到 `UITouchPolicy`。
- [x] (2026-02-13 18:51Z) 运行全量回归并通过：`All regression checks passed (129)`。
- [x] (2026-02-13 18:57Z) 新增 `UITouchPolicy` 直接回归用例（auto controls / runtime nodes）。
- [x] (2026-02-13 18:58Z) 运行全量回归并通过：`All regression checks passed (131)`。
- [x] (2026-02-13 19:05Z) 收敛 choice/market 触控锁定逻辑到 `UITouchPolicy`（批量触控与屏幕锁定 helper）。
- [x] (2026-02-13 19:06Z) 运行全量回归并通过：`All regression checks passed (131)`。
- [x] (2026-02-13 19:12Z) 完成输入锁边界注释化收口（放行/锁定规则），并清理未使用参数命名。
- [x] (2026-02-13 19:13Z) 运行全量回归并通过：`All regression checks passed (131)`。

## 意外与发现

- 观察：`src/app/init.lua` 目前仍直接维护 `required_nodes` 字符串数组，属于高层策略对低层节点细节的直接依赖。
  证据：`src/app/init.lua` 的 `_install_game_init` 内部 `required_nodes = { ... }`。
- 观察：`UIEventRouter` 已支持双节点调试开关，但列表定义在 router 内部，而非节点配置源。
  证据：`src/presentation/interaction/UIEventRouter.lua` 中 `for _, name in ipairs({ ui_nodes.debug.toggle_button, ui_nodes.debug.toggle_image })`。
- 观察：将 required list 与调试目标统一后，不需要改测试即可保持行为稳定。
  证据：全量回归输出 `All regression checks passed (129)`。
- 观察：触控启用逻辑仍在多个模块分别写入，后写覆盖前写，排查成本高。
  证据：`UIPanelPresenter.render_auto_controls_for_role` 与 `UIInputLockPolicy.apply` 都会设置托管控件 touch。
- 观察：收敛触控策略后，既有回归无需调整即可通过。
  证据：全量回归输出 `All regression checks passed (129)`。
- 观察：节点级 `disabled` 写入迁移后，行为仍保持一致。
  证据：迁移后全量回归输出 `All regression checks passed (129)`。
- 观察：加入策略层直测后，回归通过数提升到 131，触控回归定位粒度提升。
  证据：全量回归输出 `All regression checks passed (131)`。
- 观察：choice/market 触控锁定下沉后，行为未变化且重复循环显著减少。
  证据：迁移后全量回归输出 `All regression checks passed (131)`。
- 观察：输入锁边界注释化后，可读性提升且无行为变化。
  证据：注释化后全量回归输出 `All regression checks passed (131)`。

## 决策日志

- 决策：本轮只做“配置收敛 + 调用方替换”，不同时推进触控策略大重构。
  理由：这是最小可交付改造，风险低，能直接降低节点重命名回归概率。
  日期/作者：2026-02-13 / Copilot
- 决策：保留 `app/init.lua` 对 `market_ui.item_buttons` 的追加逻辑，通过 `UINodes.required_click_nodes({ extra = ... })` 注入可变列表。
  理由：黑市按钮数量由布局定义，仍应由调用方在运行期拼入。
  日期/作者：2026-02-13 / Copilot
- 决策：`required_click_nodes` 返回“新数组”，不在 `UINodes` 内缓存可变结果。
  理由：避免调用方意外修改共享引用，降低后续调试成本。
  日期/作者：2026-02-13 / Copilot
- 决策：下一阶段采用“提取轻量策略模块 + 保持原接口不变”的方式收敛触控逻辑。
  理由：能降低重复逻辑且不扩散改动面，回归风险可控。
  日期/作者：2026-02-13 / Copilot
- 决策：`UIEventBindings` 的节点级 `disabled` 直接写入暂不并入 `UITouchPolicy`。
  理由：初始阶段先保守落地，避免扩大改动面。
  日期/作者：2026-02-13 / Copilot
- 决策：在回归稳定后，将 `UIEventBindings` 的节点级写入纳入 `UITouchPolicy.set_runtime_nodes_touch_enabled`。
  理由：进一步减少触控规则分散，实现单点维护，且验证通过后风险可控。
  日期/作者：2026-02-13 / Copilot

## 结果与复盘

第一阶段（节点配置收敛）与第二阶段（触控策略收敛）均已完成并通过全量回归（129）。

完成项：

1. `UINodes` 成为“调试开关目标 + required click nodes”统一配置源；
2. `UIEventRouter` 从配置读取调试开关节点，不再内联双节点列表；
3. `app/init` 启动校验从配置函数取 required nodes，不再维护长字符串数组。

用户可见收益：UI 节点改名时，修改点集中到 `UINodes`，减少“漏改路由/漏改校验清单”导致的启动失败和点击失效。

第二阶段成果：

1. 新增 `UITouchPolicy` 统一托管控件触控与调试开关触控规则；
2. `UIPanelPresenter` 与 `UIInputLockPolicy` 复用同一触控策略，减少重复实现；
3. 托管按钮在输入锁时保持可点击的行为不变。

第三步成果：

1. `UIEventBindings.enable_debug_toggle_touch` 不再直接写 `node.disabled`；
2. 节点级触控启用通过 `UITouchPolicy.set_runtime_nodes_touch_enabled` 统一处理；
3. 全量回归保持 129 通过。

第四步成果：

1. 新增 `UITouchPolicy` 直接测试，覆盖托管控件 touch 规则与 runtime 节点 disabled 开关；
2. 触控策略从“仅集成回归覆盖”提升为“策略层+集成层双覆盖”；
3. 全量回归更新为 131 通过。

第五步成果：

1. `UITouchPolicy` 新增 `set_many_touch_enabled` 与 `set_choice_screen_locked`；
2. `UIInputLockPolicy` 不再内联 choice/market 锁定循环，改为复用策略函数；
3. 全量回归保持 131 通过。

第六步成果：

1. `UIInputLockPolicy` 明确标注了输入锁期间“必须放行/必须锁定”的交互边界；
2. 轻量清理 `_can_popup_confirm` 未使用参数，降低阅读噪音；
3. 全量回归保持 131 通过。

剩余债务：若后续新增更多触控类型（比如 market/choice 特例），建议继续按同模式补策略层直测。

## 背景与导读

与本任务直接相关的文件如下：

- `src/presentation/shared/UINodes.lua`：UI 节点名常量定义。
- `src/presentation/interaction/UIEventRouter.lua`：UI 点击路由到 intent 的入口。
- `src/app/init.lua`：启动流程，包含 UI 必需节点校验。
- `Data/UIManagerNodes.lua`：编辑器导出的节点清单，提供 `validate(required_names)` 用于启动校验。

“required click nodes” 指启动时必须存在的可交互节点列表；若缺失会在 `GAME_INIT` 阶段抛错，阻止进入游戏。

## 工作计划

先在 `UINodes` 增加两个稳定导出：调试开关目标节点列表、统一 required click nodes 构建函数。随后将 `UIEventRouter` 和 `app/init` 改为消费这些导出，移除本地重复硬编码。最后跑全量回归验证行为不变。

## 具体步骤

在仓库根目录执行：

    lua .agents/tests/regression.lua

预期输出片段：

    All regression checks passed (N)

其中 `N` 取决于当前回归集数量，需大于等于本轮前的通过数。

## 验证与验收

验收标准：

1. `UINodes` 中存在统一导出函数，返回 required click nodes 列表。
2. `UIEventRouter` 不再内联调试按钮列表，改为读取 `UINodes` 配置。
3. `app/init.lua` 不再硬编码整段 required nodes 字符串数组。
4. 全量回归通过。

## 可重复性与恢复

改动为增量、可重复执行。若回归失败，按以下顺序恢复：

1. 回退 `src/app/init.lua` 的 required nodes 来源；
2. 回退 `src/presentation/interaction/UIEventRouter.lua` 的调试目标来源；
3. 回退 `src/presentation/shared/UINodes.lua` 新增导出；
4. 重新运行回归定位最小失败面。

## 产物与备注

预计产物：

- 修改：`src/presentation/shared/UINodes.lua`
- 修改：`src/presentation/interaction/UIEventRouter.lua`
- 修改：`src/app/init.lua`
- （如需）修改：`.agents/tests/suites/presentation_ui.lua`

## 接口与依赖

新增（或确认）接口：

- `ui_nodes.debug.toggle_targets`：调试开关可点击节点列表。
- `ui_nodes.required_click_nodes(opts)`：返回启动校验所需节点名数组；`opts.extra` 可追加动态节点。

调用方约束：

- `UIEventRouter` 仅消费 `toggle_targets`，不再自己拼列表。
- `app/init` 仅消费 `required_click_nodes`，不再维护重复字符串数组。

变更说明（2026-02-13 / Copilot）：创建并启用本任务可执行计划，进入实施阶段。
变更说明（2026-02-13 / Copilot）：完成配置收敛改造并记录回归结果（129 通过）。
变更说明（2026-02-13 / Copilot）：启动第二阶段触控策略收敛并更新任务清单。
变更说明（2026-02-13 / Copilot）：完成第二阶段触控策略收敛并记录回归结果（129 通过）。
变更说明（2026-02-13 / Copilot）：完成节点级触控写入收敛并记录回归结果（129 通过）。
变更说明（2026-02-13 / Copilot）：新增 UITouchPolicy 单测并记录回归结果（131 通过）。
变更说明（2026-02-13 / Copilot）：完成 choice/market 触控锁定收敛并记录回归结果（131 通过）。
变更说明（2026-02-13 / Copilot）：完成输入锁边界注释化收口并记录回归结果（131 通过）。
