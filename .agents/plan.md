# UIManagerNodes 新节点接入执行计划（黑市分页分类 + 位置槽位）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护；任何实施、讨论、或中途改线都要先对照该规范，确保章节完整、命令可执行、验收可观察。

## 目的 / 全局视角


这项工作要把新版 `Data/UIManagerNodes.lua` 里新增但尚未接入的 26 个节点真正接入业务链路，避免玩家点击后只看到“UI 节点未适配”。

改动完成后，用户可以在黑市界面点击“上一页/下一页/分类按钮”切换可购买项，并且在位置选择界面直接点击 7 个槽位完成目标选择。可见成功标准是：按钮点击能触发正确意图、列表与选项状态按预期切换、确认动作通过 `ChoiceResolver._option_exists` 校验、回归测试全绿。

## 进度


- [x] (2026-03-04 17:30+08:00) P0 深度理解：阅读 `.agents/harness/PLANS.md`，确认可执行计划硬性规范与活文档要求。
- [x] (2026-03-04 17:33+08:00) P0 深度理解：阅读 `.agents/research.md`，确认“黑市 5 节点 + 位置 21 节点”的功能边界与约束。
- [x] (2026-03-04 17:40+08:00) P0 计划初始化：完成本计划首版重写并对齐研究结论。
- [x] (2026-03-04 17:55+08:00) P0 里程碑拆分：将 M1-M4 细化为可勾选子任务与验收门槛，便于按步推进和中途接力。
- [x] (2026-03-04 18:04+08:00) M1-1 黑市节点模型扩展：`MarketLayout.lua` 与 `canvas/market/nodes.lua` 已增加分页/分类节点字段。
- [x] (2026-03-04 18:05+08:00) M1-2 黑市意图扩展：`market/intents.lua` 已增加 `market_page_prev` / `market_page_next` / `market_tab_select`。
- [x] (2026-03-04 18:07+08:00) M1-3 黑市事件路由接线：分发层已接入新 intent，并通过路由注册覆盖 5 个新增按钮。
- [x] (2026-03-04 18:08+08:00) M1-GATE 验收门槛：执行 `presentation_ui_event_bindings` 套件通过，既有购买/关闭行为未退化。
- [x] (2026-03-04 18:09+08:00) M2-1 choice 状态建模：market choice 已增加 `active_tab`、`page_index`、`page_count` 与当前页 `options`。
- [x] (2026-03-04 18:10+08:00) M2-2 翻页/分类处理：`TurnDispatch` + `market/service/Choice.lua` 已接入后端重建逻辑。
- [x] (2026-03-04 18:10+08:00) M2-3 兼容回退：`MarketView` 与 `ChoiceSlice` 已对缺省字段提供回退行为（默认 `item` / 第 1 页 / 单页）。
- [x] (2026-03-04 18:11+08:00) M2-GATE 验收门槛：执行 `market` + `presentation_ui_interaction` 套件通过，确认路径仍受 `_option_exists` 约束。
- [x] (2026-03-04 18:12+08:00) M3-1 位置槽位节点建模：`target_choice/nodes.lua` 已增加 `slot_buttons/labels/projections[1..7]`。
- [x] (2026-03-04 18:12+08:00) M3-2 槽位映射渲染：`choice_screen_service/openers.lua` 已实现 option->槽位映射与空槽位隐藏/禁用。
- [x] (2026-03-04 18:13+08:00) M3-3 双路径兼容：新增 `target_lock` 意图接入同一锁定/确认/取消状态机，场景点选路径保留。
- [x] (2026-03-04 18:13+08:00) M3-GATE 验收门槛：`presentation_ui_interaction` + `presentation_ui` 套件通过，槽位与旧路径行为一致。
- [x] (2026-03-04 18:13+08:00) M4-1 定向测试：按里程碑执行 `presentation_ui_event_bindings`、`market`、`presentation_ui_interaction` 套件全部通过。
- [x] (2026-03-04 18:14+08:00) M4-2 全量回归：`lua tests/regression.lua` 通过（252/252）。
- [x] (2026-03-04 18:14+08:00) M4-3 收尾清理：已完成活文档回填与证据记录。
- [x] (2026-03-04 18:14+08:00) M4-GATE 交付门槛：最小验收场景全通过，可按本文档复现。

## 意外与发现


- 观察：新增黑市按钮当前不会进入业务路由，而是触发兜底“UI 节点未适配”提示。
  证据：研究文档第 3.2 节已确认 `黑市-` 前缀节点无代码引用，且 `UIEventBindings.register_missing_button_tip` 存在未路由按钮兜底逻辑。

