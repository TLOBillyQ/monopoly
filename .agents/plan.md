# 架构复杂度治理执行计划（基于 `.agents/research.md`）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 的维护要求。研究输入来源：`.agents/research.md`（2026-02-25 版）。


## 目的 / 全局视角

本次工作的目标不是重写架构，而是把研究结论落地成稳定可执行的改造路径。用户可见结果有三点：第一，依赖方向检查在 Windows 和 Linux 上都可靠，不能再出现命令报错却显示通过的“假绿灯”；第二，`GameplayLoop.tick` 的职责边界更清楚，后续改动时回归半径更小；第三，UI 交互链再减一层，新增简单按钮语义时改动文件数不再扩散。

如何证明改造生效：在每个里程碑结束时运行固定回归命令，观察明确输出；同时检查目标文件的函数边界与调用链长度是否按计划收敛。


## 进度

- [x] (2026-02-25 05:05Z) 读取并重审 `.agents/research.md`，确认结论为“非系统性过度工程，存在局部过度抽象与约束校验失真”。
- [x] (2026-02-25 05:06Z) 复核基线测试：`regression=154`，`dep_rules ok`，`tick ok`；同时确认 Windows 下存在 `[` 命令报错噪音。
- [x] (2026-02-25 05:10Z) 将研究结论转换为本执行计划（P0 -> P1 -> P2 顺序）。
- [ ] 里程碑 P0：修复 `tests/internal/dep_rules.lua` 跨平台与失败语义。
- [ ] 里程碑 P1：拆分 `GameplayLoop.tick` 的横切职责，保持行为不变。
- [ ] 里程碑 P2：压平 UI 交互链中的低语义层，缩短常见改动链。
- [ ] 里程碑 P3：建立轻量复杂度监控与执行节奏，防止反弹。


## 意外与发现

- 观察：`dep_rules` 在 Windows 环境会调用不可用的 shell 语法，出现报错后仍可能输出通过。
  证据：

    lua tests/internal/dep_rules.lua
    '[' is not recognized as an internal or external command,
    operable program or batch file.
    dep_rules ok

- 观察：综合回归当前仍是健康状态，便于做增量重构。
  证据：

    lua tests/regression.lua
    All regression checks passed (154)
    dep_rules ok
    tick ok

- 观察：`GameplayLoop.tick` 仍承载输入锁、自动执行、超时、动画、dirty 刷新、debug 同步等多类职责，属于复杂度热点。
  证据：`src/game/flow/turn/GameplayLoop.lua` 第 233-307 行。

- 观察：`intent_builders` 并非全部“纯转发”，但其中存在可内联的低语义节点映射逻辑。
  证据：`ActionLogIntents.lua`（节点映射）与 `PopupIntents.lua`（弹窗关闭判断）可局部并入 `UIEventRouter`，而 `ChoiceIntents.lua`、`MarketIntents.lua` 仍含较明确业务语义。


## 决策日志

- 决策：本轮按 `P0 -> P1 -> P2` 顺序实施，不并行推进。
  理由：先修测试门槛可信度，后续重构才有可靠验收基线。
  日期/作者：2026-02-25 / agent。

- 决策：`TurnActionPort` 在本计划中保留，不作为删除目标。
  理由：它承担 `presentation -> game` 的边界适配和默认回退语义，直接并入 `TurnDispatch` 风险高于收益。
  日期/作者：2026-02-25 / agent。

- 决策：`GameplayLoop.tick` 优先“同文件私有函数拆分”，暂不强制新增多个新模块文件。
  理由：先降认知复杂度、后评估模块化，能降低一次性重构回归风险。
  日期/作者：2026-02-25 / agent。

- 决策：UI 链路收敛先做低风险内联（`ActionLogIntents` / `PopupIntents`），其余 builder 保留并观察。
  理由：这两处耦合范围小、回归面可控，适合作为减层起点。
  日期/作者：2026-02-25 / agent。


## 结果与复盘

当前状态是“计划已落地、实施未开始”。本文件已经把研究结论转换成可执行里程碑、明确了顺序和验收口径。待 P0 完成后，需要回填本节的阶段复盘：是否消除了 `dep_rules` 假通过、是否引入新误报、是否影响回归稳定性。待 P1/P2 完成后，再对“是否仍属于局部过度工程”做最终复评。


## 背景与导读

项目入口从 `main.lua` 进入 `src/app/init.lua`，运行期主循环在 `src/game/flow/turn/GameplayLoop.lua`。`tick(game, state, dt)` 是每帧协调中心，负责把输入状态、自动执行、超时、动画和 UI 刷新串起来。

