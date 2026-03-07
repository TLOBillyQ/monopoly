# `/src` 有效代码行收敛计划（并行版，修订后）

## 摘要
- 目标：在 **不打破现有分层边界** 的前提下，降低 `/src` 的净有效代码行，并压缩热点大文件数量。
- 已冻结基线（**2026-03-08**）：`lua tests/regression.lua` 通过，回归总数 **381**；`/src` 有效代码约 **22162**；`>=250` 有效行的热点文件 **11** 个。
- 硬验收：
  - `/src` 有效代码 **<= 21662**；
  - 热点文件数 **11 -> <= 6**；
  - **不得新增** `>=250` 有效行的新文件；
  - 分层 LOC 不得通过“横向搬运复杂度”作弊：至少跟踪 `src/presentation`、`src/game/flow`、`src/game/systems`、`src/core`、`src/infrastructure` 五组。
- 允许的小范围交互归一化仅限：
  - market tab/page clamp 与空页 fallback；
  - choice 默认选中逻辑统一；
  - secondary confirm 默认 title/body fallback；
  - cancel/confirm 显隐一致性。
  - 其余交互不在本次调整范围内。

## 关键约束
- 公开入口保持稳定：`gameplay_loop`、`market_view`、`ui_panel_presenter`、`runtime_context`、`logger`、`eggy_paid_purchase_gateway`、`test_profiles` 的模块入口与导出名不变。
- `presentation` 不得补业务语义；`game/flow` 不得回碰 UI/宿主细节；宿主实现继续留在 `src/infrastructure/runtime` 或 `src/app/bootstrap`。
- 共享 helper 的落点先冻结，避免并行任务各自造 `helpers.lua`：
  - market/choice 共享仅落 `src/presentation/view/render/market_*` 与 `src/presentation/view/widgets/choice_screen_service/*`
  - panel 共享仅落 `src/presentation/view/widgets/ui_panel_*`
  - gameplay loop 共享仅落 `src/game/flow/turn/gameplay_loop_*`
  - runtime context 共享仅落 `src/infrastructure/runtime/runtime_context_*`
  - 玩法规则共享仅落 `src/game/systems/*` 或同层 shared-mechanics，不上提到 `src/core`
- `logger` 单独后置，且只允许“私有职责抽取”，禁止 API、输出格式、调用方式变化。
- 任何删代码都不能只靠 `rg`；必须同时检查 bootstrap 装配、runtime helper 安装、editor/runtime refs、场景/节点绑定与目标测试。

## 任务图
```text
T1 ── T2 ──┬── T3 ──┐
           ├── T4 ──┼── T7 ── T8 ── T9
           ├── T5a ─┤
           ├── T5b ─┤
           └── T6a ─┘
T4 ── T5c ──────────┘
T7 ── T6b ──────────┘
```

### T1: 冻结基线与护栏
- **depends_on**: `[]`
- **description**: 冻结当前绿线、LOC 口径、热点名单、分层 LOC 基线；把“先绿后改”定为后续所有任务前提。
- **必须通过**:
  - `lua tests/regression.lua`
  - `tests/internal/dep_rules.lua`
  - `tests/internal/gameplay_loop_no_ui.lua`
  - `tests/suites/architecture/architecture_guard_contract.lua`
- **热点冻结名单**:
  - `src/presentation/view/render/market_view.lua`
  - `src/core/utils/logger.lua`
  - `src/infrastructure/runtime/runtime_context.lua`
  - `src/presentation/view/widgets/ui_panel_presenter.lua`
  - `src/game/flow/turn/gameplay_loop.lua`
  - `src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`
  - `src/game/core/ai/agent.lua`
  - `src/presentation/view/render/board_feedback_service.lua`
  - `src/game/systems/items/item_post_effects.lua`
  - `src/game/systems/board/board.lua`
  - `src/app/testing/config/test_profiles.lua`

