# 架构重构路线图与阶段0守护

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。讨论、实施、暂停和重启都只依赖这份计划本身，不依赖聊天历史。

## 目的 / 全局视角

这份计划服务的是一次渐进式架构收口，而不是推倒重写。用户真正需要的是：在继续开发玩法、UI 和宿主适配时，仓库不会再偷偷长出新的跨层依赖；后续阶段的重构可以在守护网内推进，而不是一边搬边继续欠债。阶段0完成后，最直接的可观察结果是三条边界开始被自动化守住：`src/core` 不能继续增加对 Eggy 全局 API 的直接触点，`src/game` 不能继续扩散 `game.ui_port` 读取点，`src/game/flow` 不能继续新增 `state.ui_*` 写入点。任何突破这三条边界的提交，都会在本地回归和 GitHub Actions 中失败。

这次计划还必须帮助下一位执行者继续阶段1，而不是只描述“今天改了什么”。因此本文既记录阶段0已完成的守护，也明确后续阶段1到阶段6要改的模块、顺序、验收方式和为什么这样拆。

## 进度

- [x] (2026-03-06 20:08 +0800) 已研读 `.agents/research.md`、`.agents/harness/PLANS.md`、`docs/eggy/lua_env.md`、`docs/eggy/ui_manager_lib.md`、`docs/eggy/eggy_lua_agent_memory.md`，并核对真实代码分布。
- [x] (2026-03-06 20:18 +0800) 已完成阶段0静态守护：`tests/internal/dep_rules.lua` 新增三组“衰减式基线”规则，冻结 `src/core` 宿主 API 触点、`game.ui_port` 读取点、`state.ui_*` 写入点的当前规模。
- [x] (2026-03-06 20:25 +0800) 已完成阶段0动态守护：新增 `tests/suites/architecture_guard_contract.lua`，验证 `GameplayLoop.set_game` 注入的是 DTO 形态的 `ui_port`，并拦截 `TurnDispatch` 关键路径上的 `state.ui_*` 写入。
- [x] (2026-03-06 20:27 +0800) 已将阶段0守护接入默认回归：`tests/regression.lua` 现在会运行 `architecture_guard_contract`。
- [x] (2026-03-06 20:29 +0800) 已补 CI 入口：新增 `.github/workflows/regression.yml`，在 `push` 和 `pull_request` 上执行 `lua tests/regression.lua`。
- [x] (2026-03-06 20:33 +0800) 已完成阶段0验收：`lua tests/internal/dep_rules.lua` 通过，定向守护 suite 通过，全量 `lua tests/regression.lua` 通过并输出 `All regression checks passed (364)`。
- [ ] 阶段1：定义用例输出协议，消除 `GameplayLoop` / `TurnDispatch` 对 `state.ui_model`、`state.ui_dirty`、`pending_choice` 的直接操纵。
- [ ] 阶段2：移除 `game.ui_port` 读路径，用显式注入的 `NotificationPort` / `AnimPort` 代替隐式挂载。
- [ ] 阶段3：把 `src/core` 中仍直接认识 Eggy 宿主的逻辑外迁到 `src/app/bootstrap` 或新的基础设施目录。
- [ ] 阶段4：拆分 `src/game/systems/market/service/Purchase.lua`，把支付、事件桥和 UI 刷新拆回各自边界。
- [ ] 阶段5：把 `PreConfirmFlow` 等 presentation 中的应用规则收回用例层，让 presentation 只渲染 ViewModel。
- [ ] 阶段6：在边界稳定后整理目录语义和命名，避免目录改动与行为改动叠加。

## 意外与发现

- 观察：仓库此前没有任何现成的 CI 配置文件，阶段0若只改本地脚本，守护无法变成团队级约束。
  证据：仓库根目录原先不存在 `.github/workflows/*`，本次新增了 `.github/workflows/regression.yml`。

