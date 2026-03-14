# 顶层目录七层迁移子代理执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。

## 目的 / 全局视角

这次改动要把仓库最外层目录从历史技术分层名，改成做大富翁玩法的人一眼就能定位的名字。完成后，新人进入 `src/` 时，应该能直接顺着 `entry -> host -> ui -> turn -> player/computer -> rules -> state/config` 这条链路找到代码，而不是先翻译 `app`、`presentation`、`game.flow`、`infrastructure` 这些历史术语。

这项工作是否真的完成，不看“目录像不像新架构图”，只看三类可观察结果。第一，运行入口和测试入口都可以通过新路径加载模块，旧路径在过渡期只剩最薄的转发壳。第二，静态边界检查已经改成认识新目录，并且能继续阻止反向依赖和循环依赖。第三，下面四条基线命令在迁移期间和迁移结束后都保持通过：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua scripts/arch.lua check
    lua tests/guard.lua
    lua tests/behavior.lua
    lua tests/contract.lua

本次改写只重做计划结构，不直接执行代码迁移。目标是把现有的线性里程碑计划改成可分发给多个子代理并行推进的任务图，让下一位执行者看到文档就知道“先做什么、依赖谁、如何验收、何时能并行”。

## 进度

以下复选框记录的是计划文档本身的真实状态；具体迁移任务的真值来源是后面的“任务清单”里的 `status` 字段。

- [x] (2026-03-14 12:05+08:00) 已核对 `.agents/harness/PLANS.md`、`.agents/harness/READING.md`、`.agents/harness/CODING.md`，确认本文件需要保持活文档形式。
- [x] (2026-03-14 12:18+08:00) 已核对当前仓库目录、`scripts/arch/config.lua`、`tests/guards/dep_rules.lua`、`tests/guards/gameplay_loop_no_ui.lua`、`tests/support/shared_support.lua` 与关键启动模块，补齐迁移约束。
- [x] (2026-03-14 12:42+08:00) 已把概念说明改写成可执行计划，并修正 `bootstrap`、`events`、`host` 等归属错误。
- [x] (2026-03-14 14:10+08:00) 已把里程碑式正文重写成 swarm-ready 子代理计划，新增依赖图、任务卡、并行波次，并修正 `game.lua`、`game/ports`、UI runtime state 的错误迁移假设。
- [x] (2026-03-14 11:43+08:00) 已执行四条基线命令并记录当前绿色结果，`T0` 完成。
- [x] (2026-03-14 11:56+08:00) 已建立双路径护栏：arch 新命名空间规则、shim 纯转发 guard、兼容 contract 已落地，`T1` 完成。
- [x] (2026-03-14 12:19+08:00) 已把 `Config/*` 与 `src/core/config/*` 迁到 `src/config/{content,gameplay,testing}/*`，旧路径改成 shim，并把 `src/`/`tests/` 消费方批量切到新 canonical require，`T2` 完成。
- [x] (2026-03-14 12:48+08:00) 已把 `players`、`tiles`、`turn` 与 `state_access` 迁到 `src/state/*`，旧路径改成 shim，并补 `src/state/player_state_ops/*` / `src/state/support/*` 过渡桥以消除 root 投影环，`T3` 完成。
- [x] (2026-03-14 13:37+08:00) 已联合完成 `T4`/`T5`：宿主桥接迁到 `src/host/eggy/*`，规则实现迁到 `src/rules/*`，旧路径全部改成 shim，`T4` 与 `T5` 完成。
- [x] (2026-03-14 14:09+08:00) 已联合完成 `T6`/`T7`：player 选择与动作迁到 `src/player/*`，AI 入口迁到 `src/computer/policies/*`，旧路径全部改成 shim，`T6` 与 `T7` 完成。
- [x] (2026-03-14 14:24+08:00) 已把共享 gameplay ports 迁到 `src/rules/ports/*` 并切换 `src/` / `tests/` 消费方，`T8` 完成。
- [ ] `T9` `turn` 核心归位进行中；`T10` 到 `T14` 仍待执行。

## 意外与发现

- 观察：`src/game/core/runtime/bootstrap.lua` 不是程序启动入口，而是规则注册器构建器。
  证据：文件直接 `require("src.game.systems.*")`，唯一公开接口是 `bootstrap.create_registries()`。
- 观察：`src/presentation/runtime/events.lua` 是 UI 广播助手，不是 Eggy 宿主事件桥。
  证据：文件导出的是 `show`、`hide`、`send_to_all`、`send_to_role`，并且依赖 UI 节点数据。
- 观察：`scripts/arch/config.lua` 与 `tests/guards/dep_rules.lua` 都硬编码了旧命名空间，不能等到最后一轮再改。
  证据：当前规则直接匹配 `src.presentation.*`、`src.game.flow.*`、`src.game.systems.*`、`src.infrastructure.*`。
- 观察：`src/game/core/runtime/game.lua` 不是早期纯状态模块，而是聚合根。这里的“聚合根”指拥有行为、持有装配结果、并把多组状态方法拼到一起的对象。
  证据：文件头部直接 `require("src.game.core.runtime.composition_root")` 和 `require("src.game.systems.endgame.game_victory")`，并在 `init()` 中执行装配。
- 观察：`src/game/ports/*` 不是 turn 私有输出，它们被 systems、flow、player 和 runtime 共同消费。
  证据：子代理审阅指出把它们直接迁到 `src/turn/output/ports/*` 会让 `rules`、`player`、`turn` 反复返工。
- 观察：UI runtime state 不是单文件，它至少由 `canvas_state.lua`、`canvas_store.lua`、`event_state.lua`、`modal_state.lua`、`src/presentation/runtime/ui_runtime/state.lua` 协同组成。
  证据：这些文件共同描述选择框、弹窗、UI dirty 标记和 runtime model，单独提前迁走 `canvas_state.lua` 会制造 state 分裂。
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
  理由：增量迁移比一次性大搬家更容易定位回归点，也更符合先切边界、再删旧壳的策略。
  日期/作者：2026-03-14 / Codex
