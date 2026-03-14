# 顶层目录七层迁移执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。

## 目的 / 全局视角

这次改动要把仓库最外层目录从“懂架构的人才看得懂”的名字，改成“做大富翁玩法的人一眼就能定位”的名字。完成后，新人进入 `src/` 时，应该能直接顺着 `entry -> host -> ui -> turn -> player/computer -> rules -> state/config` 这条链路找到代码，而不是先理解 `app`、`presentation`、`game.flow`、`infrastructure` 这些历史分层。

这项工作是否真的完成，不看“目录像不像新架构图”，只看三件可观察的事。第一，运行入口和测试入口都可以通过新路径加载模块。第二，静态边界检查已经改成认识新目录，并且能继续阻止反向依赖和循环依赖。第三，下面四条基线命令在迁移期间和迁移结束后都保持通过：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua scripts/arch.lua check
    lua tests/guard.lua
    lua tests/behavior.lua
    lua tests/contract.lua

## 进度

- [x] (2026-03-14 12:05+08:00) 已核对 `.agents/harness/PLANS.md`、`.agents/harness/READING.md`、`.agents/harness/CODING.md`，明确本文件需要改成活文档式可执行计划。
- [x] (2026-03-14 12:18+08:00) 已核对当前仓库目录、`scripts/arch/config.lua`、`tests/guards/dep_rules.lua`、`docs/architecture/quality_map.md` 与核心启动模块，补齐原始概念稿里缺失的迁移约束。
- [x] (2026-03-14 12:42+08:00) 已把原始概念说明改写为可执行计划，并修正若干错误映射，尤其是 `bootstrap`、`events`、`host` 的归属。
- [ ] 里程碑 1：建立新顶层目录、双路径兼容策略和对应的架构护栏。
- [ ] 里程碑 2：迁移 `config`、`state`、`host` 三个低层支撑区，并让旧路径仅保留转发职责。
- [ ] 里程碑 3：迁移 `rules`、`player`、`computer`、`turn`，完成玩法主链切换。
- [ ] 里程碑 4：迁移 `ui` 与 `entry`，让外部入口和展示层都改用新目录。
- [ ] 里程碑 5：删除旧路径转发模块，收敛文档、测试、静态扫描配置，并做全量回归。

## 意外与发现

- 观察：`src/game/core/runtime/bootstrap.lua` 不是“程序启动入口”，而是规则注册器构建器。
  证据：文件直接 `require("src.game.systems.*")`，唯一公开接口是 `bootstrap.create_registries()`。
- 观察：`src/presentation/runtime/events.lua` 是 UI 事件名和广播助手，不是 Eggy 宿主事件桥。
  证据：文件扫描 `Data.UIManagerNodes`，导出的是 `show`、`hide`、`send_to_all`、`send_to_role`。
- 观察：`scripts/arch/config.lua` 与 `tests/guards/dep_rules.lua` 都硬编码了旧命名空间，不能等到最后再改。
  证据：当前规则直接匹配 `src.presentation.*`、`src.game.flow.*`、`src.game.systems.*`、`src.infrastructure.*`。
- 观察：当前质量基线是绿色，可以作为迁移过程的对照。
  证据：
    $ lua scripts/arch.lua check
    arch_view 检查通过 / arch_view check ok

    $ lua tests/guard.lua
    dep_rules ok
    gameplay_loop_no_ui ok
    forbidden_globals ok
    arch_view_guard ok

    $ lua tests/behavior.lua
    [behavior] mode=dev
    ...
    All regression checks passed (986)

    $ lua tests/contract.lua
    [contract] mode=dev
    ...
    All regression checks passed (103)

## 决策日志

- 决策：文档继续保留“七层模型”的叙事，但实际目录名统一使用 `turn` 和 `rules`，不落地 `turn_management` 与 `shared_mechanics`。
  理由：`turn`、`rules` 更短、更接近当前 require 习惯，也更容易写静态规则；叙事名可以留在文档解释层。
  日期/作者：2026-03-14 / Codex
- 决策：迁移采用“双路径过渡”，新目录先成为唯一实现，旧路径只保留最薄的转发模块。
  理由：仓库现有测试和护栏覆盖足够，增量迁移比一次性大搬家更容易定位回归点，也更符合 Clean Architecture 的“先切边界，再删旧壳”。
  日期/作者：2026-03-14 / Codex
- 决策：`src/game/core/runtime/bootstrap.lua` 不进入 `entry`，而是迁到 `src/rules/bootstrap/registries.lua`。
  理由：它依赖的是规则子系统，不是外层装配；把它放进 `entry` 会让启动层反向拥有业务注册细节。
  日期/作者：2026-03-14 / Codex
