# 第一周执行计划：UI 热点拆分与 `market_buy` 契约前移

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。本版本只覆盖 `.agents/research.md` 中定义的“第 1 周”工作，不再承接旧的 LOC 压缩目标。

## 目的 / 全局视角

这一周的目标不是继续做目录迁移，也不是单纯把 Lua 行数压得更低，而是先把最容易继续失控的三个点收住：`src/presentation/view/render/market_view.lua` 的市场弹窗编排，`src/presentation/view/widgets/ui_panel_presenter.lua` 的玩家面板编排，以及 `market_buy` choice 在进入运行态之前的契约校验。

完成后，用户应能看到三个可观察结果。第一，市场弹窗的打开、选择、翻页、切页签、关闭行为与现在一致，但 `market_view.lua` 只保留薄入口。第二，玩家面板的头像、资产、现金变化提示行为与现在一致，但 `ui_panel_presenter.lua` 不再同时承担多类细节渲染。第三，非法的 `market_buy` 输入会更早在 descriptor/dispatcher 边界报错，而不是深处 handler 才失败。最直接的证明方式仍然是运行 `lua tests/regression.lua`，并补跑市场与 UI 相关 suite。

## 进度

- [x] (2026-03-08 12:10Z) 已冻结第一周目标：只做 `market_view` 拆分、`ui_panel_presenter` 拆分、`market_buy` descriptor 契约强化。
- [x] (2026-03-08 12:16Z) 基线验证完成：目标文件行数与计划一致，`presentation_ui` / `domain.market` suite 起点均通过。
- [x] (2026-03-08 12:24Z) M1 完成：`market_view.lua` 收口为薄入口，新增 `market_view_slots.lua` 与 `market_view_controls.lua`，外部入口与行为保持不变。
- [x] (2026-03-08 12:31Z) M2 完成：`ui_panel_presenter.lua` 收口为 role 级编排入口，新增 `ui_panel_player_slots.lua` 与 `ui_panel_cash_delta.lua`。
- [x] (2026-03-08 12:35Z) M3 完成：choice descriptor 支持 `normalize_meta` / `meta_validator` / `normalize_action`，`market_buy` 与 `market_vehicle_replace` 接入，相关测试补齐。
- [x] (2026-03-08 12:37Z) M4 完成：`presentation_ui`、`domain.market`、`gameplay` 与 `lua tests/regression.lua` 全部通过，本文已同步为真实结果。

## 意外与发现

当前仓库已经有可复用的 support 层，因此本周不应再把“抽 helper”当作主要目标。`src/presentation/view/support/ui_controls.lua`、`src/presentation/view/support/effect_timeline.lua`、`src/presentation/view/support/market_layout.lua` 已经存在，新的改动要优先复用这些模块，而不是再建一层新的通用目录。

市场 choice 的分页字段已经是显式字段，而不是靠 `meta` 临时兜底。`src/core/choice/choice_contract.lua` 已经列出 `active_tab`、`page_index`、`page_count`，`src/game/systems/market/application/choice_session.lua` 也已经显式维护它们。因此本周不再做“把分页状态从 `meta` 拿出来”这类工作。

Choice 体系也不是零契约状态。`src/game/systems/choices/choice_registry.lua` 已支持 `required_meta`，`src/game/flow/intent/intent_dispatcher.lua` 会在 `open_choice` 时检查 `meta` 必填项。本周要做的是把这条链路从“只检查字段存在”增强到“可归一化、可验证、可在 resolver 前处理 action”。

市场 UI 的 companion 文件不能缓存 `market_cfg` 快照。`tests/suites/presentation/presentation_ui.lua` 里有通过 `package.loaded["src.presentation.view.render.market_view"] = nil` 再热重载主文件的用例，如果 companion 在 `require` 时把 `market_cfg` 建成静态索引，会让 `market_enabled=false` 相关断言读到旧配置。实施时已改成按调用读取配置。

`market_buy` 的 `normalize_action` 不能越过 `choice_resolver` 现有的“非法 option 保持 pending choice”语义。若在 normalizer 里直接校验商品存在性，会把原本应该记录 `invalid choice option` 的拒绝流打成 hard error。最终实现只负责数值归一化，把 option membership 继续留给 resolver。

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

## 结果与复盘