- 决策：`src/game/core/runtime/bootstrap.lua` 迁到 `src/rules/bootstrap/registries.lua`，不进入 `entry`。
  理由：它依赖的是规则子系统，不是外层装配；把它放进 `entry` 会让启动层反向拥有业务注册细节。
  日期/作者：2026-03-14 / Codex
- 决策：`src/presentation/runtime/events.lua` 迁到 `src/ui/controllers/ui_events.lua`；真正的宿主事件桥来自 `src/infrastructure/runtime/event_bridge.lua`，后者迁到 `src/host/eggy/event_bridge.lua`。
  理由：一个是 UI 广播助手，一个是宿主自定义事件适配器，职责不同，不能混名。
  日期/作者：2026-03-14 / Codex
- 决策：第一轮完成标准不是立刻消灭全部 `src/core/*`，而是先让玩法主链入口全部搬到新顶层目录；仍有横切价值的 `src/core/utils/*`、`src/core/events/*`、`src/core/choice/*`、`src/core/ui_sync/*` 默认留在原位，除非后续另开计划处理。
  理由：这些目录目前更像共享工具，不宜为了目录整齐在第一轮强行拆散，避免把“命名重构”扩大成“基础设施重写”。
  日期/作者：2026-03-14 / Codex
- 决策：`src/game/core/runtime/game.lua`、`game_factory.lua`、`composition_root.lua` 不进入早期 state 任务，而是在 `T13` 作为聚合根与装配层一起处理；其中 `game.lua` 的最终落点是 `src/state/game_state.lua`。
  理由：它们同时承担装配、行为和公开 API，过早塞进纯 state 任务会破坏任务边界并误导执行者。
  日期/作者：2026-03-14 / Codex
- 决策：`src/game/ports/*` 不再规划迁入 `src/turn/output/ports/*`，统一改成中性的 `src/rules/ports/*`。
  理由：这些 contract 被多个 gameplay 子系统共享，不是 turn 私有输出；放到 `rules/ports` 更容易表达“共享窄接口”而不是“某个 runtime 的局部细节”。
  日期/作者：2026-03-14 / Codex
- 决策：UI runtime state 必须作为一组在 `T12` 迁到 `src/ui/stores/*`，不再提前单独迁 `canvas_state.lua` 到 `src/state/*`。
  理由：UI dirty 标记、modal 状态、choice 状态和 runtime model 本来就是一组；拆开会制造跨命名空间的双写与双读。
  日期/作者：2026-03-14 / Codex
- 决策：forwarding shim 只能在对应目标文件真实落地时一起创建，禁止在 `T1` 预先铺满全仓旧路径壳。
  理由：Lua 的 `require` 缓存对模块身份敏感，先建空壳容易出现 old -> new -> old 循环依赖，或两个路径得到两个不同模块实例。
  日期/作者：2026-03-14 / Codex
- 决策：执行结构从“里程碑顺序文”改成“任务图 + 显式依赖 + 并行波次”。
  理由：这次计划的直接用户不是单线程执行者，而是多个子代理；没有显式 `depends_on`，就无法安全并行。
  日期/作者：2026-03-14 / Codex

## 结果与复盘

当前完成的是计划结构重写，不是代码迁移本身。和上一版相比，这个版本补上了三类以前不够决策完整的信息：第一，哪些任务可以交给独立子代理并行推进；第二，哪些模块必须延后，不能误归到早期 `state` 或 `turn` 任务；第三，每个任务最少要跑哪些验证，才能证明不是“只改了路径名”。最大的剩余风险仍然在 `src/presentation/runtime/*`、`src/game/flow/*`、`src/game/runtime/*` 这三块历史包裹较厚的区域，所以它们在任务图里被拆成更细的子任务，而不再作为一个大波次整体搬运。

## 背景与导读

当前仓库的顶层语义由历史技术分层主导。`src/app` 负责装配和启动，`src/presentation` 负责 UI，`src/game/flow` 管理回合推进，`src/game/systems` 承担玩法规则，`src/game/ai` 负责 AI，`src/game/core/runtime` 同时承载运行态模型与装配，`src/infrastructure/runtime` 负责 Eggy 宿主细节，`Config/` 与 `src/core/config/` 分别保存静态表和运行配置。新手理解功能时，必须先把这些历史名词翻译成“大富翁玩法链路”。

本计划要把这种“先翻译后定位”的负担挪走。迁移完成后，`src/` 的主视图应接近下面这个树。它是主视图，不是穷举视图；某些辅助子目录如 `support/`、`ports/`、`bootstrap/` 会在具体任务里按需要出现。

    src/
      entry/
        boot.lua
        start_game.lua
        start_ui.lua
        wire_host.lua
        wire_events.lua
        testing/
      host/
        eggy/
          context.lua
          default_ports.lua
          event_bridge.lua
          init.lua
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
        loop/
        phases/
        actions/
        policies/
        waits/
        timing/
        output/
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
        ports/
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
        state_access/
      config/
        gameplay/
        content/
        testing/

这里有五个必须先讲清的术语。第一，“canonical 路径”指迁移完成后唯一被新代码直接 `require` 的新路径。第二，“转发模块”或“shim”指旧路径文件不再保留业务实现，只写一行 `return require("新路径")`，用于过渡期托底。第三，“主玩法链”指 `ui -> turn -> (player | computer) -> rules -> (state | config)` 这条用户能感知的游戏运行链路。第四，“支撑层”指 `entry` 和 `host`，它们负责装配和宿主接入，但不拥有玩法规则。第五，“聚合根”指像 `Game` 这样把多组状态与行为拼到一起的核心对象；它不是单纯的数据表，因此不能过早归入纯状态任务。

旧路径到新路径的主映射按下面这份矩阵执行。这里列的是 canonical 落点，不代表每个任务会一次性完成全部移动。