- 观察：如果直接把研究报告里的边界规则改成“零容忍”，当前代码会立刻失败，因为存量债务还没有迁完。
  证据：真实代码基线是 `src/core` 宿主全局 API 触点 47 处，`game.ui_port` 依赖点 23 处，`src/game/flow` 中 `state.ui_*` 写入 13 处。

- 观察：`GameplayLoop.set_game` 触发的初始化会顺带安装市场支付映射，因此即便只跑守护契约测试，也会看到既有的 `market paid goods mapping missing` 告警。
  证据：定向运行 `architecture_guard_contract` 时，最终通过，但终端仍打印现有 market 告警。

- 观察：全量回归目前在本机的默认模式是 `release_trimmed`，因此阶段0验收输出是 `All regression checks passed (364)`，不是研究报告里的旧数字。
  证据：`lua tests/regression.lua` 开头打印 `[regression] mode=release_trimmed`，结尾打印 `All regression checks passed (364)`。

## 决策日志

- 决策：阶段0采用“衰减式基线”而不是“立即清零”的静态规则。
  理由：`src/core`、`game.ui_port`、`state.ui_*` 都还有存量违规点；阶段0目标是先停止债务增长，而不是在没有完成阶段1到阶段3前让仓库无法通过回归。
  日期/作者：2026-03-06 / Codex

- 决策：动态守护单独放在 `tests/suites/architecture_guard_contract.lua`，不塞进玩法 suite。
  理由：阶段0关注的是边界契约，不是玩法结果。独立 suite 更容易在阶段1到阶段3逐步替换、扩展和定位失败原因。
  日期/作者：2026-03-06 / Codex

- 决策：CI 直接运行现有统一入口 `lua tests/regression.lua`。
  理由：`tests/regression.lua` 已经串联了 suites、`dep_rules`、`tick`、`forbidden_globals`，用一个入口最不容易出现“本地和 CI 跑的不是同一套东西”。
  日期/作者：2026-03-06 / Codex

- 决策：阶段1优先收口 `GameplayLoop`、`TurnDispatch` 和 `TickTimeout`，不先动 Market 或 presentation 细节。
  理由：`state.ui_*` 写入最集中、最影响后续所有边界，如果不先把输出协议定下来，阶段2到阶段5都会继续围着共享状态打补丁。
  日期/作者：2026-03-06 / Codex

## 结果与复盘

阶段0已经完成。它没有消除所有架构债务，但已经把三类最关键的债务增长点锁住，并把锁接进了默认回归和 GitHub Actions。今天之后，新代码若想继续在 `src/core` 里直接摸 `GameAPI`、在 `src/game` 里读取更多 `game.ui_port`、或在 `src/game/flow` 里继续扩 `state.ui_*`，都会先碰到失败的自动化。

阶段0的经验很直接。第一，当前仓库最适合的治理方式不是一次性“洁癖式”封禁，而是先冻结现状，再逐步压缩。第二，动态守护必须贴着已抽出的真实边界写，例如 `GameplayLoop.set_game` 注入 DTO、`TurnDispatch` 只发出 `ui_dirty` 这种粗粒度输出；写成愿景测试只会在阶段0卡住。第三，CI 接的必须是现有统一入口，否则团队很快会出现“本地过、线上不过”或反过来的漂移。

## 背景与导读

如果你第一次进入这个仓库，只需要先理解五组文件。

第一组是当前的研究结论，位于 `.agents/research.md`。它给出的核心判断是：这个仓库已经有了正确的分层骨架，但三个边界仍在泄漏。第一，`src/core` 仍直接认识 Eggy 宿主全局，如 `GameAPI`、`GlobalAPI`、`SetTimeOut`。第二，`src/game` 仍通过 `game.ui_port` 读取动画等待、弹窗和 UI 状态。第三，`src/game/flow` 仍直接写 `state.ui_dirty`、`state.ui_model`、`state.ui_modal_elapsed` 这类 UI 协调字段。