- 观察：`choice_select` 受 `ChoiceResolver._option_exists` 强校验约束，前端假分页会直接失效。
  证据：研究文档第 4 节指出当前 `market/service/Choice.lua` 只构造最多 10 条可见项，若不扩展后端 choice 结构，切页后确认会因 `option_id` 不在 `pending_choice.options` 而失败。

- 观察：黑市分页/分类接入后，必须把新 intent 加入事件角色注入名单，否则多人模式会因缺失 `actor_role_id` 被拒绝。
  证据：`CanvasEventRouter` 已将 `market_page_prev` / `market_page_next` / `market_tab_select` 纳入 `_requires_event_actor`，且定向套件通过。

- 观察：位置槽位点击若直接发 `choice_select` 会绕过“先锁定再确认”的既有语义，导致状态机不一致。
  证据：最终采用 `target_lock` 视图命令并复用 `TargetChoiceEffects.on_scene_pick`，`presentation_ui` 套件 117 项通过。

## 决策日志


- 决策：黑市分页/分类采用“后端驱动 choice 状态，前端只渲染与分发意图”的路线，不做前端本地假分页。
  理由：必须保持 `ChoiceResolver._option_exists` 契约成立，避免确认购买时出现 option 越界。
  日期/作者：2026-03-04 / Codex

- 决策：位置选择新增槽位接入采用“保留旧路径 + 增量接入新槽位”的双路径策略。
  理由：可降低回归风险，避免一次性硬切导致现有 3D 场景点击选目标退化。
  日期/作者：2026-03-04 / Codex

- 决策：分类文案“坐骑商店”只做显示层映射，业务枚举继续沿用 `vehicle`。
  理由：研究已确认业务内部命名稳定为 `vehicle`，改枚举会扩大影响面且无用户价值。
  日期/作者：2026-03-04 / Codex

- 决策：黑市翻页/分类 action 采用独立 action type（`market_page_prev` / `market_page_next` / `market_tab_select`）并在 `TurnDispatch` 内直接重建 pending choice。
  理由：这样可复用 `validate_choice_action` 的 actor/choice_id 校验，同时避免把非购买动作伪装成 `choice_select` 破坏 `_option_exists` 语义。
  日期/作者：2026-03-04 / Codex

- 决策：位置槽位点击新增 `target_lock` 视图命令，而非新增 game action。
  理由：槽位点击本质是 UI 锁定行为，不应直接提交回合动作；复用既有 `TargetChoiceEffects` 可保持与场景点选同一状态机。
  日期/作者：2026-03-04 / Codex

- 决策：坐骑商店（`vehicle` tab）暂时禁用，前端按钮保留显示但不可点击，后端收到 `vehicle` 也回退到 `item`。
  理由：当前产品需求要求阶段性下线该入口，同时保持后续恢复时最小改动；三层兜底可避免旧事件或异常输入触发无效流程。
  日期/作者：2026-03-04 / Codex

## 结果与复盘


本次实施已完成四个里程碑，核心结果如下：黑市新增 5 个按钮已接入意图分发和后端重建；黑市分页/分类由后端 choice 驱动并保持 `_option_exists` 契约；位置选择屏已支持 7 槽位点击锁定，并与原场景点选共用同一确认/取消状态机；回归测试全绿。

已完成内容与“目的 / 全局视角”对照结论：玩家现在可在黑市执行上一页/下一页/分类切换，且确认动作始终提交当前页真实 `pending_choice.options`；玩家可在位置选择屏直接点击槽位完成锁定并确认，取消后可恢复未锁定状态。两项用户可见目标都已达成。

剩余风险：当前验证以自动化套件为主，仍建议后续在真实客户端场景补做一次多人联机点击烟测，重点关注 tab 切换后按钮高亮视觉是否满足 UI 设计预期。

## 背景与导读


本任务涉及三个层次。第一层是节点映射层：把 `UIManagerNodes` 名称映射成可访问节点字段。第二层是交互意图层：把点击事件转成 `market_page_next`、`market_tab_select`、`choice_select` 等可处理意图。第三层是业务 choice 层：保证前端展示与后端 `pending_choice.options` 一致，确认时不会被校验拒绝。

关键文件与职责如下。

- `Data/UIManagerNodes.lua`：新版节点清单来源，包含本次新增 26 节点。
- `src/presentation/shared/MarketLayout.lua`：黑市节点命名与布局抽象。
- `src/presentation/canvas/market/nodes.lua`：黑市画布节点绑定入口。
- `src/presentation/canvas/market/intents.lua`：黑市意图定义与参数组织。
- `src/presentation/render/MarketView.lua`：黑市视图渲染。
- `src/presentation/ui/MarketModalRenderer.lua`：黑市弹层 UI 更新。
- `src/presentation/canvas/target_choice/nodes.lua`：位置选择节点模型。
- `src/presentation/ui/choice_screen_service/openers.lua`：位置选择界面打开与 option 映射。
- `src/presentation/interaction/UIEventBindings.lua`：按钮事件绑定与未适配兜底提示。
- `src/game/systems/market/service/Choice.lua`：黑市 choice 组装（当前仅 10 条可见项）。
- `src/game/systems/choices/ChoiceResolver.lua`：`choice_select` 合法性校验（`_option_exists`）。
- `src/game/systems/choices/ChoiceHandlers/MarketChoiceHandler.lua`：黑市 choice 处理。