### T2: 冻结 `presentation` 合约与共享落点
- **depends_on**: `[T1]`
- **description**: 在改展示代码前先冻结 contract，明确本轮 dedupe 不能重新引入推断逻辑。
- **要锁住的字段/语义**:
  - market：`active_tab`、`page_index`、`page_count`
  - choice owner：`owner_role_id`
  - secondary confirm：默认文案 fallback 规则
  - target picker：owner 必须走显式字段，不回读 `meta.player_id`
- **涉及消费者**:
  - `choice_screen_service/*`
  - `market_view`
  - `ui_intent_dispatcher/pre_confirm_flow`
  - `presentation/model` 中消费 choice/market slice 的模块
  - `target_choice_effects`
- **验证**: presentation 相关 contract 测试先补齐/冻结，再进入 T3。

### T3: 收敛 `choice_screen_service + market_view`
- **depends_on**: `[T2]`
- **description**: 合并 option 解析、按钮显隐、默认选中、selection frame、tab/page 控制与 fallback；保留 `market_view` 入口不变。
- **落点**:
  - market 共享 helper 只放 `src/presentation/view/render/market_*`
  - choice screen 共享保持在 `src/presentation/view/widgets/choice_screen_service/*`
- **本任务负责消灭的热点**:
  - `src/presentation/view/render/market_view.lua`
- **阶段验证**:
  - market tab/page clamp
  - 空页 fallback
  - confirm title/body fallback
  - target picker owner 显式字段
  - market/popup/ui gate/ui runtime 相关 suite

### T4: 先稳住 `gameplay_loop` 外观 API
- **depends_on**: `[T1]`
- **description**: 先把 `gameplay_loop` 中 AFK、`set_game` 装配、`tick` orchestration 拆到同层 helper，稳定它对 `agent/logger/ports` 的接口面，再允许后续 game 侧继续减法。
- **落点**: 仅 `src/game/flow/turn/gameplay_loop_*`
- **本任务负责消灭的热点**:
  - `src/game/flow/turn/gameplay_loop.lua`
- **阶段验证**:
  - `architecture_guard_contract`
  - `intent_output_contract`
  - `runtime_bootstrap`
  - `gameplay_loop_no_ui`

### T5a: 收敛 `item_post_effects`
- **depends_on**: `[T1]`
- **description**: 把可枚举后效处理改为 handler registry / spec table，合并重复分支与日志路径。
- **落点**: `src/game/systems/items/*`
- **本任务负责消灭的热点**:
  - `src/game/systems/items/item_post_effects.lua`
- **阶段验证**: `tests/suites/domain/item.lua` + 相关 gameplay suite

### T5b: 收敛 `board`
- **depends_on**: `[T1]`
- **description**: 将方向选择、邻接 fallback、覆盖物读写的重复分支表驱动化；不改 `board` 对外方法名。
- **落点**: `src/game/systems/board/*`
- **本任务负责消灭的热点**:
  - `src/game/systems/board/board.lua`
- **阶段验证**: `land`、`movement`、`landing` 相关 suite

### T5c: 收敛 `agent`
- **depends_on**: `[T4]`
- **description**: 在 `gameplay_loop` 接口面稳定后，再提炼 `agent` 的目标选择/自动决策；禁止新增 `meta.player_id` ownership 推断，优先对齐 `owner_role_id`。
- **落点**: `src/game/core/ai/*` 或同层 mechanics helper
- **本任务负责消灭的热点**:
  - `src/game/core/ai/agent.lua`
- **阶段验证**: AI 选择路径、remote dice、choice auto-action 相关 gameplay suite

### T6a: 收敛 `runtime_context + payment + test_profiles`
- **depends_on**: `[T1]`
- **description**:
  - `runtime_context`：拆 vehicle/change-skin/install builder
  - `eggy_paid_purchase_gateway`：统一 goods mapping、pending queue、role 解析与 warn 流程
  - `test_profiles`：抽共享片段/构造器，保留现有 profile key
- **边界**: 宿主/支付/runtime builder 仍留在 `src/infrastructure/runtime` 与 `src/app/bootstrap`
- **本任务负责消灭的热点**:
  - `src/infrastructure/runtime/runtime_context.lua`
  - `src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`
  - `src/app/testing/config/test_profiles.lua`
