# 测试架构一次性重构方案（全量重写并一次切换）

## 摘要

当前测试体系（`tests/regression.lua` + `tests/TestHarness.lua` + `tests/suites/*`）与重构后的生产代码（端口化、运行时拆分、phase 驱动）已经出现语义错位。  
本方案按你的选择执行：**激进重写（1C）+ 一次切换（2B）**，目标是在一次重构中完成：

- 新测试架构落地（分层、统一 DSL、统一 fixtures、统一断言）
- 旧入口替换为新入口（不保留双轨）
- 旧 suites 全量迁移或淘汰
- 回归集恢复稳定并与当前架构严格对齐

---

## 目标与验收标准

- **目标**
  - 测试组织与当前代码边界一致：`game/`、`turn/`、`choice/`、`chance/`、`visual/`。
  - 测试语义与端口契约一致：所有 `ports` 场景通过契约层驱动，不在各测试重复拼接 mock。
  - 消除“隐式时序/状态假设”导致的脆弱失败（如 phase 变化、input_blocked 同步时机）。
  - 一条命令运行新回归集并得到稳定结果。

- **完成判定（DoD）**
  - `tests/regression.lua`（或新命名但保持原调用路径）仅引用新 runner。
  - `tests/suites/` 旧结构不再作为主执行路径。
  - 新测试目录中至少包含 `unit/contract/integration/regression` 四层。
  - 原有关键行为（回合推进、动画 phase、输入锁、choice/market/popup 超时）在新集内有明确覆盖。
  - 全量回归通过，且失败输出能直接定位到“层 + 领域 + 用例”。

---

## 公共接口/类型/入口变更（必须显式）

- **执行入口**
  - `tests/regression.lua` 改为新架构入口（一次切换）。
  - 新增：`tests/runner/init.lua`（统一收集、过滤、执行、汇总）。
  - 新增：`tests/runner/report.lua`（失败分组、摘要输出）。

- **测试注册接口**
  - 新增统一注册协议，例如：
    - `tests/specs/<layer>/<domain>/*.lua` 返回 `cases` 数组
    - 每个 case 包含：`id`、`desc`、`arrange`、`act`、`assert`
  - 替代旧 `*_registry.lua` 的切片式注册。

- **测试上下文构建接口**
  - 新增：`tests/support/context_builder.lua`
  - 统一暴露：
    - `new_game_context(opts)`
    - `new_loop_state(opts)`
    - `new_ports_stub(overrides)`
    - `run_tick(game, state, dt, opts)`

- **端口契约测试接口**
  - 新增：`tests/contract/ports_contract.lua`
  - 固定校验端口最小契约（字段、默认行为、回调参数形状、幂等语义）。

---

## 目录重组蓝图（一次性落地）

- 新目录（主路径）
  - `tests/runner/`
  - `tests/specs/unit/`
  - `tests/specs/contract/`
  - `tests/specs/integration/`
  - `tests/specs/regression/`
  - `tests/support/`
  - `tests/fixtures/`（保留并标准化）

- 旧目录处理
  - `tests/suites/`：迁移完成后移除或保留为 `tests/_legacy_suites_disabled/`（不参与执行）
  - `tests/TestHarness.lua`：迁移到 `tests/runner/legacy_adapter.lua` 仅短期复用；重构完成后删除
  - `tests/internal/`：归并到 `tests/specs/integration/internal_*`（仍可保留 internal 标签）

---

## 分层设计（决策完备）

- **unit**
  - 只测纯逻辑/局部函数，不触发完整 game loop。
  - 示例：`turn/runtime.lua` 的 phase 判定、timer 递增/复位逻辑。

- **contract**
  - 只测模块边界协议，尤其是 `turn/ports.lua` resolve 后行为。
  - 固定验证：
    - 默认端口补齐
    - override 合并优先级
    - `ui_sync.set_input_blocked` 与 `is_input_blocked` 一致性
    - 动画回调参数 `(state, anim_ctx)` 形状

- **integration**
  - 覆盖单次 tick 到多次 tick 的跨模块行为。
  - 示例：`wait_move_anim -> move_anim_done -> next phase`；输入锁对 action button timeout 的阻断。

- **regression**
  - 只放高价值链路（游戏回合主流程、choice + market + popup 并存场景、detained_wait 超时、自动玩家行为）。
  - 禁止在 regression 内直接构造复杂 mock；统一走 `support/context_builder`。