- 决策：`src/presentation/runtime/events.lua` 迁到 `src/ui/controllers/ui_events.lua`，真正的宿主事件桥来自 `src/infrastructure/runtime/event_bridge.lua`，后者迁到 `src/host/eggy/event_bridge.lua`。
  理由：一个是 UI 广播助手，一个是宿主自定义事件适配器，职责不同，不能混名。
  日期/作者：2026-03-14 / Codex
- 决策：本计划的第一完成标准不是立刻消灭全部 `src/core/*`，而是先让玩法主链入口全部搬到新顶层目录；仍有共享工具价值的 `src/core/utils/*`、`src/core/events/*` 可以在最后一轮再决定是否继续下沉。
  理由：这些目录目前更像横切辅助件，不宜为了目录整齐在第一轮强行拆散，避免把“命名重构”扩大成“基础设施重写”。
  日期/作者：2026-03-14 / Codex

## 结果与复盘

当前完成的是“把概念草案升级成能落地的计划”，还没有开始代码迁移。和原稿相比，这个版本补上了四类缺失信息：一是哪些现有文件必须移动，二是哪些旧路径需要转发过渡，三是哪些测试和静态扫描需要同步改，四是原稿中几处明显错误的归属判断。最大的剩余风险在于 `presentation/runtime` 与 `game/flow/turn/runtime` 这两块历史包裹较厚，真正实施时必须按里程碑逐层切，不要跨层混搬。后续每完成一个里程碑，都要回到这里更新真实进展、发现和是否需要缩小或扩大范围。

## 背景与导读

当前仓库的顶层语义由历史技术分层主导。`src/app` 负责装配和启动，`src/presentation` 负责 UI，`src/game/flow` 管理回合推进，`src/game/systems` 承担玩法规则，`src/game/ai` 负责 AI，`src/game/core/runtime` 同时承载运行态模型与装配，`src/infrastructure/runtime` 负责 Eggy 宿主细节，`Config/` 与 `src/core/config/` 分别保存静态表和运行配置。新手理解功能时，必须先把这些历史名词翻译成“大富翁玩法链路”。

本计划要把这种“先翻译后定位”的负担挪走。迁移完成后，`src/` 的主视图应接近下面这个树。它是主视图，不是穷举视图；某些辅助子目录如 `support/`、`ports/`、`bootstrap/` 会在具体里程碑中按需要出现。

    src/
      entry/
        boot.lua
        start_game.lua
        start_ui.lua
        wire_host.lua
        wire_events.lua
      host/
        eggy/
          context.lua
          default_ports.lua
          event_bridge.lua
          raycast.lua
          role_resolver.lua
          scene_ui.lua
          scheduler.lua
          sound.lua
          synthetic_actor_registry.lua
          units.lua
      ui/
        input/
        controllers/
        presenters/
        render/
        widgets/
        stores/
        schema/
      turn/
        auto/
        loop/
        phases/
        actions/
        policies/
        waits/
        timing/
        output/
          ports/
      player/
        choices/
        actions/
        policies/
      computer/
        policies/
        planners/
        evaluators/
        selectors/
      rules/
        bootstrap/
        board/
        chance/
        commerce/
        effects/
        endgame/
        items/
        land/
        market/
        movement/
        vehicle/
      state/
        game_state.lua
        player_state.lua
        board_state.lua
        turn_state.lua
        ui_state.lua
        state_access/
      config/
        gameplay/
        content/
        testing/

这里有三个必须先讲清的术语。第一，“转发模块”指的是旧路径文件不再保留业务实现，只写一行 `return require("新路径")`，用于给迁移中的旧调用点托底。第二，“主玩法链”指 `ui -> turn -> (player | computer) -> rules -> (state | config)` 这条用户能感知的游戏运行链路。第三，“支撑层”指 `entry` 和 `host`，它们负责装配和宿主接入，但不拥有玩法规则。

这份计划默认遵守下面这条依赖方向。`ui` 可以依赖 `turn`、`state`、`config`、`host`；`turn` 可以依赖 `player`、`computer`、`rules`、`state`、`config`、`host`；`player` 和 `computer` 只能向内依赖 `rules`、`state`、`config`；`rules` 只能依赖 `state` 和 `config`；`host` 不能回流依赖玩法主链；`entry` 是唯一允许做装配和默认实现选择的地方。`scripts/arch/config.lua` 最终必须表达这条规则。