第一周工作已经完成，结果满足最初定义的三个目标。其一，`src/presentation/view/render/market_view.lua` 已缩成 76 行薄入口，槽位渲染和控件状态分别下沉到 `market_view_slots.lua` 与 `market_view_controls.lua`，`market_modal_renderer.lua` 和 `ui_view_service.lua` 的调用方式未改。其二，`src/presentation/view/widgets/ui_panel_presenter.lua` 已缩成 134 行 role 级编排入口，玩家槽位渲染与现金变化状态机分别下沉到 `ui_panel_player_slots.lua` 与 `ui_panel_cash_delta.lua`，`refresh(state, ui_model, deps)` 签名保持不变。其三，`choice_registry` / `intent_dispatcher` / `choice_resolver` 现在支持 descriptor 级归一化与验证钩子，`market_buy` 会在 `open_choice` 阶段提前拒绝未知 `player_id`，并在 `resolve` 早期把字符串 `option_id` 归一化为整数。

验收结果也符合预期。`lua -e '...presentation_ui...'` 继续通过，说明市场弹窗打开、翻页、页签切换、关闭、玩家面板头像与现金变化提示都没有回归。`lua -e '...domain.market..., ...gameplay.gameplay...'` 通过，说明 market 领域逻辑与 gameplay 主流程兼容新的 descriptor 钩子。最终 `lua tests/regression.lua` 输出 `All regression checks passed (384)`，并继续包含 `dep_rules ok`、`legacy_path_guard ok`、`tick ok`。

这轮实施最大的经验是：UI companion 可以拆，但不能把测试依赖的热重载语义和现有 resolver 失败语义一起“顺手优化”掉。后续如果继续拆别的 presentation 热点，优先保留现有入口与运行时副作用，只抽离内部编排。

## 背景与导读

本仓库的 UI 层主要在 `src/presentation/`。本周涉及的两个热点文件都属于“接口适配层”，也就是把领域状态和 runtime 状态投影成 UI 节点状态的那一层。`src/presentation/view/render/market_view.lua` 负责市场弹窗的槽位渲染、选中态、翻页按钮、页签按钮和关闭动作。它不应该理解新的业务规则，只应该编排现有市场数据如何显示到 UI。`src/presentation/view/widgets/ui_panel_presenter.lua` 负责基础玩家面板的标签、头像、头顶王冠、自动按钮、现金变化提示。它同样不应该承担新的业务逻辑，只应该把 `ui_model.panel` 渲染到节点。

Choice 相关逻辑主要在 `src/game/systems/choices/` 和 `src/game/flow/intent/`。这里的“descriptor”指的是 `choice_registry` 中每个 `choice.kind` 对应的一张表，当前最少包含 `execute`，有些 descriptor 还声明 `required_meta`。本周的目标是让 descriptor 除了声明“哪些字段必须有”，还可以声明“如何归一化 meta”和“如何验证 action”，这样 `market_buy` 的失败点可以更靠近边界。

与本周工作直接相关的文件有：`src/presentation/view/render/market_view.lua`、`src/presentation/view/support/ui_controls.lua`、`src/presentation/view/support/market_layout.lua`、`src/presentation/view/widgets/ui_panel_presenter.lua`、`src/presentation/model/ui_role_context.lua`、`src/game/systems/choices/choice_registry.lua`、`src/game/flow/intent/intent_dispatcher.lua`、`src/game/systems/choices/choice_resolver.lua`、`src/game/systems/choices/choice_handlers/market_choice_handler.lua`、`tests/suites/presentation/presentation_ui.lua`、`tests/suites/domain/market.lua`、`tests/suites/gameplay/gameplay.lua`。

当前已知基线是：`src/presentation/view/render/market_view.lua` 为 294 行，`src/presentation/view/widgets/ui_panel_presenter.lua` 为 294 行，`src/game/flow/intent/intent_dispatcher.lua` 为 114 行，`src/game/systems/choices/choice_registry.lua` 为 51 行，`src/game/systems/choices/choice_handlers/market_choice_handler.lua` 为 45 行。

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

## 工作计划

先做基线验证，再动 UI，再动 Choice。基线验证的目的不是走形式，而是确认本周所有回归锚点都可用。验证完成后，先改 `market_view`，因为它最集中体现了“重复 UI 状态编排”的问题，且已经有 `ui_controls` 和 `market_layout` 可复用，拆分收益最高。接着改 `ui_panel_presenter`，因为它也是 UI 入口，但与市场弹窗无共享状态，适合在第二个里程碑独立推进。最后再改 Choice descriptor 链路，因为这一步会同时触碰 `choice_registry`、`intent_dispatcher`、`choice_resolver` 和 market choice handler，越放在后面越能减少与 UI 重构交叉调试。