术语说明（面向新手）：

- “choice” 是给玩家的一次可选动作集合，玩家最终提交 `choice_select(option_id)`。
- “option_id 校验” 是在提交选择时检查该 id 是否确实在当前待选列表里，防止非法提交。
- “双路径兼容” 指新旧两套交互暂时并存，先保证可用，再按测试结果逐步收敛。

## 里程碑


### 里程碑 1：黑市节点建模与意图定义

先把新增黑市 5 个按钮接到前端节点层与意图层，但先不改业务行为。完成后，点击这 5 个按钮不再走“未适配提示”，而是进入明确 intent 路由。

本里程碑修改 `MarketLayout.lua`、`canvas/market/nodes.lua`、`market/intents.lua`，新增字段 `page_prev/page_next/tab_item/tab_skin/tab_vehicle` 与对应 intent（`market_page_prev`、`market_page_next`、`market_tab_select(tab)`）。

验收标准是：事件绑定日志可见新意图进入分发层，且不会误影响 `黑市_购买按钮` 与 `黑市_关闭` 现有行为。

推进拆分：先改节点模型（M1-1），再补 intent 常量与参数（M1-2），最后做事件接线与兜底清理（M1-3）。达到 M1-GATE 后再进入下一里程碑。

### 里程碑 2：黑市后端分页/分类 choice 契约扩展

在业务层补齐分页与分类状态，让黑市列表切换由后端 choice 驱动而非前端假渲染。完成后，分页/分类后的可见商品与 `pending_choice.options` 保持一致，确认购买可通过 `_option_exists`。

本里程碑改 `market/service/Choice.lua`、`MarketChoiceHandler.lua`（如需）、以及 intent 到 turn action 的路由处理，新增或扩展 `active_tab/page_index/page_count/options` 字段。必须提供缺省回退：如果新字段缺失，前端继续按当前 10 项行为运行。

验收标准是：分页切换后点击购买可成功提交，且非法页码、非法分类输入会被安全处理（不崩溃、不越权）。

推进拆分：先定义 choice 状态结构（M2-1），再连接翻页/分类处理（M2-2），最后补缺省回退（M2-3）。达到 M2-GATE 前不进入槽位接入。

### 里程碑 3：位置槽位节点接入与双路径兼容

把 7 个槽位（按钮/文本/投影）接入 `target_choice`，并保持旧路径（场景点选）可继续工作。完成后，玩家可在“位置选择屏”直接点槽位进入锁定态，确认后产生正确 `choice_select`。

本里程碑改 `target_choice/nodes.lua`、`choice_screen_service/openers.lua`，以及 `ui_view_service/core.lua`（`build_choice_screens`）把槽位按钮纳入 `option_buttons`。渲染映射要处理“option 少于 7”的空槽位状态（禁用/隐藏/占位文案）。

验收标准是：槽位点击、确认、取消的状态流与旧路径一致，取消后可回到未锁定状态。

推进拆分：先建 7 槽位节点数组（M3-1），再做渲染与禁用态映射（M3-2），最后联通状态机并验证双路径（M3-3）。

### 里程碑 4：端到端验证、回归与收尾

在本里程碑集中完成自动化验证与日志证据收集，并清理遗留兜底路径。完成后，本任务能被“新人仅靠本计划”复现验证。

本里程碑更新测试与计划活文档章节，记录关键输出证据、失败修复与最终结论。

验收标准是：最小验收场景全部通过，`lua tests/regression.lua` 全绿，且无新增“UI 节点未适配”噪声。

推进拆分：按“定向测试 -> 全量回归 -> 收尾清理”执行（M4-1/M4-2/M4-3），每一步都补充证据到本文档。

## 工作计划


执行顺序遵循“先接线、再补契约、再扩入口、最后回归”。先做里程碑 1 可以快速消除未路由状态并建立可观测意图；随后做里程碑 2 把业务契约补齐，确保点击能真正成交；再做里程碑 3 扩展位置槽位并保留旧路径，降低风险；最后在里程碑 4 做集中回归与证据沉淀。

编辑策略采用小步提交。每完成一个里程碑就运行对应测试，若失败只在当前里程碑范围修复，不跨里程碑混改。所有新增字段都提供缺省兼容，避免一次性升级导致旧数据无法渲染。

