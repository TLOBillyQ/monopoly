# 前两周执行计划：第一周已完成，第二周推进 Choice 契约扩展与 Port 命名收口

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。本版本覆盖 `.agents/research.md` 中定义的“第 1 周”已完成工作与“第 2 周”待执行工作，不再承接旧的 LOC 压缩目标。

## 目的 / 全局视角

第一周已经把最容易继续失控的三个点收住：`src/presentation/view/render/market_view.lua` 的市场弹窗编排、`src/presentation/view/widgets/ui_panel_presenter.lua` 的玩家面板编排，以及 `market_buy` choice 在进入运行态之前的契约校验。第二周不再继续拆 UI 热点，而是把同一条“边界前移”思路扩到 item choice 和 `landing_optional_effect`，然后补上 `choice.meta` 审计与 Port 命名规则说明。

第二周完成后，用户应能看到三个新的可观察结果。第一，`item_phase_choice`、`remote_dice_value`、`roadblock_target`、`steal_prompt`、`landing_optional_effect` 这类高频 choice 的非法 `meta` 或 `action` 会更早在 descriptor/dispatcher/resolver 边界失败，而不是深入 handler 后才断言。第二，`src/core/choice/choice_contract.lua` 会明确哪些字段值得提升为显式字段，哪些仍应留在 `meta`，后续开发者不需要再凭感觉新增 `choice.xxx`。第三，Port / Ports / Port Adapter 的命名和目录语义会在架构文档中写清楚，后来者在触碰 `src/core/ports/`、`src/game/ports/`、`src/game/flow/turn/gameplay_loop_ports.lua`、`src/presentation/runtime/presentation_ports.lua` 时可以直接对照规则落点。最直接的证明方式仍然是运行 `lua tests/regression.lua`，并补跑 item / land / gameplay / architecture 相关 suite。

## 进度

- [x] (2026-03-08 12:10Z) 已冻结第一周目标：只做 `market_view` 拆分、`ui_panel_presenter` 拆分、`market_buy` descriptor 契约强化。
- [x] (2026-03-08 12:16Z) 基线验证完成：目标文件行数与计划一致，`presentation_ui` / `domain.market` suite 起点均通过。
- [x] (2026-03-08 12:24Z) M1 完成：`market_view.lua` 收口为薄入口，新增 `market_view_slots.lua` 与 `market_view_controls.lua`，外部入口与行为保持不变。
- [x] (2026-03-08 12:31Z) M2 完成：`ui_panel_presenter.lua` 收口为 role 级编排入口，新增 `ui_panel_player_slots.lua` 与 `ui_panel_cash_delta.lua`。
- [x] (2026-03-08 12:35Z) M3 完成：choice descriptor 支持 `normalize_meta` / `meta_validator` / `normalize_action`，`market_buy` 与 `market_vehicle_replace` 接入，相关测试补齐。
- [x] (2026-03-08 12:37Z) M4 完成：`presentation_ui`、`domain.market`、`gameplay` 与 `lua tests/regression.lua` 全部通过，本文已同步为真实结果。
- [x] (2026-03-08 12:40Z) 已冻结第二周目标：扩展 item / `landing_optional_effect` descriptor 契约、审计 `choice.meta` 显式字段、补 Port 命名规则说明。
- [ ] 第二周基线验证：记录 `item_choice_handler.lua`、`optional_effect_handler.lua`、`choice_contract.lua`、相关架构文档行数，并运行 item / land / gameplay / architecture suite。
- [ ] M5：为 `src/game/systems/choices/choice_handlers/item_choice_handler.lua` 与 `src/game/systems/choices/choice_handlers/optional_effect_handler.lua` 接入 descriptor 级 `normalize_meta` / `meta_validator` / `normalize_action`。
- [ ] M6：完成 `choice.meta` 审计，只把真正跨层稳定的字段收进 `src/core/choice/choice_contract.lua`，并用 architecture / gameplay / presentation 测试锁定结论。
- [ ] M7：把 Port / Ports / Port Adapter 的文件命名规则补入架构文档，不做批量 rename，但给后续触碰代码的人稳定落点。
- [ ] M8：运行第二周终验、同步本文档的“结果与复盘”，确认前两周计划能从当前工作树无歧义继续推进。

## 意外与发现

当前仓库已经有可复用的 support 层，因此本周不应再把“抽 helper”当作主要目标。`src/presentation/view/support/ui_controls.lua`、`src/presentation/view/support/effect_timeline.lua`、`src/presentation/view/support/market_layout.lua` 已经存在，新的改动要优先复用这些模块，而不是再建一层新的通用目录。