和这次改动直接相关的现有关键文件是：`scripts/arch/config.lua`、`tests/guards/dep_rules.lua`、`tests/guards/gameplay_loop_no_ui.lua`、`tests/support/shared_support.lua`、`src/app/bootstrap/*`、`src/presentation/**/*`、`src/game/flow/**/*`、`src/game/scheduler/*`、`src/game/systems/**/*`、`src/game/ai/*`、`src/game/core/runtime/*`、`src/core/state_access/*`、`src/infrastructure/runtime/*`、`Config/*`。实施时只按需要打开这些路径，不要再次通读整个仓库。

## 工作计划

执行顺序采用“先立新壳，再搬实现，最后删旧壳”的方式。第一步先让新目录和旧目录同时存在，但只有新目录承载真实实现，旧目录退化成转发层。这样做的目的是把“路径变化”与“行为变化”分离：如果测试挂了，优先说明 require 路径或边界规则改错了，而不是玩法逻辑一起坏了。

迁移顺序必须从低层向高层推进。先搬 `config`、`state`、`host`，因为它们给更外层提供稳定读写能力和宿主封装；然后搬 `rules`、`player`、`computer`、`turn`，因为它们形成玩法主链；最后搬 `ui` 与 `entry`，因为这两层 require 最广，最适合在内层已经稳定之后一次切换。每一层切换完成后，都要把旧路径改成转发模块，并立即更新对应的测试与架构护栏。

本次迁移不追求在第一轮把所有“共享工具”彻底定居。`src/core/utils/logger.lua`、`src/core/utils/number_utils.lua`、`src/core/utils/role_id.lua`、`src/core/events/monopoly_events.lua` 这类横切工具，如果没有明显的唯一宿主，先允许保留旧路径并继续被新模块引用。它们不是主玩法链目录，不影响用户通过顶层目录理解系统。等玩法主链彻底切到新目录后，再决定是否需要单独的“shared”计划，而不是在这次任务里掺着做。

## 里程碑 1：建立新目录和过渡护栏

这一里程碑的目标不是搬业务，而是让仓库学会同时认识旧命名和新命名。完成后，开发者可以开始把一个子系统搬到新目录，而 `arch_view`、`guard`、`contract` 不会因为“目录名变了”而误报。验证标准是新增的双路径规则生效，且四条基线命令仍然通过。

先创建目标目录骨架，然后修改 `scripts/arch/config.lua`。在过渡期，旧路径和新路径应该被归到同一个逻辑组件里，例如 `src.presentation.*` 与 `src.ui.*` 同属 UI 组件，`src.game.systems.*` 与 `src.rules.*` 同属规则组件，`src.infrastructure.runtime.*` 与 `src.host.eggy.*` 同属宿主组件。禁止规则也要成对出现：既要防止 `src.presentation.* -> src.game.*`，也要防止 `src.ui.* -> src.turn.*` 之外的越界依赖。只有这样，迁移中途的模块不会从扫描器视角“掉出图外”。

接着修改 `tests/guards/dep_rules.lua`、`tests/guards/gameplay_loop_no_ui.lua`、任何直接 `require` 旧路径的架构契约测试，让它们接受“旧路径暂时允许存在，但只允许作为转发壳”这一现实。最稳妥的方法是增加一个新的契约用例，专门验证若干代表性模块的旧路径与新路径都能加载，而且二者导出的关键函数一致，例如 `src.app.bootstrap.runtime.global_aliases` 与 `src.entry.boot`、`src.infrastructure.runtime.event_bridge` 与 `src.host.eggy.event_bridge`。

## 里程碑 2：迁移 `config`、`state`、`host`

这一里程碑完成后，内层静态配置、运行态数据、Eggy 宿主封装都应该拥有新的 canonical 路径，后续所有玩法层迁移都只面向这些新路径。验证标准是：`Config.*`、`src.game.core.runtime.*` 的状态模型、`src.infrastructure.runtime.*` 的宿主桥接都已经有新家，旧文件只做转发，四条基线命令继续通过。

`config` 这部分要从两个来源收敛。`Config/generated/*` 迁到 `src/config/content/tables/*`，`Config/maps/*` 迁到 `src/config/content/maps/*`，`Config/runtime_refs.lua` 迁到 `src/config/content/refs.lua`，`Config/testing/*` 迁到 `src/config/testing/*`。同时把 `src/core/config/feature_toggles.lua`、`src/core/config/runtime_constants.lua`、`src/core/config/gameplay_rules.lua`、`src/core/config/vehicle_catalog.lua`、`src/core/config/config_sanity.lua` 分别搬到 `src/config/gameplay/` 或 `src/config/content/` 下。切换时先改被依赖最多的 require 调用点，再把旧文件替换成转发模块。