UI 点击链路位于 `src/presentation/interaction/`。`UIEventRouter.lua` 负责注册点击节点并构造 intent；`UIIntentDispatcher.lua` 负责把 intent 分流到视图命令或游戏动作；游戏动作通过 `src/presentation/api/TurnActionPort.lua` 转到 `src/game/flow/turn/TurnDispatch.lua`。这里的“intent”可以理解为“点击后要执行的动作描述对象”。

依赖方向守卫在 `tests/internal/dep_rules.lua`。它的目标是阻止 `presentation/interaction` 直接依赖 `src.game.*`。当前实现依赖 shell 命令遍历目录，导致跨平台不稳定，这是本计划第一优先级。

“过度工程”在本计划中的定义不是“文件多”，而是“同一改动需要跨太多低语义层同步修改，且这些层没有提供边界价值”。因此本计划重点处理“低收益跳转层”和“复杂度热点函数”。


## 工作计划

### 里程碑 P0：修复依赖规则检查可信度

这一里程碑的结果是：`dep_rules` 在 Windows/Linux 都能稳定运行，命令失败时必须失败退出，不能再出现报错后 `ok`。实施位置只涉及 `tests/internal/dep_rules.lua`。改法是移除 `ls` 与 `[ -d ]` 这类平台相关调用，改成按系统分支的文件列表策略，再统一扫描 Lua 文件内容。为了避免“命令空输出被误判为通过”，脚本需要对“文件列表为空”给出显式失败。

完成后要做两类证明。第一类是正常路径：仓库现状下 `dep_rules ok`。第二类是故障路径：人为加入一条违规则 require，脚本必须报错并返回非 0。两类都通过，才算 P0 结束。

### 里程碑 P1：拆分 `GameplayLoop.tick` 职责（行为保持不变）

这一里程碑不改变外部接口，也不改游戏规则，只做可读性和边界收敛。编辑主文件是 `src/game/flow/turn/GameplayLoop.lua`，必要时配合 `src/game/flow/turn/GameplayLoopRuntime.lua`。把 `tick` 内部逻辑分成几个私有函数：自动执行上下文与步进、超时处理、阶段同步与动画、dirty 刷新与输入锁回写、debug 同步。这样做的目标是让每个子函数有单一职责，减少修改一个点时触发的连锁回归。

完成标准不是“函数变短”本身，而是“行为不变且职责边界清晰”。也就是说回归结果必须保持 154，并且 `tick` 主体只保留编排步骤。

### 里程碑 P2：压平 UI 交互链中的低语义层

这一里程碑聚焦 `src/presentation/interaction/UIEventRouter.lua` 和 `src/presentation/interaction/intent_builders/`。先处理低风险对象：将 `ActionLogIntents.lua` 与 `PopupIntents.lua` 的构造逻辑内联到 `UIEventRouter` 的局部构建函数，减少 require 跳转和文件分散。`BasicIntents.lua`、`ChoiceIntents.lua`、`MarketIntents.lua`、`ItemSlotIntents.lua` 先保留，因为它们仍包含可读的业务分组价值。

P2 的目标是缩短“简单节点行为”的改动路径，而不是强行把所有 builder 合并成一个大文件。完成后若回归稳定，再决定是否继续合并其余 builder。

### 里程碑 P3：建立防反弹机制

这一里程碑不做大改，只建立节奏和门槛。每两周输出一次轻量复杂度快照（抽象命名密度、`<=20` 行文件数量、UI 链路层数）。新增的短小文件若只有转发语义，需要在代码评审中给出“边界价值说明”，否则不引入。P3 的意义是让复杂度治理持续化，而不是一次性清理后反弹。


## 具体步骤

以下步骤按里程碑顺序执行，工作目录均为仓库根目录 `c:\Users\Lzx_8\Desktop\dev\monopoly`。

P0 步骤：

1. 编辑 `tests/internal/dep_rules.lua`，去掉 `_walk_dir` 和 `_is_dir` 这类依赖 shell 目录判断的方法，改为跨平台文件列表函数。
2. 保留现有“扫描 `src/presentation/interaction` 中 `.lua` 文件并查找 `src.game.` 前缀”的规则语义。
3. 新增失败保护：文件列表为空或文件不可读时直接 `os.exit(1)`。
4. 运行：

    lua tests/internal/dep_rules.lua

   预期：仅出现 `dep_rules ok`，无 `[` 相关报错。

5. 做反向验证：临时在 `src/presentation/interaction` 下新增一个只含违规则 require 的探针文件，运行 dep_rules，确认失败；随后删除探针文件并再次确认通过。