市场 choice 的分页字段已经是显式字段，而不是靠 `meta` 临时兜底。`src/core/choice/choice_contract.lua` 已经列出 `active_tab`、`page_index`、`page_count`，`src/game/systems/market/application/choice_session.lua` 也已经显式维护它们。因此本周不再做“把分页状态从 `meta` 拿出来”这类工作。

Choice 体系也不是零契约状态。`src/game/systems/choices/choice_registry.lua` 已支持 `required_meta`，`src/game/flow/intent/intent_dispatcher.lua` 会在 `open_choice` 时检查 `meta` 必填项。本周要做的是把这条链路从“只检查字段存在”增强到“可归一化、可验证、可在 resolver 前处理 action”。

市场 UI 的 companion 文件不能缓存 `market_cfg` 快照。`tests/suites/presentation/presentation_ui.lua` 里有通过 `package.loaded["src.presentation.view.render.market_view"] = nil` 再热重载主文件的用例，如果 companion 在 `require` 时把 `market_cfg` 建成静态索引，会让 `market_enabled=false` 相关断言读到旧配置。实施时已改成按调用读取配置。

`market_buy` 的 `normalize_action` 不能越过 `choice_resolver` 现有的“非法 option 保持 pending choice”语义。若在 normalizer 里直接校验商品存在性，会把原本应该记录 `invalid choice option` 的拒绝流打成 hard error。最终实现只负责数值归一化，把 option membership 继续留给 resolver。

`src/game/systems/choices/choice_handlers/item_choice_handler.lua` 仍保留大量“在 handler 深处先 `number_utils.to_integer(...)`、再 `assert(game:find_player_by_id(...))`”的重复模式。`demolish_target`、`roadblock_target`、`steal_item`、`item_target_player`、`remote_dice_value`、`item_phase_choice` 至少都还没走 descriptor 级归一化与前置校验，第二周扩展这条链路时要优先复用第一周已接好的 registry / dispatcher / resolver 能力，而不是另起 helper 体系。

`src/game/systems/choices/choice_handlers/optional_effect_handler.lua` 目前只有 `required_meta = { "player_id", "tile_id" }`，但 handler 内仍直接依赖 `meta.effect_ids`、`meta.move_result`、`game.board:get_tile_by_id(meta.tile_id)`。这说明它已经存在“稳定必需字段”和“kind-specific payload”混放的现象，第二周的 `choice.meta` 审计要把这类例子写清楚，避免把 `move_result` 一类 payload 误提升为显式字段。

`docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 已经解释了 Port 的目录语义，但还没有把文件名后缀规则本身写成一条开发者能直接套用的规范。第二周不需要新建命名治理工程，只需要把 “`*_port.lua` / `*_ports.lua` / `*_port_adapter.lua` 分别代表什么” 写到现有文档里，并附本仓库的真实例子。

## 决策日志

决策：本周不新建大而全的 schema 机制，而是在现有 descriptor 结构上做增量扩展。
理由：仓库已有 `required_meta`，继续沿 descriptor 增量演化，风险最低，也最符合现有 `choice_registry` 的组织方式。
日期/作者：2026-03-08 / Codex

决策：`market_view` 和 `ui_panel_presenter` 的拆分采用“同目录 companion 文件”形式，而不是新增同名目录。
理由：当前已有 `market_view.lua` 与 `ui_panel_presenter.lua` 主文件，文件系统里不能同时存在同名目录；使用 `market_view_controls.lua`、`market_view_slots.lua`、`ui_panel_cash_delta.lua`、`ui_panel_player_slots.lua` 这类 sibling 文件最直接，也最少 require churn。
日期/作者：2026-03-08 / Codex

决策：`board_feedback_service.lua` 不进入第一周范围。
理由：它虽然不小，但职责单一、调用稳定、测试覆盖相对充分，当前收益明显低于 `market_view` 与 `ui_panel_presenter`。
日期/作者：2026-03-08 / Codex

决策：`market_view_slots.lua` 不在模块加载时缓存 `market_cfg` / `items_cfg` 索引。
理由：现有 presentation 测试会只重载 `market_view.lua` 来验证 `market_enabled=false` 过滤行为，companion 若缓存配置会与测试和运行时热更新预期冲突。
日期/作者：2026-03-08 / Codex

决策：`market_buy.normalize_action` 只做 `option_id` 数值归一化，不提前校验 option 是否属于当前 choice。
理由：resolver 现有职责已经覆盖“非法 option 保持 pending choice 并记录 warn”；把这个语义前移到 normalizer 会改变已有行为和测试预期。
日期/作者：2026-03-08 / Codex

决策：第二周继续沿用第一周的“descriptor 增量扩展”路线，不引入新的通用 schema 或 validation DSL。
理由：`choice_registry`、`intent_dispatcher`、`choice_resolver` 这条链路已经能承载 `normalize_meta` / `meta_validator` / `normalize_action`，继续沿现有结构扩展 item / landing choice 风险最低，也最符合当前仓库的渐进式收口方式。
日期/作者：2026-03-08 / Codex

决策：第二周的 Port 命名规则写入现有架构文档，而不是单开一份“命名规范”新文档。
理由：`docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 已经承接目录语义和分层约束，把文件后缀规则补在同一处，后来者阅读路径最短，也避免规则分散。
日期/作者：2026-03-08 / Codex