第二组是阶段0的静态守护文件，位于 `tests/internal/dep_rules.lua`。它原本只负责一些禁止 require 和禁止旧桥接路径的检查；现在还承担“冻结当前债务规模”的职责。这里的“衰减式基线”意思是：允许已有债务继续存在，但不允许增长；如果债务减少，就必须同步收紧基线，让文件重新回到“精确描述当前剩余债务”的状态。

第三组是阶段0的动态守护文件，位于 `tests/suites/architecture_guard_contract.lua`。它做两件事。第一，验证 `src/game/flow/turn/GameplayLoop.lua` 在 `set_game` 时给 `game` 注入的是经过裁剪的运行时 `ui_port` DTO，而不是把整个 `state` 原样挂出去。第二，给 `src/game/flow/turn/TurnDispatch.lua` 包一层 `__newindex` 拦截，确认关键输入路径只会发出 `ui_dirty` 这种粗粒度失效信号，而不会再静默写出新的 `state.ui_*` 字段。

第四组是阶段0之后最先要动的用例层文件。`src/game/flow/turn/GameplayLoop.lua` 负责主循环和初始化，`src/game/flow/turn/TurnDispatch.lua` 负责玩家输入落地，`src/game/flow/turn/TickTimeout.lua` 负责倒计时和弹窗超时，`src/game/flow/intent/IntentDispatcher.lua` 负责用例层向 UI 发出选择与弹窗意图。阶段1必须先把这几处对 UI 状态的直接读写抽到稳定端口上。

第五组是运行和验证入口。`tests/regression.lua` 是本地与 CI 的统一回归脚本；`.github/workflows/regression.yml` 是本次新增的 CI 接线。只要阶段1到阶段6仍沿用这条入口，守护就不会失效。

## 里程碑 0：架构守护（已完成）

这个里程碑的目标不是“把边界修好”，而是“停止继续变坏”。完成后，仓库第一次具备了自动化的架构健身函数，也就是能持续判断系统有没有朝错误方向长。你可以通过三步看到它已经生效：先跑 `lua tests/internal/dep_rules.lua`，它会验证静态边界；再跑定向守护 suite；最后跑全量回归，确认守护已经接入默认入口。

这个里程碑已改动的文件只有四个。`tests/internal/dep_rules.lua` 记录了三组基线。`tests/suites/architecture_guard_contract.lua` 记录了动态契约。`tests/regression.lua` 把新 suite 接入默认回归。`.github/workflows/regression.yml` 把同一入口接到 GitHub Actions。这个范围刻意很小，因为阶段0的价值在于“守住现状”，而不是带着大规模业务改动一起提交。

验收标准已经成立：本地全量回归通过，`dep_rules ok` 会在默认入口里出现，GitHub Actions 会在 `push` 和 `pull_request` 上运行同样的命令。

## 里程碑 1：定义用例输出协议

这个里程碑完成后，用例层将不再直接认为自己拥有 UI 状态结构，而是只知道“我要发出什么输出”。这里的“输出协议”不是网络协议，而是一组稳定的 Lua 端口函数和数据结构，用来描述“请求选择”“显示弹窗”“排队动作动画”“标记 UI 失效”等意图。完成后，`GameplayLoop`、`TurnDispatch`、`TickTimeout` 应该能在没有真实 UI 状态表的情况下运行。

具体从 `src/game/flow/turn/GameplayLoop.lua`、`src/game/flow/turn/TurnDispatch.lua`、`src/game/flow/turn/TickTimeout.lua` 下手。新增一个端口模块，建议路径是 `src/game/flow/ports/UseCaseOutputPort.lua`。先让 `GameplayLoopPorts` 解析出 `output` 分组，再把 `state.ui_dirty`、`state.ui_model`、`state.ui_modal_elapsed`、`state.pending_choice*` 的直接写入逐步替换为 `output` 调用。presentation 侧继续保留兼容实现，先让老路径和新端口同时工作，再移除旧写入。

