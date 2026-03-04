# Role 身份与作用域统一治理计划（UIManager / 回合动作 / 场景事件）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护；任何实施或讨论都要先对照该规范检查章节完整性与可验证性。

## 目的 / 全局视角


这项工作解决的是“同一玩家身份在不同层被不同方式解释”的长期稳定性问题。当前项目里同时存在 `player_id`、`role_id`、`actor_role_id` 三种近义字段，并且来源有 `data.role`、`UIManager.client_role`、`ui_model.current_player_id`、`choice.meta.player_id`。这会导致两个用户可见风险：一是输入动作被错误拒绝或错误放行，二是 UI 在多客户端下出现串屏或错屏。

改动完成后，用户能稳定获得三件事：任何可交互动作都有明确操作者，非操作者无法越权提交动作，UI 只在目标客户端可见且不会污染其他客户端。验证方式不是“看代码像是对的”，而是通过自动化测试和实机日志证明：`actor_role_id` 全链路完整、校验一致、作用域无泄漏。

## 进度


- [x] (2026-03-04 12:20+08:00) 已完成：阅读 `.agents/harness/PLANS.md`，确认计划结构与写作约束。
- [x] (2026-03-04 12:24+08:00) 已完成：阅读 `.agents/research.md` 与相关源码，提炼统一方案边界。
- [x] (2026-03-04 12:30+08:00) 已完成：产出本可执行计划初稿并写入 `.agents/plan.md`。
- [ ] 待完成：里程碑 1（身份契约收敛）实施与提交。
- [ ] 待完成：里程碑 2（actor 注入与输入链路统一）实施与提交。
- [ ] 待完成：里程碑 3（role 解析入口收敛）实施与提交。
- [ ] 待完成：里程碑 4（UI 作用域防污染）实施与提交。
- [ ] 待完成：里程碑 5（测试与回归验收）实施与记录。

## 意外与发现


- 观察：仓库当前已有 `actor_role_id` 强校验，但“身份注入”与“身份来源”仍是分散实现。
  证据：`src/game/flow/turn/TurnDispatchValidator.lua` 强制校验 `next/item_slot/choice`，同时 `src/presentation/canvas_runtime/LocalActorResolver.lua` 是注入入口。

- 观察：`UIManager` 文档已明确 click 回调提供 `data.role`，这应成为输入身份的一号来源，而不是可选来源。
  证据：`docs/eggy/ui_manager_lib.md` 的 `listen("CLICK", function(data) ...)` 示例中明确写出 `data.role`。

- 观察：少量业务模块仍直接走 `GameAPI.get_role`，绕过统一 resolver，未来容易出现同一身份在不同模块不一致。
  证据：`src/game/systems/commerce/PaidCurrencyBridge.lua`。

## 决策日志


- 决策：将统一工作的主线定义为“先统一身份契约，再统一入口，再清理旁路”，不做一次性大爆炸重构。
  理由：当前代码已具备局部正确性（如回合校验），增量收敛风险更低且便于回归定位。
  日期/作者：2026-03-04 / Codex

- 决策：`actor_role_id` 作为所有交互动作的唯一操作者字段，继续保留并扩大覆盖，不新增并行字段。
  理由：该字段已在 `TurnDispatch` 与测试中成为事实标准，顺势扩展成本最低。
  日期/作者：2026-03-04 / Codex

- 决策：`data.role -> UIManager.client_role -> ui_model.current_player_id` 作为统一 actor 解析优先级，最后一项仅作容错。
  理由：与 UIManager 文档能力一致，同时能避免极端情况下回合卡死。
  日期/作者：2026-03-04 / Codex

- 决策：禁止在业务层新增直接 `GameAPI.get_role` 调用；通过 `runtime_ports`/`host_runtime` 统一入口访问 role。
  理由：避免身份解释分叉，提升可测试性与替换能力。
  日期/作者：2026-03-04 / Codex

## 结果与复盘


当前状态是“计划已就绪，实施未开始”。

对照目标，本计划已经明确了用户可见成功标准、实施顺序、文件落点、测试指令与回退方案。实施完成后，本节必须回填：完成项、遗留项、偏差原因、后续建议。

## 背景与导读


本任务跨越四个层次。第一层是“身份对象”，也就是引擎 `role`（有 `get_roleid/get_ctrl_unit/send_ui_custom_event` 等能力）。第二层是“身份主键”，也就是数值 id（`role_id` / `player.id` / `actor_role_id`）。第三层是“输入意图”，也就是 UI 点击最终被派发的 action。第四层是“作用域控制”，也就是 `UIManager.client_role` 决定 UI 变更影响哪位玩家。