决策：`choice.meta` 审计采取保守提升策略；如果某字段没有跨层通用消费者，就明确保留在 `meta`，并用测试锁定这个结论。
理由：第二周的目标是减少边界歧义，不是把 handler payload 全部“升格”为显式字段。保守策略更符合 `research.md` 的筛选标准，也能避免把单玩法细节错误扩散到 presentation / flow。
日期/作者：2026-03-08 / Codex

## 结果与复盘

第一周工作已经完成，结果满足最初定义的三个目标。其一，`src/presentation/view/render/market_view.lua` 已缩成 76 行薄入口，槽位渲染和控件状态分别下沉到 `market_view_slots.lua` 与 `market_view_controls.lua`，`market_modal_renderer.lua` 和 `ui_view_service.lua` 的调用方式未改。其二，`src/presentation/view/widgets/ui_panel_presenter.lua` 已缩成 134 行 role 级编排入口，玩家槽位渲染与现金变化状态机分别下沉到 `ui_panel_player_slots.lua` 与 `ui_panel_cash_delta.lua`，`refresh(state, ui_model, deps)` 签名保持不变。其三，`choice_registry` / `intent_dispatcher` / `choice_resolver` 现在支持 descriptor 级归一化与验证钩子，`market_buy` 会在 `open_choice` 阶段提前拒绝未知 `player_id`，并在 `resolve` 早期把字符串 `option_id` 归一化为整数。

第二周尚未实施，因此这里同时记录第二周的成功标准。成功标准不是“给更多 choice 加了更多 if”，而是三件事实同时成立：一，item choice 与 `landing_optional_effect` 的重复断言显著从 handler 内部前移到 descriptor / dispatcher / resolver 边界；二，`src/core/choice/choice_contract.lua` 的显式字段集合有明确去留原则，并由测试锁定，而不是继续按功能随手增加；三，Port / Ports / Port Adapter 的命名规则被补进现有架构文档，后来者只看文档就能判断文件该落在哪里、该叫什么。

第二周的验收也必须可观察。除了最终 `lua tests/regression.lua` 继续通过外，还要看到 `domain.item`、`domain.land`、`gameplay`、`architecture.usecase_boundary_contract` 这些 suite 能明确证明 choice 契约扩展与 `choice_contract` 审计没有引入回归。如果审计后发现没有任何新字段值得从 `meta` 提升出来，也必须把这个“不提升”的结论写进计划和测试，而不是口头说明后留给后来者再次重做。

## 背景与导读

本仓库的 UI 层主要在 `src/presentation/`。本周涉及的两个热点文件都属于“接口适配层”，也就是把领域状态和 runtime 状态投影成 UI 节点状态的那一层。`src/presentation/view/render/market_view.lua` 负责市场弹窗的槽位渲染、选中态、翻页按钮、页签按钮和关闭动作。它不应该理解新的业务规则，只应该编排现有市场数据如何显示到 UI。`src/presentation/view/widgets/ui_panel_presenter.lua` 负责基础玩家面板的标签、头像、头顶王冠、自动按钮、现金变化提示。它同样不应该承担新的业务逻辑，只应该把 `ui_model.panel` 渲染到节点。