这个里程碑的验收不是“文件里出现了 OutputPort”，而是两件更具体的事。第一，新增的假端口测试能在没有真实 UI state 的前提下驱动一轮完整回合。第二，阶段0的 `state.ui_*` 写入基线要缩小，并在同一提交里更新 `tests/internal/dep_rules.lua` 的预算值。

## 里程碑 2：移除 `game.ui_port` 隐式挂载

这个里程碑要解决的是依赖方向问题，而不是语法问题。当前 `game.ui_port` 让领域和用例层“知道外层对象长什么样”，这会把 presentation 的细节一路拖进 `src/game`。完成后，`TurnRoll`、`TurnMove`、`TurnDecision`、`IntentDispatcher`、`Bankruptcy`、`ItemPhase` 等模块应只认识显式注入的端口，例如 `NotificationPort`、`AnimGatePort` 或更小的专用端口。

实施顺序要从最窄的读路径开始。先把只读布尔判断迁出，比如 `wait_action_anim`、`wait_move_anim`，再迁 `push_popup` 这类行为端口，最后处理 `ui_port.state` 这种最危险的反向回读。每迁完一个文件，就同步缩小 `game.ui_port` 的基线预算。不要一次性替换所有使用点，否则很难定位回归。

验收标准是：阶段0里 `game.ui_port` 的预算开始下降，并新增契约测试证明某个被迁出的模块在没有 `game.ui_port` 的情况下仍能运行。

## 里程碑 3：完成 runtime 适配器外迁

这个里程碑要把 `src/core` 恢复成“只包含策略、规则和跨宿主抽象”的目录，不再直接摸 Eggy 宿主 API。优先迁 `src/core/RuntimeEnvBindings.lua`、`src/core/runtime_ports/DefaultPorts.lua`、`src/core/RuntimeContext.lua`、`src/core/RuntimeEditorExports.lua`、`src/core/Logger.lua`。目标位置应落在 `src/app/bootstrap` 或新的 `src/infrastructure` 风格目录，关键原则是让 `src/core` 只定义接口或纯逻辑，不负责绑定全局。

实施时先迁环境安装，再迁默认端口，再迁编辑器导出与日志。`Logger` 必须改成注入 sink，而不是继续直接找 `GlobalAPI.show_tips`。每完成一项，就让 `tests/internal/dep_rules.lua` 中 `src/core` 宿主 API 的预算下降，并在同一提交里更新预算数字。

验收标准是：`src/core` 宿主 API 预算明显缩小，且 `runtime_ports_contract` 或新增契约测试能证明新的 bootstrap 适配器提供了同样的行为。

## 里程碑 4：拆分 Market 购买链路

这个里程碑要处理当前最典型的跨层事务脚本。`src/game/systems/market/service/Purchase.lua` 同时做商品映射、平台支付、事件注册、购买兑现和 UI 刷新，任何一个点出问题都会让测试和宿主耦合在一起。完成后，业务规则应留在 `src/game/systems/market` 下的 domain 或 service，平台支付应移到独立 gateway，UI 刷新应回到 presentation 或 output port。

建议先定义 `PaymentGatewayPort`，再把平台映射与回调桥接移到外层实现，最后让用例层只接收“支付已完成”事件。不要在这个阶段顺手做 presentation 文案清理，那是阶段5的职责。

## 里程碑 5：整理 presentation 应用规则

这个里程碑完成后，presentation 只负责把 ViewModel 渲染出来，不再根据 `choice.kind` 和 `meta` 再做一轮业务判断。优先处理 `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`，然后收口 `src/presentation/ui/choice_screen_service/common.lua` 和 target choice 相关渲染模块。最终目标是让 choice DSL 只存在于用例层定义的稳定输出模型中，而不是散落在 UI 适配器里。

验收标准是：presentation 中对 `choice.kind` 的分支显著减少，且新增的确认弹窗文案来自用例层提供的完整 ViewModel。