`state` 这部分至少包括 `src/game/core/runtime/game.lua`、`players.lua`、`tiles.lua`、`turn.lua`，以及整个 `src/core/state_access/`。目标路径分别是 `src/state/game_state.lua`、`src/state/player_state.lua`、`src/state/board_state.lua`、`src/state/turn_state.lua` 和 `src/state/state_access/*`。`src/presentation/runtime/canvas_state.lua` 应同时迁到 `src/state/ui_state.lua`，因为它描述的是运行态 UI 数据而不是渲染行为。`src/core/utils/dirty_tracker.lua` 跟着迁到 `src/state/state_access/dirty_tracker.lua`，因为它只为状态脏标记服务。

`host` 这部分来自两个历史来源。把 `src/infrastructure/runtime/context.lua`、`default_ports.lua`、`event_bridge.lua`、`synthetic_actor_registry.lua` 迁到 `src/host/eggy/`；再把 `src/presentation/runtime/host/scene_ui.lua`、`raycast.lua`、`sfx_runtime.lua`、`unit_lifecycle.lua`、`role_resolver.lua` 迁到 `src/host/eggy/`，其中 `sfx_runtime.lua` 改名为 `sound.lua`，`unit_lifecycle.lua` 改名为 `units.lua`。这里不要把 `src/presentation/runtime/events.lua` 一起搬进来，因为它不是宿主桥。

## 里程碑 3：迁移 `rules`、`player`、`computer`、`turn`

这一里程碑完成后，玩法主链的中段应该已经改成新目录，开发者可以只看 `src/rules`、`src/player`、`src/computer`、`src/turn` 理解大部分游戏逻辑。验证标准是：`src.game.systems.*`、`src.game.ai.*`、`src.game.flow.*`、`src.game.scheduler.*` 的真实实现已迁走，旧目录不再承载业务逻辑。

先做 `rules`。把 `src/game/systems/board`、`chance`、`commerce`、`effects`、`endgame`、`items`、`land`、`market`、`movement`、`vehicle` 整体迁到 `src/rules/` 同名目录。把 `src/game/core/runtime/bootstrap.lua` 改成 `src/rules/bootstrap/registries.lua`，因为它负责组装规则注册表。把 `src/game/ports/*.lua` 移到 `src/turn/output/ports/*.lua`，因为这些端口是 turn 用例对外发出的窄接口，而不是 rules 自己的实现细节。

然后做 `player` 和 `computer`。把 `src/game/systems/choices/*` 迁到 `src/player/choices/*`，把 `src/game/core/player/init.lua`、`inventory.lua`、`state_ops/*` 迁到 `src/player/actions/`。`computer` 的主要来源是 `src/game/ai/agent.lua` 与 `src/game/core/ai/agent.lua`。做法不要直接覆盖：先把前者迁成 `src/computer/policies/agent.lua`，再把后者临时迁成 `src/computer/policies/core_agent.lua`，对比两个文件的职责，把真正保留的公共 API 合并回 `agent.lua`，最后删掉 `core_agent.lua`。只有当两个旧 AI 文件都不再被任何调用点直接 require 时，才删除它们。

最后做 `turn`。`src/game/scheduler/init.lua`、`session.lua`、`action_router.lua` 迁到 `src/turn/loop/scheduler.lua`、`src/turn/loop/session.lua`、`src/turn/actions/router.lua`。`src/game/flow/turn/phases/*`、`policies/*`、`waits/*`、`auto/*`、`dispatch/*` 分别迁到 `src/turn/phases/*`、`src/turn/policies/*`、`src/turn/waits/*`、`src/turn/auto/*`、`src/turn/actions/*`。`src/game/flow/turn/runtime/loop_runtime.lua`、`scheduler_runtime.lua`、`session_script.lua`、`logger.lua` 迁到 `src/turn/loop/`；`tick_flow.lua` 与 `tick_steps.lua` 迁到 `src/turn/timing/`；`anim.lua`、`ports.lua`、`ui_sync_defaults.lua`、`src/game/flow/output_adapters/*` 和 `src/game/runtime/*` 迁到 `src/turn/output/`。`src/game/flow/intent/intent_dispatcher.lua` 则迁到 `src/turn/phases/intent_dispatcher.lua`。

## 里程碑 4：迁移 `ui` 与 `entry`