Choice 相关逻辑主要在 `src/game/systems/choices/` 和 `src/game/flow/intent/`。这里的“descriptor”指的是 `choice_registry` 中每个 `choice.kind` 对应的一张表，当前最少包含 `execute`，有些 descriptor 还声明 `required_meta`。本周的目标是让 descriptor 除了声明“哪些字段必须有”，还可以声明“如何归一化 meta”和“如何验证 action”，这样 `market_buy` 的失败点可以更靠近边界。

与前两周工作直接相关的文件有：`src/presentation/view/render/market_view.lua`、`src/presentation/view/render/market_view_slots.lua`、`src/presentation/view/render/market_view_controls.lua`、`src/presentation/view/widgets/ui_panel_presenter.lua`、`src/presentation/view/widgets/ui_panel_player_slots.lua`、`src/presentation/view/widgets/ui_panel_cash_delta.lua`、`src/core/choice/choice_contract.lua`、`src/game/systems/choices/choice_registry.lua`、`src/game/flow/intent/intent_dispatcher.lua`、`src/game/systems/choices/choice_resolver.lua`、`src/game/systems/choices/choice_handlers/market_choice_handler.lua`、`src/game/systems/choices/choice_handlers/item_choice_handler.lua`、`src/game/systems/choices/choice_handlers/optional_effect_handler.lua`、`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`、`tests/suites/presentation/presentation_ui.lua`、`tests/suites/domain/market.lua`、`tests/suites/domain/item.lua`、`tests/suites/domain/land.lua`、`tests/suites/gameplay/gameplay.lua`、`tests/suites/architecture/usecase_boundary_contract.lua`。

当前已知基线分成两组。第一周改动的收口基线已经记录在“产物与备注”里。第二周的目标基线是：`src/game/systems/choices/choice_handlers/item_choice_handler.lua` 为 229 行，`src/game/systems/choices/choice_handlers/optional_effect_handler.lua` 为 47 行，`src/core/choice/choice_contract.lua` 为 47 行，`docs/architecture/boundaries.md` 为 55 行，`docs/architecture/layer-model.md` 为 82 行。

## 里程碑

### M1：`market_view` 从“大文件”变回“薄入口”

这一里程碑完成后，市场弹窗仍然可以打开、选择商品、切换页签、翻页、关闭，但 `src/presentation/view/render/market_view.lua` 自身只保留对外函数与少量编排。具体做法是把槽位渲染、选中框刷新和通用控件状态拆出去，分别放到 `src/presentation/view/render/market_view_slots.lua` 与 `src/presentation/view/render/market_view_controls.lua`。原文件继续作为稳定入口，被 `src/presentation/view/widgets/market_modal_renderer.lua` 直接引用，避免改调用点。

这一里程碑完成的证明不是“新增了两个文件”，而是现有市场相关测试依然通过，尤其是 `tests/suites/presentation/presentation_ui.lua` 中覆盖市场打开、重开、空页签、选中切换的那些用例继续全绿。

### M2：`ui_panel_presenter` 只保留入口编排

这一里程碑完成后，玩家面板仍然会刷新头像、名称、现金、地产数、总资产、自动状态和现金变化提示，但 `src/presentation/view/widgets/ui_panel_presenter.lua` 不再同时拥有全部细节实现。具体做法是先提取 `src/presentation/view/widgets/ui_panel_player_slots.lua`，承接玩家槽位文本、头像与头冠刷新；再提取 `src/presentation/view/widgets/ui_panel_cash_delta.lua`，承接现金变化缓存、显示与延迟隐藏。若拆完两块后主文件仍明显偏大，可以再把 `_render_role_view` 一组逻辑拆到 `src/presentation/view/widgets/ui_panel_role_view.lua`，但这一步不是强制要求，只有在前两步仍不足以让入口变薄时才执行。

这一里程碑的证明是玩家面板相关的 presentation suite 继续通过，而且 `refresh()` 仍然是外部唯一稳定入口，`src/presentation/view/canvas/base/presenter.lua` 无需行为改动。

### M3：为 `market_buy` 增加 descriptor 级的归一化与校验

这一里程碑完成后，`market_buy` 不仅能声明 `required_meta = { "player_id" }`，还可以在更靠前的位置处理输入。计划中的最小扩展是：在 `src/game/systems/choices/choice_registry.lua` 允许 descriptor 声明 `normalize_meta`、`meta_validator`、`normalize_action` 三个可选钩子；在 `src/game/flow/intent/intent_dispatcher.lua` 里，在复制显式字段并写入 `pending_choice` 之前，先运行 `normalize_meta` 和 `meta_validator`；在 `src/game/systems/choices/choice_resolver.lua` 里，在 cancel 分支和 option 校验之前，如果 descriptor 提供了 `normalize_action`，就先用它归一化 action；在 `src/game/systems/choices/choice_handlers/market_choice_handler.lua` 里，给 `market_buy` 增加针对 `player_id` 与 `option_id` 的轻量实现。