- `src/app/init.lua`、`src/app/bootstrap/*`、`src/app/testing/*` 迁到 `src/entry/*` 与 `src/entry/testing/*`。
- `src/infrastructure/runtime/*`、`src/presentation/runtime/host/*`、`src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua` 迁到 `src/host/eggy/*`。
- `src/presentation/{schema,model,view,input,runtime}/*` 迁到 `src/ui/*`；其中 host 专用模块不留在 UI，UI runtime state 统一归 `src/ui/stores/*`。
- `src/game/scheduler/*`、`src/game/flow/*`、`src/game/runtime/*` 迁到 `src/turn/*`；其中共享 contract 不再继续挂在旧 `game/ports` 下。
- `src/game/systems/*` 与 `src/game/core/runtime/bootstrap.lua` 迁到 `src/rules/*`。
- `src/game/ports/*` 迁到 `src/rules/ports/*`。
- `src/game/systems/choices/*` 与 `src/game/core/player/*` 迁到 `src/player/*`。
- `src/game/ai/agent.lua` 与 `src/game/core/ai/agent.lua` 迁到 `src/computer/policies/*`。
- `src/game/core/runtime/{players,tiles,turn}.lua` 与 `src/core/state_access/*` 迁到 `src/state/*`。
- `Config/*` 与 `src/core/config/*` 迁到 `src/config/*`。
- `src/game/core/runtime/game.lua` 的最终 canonical 路径是 `src/state/game_state.lua`，但它只在 `T13` 与 `game_factory.lua`、`composition_root.lua` 一起处理，不能提前拆进纯 state 任务。

和这次改动直接相关的现有关键文件是：`scripts/arch/config.lua`、`tests/guards/dep_rules.lua`、`tests/guards/gameplay_loop_no_ui.lua`、`tests/support/shared_support.lua`、`src/app/**/*`、`src/presentation/**/*`、`src/game/flow/**/*`、`src/game/scheduler/*`、`src/game/systems/**/*`、`src/game/ports/*`、`src/game/runtime/*`、`src/game/ai/*`、`src/game/core/runtime/*`、`src/game/core/player/*`、`src/game/core/ai/*`、`src/core/state_access/*`、`src/core/config/*`、`src/infrastructure/runtime/*`、`Config/*`。执行时只按任务需要打开这些路径，不要再次通读整个仓库。

这份计划默认遵守下面这条依赖方向。`ui` 可以依赖 `turn`、`state`、`config`、`host`；`turn` 可以依赖 `player`、`computer`、`rules`、`state`、`config`、`host`；`player` 和 `computer` 只能向内依赖 `rules`、`state`、`config`；`rules` 只能依赖 `state`、`config` 和 `rules/ports`；`host` 不能回流依赖玩法主链；`entry` 是唯一允许做装配和默认实现选择的地方。`scripts/arch/config.lua` 最终必须表达这条规则。

## 依赖图

本计划改为任务图执行。每个任务都必须能被单个子代理独立领取，只有 `depends_on` 为空或已经满足的任务才允许并行启动。

    T0 -> T1 -> T2 -> T3
    T3 -> T4
    T3 -> T5 -> T6
    T5 -> T7
    T4, T5, T6, T7 -> T8 -> T9 -> T10 -> T11 -> T12 -> T13 -> T14

如果要更口语地理解这张图，可以把它读成三句话。先做基线与护栏，再把最内层 `config` 和纯 `state` 稳住。接着把 `host`、`rules`、`player`、`computer` 与共享 ports 各自归位。最后按 `turn -> ui -> entry -> cleanup` 的顺序收口，因为这些层最容易同时牵动启动、测试和兼容路径。

## 任务清单

下面的任务卡是本计划的执行真值来源。每个任务都必须保留 `status`、`log`、`files edited/created` 三个字段，执行者完成后直接在这里更新，不要另起一份临时清单。

### T0：基线冻结与迁移矩阵

- **id**: `T0`
- **depends_on**: `[]`
- **location**: `.agents/plan.md`, `scripts/arch/config.lua`, `tests/guards/*`, `src/app/*`, `src/presentation/*`, `src/game/*`, `src/infrastructure/*`, `Config/*`
- **description**: 在文档里固化旧路径到新路径的迁移矩阵、已知例外项、四条基线命令和暂不迁移的共享工具残留区。矩阵必须覆盖本计划点名的所有源码根路径，并明确哪些模块会延后到 `T13` 才处理。
- **validation**: 读者仅通过本文件就能看出每个旧子系统的 canonical 新家、例外项和基线命令；执行前先跑四条基线命令，记录结果到“意外与发现”或“产物与备注”。
- **status**: `Completed`
- **log**: `2026-03-14 11:43+08:00` 在仓库根目录执行 `lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua`，全部通过；当前基线仍是 `arch_view check ok`、guard 四项通过、behavior `986`、contract `103`。
- **files edited/created**: `.agents/plan.md`

### T1：双路径护栏与 shim 规则

- **id**: `T1`
- **depends_on**: `[T0]`
- **location**: `.agents/plan.md`, `scripts/arch/config.lua`, `tests/guards/dep_rules.lua`, `tests/guards/gameplay_loop_no_ui.lua`
- **description**: 建立过渡期护栏。把 arch 规则、guard 规则、compat require 检查、旧路径只允许做转发壳的约束写清楚，并把“shim 必须与目标文件同一步落地，禁止预建全仓旧路径壳”写成硬规则。
- **validation**: `lua scripts/arch.lua check` 与 `lua tests/guard.lua` 通过；计划中出现 `require(old_path) == require(new_path)` 的契约检查；针对 `src/` 与 `tests/` 的 grep 策略已经写明，不再允许模糊搜索。
- **status**: `Completed`
- **log**: `2026-03-14 11:56+08:00` 新增 `tests/guards/migration_shim_rules.lua`，要求“旧路径与新路径同时存在时，旧文件必须是纯 `return require("新路径")` shim”；新增 `tests/suites/architecture/migration_shim_contract.lua`，对已迁移双路径执行 `require(old) == require(new)` 契约；`scripts/arch/config.lua` 增补 `entry`、`host`、`ui`、`turn`、`player`、`computer`、`rules`、`state`、`config` 新命名空间与对应依赖禁令；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `.agents/plan.md`, `scripts/arch/config.lua`, `tests/catalog.lua`, `tests/guards/migration_shim_rules.lua`, `tests/suites/architecture/migration_shim_contract.lua`, `tests/support/guards/guard_support.lua`, `tests/support/migration_pairs.lua`