P1 步骤：

1. 编辑 `src/game/flow/turn/GameplayLoop.lua`，把 `tick` 的内联块拆成私有函数。
2. 保持导出接口不变：`gameplay_loop.tick(game, state, dt)`。
3. 避免修改行为分支条件和端口调用顺序；只做结构重排和命名。
4. 运行：

    lua tests/internal/gameplay_loop_no_ui.lua
    lua tests/regression.lua

   预期：`tick ok`；`All regression checks passed (154)`。

P2 步骤：

1. 将 `ActionLogIntents.lua` 和 `PopupIntents.lua` 的构造逻辑移入 `UIEventRouter.lua` 的私有函数。
2. 更新 `UIEventRouter.lua` 的 require 列表与 `_build_default_route_specs` 组装逻辑。
3. 删除已内联文件，并搜索确认无残留引用。
4. 运行：

    rg -n "ActionLogIntents|PopupIntents" src tests
    lua tests/regression.lua
    lua tests/internal/dep_rules.lua

   预期：搜索无引用；回归通过；dep_rules 通过且无 shell 报错。

P3 步骤：

1. 在 `.agents/` 追加“复杂度快照模板”，记录统计项与采样日期。
2. 在团队执行说明中加入“短小转发文件需说明边界价值”的评审规则。
3. 与业务迭代同步，按双周更新一次。


## 验证与验收

验收必须同时满足行为结果和结构结果。

行为结果：

1. `lua tests/regression.lua` 输出 `All regression checks passed (154)`。
2. `lua tests/internal/gameplay_loop_no_ui.lua` 输出 `tick ok`。
3. `lua tests/internal/dep_rules.lua` 输出 `dep_rules ok`，并且没有 `[` 命令报错。
4. 人为注入依赖违规时，`dep_rules` 必须失败退出（非 0）。

结构结果：

1. `GameplayLoop.tick` 主体变为编排函数，横切逻辑有清晰私有函数边界。
2. UI 链路至少减少一个低语义跳转层（`ActionLogIntents` / `PopupIntents` 已内联）。
3. `TurnActionPort` 仍保留边界职责，不出现 `interaction` 直接依赖 `src.game.*` 的退化。


## 可重复性与恢复

本计划采用增量改造，每一步都可独立回滚。建议每个里程碑单独提交，失败时只回退当前里程碑。回归命令是幂等的，可重复执行。若中途失败，先用 `git diff` 缩小问题范围，再只恢复最近一个里程碑涉及的文件。

推荐恢复策略是文件级恢复而非整仓回退。这样不会覆盖并行开发中的其他改动，也更容易定位回归来源。


## 产物与备注

当前基线（2026-02-25）：

    lua tests/regression.lua
    '[' is not recognized as an internal or external command,
    operable program or batch file.
    All regression checks passed (154)
    dep_rules ok
    tick ok

    lua tests/internal/dep_rules.lua
    '[' is not recognized as an internal or external command,
    operable program or batch file.
    dep_rules ok

    lua tests/internal/gameplay_loop_no_ui.lua
    tick ok

P0 完成后在此追加：

    dep_rules 正常路径输出
    dep_rules 违规注入时失败输出

P1 完成后在此追加：

    gameplay_loop_no_ui 输出
    regression 输出

P2 完成后在此追加：

    ActionLogIntents/PopupIntents 引用搜索结果
    regression + dep_rules 输出


## 接口与依赖

本计划不引入外部新依赖，不修改游戏规则接口。关键接口保持如下：

1. `src/game/flow/turn/GameplayLoop.lua` 继续导出 `tick(game, state, dt)`、`new_game(state)`、`set_game(state, game)`。
2. `src/presentation/interaction/UIEventRouter.lua` 继续导出 `bind(state, get_game)` 与 `unbind(state)`。
3. `src/presentation/interaction/UIIntentDispatcher.lua` 继续通过 `TurnActionPort` 边界转发游戏动作。
4. `tests/internal/dep_rules.lua` 继续作为脚本入口运行，不改调用命令，仅改内部遍历与失败语义。

里程碑结束时，依赖方向规则仍应保证：`src/presentation/interaction` 不允许直接依赖 `src.game.*`。


## 本次更新说明

2026-02-25：将旧版“已完成 M0-M3 收敛记录”重写为“基于最新 `.agents/research.md` 的执行计划”，原因是研究结论已更新为“先修约束可信度，再做复杂度收敛”。新版本明确了 P0-P3 顺序、每个里程碑的文件范围、命令级验收和失败回滚策略，便于后续代理直接按计划实施。