修改 `market_view` 时，不改变 `market_modal_renderer.lua` 的调用方式。主文件继续导出 `refresh_market_selection`、`select_market_option`、`refresh_market`、`close_market_panel`。新文件只承接内部 helper，不暴露新的跨层 API。修改 `ui_panel_presenter` 时，同样不改外部入口；`src/presentation/view/canvas/base/presenter.lua` 继续只调用 `panel_presenter.refresh(state, ui_model, deps)`。修改 Choice 契约时，所有数值归一化都使用 `src.core.utils.number_utils`，不允许重新引入 `tonumber` 或 `type(x) == "number"` 式分支。

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

## 验证与验收

第一周的验收必须同时覆盖 UI 和 Choice 两条线。UI 线的验证标准是：市场弹窗相关测试证明打开、重开、切页签、翻页、关闭行为不变；玩家面板相关测试证明头像、文本、现金变化提示和自动状态行为不变。Choice 线的验证标准是：`market_buy` 的非法输入可以在 descriptor/dispatcher/resolver 边界被更早拒绝，且测试能分辨不同失败原因，而不是只在 handler 深处收到通用断言。

如果需要人工 spot check，可以在修改后重点阅读 `tests/suites/presentation/presentation_ui.lua` 中市场段落和玩家面板段落，以及 `tests/suites/domain/market.lua`、`tests/suites/gameplay/gameplay.lua` 中 `market_buy` 相关 case，确认新增断言的名字与行为一致。最终仍以 `lua tests/regression.lua` 为准。

## 可重复性与恢复

这一周的所有改动都应当是增量可重复的。若某个里程碑中途失败，可以先回到最近一次通过测试的状态，再重做当前里程碑。恢复手段保持简单：对被修改的既有文件使用 `git checkout -- <path>`，对本周新增的 companion 文件使用 `rm <path>` 删除。每完成一个里程碑就运行对应 suite，不要把三个里程碑积到最后一起调试。

如果某个 companion 文件提取后发现只是在做无意义转发，应当立即回收，不要因为“计划里写了要拆”就保留死中间层。计划服务于可运行结果，不服务于人为制造文件数量。

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

## 接口与依赖

第一周结束时，Choice descriptor 至少应支持以下稳定结构：`execute(game, choice, action)` 仍然必选；`required_meta` 仍然是字符串数组；新增的 `normalize_meta(game, meta, choice_spec)` 返回归一化后的 `meta` 表；新增的 `meta_validator(game, meta, choice_spec)` 在发现非法输入时直接抛出带上下文的错误；新增的 `normalize_action(game, choice, action)` 返回归一化后的 `action` 表。`src/game/systems/choices/choice_registry.lua` 负责接纳这些字段，`src/game/flow/intent/intent_dispatcher.lua` 负责在 open choice 时调用前两个钩子，`src/game/systems/choices/choice_resolver.lua` 负责在 resolve 早期调用 `normalize_action`。

UI 侧不新增公共接口。`src/presentation/view/render/market_view.lua` 和 `src/presentation/view/widgets/ui_panel_presenter.lua` 的对外函数签名保持原样，这一点是第一周的硬约束。内部新模块只被同层主文件 require，不得向 `game/`、`core/ports/` 或 `infrastructure/` 扩散新的依赖。

所有数值解析继续统一走 `src.core.utils.number_utils`。这是仓库约束，不允许为了图省事重新写 `tonumber` 或 `type(x) == "number"` 分支。

更新记录（2026-03-08 12:10Z）：清空旧的 3.3 轮降线计划，改写为只覆盖第一周的可执行计划。这样做是因为 `.agents/research.md` 已切换为“下一步行动建议”，而旧计划仍围绕已过时的 LOC 压缩目标，会误导后续实施。

更新记录（2026-03-08 12:37Z）：完成第一周实施并把文档改成真实状态，补充了 companion 热重载约束、`market_buy` normalizer 边界、实际行数与全量回归结果。这样做是为了让后来者只看当前工作树和本文件，就能无歧义地继续后续周计划。