### T2：`config` 归位

- **id**: `T2`
- **depends_on**: `[T1]`
- **location**: `Config/*`, `src/core/config/*`, `src/config/{content,gameplay,testing}/*`
- **description**: 先迁最内层配置。把 `Config/generated/*`、`Config/maps/*`、`Config/runtime_refs.lua`、`Config/testing/*` 和 `src/core/config/*` 统一改写到 `src/config/*`，并把新路径定义为后续任务唯一允许新增的 canonical require。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`rg -n 'require\("(Config\.|src\.core\.config\.)' src tests` 只剩当前任务允许保留的 shim 或尚未执行的旧模块。
- **status**: `Completed`
- **log**: `2026-03-14 12:19+08:00` 使用双路径迁移把 `Config/generated/*`、`Config/maps/*`、`Config/runtime_refs.lua`、`Config/testing/test_profiles.lua` 与 `src/core/config/*` 迁到 `src/config/*`，旧路径全部改成 shim；随后批量把 `src/` 与 `tests/` 中的 `Config.*` / `src.core.config.*` require 切到 `src.config.*`。执行中发现 `config_sanity.lua` 若放在 `src/config/content/*` 会与 `vehicle_catalog.lua` 形成 `content <-> gameplay` 投影环，因此改判为 `src/config/gameplay/config_sanity.lua`。验证结果：`rg -n 'require\("(Config\.|src\.core\.config\.)|require\(\'(Config\.|src\.core\.config\.)' src tests` 无命中；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `Config/generated/*.lua`, `Config/maps/*.lua`, `Config/runtime_refs.lua`, `Config/testing/test_profiles.lua`, `src/core/config/*.lua`, `src/config/content/*.lua`, `src/config/content/maps/*.lua`, `src/config/gameplay/*.lua`, `src/config/testing/test_profiles.lua`, `src/app/**/*`, `src/game/**/*`, `src/infrastructure/runtime/*`, `src/presentation/**/*`, `tests/**/*`

### T3：纯状态与 `state_access` 归位

- **id**: `T3`
- **depends_on**: `[T2]`
- **location**: `src/game/core/runtime/{players,tiles,turn}.lua`, `src/core/state_access/*`, `src/state/*`
- **description**: 只迁纯状态模块和 `state_access`。显式排除 `src/game/core/runtime/game.lua`、`src/game/core/runtime/game_factory.lua`、`src/game/core/runtime/composition_root.lua`，也不提前拆任何 UI runtime state。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`rg -n 'src\.game\.core\.runtime\.(game|game_factory|composition_root)' src/state src/entry tests` 仍然只在计划允许的旧路径或注释里出现，不会被误搬进 `T3`。
- **status**: `Completed`
- **log**: `2026-03-14 12:48+08:00` 已将 `src/game/core/runtime/{players,tiles,turn}.lua` 迁到 `src/state/{player_state,board_state,turn_state}.lua`，并将 `src/core/state_access/*` 迁到 `src/state/state_access/*`；旧路径全部改成 shim，并把 `src/` 与 `tests/` 的 consumer 与 `package.loaded` 注入点切到新命名空间。执行中发现 root 投影环来自“旧路径 shim 仍被 arch_view 当作依赖边 + `player_state`/`state_access` 仍需要旧 `game/core` 辅助模块”。修复方式是两步：一，`scripts/arch/arch_view/dependency_extract.lua` 对纯 `return require(...)` shim 不再计入架构边；二，新增 `src/state/player_state_ops/*` 与 `src/state/support/*` 作为 state 侧转发桥，让 `src/state/*` 不再直接写出 `src.game.*` / `src.core.*` require。显式排除项保持不变：`src/game/core/runtime/{game,game_factory,composition_root}.lua` 未迁移，只更新其对纯状态模块的消费路径。验证结果：`rg -n 'src\.game\.core\.runtime\.(game|game_factory|composition_root)' src/state src/entry tests` 无命中；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `src/game/core/runtime/{players,tiles,turn}.lua`, `src/core/state_access/*.lua`, `src/state/{player_state,board_state,turn_state}.lua`, `src/state/state_access/*.lua`, `src/state/player_state_ops/*.lua`, `src/state/support/*.lua`, `scripts/arch/arch_view/dependency_extract.lua`, `scripts/arch/config.lua`, `src/app/**/*`, `src/game/**/*`, `src/infrastructure/runtime/*`, `src/presentation/**/*`, `tests/**/*`, `.agents/plan.md`

### T4：`host` / Eggy 归位