这里的“轻量”有明确边界。本周不引入新的 schema 框架，不新增独立 DSL，也不把所有 choice kind 一次性迁完。第一周只要求 `market_buy` 率先走通整条链路，然后用测试证明它可行。等第二周再决定是否扩到 item choice 和 `landing_optional_effect`。

这一里程碑完成的证明，是市场领域测试与 gameplay 测试里新增或改造后的 case 可以明确区分“缺字段”“字段不可归一化”“玩家不存在”这几类失败，并且失败点比现在更靠前。

### M4：第一周终验与文档收口

这一里程碑不是额外功能，而是把本周的结果固定下来。完成后，开发者应该可以只看当前工作树和这份 `plan.md`，就知道第一周做了什么、还剩什么、应该从哪里接着做。要做的事包括：运行全量回归；把“进度”改成真实状态；把“结果与复盘”改成真实结果；如果中途改过文件落点或函数签名，把变更原因补进“决策日志”。

### M5：把 descriptor 契约从 `market_buy` 扩到 item choice 与 `landing_optional_effect`

这一里程碑完成后，第二周新增的能力不是“choice 更抽象了”，而是 item / landing 高频路径的失败点会更靠外。具体做法是把 `src/game/systems/choices/choice_handlers/item_choice_handler.lua` 中的 `item_phase_choice`、`demolish_target`、`roadblock_target`、`steal_item`、`steal_prompt`、`item_target_player`、`remote_dice_value` 按现有 descriptor 结构补上 `normalize_meta`、`meta_validator`、`normalize_action`；同时把 `src/game/systems/choices/choice_handlers/optional_effect_handler.lua` 的 `landing_optional_effect` 接到同一条链路。数值解析仍统一走 `src.core.utils.number_utils`，不允许重新引入 `tonumber` 或 `type(x) == "number"` 分支。

这里的重点不是给每个 kind 写一套新框架，而是把当前 handler 内重复出现的“解析 `option_id` / 读取 `player_id` / 查找 target / 验证 tile 是否存在”尽量前移。对于 `steal_prompt.queue`、`landing_optional_effect.move_result` 这类明确属于 kind-specific payload 的字段，仍留在 `meta`，不要为了统一而硬搬到显式字段。

这一里程碑的证明，是 `tests/suites/domain/item.lua`、`tests/suites/domain/land.lua`、`tests/suites/gameplay/gameplay.lua` 能覆盖“缺字段”“字段不可归一化”“玩家或 tile 不存在”“字符串 option_id 被提前归一化”这些行为，而且 choice handler 本身明显少掉一部分重复防御式断言。

### M6：完成 `choice.meta` 审计，并把结论锁进 `choice_contract`

这一里程碑完成后，开发者应该能明确判断一个字段到底该放在 `choice.meta` 还是 `choice.xxx` 显式字段。具体做法是审查 `src/game/systems/items/item_handlers.lua`、`src/game/systems/land/land_choice_specs.lua`、`src/game/systems/effects/effect_pipeline.lua`、`src/presentation/view/widgets/ui_choice.lua`、`src/presentation/model/ui_model/item_slice.lua` 等当前显式消费 choice 字段的地方，然后只提升真正跨层稳定、被多个外层共同消费的语义。

这一里程碑允许两种正确结果，但不能模糊。第一种结果是审计后确认存在少量真正应提升的字段，那么就把它们加进 `src/core/choice/choice_contract.lua`，并更新 `intent_dispatcher`、相应 spec builder 与测试。第二种结果是审计后确认当前显式字段集合已经足够，那就不要新增字段，而是把“不提升”的结论补进测试，尤其是 `tests/suites/architecture/usecase_boundary_contract.lua`，让后来者看到哪些字段必须继续留在 `meta`。无论哪种结果，都必须在“决策日志”和“结果与复盘”里写清理由。

这一里程碑的证明，不是字段数量变多，而是 architecture / gameplay / presentation 侧对 `owner_role_id`、`target_picker_owner_role_id`、分页字段、item slot / target picker 路由字段的依赖关系变得更稳定，且 `choice_contract` 的职责边界比现在更清楚。