## 具体步骤


所有命令均在仓库根目录执行：`/Users/gangan/Dev/repo/monopoly`。

1. 建立基线并确认工作树：

    git status --short
    rg -n "黑市-|位置-槽位|register_missing_button_tip" src Data/UIManagerNodes.lua

2. 里程碑 1 实施后，验证黑市新按钮是否进入 intent：

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({require('presentation_ui_event_bindings')})"

3. 里程碑 2 实施后，验证黑市分页/分类与购买链路：

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({require('market'), require('presentation_ui_interaction')})"

4. 里程碑 3 实施后，验证位置槽位点选与锁定/取消语义：

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({require('presentation_ui_interaction'), require('presentation_ui')})"

5. 里程碑 4 收尾回归：

    lua tests/regression.lua

6. 检查是否仍出现未适配噪声日志（按本地日志路径替换）：

    rg "UI 节点未适配|未适配|market_page_|market_tab_select|位置-槽位" <日志文件路径>

## 验证与验收


必须同时满足以下行为验收。

黑市验收：点击“分类/翻页”会切换列表；点击当前可见项后确认购买成功；提交的 `option_id` 必须来自当前 `pending_choice.options`。位置验收：点击任一有效槽位进入锁定态，确认后提交正确 `choice_select`，取消后解锁且状态恢复。兼容验收：旧路径（场景点选目标）不退化，黑市原有购买/关闭不退化。回归验收：`lua tests/regression.lua` 全绿。

若出现失败，必须记录“失败用例名 + 触发输入 + 日志关键字 + 修复后结果”，并回填到“意外与发现”和“结果与复盘”。

## 可重复性与恢复


本计划可重复执行。节点映射和意图扩展采用增量方式，不依赖一次性迁移。

若中途失败，按“最近一个测试通过点”恢复：优先 `git restore --source=<commit> -- <file>` 定点恢复单文件，或 `git revert <commit>` 回退单次提交；禁止使用 `git reset --hard` 之类不可审计的破坏性命令。

重试时只重做当前里程碑，并重复该里程碑测试与一次最小回归，确认无连带回归再进入下一里程碑。

## 产物与备注


本任务预期产物包括：黑市新增节点映射代码、分页/分类 choice 契约字段、位置槽位节点接入代码、对应测试补充与回归记录。

证据保留格式使用短输出片段，不贴大段日志。示例：

    [PASS] presentation_ui_event_bindings (5)
    [PASS] market + presentation_ui_interaction (21)
    [PASS] presentation_ui_interaction + presentation_ui (117)
    [PASS] regression (252)

## 接口与依赖


本任务必须保持以下接口约束稳定。

- `ChoiceResolver._option_exists` 的语义不变：仅允许当前 `pending_choice.options` 内的 `option_id`。
- 黑市新 intent 命名固定为 `market_page_prev`、`market_page_next`、`market_tab_select`，并在分发层显式处理。
- `market_tab_select` 的业务参数使用稳定枚举：`item`、`skin`、`vehicle`。
- `target_choice` 槽位接口固定为三个数组字段：`slot_buttons[1..7]`、`slot_labels[1..7]`、`slot_projections[1..7]`。
- 缺省兼容必须存在：当新字段缺失时，回退旧行为，不导致 UI 打开失败。

文末变更说明（2026-03-04 17:40+08:00）：本次将 `.agents/plan.md` 从“Role 身份治理”主题整体替换为“UIManagerNodes 新节点接入”主题，原因是用户当前需求要求依据 `.agents/research.md` 交付可执行计划；旧计划与当前任务目标不一致，继续沿用会误导实施范围与验收标准。
文末变更说明（2026-03-04 17:55+08:00）：本次基于“深度理解，拆分里程碑进度”要求，将“进度”章节从粗粒度里程碑状态改为 M1-M4 子任务清单与 Gate 门槛，并在每个里程碑追加推进拆分顺序；原因是原版本无法表达执行先后和中途可交接状态，不利于持续推进与复盘。
文末变更说明（2026-03-04 18:14+08:00）：本次完成“执行全部计划”落地：实现黑市分页/分类后端驱动、事件路由与兼容回退，实现位置 7 槽位映射与 `target_lock` 交互，并补齐定向与全量回归证据；原因是用户要求按计划端到端交付可运行结果而非仅维护计划文本。
文末变更说明（2026-03-04 18:20+08:00）：本次按新需求修订“坐骑商店暂时禁用”：在 `MarketView` 禁用按钮触控、在 `market/intents.lua` 拦截 `tab_vehicle` 意图、在 `market/service/Choice.lua` 将 `vehicle` 选择回退到 `item`；原因是需要在不破坏主流程的前提下临时关闭该入口。