## 里程碑 6：目录语义整理

这个里程碑只在前五个阶段都稳定后再做。届时才能安全重命名目录、补 ADR、整理 `src/core` / `src/game/flow` / `src/presentation/read_model` 的职责解释。这里不要夹带行为改动，只做命名、导读和收尾清理，否则很容易把阶段1到阶段5的回归和目录变动混在一起。

## 工作计划

如果现在继续推进，不要再回头扩阶段0。下一步就是开始阶段1。先在 `src/game/flow/ports` 下定义一个稳定的输出端口模块，把它接到 `src/game/flow/turn/GameplayLoopPorts.lua` 的 grouped ports 中。随后分三批迁移当前的直接 UI 写入。第一批只迁 `state.ui_dirty` 这类失效信号，因为风险最低。第二批迁 `pending_choice` 和 `ui_model` 的构建与关闭路径，因为它们决定了选择框和 market 的主流程。第三批再迁 `TickTimeout.lua` 里的 `ui_modal_elapsed`、`ui_modal_ref`，让倒计时状态也进入端口化管理。

阶段1一旦有一条路径完成，就立刻补测试，而不是等全部文件都迁完。最先应该增加的是“Fake Output Port 下运行 GameplayLoop 一帧并收到预期输出”的契约测试。等阶段1把 `state.ui_*` 的预算压下去后，再进入阶段2；阶段2开始前不要把 `game.ui_port` 和 `state.ui_*` 两类边界同时大改，否则很难知道回归是从哪一类泄漏进来的。

阶段2和阶段3都要沿用同一个节奏。每次只迁一小组文件，迁完立刻缩预算、补契约、跑全量。阶段4到阶段6则建立在前面三阶段已经让边界稳定的前提上，否则 Market 和 presentation 的重构会重新把边界拉回去。

## 具体步骤