---

## 重构实施步骤（按顺序，不留实现决策）

1. 建立新 runner 骨架与统一用例协议。  
2. 搭建 `tests/support`（context_builder、assertions、time_stub、ports_stub）。  
3. 先实现 `contract` 层（锁定端口语义，防止后续迁移继续漂移）。  
4. 迁移 `turn/runtime` 和 `turn/init` 相关用例到 `unit + integration`。  
5. 迁移 gameplay 主链路旧用例到 `regression`（按功能簇：动画、输入锁、按钮超时、auto runner）。  
6. 迁移 `choice/chance/market/landing` 用例并清理重复断言。  
7. 切换 `tests/regression.lua` 到新 runner（一次切换点）。  
8. 删除旧注册器和失效 harness 适配层，保留最小兼容 shim（如有必要仅 1 版）。  
9. 全量跑回归并按失败分层修正（先 contract 再 integration 再 regression）。  
10. 更新测试文档（如何新增 case、如何运行单层/单域测试）。

---

## 关键技术约束与默认策略

- **默认一：严格最小 mock**
  - 禁止每个测试手写散乱端口表；全部通过 `new_ports_stub(overrides)`。
- **默认二：时间相关统一 stub**
  - 所有 timeout/timer 测试使用统一 `time_stub`，禁止直接依赖真实 `SetTimeOut`。
- **默认三：断言风格统一**
  - 使用 `assert_equal/assert_truthy/assert_phase` 等 helper，避免自由文本 assert 导致定位困难。
- **默认四：测试命名统一**
  - `given_when_then` 风格，如：`given_input_locked_when_tick_then_action_timeout_blocked`。
- **默认五：不在本轮改生产逻辑**
  - 本计划聚焦测试架构；仅当发现“测试无法表达真实语义”时才提出单独生产修复任务。

---

## 重点迁移映射（旧 -> 新）

- `tests/suites/gameplay.lua`  
  - 动画 phase 与 dispatch 行为 -> `tests/specs/integration/turn_phase_anim_spec.lua`
  - action button timeout 相关 -> `tests/specs/unit/action_button_timer_spec.lua` + `integration` 场景
- `tests/suites/gameplay_runtime.lua`  
  - runtime 纯逻辑 -> `tests/specs/unit/runtime_phase_flags_spec.lua`
- `tests/suites/presentation_ui*.lua`  
  - 端口契约相关部分 -> `tests/specs/contract/ui_sync_ports_spec.lua`
  - 纯表现层行为 -> `tests/specs/integration/visual_input_lock_spec.lua`
- `tests/internal/*`  
  - 保留为 `integration/internal_*`，并标记 `internal = true` 标签以便过滤运行

---

## 测试场景清单（必须覆盖）

- 动画链路：
  - `wait_move_anim` 注入端口调用一次、seq 转发正确
  - `wait_action_anim` 注入端口调用一次、seq 匹配 gate 生效
- 输入锁与按钮超时：
  - input_blocked=true 时，action_button timer 不激活且 elapsed 复位
  - popup/choice/market 活跃时，timer 禁用
  - 条件解除后 timer 重新累计且超时触发 next
- phase 同步：
  - 同一 tick 内 phase 变化后 input_blocked 与 phase 保持一致
- auto runner：
  - 输入锁、popup min visible 限制下不会提前推进
- 端口 resolve：
  - override 不丢字段，默认 fallback 可用
  - `set_input_blocked` 返回值语义（是否发生状态变化）一致

---

## 风险与缓解

- **风险：一次切换导致大面积红灯**
  - 缓解：先完成 contract 层并全部通过，再迁移 integration/regression。
- **风险：旧测试隐含依赖被移除**
  - 缓解：建立 `legacy_behavior_notes.md` 记录每个行为的“新语义解释”。
- **风险：用例迁移时重复/冲突**
  - 缓解：迁移前做 case inventory（按功能簇编号），迁移后对照核销。

---

## 假设与已选默认

- 已按你的决策采用：**激进重写 + 一次切换**。
- 假设当前 `lua tests/regression.lua` 是团队主要回归入口，且允许其内部实现替换。
- 假设可接受一次重构期间短暂不稳定，但最终需恢复“单入口稳定回归”。
- 默认不引入外部测试框架，继续使用现有 Lua 环境与仓内执行方式。