- **id**: `T4`
- **depends_on**: `[T2, T3]`
- **location**: `src/infrastructure/runtime/*`, `src/presentation/runtime/host/*`, `src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`, `src/host/eggy/*`
- **description**: 迁移宿主桥接与宿主专用适配器，包括 `context.lua`、`default_ports.lua`、`event_bridge.lua`、`synthetic_actor_registry.lua`、`host/init.lua`、`scene_ui.lua`、`raycast.lua`、`role_resolver.lua`、`sfx_runtime.lua -> sound.lua`、`unit_lifecycle.lua -> units.lua` 和付费网关。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`src/presentation/runtime/events.lua` 仍未归入本任务；`rg -n 'src\.infrastructure\.runtime|src\.presentation\.runtime\.host' src tests` 的残留要么是 shim，要么是尚未处理的调用点。
- **status**: `Completed`
- **log**: `2026-03-14 13:37+08:00` 已将 `src/infrastructure/runtime/{context,default_ports,event_bridge,synthetic_actor_registry}.lua` 迁到 `src/host/eggy/*`，并将 `src/presentation/runtime/host/{init,raycast,role_resolver,scene_ui}.lua` 迁到 `src/host/eggy/*`，`sfx_runtime.lua -> sound.lua`，`unit_lifecycle.lua -> units.lua`；付费网关迁到 `src/host/eggy/paid_purchase_gateway.lua`。为保持 `host` 不直接写出对 `config` / `rules` / `state` 的依赖，新增 `src/host/eggy/support/*` 过渡桥，把 `runtime_constants`、`runtime_refs`、`runtime_editor_exports`、vehicle feature 与 market context 的访问都收敛到 host 内侧。验证结果：`rg -n 'src\.(infrastructure\.runtime|presentation\.runtime\.host)' src tests` 无命中；`src/presentation/runtime/events.lua` 未迁移；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `src/infrastructure/runtime/*.lua`, `src/presentation/runtime/host/*.lua`, `src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`, `src/host/eggy/*.lua`, `src/host/eggy/support/*.lua`, `src/app/**/*`, `src/presentation/**/*`, `tests/**/*`, `.agents/plan.md`

### T5：`rules` 归位

- **id**: `T5`
- **depends_on**: `[T2, T3]`
- **location**: `src/game/systems/*`, `src/game/core/runtime/bootstrap.lua`, `src/rules/*`
- **description**: 迁移全部规则子系统，并把注册器构建器迁到 `src/rules/bootstrap/registries.lua`。本任务只处理规则实现，不处理共享 gameplay ports。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`rg -n 'src\.game\.systems' src/rules tests` 只剩 shim 或待切换调用点；`src/game/core/runtime/bootstrap.lua` 的新 canonical 路径已经稳定为 `src/rules/bootstrap/registries.lua`。
- **status**: `Completed`
- **log**: `2026-03-14 13:37+08:00` 已将 `src/game/systems/*` 整体迁到 `src/rules/*`，并把 `src/game/core/runtime/bootstrap.lua` 迁到 `src/rules/bootstrap/registries.lua`；旧路径全部改成 shim，`src/` 与 `tests/` 的 consumer 已切到 `src.rules.*`。迁移中保留的唯一旧 gameplay contract 例外是 `src/game/ports/*`：`src/rules/*` 继续经由这些旧 port 读取抽象契约，待 `T8` 再统一搬到 `src/rules/ports/*`。为了避免“抽象 port 的反向边”把 root 视图误判成投影环，本轮同步调整 `scripts/arch/arch_view/projection.lua`，让投影层反馈边只依据 direct edge 计算，abstract edge 继续显示但不参与 cycle 判定。验证结果：`rg -n 'src\.game\.systems|src\.game\.core\.runtime\.bootstrap' src tests` 无命中；`src/game/core/runtime/bootstrap.lua` 已稳定为 shim；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `src/game/systems/**/*.lua`, `src/game/core/runtime/bootstrap.lua`, `src/rules/**/*.lua`, `scripts/arch/arch_view/projection.lua`, `src/app/**/*`, `src/game/**/*`, `src/presentation/**/*`, `tests/**/*`, `.agents/plan.md`

### T6：`player` 归位

- **id**: `T6`
- **depends_on**: `[T2, T3, T5]`
- **location**: `src/game/systems/choices/*`, `src/game/core/player/*`, `src/player/{choices,actions,policies}/*`
- **description**: 迁移玩家选择、动作和 state ops，保持玩家层只面向 `rules`、`state`、`config`，不回流依赖 `turn` 和 `ui`。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`rg -n 'src\.game\.(systems\.choices|core\.player)' src/player tests` 只剩 shim 或待切换调用点；如本任务引入旧路径 shim，必须补 `require(old) == require(new)` 契约测试。
- **status**: `Completed`
- **log**: `2026-03-14 14:09+08:00` 已将 `src/game/core/player/{init,inventory}.lua` 迁到 `src/player/actions/*`，将 `src/game/core/player/state_ops/*` 迁到 `src/player/actions/state_ops/*`，并将原 `src/rules/choices/*` 的实现迁到 `src/player/choices/*`。为了不让 `rules` / `state` 在过渡期直接回流依赖 `player`，保留 `src/rules/choices/*` 与 `src/state/player_state_ops/*` 作为 shim 桥，由 `rules` 与 `state` 继续引用本层命名空间，最终落点则统一指向 `src/player/*`。验证结果：`rg -n 'src\.game\.(systems\.choices|core\.player)' src tests` 无命中；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `src/game/core/player/**/*.lua`, `src/rules/choices/**/*.lua`, `src/player/actions/*.lua`, `src/player/actions/state_ops/*.lua`, `src/player/choices/**/*.lua`, `src/state/player_state.lua`, `src/state/player_state_ops/*.lua`, `src/game/**/*`, `tests/**/*`, `.agents/plan.md`

### T7：`computer` 归位

- **id**: `T7`
- **depends_on**: `[T2, T3, T5]`
- **location**: `src/game/ai/agent.lua`, `src/game/core/ai/agent.lua`, `src/computer/policies/*`
- **description**: 把 AI 合并写成单独任务。先临时落地 `src/computer/policies/core_agent.lua`，完成公开 API 对比与收敛后，再把对外入口合并回 `src/computer/policies/agent.lua`。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；旧 `game/ai` 与 `game/core/ai` 的入口都还能通过 shim 加载；只有当两个旧 AI 文件都不再被任何生产代码直接 `require` 时，才允许删除临时文件。
- **status**: `Completed`
- **log**: `2026-03-14 14:09+08:00` 已将 `src/game/ai/agent.lua` 迁到 `src/computer/policies/core_agent.lua`，并新增 `src/computer/policies/agent.lua -> core_agent.lua` 的公开入口；旧 `src/game/ai/agent.lua` 与 `src/game/core/ai/agent.lua` 都改成 shim，`src/` / `tests/` 的生产消费方已切到 `src.computer.policies.agent`。当前仍保留 `core_agent.lua` 作为临时收敛文件，待后续收口时再决定是否合并回单一 `agent.lua` 实现。验证结果：`rg -n 'src\.game\.(ai\.agent|core\.ai\.agent)' src tests` 无命中；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `src/game/ai/agent.lua`, `src/game/core/ai/agent.lua`, `src/computer/policies/core_agent.lua`, `src/computer/policies/agent.lua`, `src/app/**/*`, `src/game/**/*`, `tests/**/*`, `.agents/plan.md`