这一里程碑完成后，最外层入口和展示层都应该使用新目录。开发者从 `src/entry` 进入，顺着 `src/ui` 找交互，再顺着 `src/turn`、`src/rules` 找玩法，路径含义应当直接贴合游戏链路。验证标准是：应用启动模块、UI 运行时模块和所有展示测试夹具都改成新命名空间。

`ui` 的迁移不能只做目录重命名，必须顺手把归属理顺。`src/presentation/input/*` 迁到 `src/ui/input/*`；`src/presentation/model/*` 迁到 `src/ui/presenters/*`；`src/presentation/schema/*` 迁到 `src/ui/schema/*`；`src/presentation/view/render/*` 迁到 `src/ui/render/*`；`src/presentation/view/widgets/*` 迁到 `src/ui/widgets/*`；`src/presentation/view/support/*` 迁到 `src/ui/render/support/*`。`src/presentation/runtime/controllers/*` 迁到 `src/ui/controllers/*`。`src/presentation/runtime/canvas_state.lua`、`canvas_store.lua`、`event_state.lua`、`modal_state.lua`、`ui_runtime/*` 迁到 `src/ui/stores/`。`src/presentation/runtime/canvas_render_pipeline.lua` 与 `node_ops.lua` 更接近渲染层，应迁到 `src/ui/render/`。`src/presentation/runtime/events.lua` 迁到 `src/ui/controllers/ui_events.lua`，不要混入 `host`。

`entry` 的迁移要把真正的启动职责集中起来。`src/app/bootstrap/runtime/global_aliases.lua` 迁到 `src/entry/boot.lua`。`src/app/bootstrap/game_startup.lua` 迁到 `src/entry/start_game.lua`。`src/app/bootstrap/ui_bootstrap.lua` 迁到 `src/entry/start_ui.lua`。`src/app/bootstrap/game_runtime_bootstrap.lua` 迁到 `src/entry/wire_host.lua`。`src/app/bootstrap/game_startup_event_bridge.lua` 迁到 `src/entry/wire_events.lua`。`src/game/core/runtime/composition_root.lua` 也应并入 `src/entry/start_game.lua`，因为它负责把状态、规则注册器和 turn runtime 装进 `Game` 实例。迁移时要先保持公开函数签名不变，再切调用方。

## 里程碑 5：删除旧路径并收口

这一里程碑的目标是让旧目录真正退休，而不是永久留下双命名系统。完成后，`src/app/bootstrap/*`、`src/presentation/*`、`src/game/flow/*`、`src/game/systems/*`、`src/game/ai/*`、`src/game/scheduler/*`、`src/infrastructure/runtime/*`、`Config/*` 不应再作为生产代码入口存在。验证标准是：搜索不到生产代码对这些旧路径的 require，旧路径文件要么已删除，要么只剩极少量待后续计划处理的共享工具目录。

收尾时先用搜索确认还剩哪些旧路径调用点，再删转发模块。删掉转发模块后，立刻重跑四条基线命令，并额外运行一次旧路径搜索，确保不是“测试绿了但仓库里还埋着历史入口”。最后同步更新 `docs/architecture/boundaries.md`、`docs/architecture/arch_view.md`、任何引用旧目录的计划或说明文档，让文字描述和代码真相一致。

## 具体步骤

下面的命令按推荐顺序给出。所有命令都在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。命令块里的 `git mv` 只列关键路径；遇到同一子树里的剩余文件，按相同规则继续移动，不要混用手工复制与删除。

先冻结基线，确认工作树在迁移前是绿色：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua scripts/arch.lua check
    lua tests/guard.lua
    lua tests/behavior.lua
    lua tests/contract.lua

建立骨架目录：

    mkdir -p \
      src/entry \
      src/host/eggy \
      src/ui src/ui/stores \
      src/turn src/turn/loop src/turn/actions src/turn/timing src/turn/output \
      src/player/actions \
      src/computer/policies \
      src/rules src/rules/bootstrap \
      src/state \
      src/config src/config/gameplay src/config/content