### M7：把 Port 命名规则补进现有架构文档

这一里程碑完成后，仓库不会多一个“命名治理工程”，但开发者会多一条可直接执行的规则。具体做法是在 `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 中增加一小段文件后缀命名说明，明确 `*_port.lua` 代表单一契约，`*_ports.lua` 代表成组 bundle，`*_port_adapter.lua` 代表适配器实现，并用 `src/game/flow/turn/gameplay_loop_ports.lua`、`src/presentation/runtime/presentation_ports.lua`、`src/game/runtime/*_port_adapter.lua` 这类现有文件举例。

这一里程碑明确不要求批量重命名，也不要求立刻调整所有历史文件。它的目的只是把第二周之后的新增与顺手修改拉回同一套命名语义中，避免 `_port.lua` / `_ports.lua` / `_adapter.lua` 继续按个人习惯混用。

这一里程碑的证明，是后来者只读这两份架构文档，就能回答三个问题：某个文件是在定义单一契约、在打包一组 override，还是在实现 adapter；它应该落在哪个目录；它的文件名后缀应该是什么。

### M8：第二周终验与文档收口

这一里程碑不是额外功能，而是把第二周的结论固定下来。完成后，开发者应该可以只看当前工作树、`research.md` 与这份 `plan.md`，就知道前两周做了什么、哪些 choice kind 已接入 descriptor 契约、`choice_contract` 为什么保留或新增某些显式字段，以及 Port 命名规则应该去哪里看。要做的事包括：运行第二周目标 suite 与全量回归；把“进度”改成真实状态；把“结果与复盘”改成真实结果；如果审计结论是“不新增显式字段”，也要把这个负结果写清楚。

## 工作计划

第一周已经结束，因此第二周的顺序不再从 UI 热点开始，而是从 Choice 契约开始。先做第二周基线验证，确认 item / land / gameplay / architecture 相关 suite 都是绿的，再改 `item_choice_handler.lua` 与 `optional_effect_handler.lua`。这一轮的目标不是重写 handler，而是把现有重复的 `number_utils.to_integer(...)`、`game:find_player_by_id(...)`、`game.board:get_tile_by_id(...)` 校验尽量前移到 descriptor 级钩子里。这样做的好处是，后面做 `choice.meta` 审计时，能更清楚地区分“需要提升成显式字段的通用语义”和“继续留在 `meta` 的 kind-specific payload”。

M5 完成后再做 M6，也就是 `choice.meta` 审计。审计时不要从“还能再加哪些显式字段”这个角度出发，而要从“哪些字段真的被 flow / presentation / timeout / route policy 跨层共同消费”来判断。重点看 `choice_contract` 的消费者，而不是单个 handler 的书写习惯。如果最后没有新增显式字段，也不算失败；失败是没有把“为什么不加”固定成测试和文档。

最后再做 M7 的文档收口。Port 命名规则不应单独游离成一份新文档，而应补进 `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 现有的目录语义说明里。第二周的代码和文档改动都必须继续遵守边界约束：presentation 不直接依赖 `game/flow` / `game/systems`，systems 不回依赖 flow，所有数值解析统一使用 `src.core.utils.number_utils`。

## 具体步骤

所有命令都在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。

先执行基线验证：

    wc -l src/presentation/view/render/market_view.lua src/presentation/view/widgets/ui_panel_presenter.lua src/game/flow/intent/intent_dispatcher.lua src/game/systems/choices/choice_registry.lua src/game/systems/choices/choice_handlers/market_choice_handler.lua
    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui")})'
    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.domain.market")})'

预期现象是目标文件行数与本文基线一致，两个 suite 均无 assertion 失败。

完成 M1 后执行：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui")})'
    wc -l src/presentation/view/render/market_view.lua src/presentation/view/render/market_view_slots.lua src/presentation/view/render/market_view_controls.lua

预期现象是市场相关 suite 继续通过，且主文件 `market_view.lua` 明显比 294 行更薄。

完成 M2 后执行：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui")})'
    wc -l src/presentation/view/widgets/ui_panel_presenter.lua src/presentation/view/widgets/ui_panel_player_slots.lua src/presentation/view/widgets/ui_panel_cash_delta.lua

如果额外提取 `ui_panel_role_view.lua`，把它也加到 `wc -l` 命令中。预期现象是玩家面板相关 suite 继续通过，主文件行数明显下降。

完成 M3 后执行：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.domain.market"), require("suites.gameplay.gameplay")})'

预期现象是市场领域测试和 gameplay 测试继续通过，新加的 `market_buy` 契约测试能稳定证明失败点前移。

完成 M4 后执行终验：

    lua tests/regression.lua

预期输出包含：

    All regression checks passed
    dep_rules ok
    legacy_path_guard ok
    forbidden_globals ok

第二周开始前执行基线验证：

    wc -l src/game/systems/choices/choice_handlers/item_choice_handler.lua src/game/systems/choices/choice_handlers/optional_effect_handler.lua src/core/choice/choice_contract.lua docs/architecture/boundaries.md docs/architecture/layer-model.md
    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.domain.item"), require("suites.domain.land"), require("suites.gameplay.gameplay"), require("suites.architecture.usecase_boundary_contract")})'

预期现象是目标文件行数与本文基线一致，四个 suite 均无 assertion 失败。

完成 M5 后执行：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.domain.item"), require("suites.domain.land"), require("suites.gameplay.gameplay"), require("suites.presentation.presentation_ui")})'

预期现象是 item / land / gameplay / presentation 相关 suite 继续通过，并且新增的 descriptor 契约测试能证明 item choice 与 `landing_optional_effect` 的失败点前移。

完成 M6 后执行：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.architecture.usecase_boundary_contract"), require("suites.gameplay.gameplay"), require("suites.presentation.presentation_ui")})'

预期现象是 `choice_contract` 的显式字段结论被 architecture / gameplay / presentation 测试同时锁定；如果没有新增显式字段，也应有新的断言证明“不提升”的结论。

完成 M7 后执行：

    git diff -- docs/architecture/boundaries.md docs/architecture/layer-model.md

预期现象是 diff 明确写出了 `*_port.lua`、`*_ports.lua`、`*_port_adapter.lua` 的命名语义和仓库内实例，而不是泛泛而谈。

完成 M8 后执行终验：

    lua tests/regression.lua

预期输出继续包含：

    All regression checks passed
    dep_rules ok
    legacy_path_guard ok
    tick ok

## 验证与验收

前两周的验收必须同时覆盖 UI、Choice 与文档三条线。第一周的 UI / `market_buy` 验收标准保持不变：市场弹窗相关测试证明打开、重开、切页签、翻页、关闭行为不变；玩家面板相关测试证明头像、文本、现金变化提示和自动状态行为不变；`market_buy` 的非法输入可以在 descriptor/dispatcher/resolver 边界被更早拒绝。

第二周新增的 Choice 线验收标准是：item choice 与 `landing_optional_effect` 至少覆盖“缺字段”“字段不可归一化”“目标不存在”“字符串 `option_id` 被提前归一化”这几类断言，并且测试能分辨失败原因，而不是只在 handler 深处收到通用断言。`choice.meta` 审计线的验收标准是：`choice_contract` 的显式字段去留有 architecture / gameplay / presentation 三侧测试兜底，不再依赖维护者口头约定。文档线的验收标准是：架构文档明确给出 Port / Ports / Port Adapter 的命名语义与仓库内实例，后续开发者不需要再翻源码猜规则。

如果需要人工 spot check，第二周可重点阅读 `tests/suites/domain/item.lua`、`tests/suites/domain/land.lua`、`tests/suites/gameplay/gameplay.lua`、`tests/suites/architecture/usecase_boundary_contract.lua`，以及 `docs/architecture/boundaries.md`、`docs/architecture/layer-model.md` 的新增段落，确认新增断言和文档规则与计划一致。最终仍以 `lua tests/regression.lua` 为准。

## 可重复性与恢复

前两周的所有改动都应当是增量可重复的。若某个里程碑中途失败，可以先回到最近一次通过测试的状态，再重做当前里程碑。恢复手段保持简单：对被修改的既有文件使用 `git checkout -- <path>`，对第一周新增的 companion 文件使用 `rm <path>` 删除。每完成一个里程碑就运行对应 suite，不要把多个里程碑积到最后一起调试。

第二周尤其要避免两类不可逆漂移。第一类是把 handler payload 大批量提升成显式字段后又删回去，这会让 `choice_contract`、presentation 和 gameplay 测试一起抖动；因此先做审计，再最小化修改。第二类是为了文档规则“看起来统一”而顺手大规模 rename Port 文件；第二周明确不做这种迁移，文档收口先于重命名收口。

## 产物与备注

当前基线证据如下：

    294 src/presentation/view/render/market_view.lua
    294 src/presentation/view/widgets/ui_panel_presenter.lua
    114 src/game/flow/intent/intent_dispatcher.lua
     51 src/game/systems/choices/choice_registry.lua
     45 src/game/systems/choices/choice_handlers/market_choice_handler.lua

本周预计新增但不一定全部保留的 companion 文件是：`src/presentation/view/render/market_view_slots.lua`、`src/presentation/view/render/market_view_controls.lua`、`src/presentation/view/widgets/ui_panel_player_slots.lua`、`src/presentation/view/widgets/ui_panel_cash_delta.lua`，以及仅在确有必要时新增的 `src/presentation/view/widgets/ui_panel_role_view.lua`。

本周实际产物如下：

    76 src/presentation/view/render/market_view.lua
   205 src/presentation/view/render/market_view_slots.lua
   128 src/presentation/view/render/market_view_controls.lua
   134 src/presentation/view/widgets/ui_panel_presenter.lua
   118 src/presentation/view/widgets/ui_panel_player_slots.lua
    98 src/presentation/view/widgets/ui_panel_cash_delta.lua
   127 src/game/flow/intent/intent_dispatcher.lua
    60 src/game/systems/choices/choice_registry.lua
   138 src/game/systems/choices/choice_handlers/market_choice_handler.lua

终验证据如下：

    All regression checks passed (384)
    dep_rules ok
    legacy_path_guard ok
    tick ok

第二周当前基线证据如下：

    229 src/game/systems/choices/choice_handlers/item_choice_handler.lua
     47 src/game/systems/choices/choice_handlers/optional_effect_handler.lua
     47 src/core/choice/choice_contract.lua
     55 docs/architecture/boundaries.md
     82 docs/architecture/layer-model.md

## 接口与依赖

第一周结束时，Choice descriptor 已支持以下稳定结构：`execute(game, choice, action)` 仍然必选；`required_meta` 仍然是字符串数组；`normalize_meta(game, meta, choice_spec)` 返回归一化后的 `meta` 表；`meta_validator(game, meta, choice_spec)` 在发现非法输入时直接抛出带上下文的错误；`normalize_action(game, choice, action)` 返回归一化后的 `action` 表。`src/game/systems/choices/choice_registry.lua` 负责接纳这些字段，`src/game/flow/intent/intent_dispatcher.lua` 负责在 open choice 时调用前两个钩子，`src/game/systems/choices/choice_resolver.lua` 负责在 resolve 早期调用 `normalize_action`。

第二周结束时，`src/game/systems/choices/choice_handlers/item_choice_handler.lua` 与 `src/game/systems/choices/choice_handlers/optional_effect_handler.lua` 中的高频 kind 也应接入同样的 descriptor 结构，且 item / landing 相关数值解析继续统一走 `src.core.utils.number_utils`。`choice_contract.explicit_fields` 只允许保留跨层稳定语义，例如 route、confirm、owner、item slot / target picker、分页这类字段；`phase`、`queue`、`move_result`、单 handler 内部消费的 payload 默认继续留在 `meta`，除非第二周审计拿出跨层消费者证据。

文档侧不新增新的架构层。第二周只在 `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 中补充命名规则说明，明确 `*_port.lua`、`*_ports.lua`、`*_port_adapter.lua` 的语义和目录落点。第一周 UI 侧也不新增公共接口；`src/presentation/view/render/market_view.lua` 和 `src/presentation/view/widgets/ui_panel_presenter.lua` 的对外函数签名保持原样，这一硬约束继续有效。

更新记录（2026-03-08 12:10Z）：清空旧的 3.3 轮降线计划，改写为只覆盖第一周的可执行计划。这样做是因为 `.agents/research.md` 已切换为“下一步行动建议”，而旧计划仍围绕已过时的 LOC 压缩目标，会误导后续实施。

更新记录（2026-03-08 12:37Z）：完成第一周实施并把文档改成真实状态，补充了 companion 热重载约束、`market_buy` normalizer 边界、实际行数与全量回归结果。这样做是为了让后来者只看当前工作树和本文件，就能无歧义地继续后续周计划。

更新记录（2026-03-08 12:40Z）：把 `.agents/research.md` 中的第二周行动建议补入本计划，新增了 M5-M8、第二周基线与验收命令、`choice.meta` 审计边界以及 Port 命名规则文档落点。这样做是为了让本文件从“第一周收尾记录”升级为“前两周可连续执行的活文档”。