- **阶段验证**:
  - runtime contract suite
  - `paid_currency.lua`
  - `test_profiles.lua`

### T7: 收敛 `ui_panel_presenter`
- **depends_on**: `[T3, T4, T5a, T5b, T6a]`
- **description**: 在 `presentation` 其他共享落点稳定后，再拆 `ui_panel_presenter`，避免并行造第二套 UI helper。
- **必须同时冻结**:
  - `ui_panel.lua` 产出的 row schema
  - avatar fallback
  - cash delta 正/负/零态
  - eliminated 行
  - crown 并列竞态
  - visible/touch_enabled 一致性
- **落点**: `src/presentation/view/widgets/ui_panel_*`
- **本任务负责消灭的热点**:
  - `src/presentation/view/widgets/ui_panel_presenter.lua`
- **阶段验证**: panel 相关 presentation suite

### T6b: 收敛 `logger`
- **depends_on**: `[T7]`
- **description**: 最后处理 `logger`，只拆私有职责：tip queue、entry store、formatting；不改对外 API、不改文本格式、不改调用点。
- **边界**: 不新增宿主全局触点；不把 logger 责任扩散到其他层。
- **本任务负责消灭的热点**:
  - `src/core/utils/logger.lua`
- **阶段验证**: logger 相关 domain/runtime 回归 + 依赖规则

### T8: 删除死代码与退休 helper
- **depends_on**: `[T5c, T6b]`
- **description**: 删除被新 helper/registry 替代的 wrapper、重复 alias、无调用 helper、退休兼容路径。
- **删除前证据**:
  - repo 级引用扫描
  - bootstrap/runtime helper/editor exports 检查
  - 节点/场景名绑定检查
  - 对应 focused suites 通过
- **禁止**: 仅凭 `rg` 判断“未使用”
- **阶段验证**: `dep_rules`、`legacy_path_guard`、对应 touched suites

### T9: 全量验证与指标对账
- **depends_on**: `[T8]`
- **description**: 跑全量回归，复算总 LOC、分层 LOC、热点文件数；未达标时只允许在已触达模块内继续净删减。
- **必须满足**:
  - `lua tests/regression.lua` 继续通过
  - `/src` 有效代码 `<=21662`
  - 热点文件 `<=6`
  - 无新增 `>=250` 有效行文件

## 并行波次
| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | `T1` | 立即开始 |
| 2 | `T2`, `T4`, `T5a`, `T5b`, `T6a` | `T1` 完成 |
| 3 | `T3`, `T5c` | `T2` / `T4` 完成后分别开始 |
| 4 | `T7` | `T3`, `T4`, `T5a`, `T5b`, `T6a` 完成 |
| 5 | `T6b`, `T8` | `T7` 完成；`T8` 还需 `T5c` 完成 |
| 6 | `T9` | `T8` 完成 |

## 测试计划
- **Wave 2 后**:
  - `presentation`：market/popup/ui gate/ui runtime 相关 suite
  - `game`：`gameplay_loop_no_ui`、`architecture_guard_contract`
  - `runtime`：runtime contract、payment/test_profiles 相关 suite
- **Wave 3 后**:
  - `choice/market` 与 AI 选择路径 focused suites
- **Wave 4/5 后**:
  - panel 展示 suite
  - logger 相关 suite
  - `dep_rules`、`legacy_path_guard`
- **最终**:
  - `lua tests/regression.lua`
  - LOC/热点/分层 LOC 复算并与 T1 基线对账

## 假设与默认项
- 本次主要追求“**净减法**”，不是单纯拆文件；每个任务都要明确自己负责消灭的热点与预期 delta。
- 若执行时要落盘，正式可执行版必须写入 `.agents/plan.md`，并补齐 `进度 / 意外与发现 / 决策日志 / 结果与复盘 / 具体命令 / 回滚路径`，以符合 `.agents/harness/PLANS.md`。
- 本计划不引入新三方依赖，不新增长期兼容 shim，不扩到 `/src` 之外的结构重组。