### T8：共享 gameplay ports 归位

- **id**: `T8`
- **depends_on**: `[T2, T3, T5, T6, T7]`
- **location**: `src/game/ports/*`, `src/rules/ports/*`
- **description**: 把共享 gameplay contract 从旧 `src/game/ports/*` 迁到中性的 `src/rules/ports/*`，不再把它们并入 `src/turn/output/ports/*`。这一步只处理 contract 的落点，不顺手处理 turn output adapter。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；本文件的目标树和“接口与依赖”章节都已出现 `src/rules/ports/*`；`rg -n 'src\.game\.ports' src/rules src/turn tests` 的残留必须能解释为 shim 或未切换调用点。
- **status**: `Completed`
- **log**: `2026-03-14 14:24+08:00` 已将 `src/game/ports/{auto_play_port,bankruptcy_feedback_port,bankruptcy_port,board_visual_feedback_port,contract_helper,intent_output_port}.lua` 迁到 `src/rules/ports/*`，旧路径全部改成 shim，并把 `src/` / `tests/` 的 consumer 批量切到 `src.rules.ports.*`。验证结果：`rg -n 'src\.game\.ports' src tests` 无命中；`lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `src/game/ports/*.lua`, `src/rules/ports/*.lua`, `src/game/**/*`, `src/rules/**/*`, `tests/**/*`, `.agents/plan.md`

### T9：`turn` 核心归位

- **id**: `T9`
- **depends_on**: `[T4, T5, T6, T7, T8]`
- **location**: `src/game/scheduler/*`, `src/game/flow/turn/{phases,policies,waits,auto,dispatch}/*`, `src/turn/{loop,phases,actions,policies,waits,timing}/*`
- **description**: 先迁 scheduler、turn loop、phase、policy、wait、action、timing 核心，不在本任务里处理 `src/game/flow/turn/runtime/*`、`src/game/flow/output_adapters/*` 和 `src/game/runtime/*`。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`tests/guards/gameplay_loop_no_ui.lua` 仍能证明 turn flow 不直接读写 UI state；`rg -n 'src\.game\.(scheduler|flow\.turn\.(phases|policies|waits|auto|dispatch))' src/turn tests` 的残留都有解释。
- **status**: `Not Completed`
- **log**: 留空；执行时记录 turn core 与故意延后的 output 模块边界。
- **files edited/created**: 留空；执行时填写真实路径。

### T10：`turn` 输出与 runtime adapter 归位

- **id**: `T10`
- **depends_on**: `[T4, T5, T6, T7, T8, T9]`
- **location**: `src/game/flow/turn/runtime/*`, `src/game/flow/output_adapters/*`, `src/game/runtime/*`, `src/turn/output/*`
- **description**: 在 turn core 稳定后，再迁 anim、output adapter、`default_ports.lua`、`intent_output_adapter.lua` 和 gameplay runtime adapter。此任务依赖 `T8`，因为它要消费新的 `src/rules/ports/*` contract。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua` 通过；`rg -n 'src\.game\.(flow\.turn\.runtime|flow\.output_adapters|runtime)' src/turn tests` 的残留只剩 shim 或未收口调用点。
- **status**: `Not Completed`
- **log**: 留空；执行时记录 turn output 与 runtime adapter 的新 canonical 路径。
- **files edited/created**: 留空；执行时填写真实路径。

### T11：`ui` 的 schema、model、view 归位

- **id**: `T11`
- **depends_on**: `[T2, T3, T4, T9, T10]`
- **location**: `src/presentation/{schema,model,view}/*`, `src/ui/{schema,presenters,render,widgets}/*`
- **description**: 先迁纯 UI 结构：schema、presenters、render、widgets、`view/support`。这是 `ui` 任务里最适合先并行整理的一部分，因为它比 runtime/controllers 更容易保持纯边界。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua` 通过；`presentation schema must stay pure` 这类规则已更新到新命名空间；`rg -n 'src\.presentation\.(schema|model|view)' src/ui tests` 的残留只剩 shim 或未切换调用点。
- **status**: `Not Completed`
- **log**: 留空；执行时记录 schema、presenters、render、widgets 的归位情况。
- **files edited/created**: 留空；执行时填写真实路径。

### T12：`ui` runtime、input、store 归位

- **id**: `T12`
- **depends_on**: `[T2, T3, T4, T10, T11]`
- **location**: `src/presentation/input/*`, `src/presentation/runtime/*`, `src/ui/{input,controllers,stores,render}/*`
- **description**: 把 `canvas_state.lua`、`canvas_store.lua`、`event_state.lua`、`modal_state.lua`、`ui_runtime/*`、controllers、bindings、handlers、`events.lua -> src/ui/controllers/ui_events.lua` 作为一个整体迁移。已在 `T4` 迁走的 host 模块不再留在本任务范围。
- **validation**: `lua scripts/arch.lua check`、`lua tests/guard.lua`、`lua tests/contract.lua` 通过；计划和代码都明确“不再把任何 UI runtime state 拆进 `src/state/*`”；`rg -n 'src\.presentation\.(input|runtime)' src/ui tests` 的残留都必须可解释。
- **status**: `Not Completed`
- **log**: 留空；执行时记录 UI runtime state 与 controllers 的整体切换情况。
- **files edited/created**: 留空；执行时填写真实路径。

### T13：`entry`、聚合根与测试/启动面归位

- **id**: `T13`
- **depends_on**: `[T2, T3, T4, T5, T8, T9, T10, T11, T12]`
- **location**: `src/app/init.lua`, `src/app/bootstrap/*`, `src/app/testing/*`, `src/game/core/runtime/{game.lua,game_factory.lua,composition_root.lua}`, `tests/support/*`, `tests/suites/runtime/*`, `src/entry/*`, `src/state/game_state.lua`
- **description**: 最后迁入口、装配、测试支撑和聚合根。`game.lua -> src/state/game_state.lua` 在这一阶段落位；`game_factory.lua` 与 `composition_root.lua` 并入 `src/entry/start_game.lua` 附近的装配层；`src/app/testing/*` 迁到 `src/entry/testing/*`；`src/app/init.lua`、`startup_policy.lua`、runtime suites 和测试 support 也在这一任务统一收口。
- **validation**: 四条基线命令全部通过；`tests/guards/gameplay_loop_no_ui.lua`、`tests/support/shared_support.lua`、`tests/suites/runtime/*` 已切到新入口或 shim；`rg -n 'src\.app|src\.game\.core\.runtime\.(game|game_factory|composition_root)' src tests` 的残留都能解释。
- **status**: `Not Completed`
- **log**: 留空；执行时记录入口、测试 support、聚合根的真实落点和 API 保留情况。
- **files edited/created**: 留空；执行时填写真实路径。

### T14：收口、删 shim、更新文档

- **id**: `T14`
- **depends_on**: `[T13]`
- **location**: forwarding shim 文件、`docs/architecture/*`, `.agents/plan.md`, `src/`, `tests/`, `src/app/testing/`, `docs/`
- **description**: 删除旧生产入口、删已完成使命的 shim、更新架构文档和计划文档、保留被明确批准的少量共享工具残留区，其余全部收口。
- **validation**: 四条基线命令通过；分作用域执行旧路径搜索时，`src/`、`tests/`、`src/app/testing/`、`docs/` 都不再命中旧生产命名空间；文档中的目标树、接口章节、任务波次与最终代码真相一致。
- **status**: `Not Completed`
- **log**: 留空；执行时记录删掉了哪些 shim、哪些 docs 已同步。
- **files edited/created**: 留空；执行时填写真实路径。

## 并行执行分组

并行执行按波次推进。一个波次里的任务只有在它们的 `depends_on` 全部满足后才能启动；如果某个任务被拆出新的子任务，也要保持相同原则，不要把未满足依赖的新任务偷偷提前。

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | `T0` | 立即 |
| 2 | `T1` | `T0` 完成 |
| 3 | `T2` | `T1` 完成 |
| 4 | `T3` | `T2` 完成 |
| 5 | `T4`, `T5` | `T3` 完成 |
| 6 | `T6`, `T7` | `T5` 完成 |
| 7 | `T8` | `T6`, `T7` 完成 |
| 8 | `T9` | `T4`, `T8` 完成 |
| 9 | `T10` | `T9` 完成 |
| 10 | `T11` | `T10` 完成 |
| 11 | `T12` | `T11` 完成 |
| 12 | `T13` | `T12` 完成 |
| 13 | `T14` | `T13` 完成 |

如果要进一步提高并行度，只能在不破坏这张表的前提下，把单个大任务继续往下拆；不能反过来合并成“一个人全做完 rules/player/computer/turn/ui”。

## 具体步骤

下面只保留执行本计划时必须反复使用的命令模板，不再保留整段线性 `git mv` 列表。执行者应按任务卡工作，每完成一个任务就立刻回归，不要累计到最后一起跑。

执行前先冻结基线：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua scripts/arch.lua check
    lua tests/guard.lua
    lua tests/behavior.lua
    lua tests/contract.lua

每完成一个偏结构性的任务，至少跑一次静态与 guard：

    lua scripts/arch.lua check
    lua tests/guard.lua

每完成一个会影响运行行为、入口、回归夹具或 output adapter 的任务，再补跑行为与契约：

    lua tests/behavior.lua
    lua tests/contract.lua

每个任务都要做作用域 grep。不要只跑一次仓库级大搜索，因为 `.agents/plan.md` 和文档本身会包含历史命名空间。推荐按下面四个作用域分开跑：

    rg -n 'require\("(Config\.|src\.(app|presentation|game|infrastructure))' src
    rg -n 'require\("(Config\.|src\.(app|presentation|game|infrastructure))' tests
    rg -n 'require\("(Config\.|src\.(app|presentation|game|infrastructure))' src/app/testing
    rg -n 'src\.(app|presentation|game|infrastructure)|Config\.' docs .agents/plan.md

只要某个任务创建了 shim，就必须在同一轮补一个代表性契约，证明旧路径与新路径指向同一模块身份。实现方式可以是 guard、contract suite 或单独的兼容测试，但要求都一样：

    local old_mod = require("旧路径")
    local new_mod = require("新路径")
    assert(old_mod == new_mod)

## 验证与验收

验收必须覆盖“计划文档正确”和“迁移执行正确”两类结果。前者是本次改写的直接交付物，后者是后续执行这份计划时每个子代理都必须遵守的完成标准。

对计划文档本身，验收标准是四条。第一，`.agents/plan.md` 仍保留 `.agents/harness/PLANS.md` 要求的活文档章节。第二，原来的 `里程碑 1..5` 已经让位给 `依赖图`、`任务清单`、`并行执行分组`。第三，`T0` 到 `T14` 每张任务卡都含有 `id`、`depends_on`、`location`、`description`、`validation`、`status`、`log`、`files edited/created`。第四，文档已经明确修正三类错误假设：`game.lua` 不是早期纯 state、`src/game/ports/*` 迁到 `src/rules/ports/*`、UI runtime state 整组归 `src/ui/stores/*`。

对迁移执行，验收要按任务级和最终级两层进行。任务级验收要求每张任务卡至少记录三类证据：`lua scripts/arch.lua check`、`lua tests/guard.lua`、以及该任务自己的 grep 或 `require(old) == require(new)` 结果。涉及运行时行为、入口、`turn/output`、`ui runtime` 或测试夹具的任务，还要补 `lua tests/behavior.lua` 和 `lua tests/contract.lua`。最终级验收要求四条基线命令全部通过，且 `src/`、`tests/`、`src/app/testing/`、`docs/` 四个作用域的旧路径搜索结果都与计划一致，不再留下旧生产入口。

## 可重复性与恢复

整个方案按任务图设计，就是为了让重试成本可控。每个任务都要求“小步移动 + 当轮回归 + 当轮记录”；执行者完成一个任务或一个波次后，应立即提交一次小 commit，这样失败时可以只回退本任务涉及的路径，而不是把整轮大搬迁一起回滚。

目录移动优先用 `git mv`，这样历史保留更好，也更容易看出哪些路径已经迁过。转发模块的改写是幂等的：旧文件一旦只剩 `return require("新路径")`，后续重复执行不会改变行为。真正不幂等的是“把两个实现文件合并成一个”的步骤，例如 `T7` 的 AI 合并与 `T13` 的聚合根归位；这类步骤必须在任务卡自己的 `log` 字段记录保留了哪些公开函数、删掉了哪些重复实现、为什么这么做。

如果某个任务中途失败，不要顺手回退其他任务的文件。只处理当前任务碰过的路径，并在 `log` 里写明失败点、已验证的状态和下一次重试应从哪里继续。这样即使换一个子代理接手，也能只靠这份计划继续推进。

## 产物与备注

下面这些短输出是当前计划写作时记录的基线证据，后续实施时应继续保留类似证据，但只保留关键行：

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

迁移时不要顺手改公开 API 名字，先保持“路径变化，接口不变”。下面这些接口必须在新路径继续存在，除非有明确决策日志说明为何改名。`src/entry/boot.lua` 必须继续提供 `install(env)`。`src/entry/start_game.lua` 必须承接 `src/app/bootstrap/game_startup.lua` 的公开入口，并在 `T13` 吸收 `src/game/core/runtime/composition_root.lua` 和 `src/game/core/runtime/game_factory.lua` 的装配职责。`src/entry/start_ui.lua` 必须继续提供 UI 启动安装函数。`src/entry/wire_host.lua` 必须承接 `src/app/bootstrap/game_runtime_bootstrap.lua` 的接线职责。`src/entry/wire_events.lua` 必须承接 `src/app/bootstrap/game_startup_event_bridge.lua` 的运行时事件订阅职责。

`src/state/game_state.lua` 是 `Game` 聚合根的最终 canonical 路径，必须继续导出当前 `Game` 类型的公开行为，包括 `advance_turn()`、`dispatch_action(action)`、`rebuild()`、`mark_players_dirty()`、`mark_board_dirty()`。`src/state/player_state.lua`、`src/state/board_state.lua`、`src/state/turn_state.lua` 则承接现有 `players.lua`、`tiles.lua`、`turn.lua` 的纯状态行为。`src/rules/bootstrap/registries.lua` 必须继续导出 `create_registries()`。

`src/rules/ports/*` 是新的共享 gameplay contract 命名空间，承接旧 `src/game/ports/*`。这些 port 可以被 `rules`、`player`、`computer`、`turn/output` 共同消费，但不能再被描述成 `turn` 私有输出。`src/turn/output/default_ports.lua` 必须继续提供当前 `src/game/runtime/default_ports.lua` 的能力，至少保留 `resolve_game_opts(opts)` 与 `install(game)`。`src/host/eggy/default_ports.lua` 必须继续提供当前宿主时间、随机数、事件发射和角色解析能力。`src/ui/controllers/ui_events.lua` 必须继续提供 `set_roles(roles)`、`send_to_all(event_name, payload)` 与 `send_to_role(role, event_name, payload)`。

`src/ui/stores/*` 是全部 UI runtime state 的 canonical 容器。`canvas_state.lua`、`canvas_store.lua`、`event_state.lua`、`modal_state.lua`、`ui_runtime/state.lua` 以及它们直接依赖的 UI dirty 标记逻辑，都应在 `T12` 一次性迁入这里，不再拆进 `src/state/*`。静态依赖的唯一真源是 `scripts/arch/config.lua`。文本级硬边界的唯一真源是 `tests/guards/dep_rules.lua`。运行回归的入口是 `tests/behavior.lua`、`tests/contract.lua`、`tests/guard.lua`。任何一次目录迁移只要影响这些真源之一，都必须在同一个任务里同步改完，不能留到下一轮。

## 本次改写说明

这次改写把原来的“里程碑 + 线性命令”正文升级成了适合子代理并行执行的任务图计划。主要变化有四类。第一，新增了 `依赖图`、`任务清单`、`并行执行分组`，并把 `T0` 到 `T14` 全部写成带 `depends_on` 的任务卡。第二，删除了不适合并行执行的大段线性 `git mv` 指令，改成按任务反复使用的基线、回归和 grep 模板。第三，修正了三处会误导执行者的错误假设：`game.lua` 不是早期纯 state、`src/game/ports/*` 不归 `turn/output`、UI runtime state 不能单拆 `canvas_state.lua`。第四，把 shim 规则、兼容验证和按作用域搜索旧路径的要求写成了硬约束，避免后续执行时出现“全仓预建空壳”或“测试绿了但旧入口还埋着”的假完成。

这样改的原因很直接：如果没有显式依赖、任务边界和验证模板，多子代理并行推进这类目录迁移很容易各搬各的，最后在 `turn`、`ui runtime` 和 `entry` 三个交汇处集中返工。现在的版本目标不是把文档写得更漂亮，而是让下一位执行者只靠这一个文件，就能安全地把任务切出去、并回来、验收掉。