迁移 `config` 与 `state`：

    git mv Config/generated src/config/content/tables
    git mv Config/maps src/config/content/maps
    git mv Config/testing src/config/testing
    git mv Config/runtime_refs.lua src/config/content/refs.lua
    git mv src/core/config/feature_toggles.lua src/config/gameplay/feature_toggles.lua
    git mv src/core/config/runtime_constants.lua src/config/gameplay/constants.lua
    git mv src/core/config/gameplay_rules.lua src/config/gameplay/rules.lua
    git mv src/core/config/config_sanity.lua src/config/gameplay/config_sanity.lua
    git mv src/core/config/vehicle_catalog.lua src/config/content/vehicles.lua
    git mv src/game/core/runtime/game.lua src/state/game_state.lua
    git mv src/game/core/runtime/players.lua src/state/player_state.lua
    git mv src/game/core/runtime/tiles.lua src/state/board_state.lua
    git mv src/game/core/runtime/turn.lua src/state/turn_state.lua
    git mv src/core/state_access src/state/state_access
    git mv src/core/utils/dirty_tracker.lua src/state/state_access/dirty_tracker.lua

迁移 `host`：

    git mv src/infrastructure/runtime/context.lua src/host/eggy/context.lua
    git mv src/infrastructure/runtime/default_ports.lua src/host/eggy/default_ports.lua
    git mv src/infrastructure/runtime/event_bridge.lua src/host/eggy/event_bridge.lua
    git mv src/infrastructure/runtime/synthetic_actor_registry.lua src/host/eggy/synthetic_actor_registry.lua
    git mv src/presentation/runtime/host/scene_ui.lua src/host/eggy/scene_ui.lua
    git mv src/presentation/runtime/host/raycast.lua src/host/eggy/raycast.lua
    git mv src/presentation/runtime/host/sfx_runtime.lua src/host/eggy/sound.lua
    git mv src/presentation/runtime/host/unit_lifecycle.lua src/host/eggy/units.lua
    git mv src/presentation/runtime/host/role_resolver.lua src/host/eggy/role_resolver.lua