先验证阶段0当前状态。工作目录固定为仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly`。

    lua tests/internal/dep_rules.lua

预期输出：

    dep_rules ok

再跑阶段0的定向守护契约。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('architecture_guard_contract') })"

预期输出最后一行是：

    All regression checks passed (3)

然后跑全量回归，确认默认入口已经包含阶段0守护。

    lua tests/regression.lua

预期输出末尾包含：

    All regression checks passed (364)
    dep_rules ok
    tick ok
    forbidden_globals ok

开始阶段1时，先新建或修改这些文件，并在每一步后重复上面的三条命令：

    src/game/flow/ports/UseCaseOutputPort.lua
    src/game/flow/turn/GameplayLoopPorts.lua
    src/game/flow/turn/GameplayLoop.lua
    src/game/flow/turn/TurnDispatch.lua
    src/game/flow/turn/TickTimeout.lua
    tests/suites/architecture_guard_contract.lua
    tests/internal/dep_rules.lua

如果在阶段1里成功减少了某个预算值，必须在同一提交里更新 `tests/internal/dep_rules.lua` 中对应的数字，否则 `dep_rules` 会因为“预算陈旧”而失败。这是有意设计的约束，不是误报。

## 验证与验收

阶段0的验收标准已经满足，并且今后每次重构都必须继续满足。

第一，静态守护必须失败于任何新增边界泄漏。验证方法是运行 `lua tests/internal/dep_rules.lua`；只要新增了 `src/core` 宿主全局触点、`game.ui_port` 读路径或 `state.ui_*` 写入，命令就应失败并给出文件名。

第二，动态守护必须证明“关键路径上只暴露 DTO 和粗粒度输出”。验证方法是运行 `architecture_guard_contract`；它应继续证明 `GameplayLoop.set_game` 没有把原始 `state` 挂给 `game.ui_port`，且 `TurnDispatch` 没有继续扩写新的 `state.ui_*` 字段。

第三，默认回归必须包含这两类守护。验证方法是运行 `lua tests/regression.lua`；结果必须通过，并继续打印 `dep_rules ok`。

第四，CI 必须跑同一入口。验证方法是检查 `.github/workflows/regression.yml`，它只能调用 `lua tests/regression.lua`，不要维护第二套回归命令。

阶段1之后的验收要更严格。每推进一阶段，都要同时看到两件事：一个新的业务或架构契约测试加入默认回归，以及 `tests/internal/dep_rules.lua` 中至少一组预算值下降。没有预算下降，说明只是搬代码，没有真正收口边界。

## 可重复性与恢复

阶段0的命令都是幂等的，可以重复运行，不会修改工作树。真正需要小心的是预算文件。`tests/internal/dep_rules.lua` 现在既是守护脚本，也是剩余债务的账本。以后如果你删除了一处旧的 `game.ui_port` 读取或 `state.ui_*` 写入，却忘了同步收紧预算，`dep_rules` 会失败。这不是回归，而是提醒你把账本和代码一起更新。

如果要回退阶段0本身，只需要回退四处变更：`tests/internal/dep_rules.lua`、`tests/suites/architecture_guard_contract.lua`、`tests/regression.lua`、`.github/workflows/regression.yml`。回退之后要重新运行 `lua tests/regression.lua`，确认仓库回到“没有阶段0守护”的旧状态。不要只回退测试或只回退 workflow，那会留下本地与 CI 不一致的坏状态。

## 产物与备注

阶段0的关键产物如下。

    tests/internal/dep_rules.lua
    tests/suites/architecture_guard_contract.lua
    tests/regression.lua
    .github/workflows/regression.yml

当前冻结的债务基线如下。

    src/core 直接宿主触点：47
    game.ui_port 依赖点：23
    src/game/flow 的 state.ui_* 写入：13

本次实际验证输出如下。

    dep_rules ok

以及：

    All regression checks passed (3)

以及：

    All regression checks passed (364)
    dep_rules ok
    tick ok
    forbidden_globals ok

## 接口与依赖

阶段0已经引入了两类必须保留的接口约束。

第一类是 `tests/internal/dep_rules.lua` 中的三组预算规则。它们不是业务接口，但它们定义了当前允许存在的边界泄漏上限。以后如果代码减少了这些泄漏，预算值必须同步下降；以后如果代码想新增这些泄漏，测试必须失败。

第二类是 `tests/suites/architecture_guard_contract.lua` 固定下来的运行时契约。当前至少要维持下面两条事实：

    gameplay_loop.set_game(state, game)
    -- 结果：game.ui_port 是裁剪后的 DTO，而不是原始 state

    turn_dispatch.dispatch_action(game, state, action, opts)
    -- 结果：关键输入路径至多写出 ui_dirty，不得继续扩写新的 state.ui_* 字段

阶段1开始后，请按下面这个接口方向推进，不要再发明新的共享状态入口。

在 `src/game/flow/ports/UseCaseOutputPort.lua` 中定义：

    local output_port = {
      invalidate_ui = function(state) end,
      open_choice = function(state, choice_model) end,
      close_choice = function(state, reason) end,
      sync_modal_timer = function(state, payload) end,
      push_popup = function(state, popup_model) end,
      queue_action_anim = function(state, anim_model) end,
    }

在 `src/game/flow/turn/GameplayLoopPorts.lua` 中把它挂到 grouped ports：

    ports.output.invalidate_ui(...)
    ports.output.open_choice(...)
    ports.output.close_choice(...)

这样做的原因只有一个：阶段1到阶段3都需要一个稳定的出口，让用例层只描述意图，不再直接认识 UI 状态表或宿主对象图。

2026-03-06 / Codex：本次更新完全重写 `.agents/plan.md`，把旧的 AFK 修复计划替换为当前“架构重构路线图与阶段0守护”活文档，并把今天已经完成的阶段0实现、验证命令、后续阶段顺序和验收标准全部写入。这样后续执行者无需聊天历史，只看本文件就能继续推进阶段1。