相关模块关系如下：`CanvasEventRouter` 负责把点击事件变成 intent 并补齐 actor；`UIIntentDispatcher` 把 intent 送到 turn dispatch；`TurnDispatchValidator` 在业务边界强校验 actor；`UIRuntimePort` 负责 `client_role` 生命周期；`UIEvents` 负责向 role 定向或广播 UI 事件；`runtime_ports` 与 `host_runtime` 提供 role 解析统一入口。

关键文件导读（必须先读）：

- `docs/eggy/ui_manager_lib.md`
- `src/presentation/canvas_runtime/CanvasEventRouter.lua`
- `src/presentation/canvas_runtime/LocalActorResolver.lua`
- `src/presentation/interaction/UIIntentDispatcher.lua`
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/turn/TurnDispatchValidator.lua`
- `src/presentation/api/UIRuntimePort.lua`
- `src/presentation/shared/UIEvents.lua`
- `src/game/systems/commerce/PaidCurrencyBridge.lua`
- `tests/suites/presentation_ui_event_bindings.lua`
- `tests/suites/presentation_ui.lua`
- `tests/suites/runtime_ports_contract.lua`

## 里程碑


### 里程碑 1：身份契约收敛（命名与字段）


这个里程碑的目标是把“谁在操作”这个问题在代码语义上统一成一个字段：`actor_role_id`。完成后，阅读任意 UI 动作链路时，不再需要猜测 `player_id/role_id` 是否混用。

实施内容包括：统一注释与局部变量命名；把 choice owner 的语义固定为 `choice.meta.player_id`（表示 owner role id）；在必要处增加轻量断言与日志语义校正。该里程碑不改业务逻辑，只改契约表达与可读性。

验收时运行现有 UI 与 turn 测试，行为不变但日志语义更一致。

### 里程碑 2：actor 注入入口统一（输入链路）


这个里程碑把 actor 注入彻底收敛到 `CanvasEventRouter + LocalActorResolver`。完成后，所有需要身份的 intent 都通过同一优先级补齐 `actor_role_id`，并在失败时统一拒绝与提示。

实施内容包括：核对并补齐“需要 actor”的 intent 白名单；确保 `choice_select/choice_cancel/market_confirm/ui_button(next|auto|item_slot_*)/toggle_action_log` 全覆盖；保留 `data.role -> client_role -> current_player_id` 解析顺序。

验收时需要新增或更新测试，证明每类 intent 都能得到正确 actor，且缺失时会被拒绝。

### 里程碑 3：role 解析入口收敛（去旁路）


这个里程碑解决“同类模块用不同入口取 role”问题。完成后，业务层默认通过 `runtime_ports.resolve_role(s)` 或 `host_runtime.resolve_role(_with)` 获取 role，而不是散落 `GameAPI.get_role`。

实施内容首选 `PaidCurrencyBridge`，把直接 `GameAPI.get_role` 改为统一入口；同时保持原能力行为不变（购买、消耗、同步余额）。如果某模块必须保留底层调用，需在决策日志记录原因。

验收时通过原有付费/货币测试，并检查不存在新增旁路调用。

### 里程碑 4：UI 作用域防污染（client_role 生命周期）


这个里程碑确保 `UIManager.client_role` 只在受控范围生效，并且总能复位。完成后，多角色渲染不会串客户端。

实施内容包括：把散落的作用域切换收敛为 `with_client_role` / `for_each_role_or_global` 约定；高风险模块（`UIPanelPresenter`、`UITurnEffects`、`PopupRenderer`、`MarketModalRenderer`、`DebugPorts`）补充防泄漏测试点。

验收时验证：每次渲染后 `UIManager.client_role == nil`，并保持原有可见性行为。

### 里程碑 5：测试矩阵与回归闭环


这个里程碑产出可证明“真的工作”的证据。完成后，能用自动化结果回答“身份是否统一、越权是否被阻止、作用域是否泄漏、旁路是否消除”。

实施内容包括：扩展 `presentation_ui_event_bindings`、`presentation_ui`、`runtime_ports_contract`，必要时增加新套件；执行回归并记录关键输出。

验收以行为为准：测试通过、关键日志符合预期、实机交互与权限边界一致。

## 工作计划


整体顺序采用“契约 -> 入口 -> 旁路 -> 作用域 -> 验证”的增量路线。先做里程碑 1 是为了让后续改动都在统一语言下进行，避免改完后仍难以审查。再做里程碑 2 是因为它直接决定用户交互是否能进入正确业务分支。里程碑 3 处理结构性债务，避免新旧入口长期并存。里程碑 4 做稳定性加固，防止多客户端串屏。最后里程碑 5 形成证据闭环。

建议每个里程碑单独提交，提交信息需包含里程碑编号和用户可见影响，便于回滚与审计。

## 具体步骤


所有命令在仓库根目录执行：`C:\Users\Lzx_8\Desktop\dev\repo\monopoly`。

1. 建立基线并确认工作树状态：

    git status --short

2. 执行里程碑 1 后，先跑最小相关测试：

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({require('presentation_ui_model_dispatch')})"

3. 执行里程碑 2 后，运行事件绑定与 UI 交互测试：

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({require('presentation_ui_event_bindings'), require('presentation_ui_interaction')})"

4. 执行里程碑 3 后，检查是否仍有新增旁路 `GameAPI.get_role`（允许 adapter 层保留）：

    git grep -n "GameAPI.get_role" src

5. 执行里程碑 4 后，运行作用域与渲染相关测试：

    lua -e "package.path=package.path..';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({require('presentation_ui_action_status'), require('presentation_player_colors')})"

6. 执行里程碑 5 后，跑全量回归：

    lua tests/regression.lua

7. 在实机日志中验证 actor 与权限边界（日志路径按本地环境填写）：

    rg "actor_role_id|missing actor_role_id|blocked by actor check|ui intent rejected" <日志文件路径>

## 验证与验收


验收必须覆盖四类行为。

第一类是身份完整性：任意可推进动作都带 `actor_role_id`，缺失时被拒绝并有统一提示。第二类是权限边界：非当前回合玩家无法触发 `next/item_slot_*`，非 owner 无法提交 `choice_select/cancel`。第三类是作用域正确性：多角色渲染后 `UIManager.client_role` 复位为 `nil`，并且 UI 不串屏。第四类是入口一致性：业务层不新增绕过 resolver 的 role 获取路径。

自动化结果以 `lua tests/regression.lua` 为准；若仓库存在与本任务无关的既有失败，必须在“意外与发现”记录失败项名称与证据，不得忽略。

## 可重复性与恢复


本计划按里程碑增量推进，可重复执行。若中途失败，优先回退到“上一个通过测试的里程碑提交”，然后仅重做当前里程碑，不跨里程碑混修。

禁止使用破坏性命令（如 `git reset --hard`）清理。需要恢复时采用可审计方式：

- 回退单个提交：`git revert <commit>`
- 或在当前分支追加修复提交

每次重试都要重新执行该里程碑测试与一轮最小回归。

## 产物与备注


实施完成后，本计划应附带以下证据片段（缩进块，保持精简）：

    [PASS] presentation_ui.event_bindings ...
    [PASS] presentation_ui.interaction ...
    [PASS] runtime_ports_contract ...
    All regression checks passed (N)

以及关键行为日志示例：

    ui intent ... actor_role_id=1
    ui_button blocked by actor check: next actor=2 current=1

如果出现失败，记录首条有效错误与定位结论，不粘贴整段噪声日志。

## 接口与依赖


本计划实施后，以下接口语义必须成立。

在 `src/presentation/canvas_runtime/LocalActorResolver.lua` 中：

    resolve_from_event(state, data) -> integer|nil

解析优先级固定为 `data.role`、`runtime.get_client_role()`、`state.ui_model.current_player_id`，并使用 `NumberUtils.to_integer` 做数值归一。

在 `src/presentation/canvas_runtime/CanvasEventRouter.lua` 中：

    _requires_event_actor(intent) -> boolean

必须覆盖 `toggle_action_log`、`choice_select`、`choice_cancel`、`market_confirm`、`ui_button(next|auto|item_slot_*)`。

在 `src/game/flow/turn/TurnDispatchValidator.lua` 中：

    validate_actor_role(game, action) -> boolean
    validate_choice_actor(game, action, choice) -> boolean

继续作为最终安全边界，不可降级为“缺失 actor 自动放行”。

在 role 解析入口上：

- 核心业务优先使用 `runtime_ports.resolve_role(player_id)`。
- 表现层/场景层优先使用 `host_runtime.resolve_role(_with)`。
- 新增业务代码不得直接引入 `GameAPI.get_role`（adapter 层例外）。

## 假设与默认值


默认假设本仓库继续采用“角色驱动初始化”为主路径，即 `player.id` 与 `role_id` 一致；调试回退路径可保留，但必须不破坏 actor 校验。

默认假设 `UIManager` click 事件继续提供 `data.role`；若未来引擎变更，需先在 `LocalActorResolver` 兼容后再改业务层。

默认假设测试运行环境可执行 `lua` 命令；若本地工具链差异导致命令不同，必须在本计划“具体步骤”中回填实际命令。

## 文档更新记录


- 2026-03-04 / Codex：将 `.agents/plan.md` 从“位置选择屏”历史计划切换为“role 统一治理”可执行计划，原因是用户要求根据 `.agents/research.md` 交付新计划，并且该文件需始终服务当前任务目标。