迁移 `rules`、`player`、`computer`、`turn`：

    git mv src/game/systems/board src/rules/board
    git mv src/game/systems/chance src/rules/chance
    git mv src/game/systems/commerce src/rules/commerce
    git mv src/game/systems/effects src/rules/effects
    git mv src/game/systems/endgame src/rules/endgame
    git mv src/game/systems/items src/rules/items
    git mv src/game/systems/land src/rules/land
    git mv src/game/systems/market src/rules/market
    git mv src/game/systems/movement src/rules/movement
    git mv src/game/systems/vehicle src/rules/vehicle
    git mv src/game/core/runtime/bootstrap.lua src/rules/bootstrap/registries.lua
    git mv src/game/systems/choices src/player/choices
    git mv src/game/core/player/init.lua src/player/actions/player_state.lua
    git mv src/game/core/player/inventory.lua src/player/actions/inventory.lua
    git mv src/game/core/player/state_ops src/player/actions/state_ops
    git mv src/game/ai/agent.lua src/computer/policies/agent.lua
    git mv src/game/core/ai/agent.lua src/computer/policies/core_agent.lua
    git mv src/game/scheduler/init.lua src/turn/loop/scheduler.lua
    git mv src/game/scheduler/session.lua src/turn/loop/session.lua
    git mv src/game/scheduler/action_router.lua src/turn/actions/router.lua
    git mv src/game/flow/turn/auto src/turn/auto
    git mv src/game/flow/turn/phases src/turn/phases
    git mv src/game/flow/turn/policies src/turn/policies
    git mv src/game/flow/turn/waits src/turn/waits
    git mv src/game/flow/turn/dispatch/* src/turn/actions/
    git mv src/game/flow/turn/loop.lua src/turn/loop/init.lua
    git mv src/game/flow/turn/runtime/loop_runtime.lua src/turn/loop/runtime.lua
    git mv src/game/flow/turn/runtime/scheduler_runtime.lua src/turn/loop/scheduler_runtime.lua
    git mv src/game/flow/turn/runtime/session_script.lua src/turn/loop/session_script.lua
    git mv src/game/flow/turn/runtime/logger.lua src/turn/loop/logger.lua
    git mv src/game/flow/turn/runtime/tick_flow.lua src/turn/timing/tick_flow.lua
    git mv src/game/flow/turn/runtime/tick_steps.lua src/turn/timing/tick_steps.lua
    git mv src/game/flow/turn/runtime/decision.lua src/turn/actions/decision.lua
    git mv src/game/flow/turn/runtime/anim.lua src/turn/output/anim.lua
    git mv src/game/flow/turn/runtime/ports.lua src/turn/output/ports.lua
    git mv src/game/flow/turn/runtime/ui_sync_defaults.lua src/turn/output/ui_sync_defaults.lua
    git mv src/game/flow/output_adapters/intent_output_adapter.lua src/turn/output/intent_output_adapter.lua
    git mv src/game/flow/output_adapters/output_state_adapter.lua src/turn/output/output_state_adapter.lua
    git mv src/game/flow/intent/intent_dispatcher.lua src/turn/phases/intent_dispatcher.lua
    git mv src/game/runtime/auto_play_port_adapter.lua src/turn/output/auto_play_port_adapter.lua
    git mv src/game/runtime/bankruptcy_port_adapter.lua src/turn/output/bankruptcy_port_adapter.lua
    git mv src/game/runtime/default_ports.lua src/turn/output/default_ports.lua
    git mv src/game/ports src/turn/output/ports

迁移 `ui` 与 `entry`：

    git mv src/presentation/input src/ui/input
    git mv src/presentation/model src/ui/presenters
    git mv src/presentation/schema src/ui/schema
    git mv src/presentation/view/render src/ui/render
    git mv src/presentation/view/widgets src/ui/widgets
    git mv src/presentation/runtime/controllers src/ui/controllers
    git mv src/presentation/runtime/canvas_state.lua src/ui/stores/canvas_state.lua
    git mv src/presentation/runtime/canvas_store.lua src/ui/stores/canvas_store.lua
    git mv src/presentation/runtime/event_state.lua src/ui/stores/event_state.lua
    git mv src/presentation/runtime/modal_state.lua src/ui/stores/modal_state.lua
    git mv src/presentation/runtime/ui_runtime src/ui/stores/runtime
    git mv src/presentation/runtime/actor_context.lua src/ui/controllers/actor_context.lua
    git mv src/presentation/runtime/canvas_coordinator.lua src/ui/controllers/canvas_coordinator.lua
    git mv src/presentation/runtime/canvas_event_router.lua src/ui/controllers/canvas_event_router.lua
    git mv src/presentation/runtime/canvas_render_pipeline.lua src/ui/render/canvas_render_pipeline.lua
    git mv src/presentation/runtime/deps.lua src/ui/controllers/deps.lua
    git mv src/presentation/runtime/event_bindings.lua src/ui/controllers/event_bindings.lua
    git mv src/presentation/runtime/event_handlers.lua src/ui/controllers/event_handlers.lua
    git mv src/presentation/runtime/events.lua src/ui/controllers/ui_events.lua
    git mv src/presentation/runtime/local_actor_resolver.lua src/ui/controllers/local_actor_resolver.lua
    git mv src/presentation/runtime/node_ops.lua src/ui/render/node_ops.lua
    git mv src/presentation/runtime/ui.lua src/ui/controllers/ui.lua
    git mv src/presentation/runtime/ports src/ui/controllers/ports
    git mv src/presentation/view/support src/ui/render/support
    git mv src/app/bootstrap/runtime/global_aliases.lua src/entry/boot.lua
    git mv src/app/bootstrap/game_startup.lua src/entry/start_game.lua
    git mv src/app/bootstrap/ui_bootstrap.lua src/entry/start_ui.lua
    git mv src/app/bootstrap/game_runtime_bootstrap.lua src/entry/wire_host.lua
    git mv src/app/bootstrap/game_startup_event_bridge.lua src/entry/wire_events.lua

每完成一个子系统移动，立刻把旧路径文件改成转发模块，然后统一修 require 路径。修完一个里程碑就跑一次回归，不要累计到最后：

    lua scripts/arch.lua check
    lua tests/guard.lua

完成一个大里程碑后，再补跑行为与契约：

    lua tests/behavior.lua
    lua tests/contract.lua

最后，确认旧路径已经退场：

    rg -n 'require\\("(Config\\.|src\\.(app|presentation|game|infrastructure))' src tests

成功标准是搜索结果只剩计划允许保留的共享工具路径，或者剩余命中全部位于待删除的转发模块中；若仍有生产实现文件命中，继续收口，不要宣告完成。

## 验证与验收

验收必须覆盖“结构正确”和“行为没坏”两类结果。结构正确由 `lua scripts/arch.lua check`、`lua tests/guard.lua` 与旧路径搜索共同证明。行为没坏由 `lua tests/behavior.lua` 与 `lua tests/contract.lua` 证明。只通过编译或只通过单条测试都不够，因为这次任务的风险正是目录切换导致的静态边界漂移与隐藏入口残留。

迁移结束时，至少要看到以下现象同时成立：一，四条基线命令全部通过；二，新增或更新的架构契约测试能同时验证代表性旧路径转发和新路径 canonical 模块；三，删除转发模块后的最终搜索不再出现 `Config.*`、`src.app.bootstrap.*`、`src.presentation.*`、`src.game.systems.*`、`src.game.flow.*`、`src.game.ai.*`、`src.game.scheduler.*`、`src.infrastructure.runtime.*` 这些旧生产入口。

如果某一轮只做了中途里程碑，还没有删旧路径，那么验收语句要写成“新路径真实实现已生效，旧路径只剩转发壳，四条基线命令通过”。不要把“旧路径仍能 require”误认为未完成；在里程碑 1 到 4 中，这恰好是计划要求的安全过渡行为。

## 可重复性与恢复

整个方案按里程碑设计，就是为了让重试成本可控。每完成一个里程碑并验证通过后，立刻提交一次小 commit。这样某个子系统切换失败时，可以只恢复本里程碑涉及的路径，而不是把整个大搬迁一起回滚。恢复时只处理当前里程碑碰过的文件，不要碰无关工作树。

目录移动优先用 `git mv`，这样历史保留更好，重复执行时也更容易看出哪些路径已经迁过。转发模块的改写是幂等的：旧文件一旦只剩 `return require("新路径")`，后续重复执行不会改变行为。真正不幂等的是“把两个实现文件合并成一个”的步骤，例如 AI 合并；这类步骤必须在本计划的“决策日志”里记录保留了哪些公开函数，删掉了哪些重复实现。

## 产物与备注

下面这些短输出是本计划写作时记录的基线证据，后续实施时应继续保留类似证据，但只保留关键行：

    $ lua scripts/arch.lua check
    arch_view 检查通过 / arch_view check ok

    $ lua tests/guard.lua
    dep_rules ok
    gameplay_loop_no_ui ok
    forbidden_globals ok
    arch_view_guard ok

    $ lua tests/behavior.lua
    [behavior] mode=dev
    ...
    All regression checks passed (986)

    $ lua tests/contract.lua
    [contract] mode=dev
    ...
    All regression checks passed (103)

如果后续某次实施后基线数量变化，例如 behavior case 数或 contract case 数更新，应在“意外与发现”记录新数字和原因，不要直接覆写旧证据而不解释。

## 接口与依赖

迁移时不要顺手改公开 API 名字，先保持“路径变化，接口不变”。下面这些接口必须在新路径继续存在，除非有明确决策记录说明为何改名。`src/entry/boot.lua` 必须继续提供 `install(env)`。`src/entry/start_game.lua` 必须承接 `src/app/bootstrap/game_startup.lua` 的公开入口，并吸收 `src/game/core/runtime/composition_root.lua` 的装配职责。`src/entry/start_ui.lua` 必须继续提供 UI 启动安装函数。`src/entry/wire_host.lua` 必须承接 `src/app/bootstrap/game_runtime_bootstrap.lua` 的启动接线职责。`src/entry/wire_events.lua` 必须承接 `src/app/bootstrap/game_startup_event_bridge.lua` 的运行时事件订阅职责。

`src/state/game_state.lua` 必须继续导出当前 `Game` 类型的公开行为，包括 `advance_turn()`、`dispatch_action(action)`、`rebuild()`、`mark_players_dirty()`、`mark_board_dirty()`。`src/rules/bootstrap/registries.lua` 必须继续导出 `create_registries()`。`src/turn/output/default_ports.lua` 必须继续提供当前 `src/game/runtime/default_ports.lua` 的能力，至少保留 `resolve_game_opts(opts)` 与 `install(game)`。`src/host/eggy/default_ports.lua` 必须继续提供当前宿主时间、随机数、事件发射和角色解析能力。`src/ui/controllers/ui_events.lua` 必须继续提供 `set_roles(roles)`、`send_to_all(event_name, payload)` 与 `send_to_role(role, event_name, payload)`。

静态依赖的唯一真源是 `scripts/arch/config.lua`。文本级硬边界的唯一真源是 `tests/guards/dep_rules.lua`。运行回归的入口是 `tests/behavior.lua`、`tests/contract.lua`、`tests/guard.lua`。任何一次目录迁移只要影响这些真源之一，都必须在同一个里程碑里同步改完，不能留到下一轮。

## 本次改写说明

这次改写把原来的概念草图升级成了符合 `.agents/harness/PLANS.md` 的可执行计划。主要变化是补上了活文档章节、里程碑、具体命令、验证标准和恢复策略，并纠正了原稿里几处会误导实施者的归属问题，例如把规则注册器错写成 `entry`、把 UI 事件助手错写成 `host event_bridge`。这样做的原因是：没有这些信息，下一位执行者即使理解了“想要什么目录”，也很难安全地把仓库迁过去。
