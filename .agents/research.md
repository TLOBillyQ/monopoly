# Monopoly 代码库 Clean Architecture 重写研究（2026-03-02，R6 执行后）

技能使用：`clean-architecture-reviewer`

## 研究范围与证据

- 扫描范围：`src/*`、`tests/internal/*`、`tests/suites/*`、`.agents/plan.md`。
- 实测基线：
  - `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
  - `lua tests/regression.lua` -> `All regression checks passed (199)` + `dep_rules ok / tick ok / forbidden_globals ok`
- 代码规模（Lua）：
  - `src/core`：13 文件 / 1270 行
  - `src/game/core`：19 文件 / 1456 行
  - `src/game/flow`：19 文件 / 2541 行
  - `src/game/runtime`：2 文件 / 147 行
  - `src/game/runtime_coroutine`：5 文件 / 442 行
  - `src/game/systems`：53 文件 / 5079 行
  - `src/presentation`：115 文件 / 6887 行
  - `src/app`：7 文件 / 531 行
- 关键依赖方向（当前）：
  - `presentation -> game/core`：0
  - `presentation -> game/flow`：0
  - `presentation -> game/systems`：0
  - `game/core -> game/flow`：0
  - `game/core -> game/runtime_coroutine`：0

## 系统策略与用例提炼

### Enterprise Rules（企业级规则）

- 玩家与胜负规则：现金、破产、淘汰、胜利判定（`src/game/core/player/*`、`src/game/core/runtime/*`）。
- 地块与投资规则：购买、升级、租金、总投入（`src/game/systems/land/*`）。
- 棋盘与移动规则：路径推进、地块访问、移动语义（`src/game/systems/board/*`、`src/game/systems/movement/*`）。

### Application Rules（应用级用例）

- 回合主流程编排：`start -> roll -> move -> landing -> post_action -> end_turn`（`src/game/runtime/PhaseRegistry.lua` + `src/game/flow/turn/*`）。
- 协程会话与动作路由：`wait_*` 状态推进（`src/game/runtime_coroutine/*`）。
- UI 意图到领域动作分发：`TurnDispatch` 与 `UIIntentDispatcher` 协作（`src/game/flow/turn/TurnDispatch.lua`、`src/presentation/interaction/*`）。

## 分层与边界映射

- Entities：`game/core/player`、`game/systems/land` 中纯规则计算。
- Use Cases：`game/flow/turn`、`game/runtime_coroutine`、`game/systems/*` 的流程与决策。
- Interface Adapters：`presentation/*`、`app/bootstrap/*`、`presentation/api/*`。
- Frameworks & Drivers：Eggy `GameAPI`、全局事件、`Config/*`、第三方运行时。

依赖方向已满足 Clean Architecture 的 Dependency Rule 底线，且由 `dep_rules` 自动化守护。

## 架构结论

R6 执行后，核心架构约束保持稳定：`presentation` 对 `game` 三层直连均为 0，兼容桥路径已纳入规则治理，热点模块完成一轮切片并保持行为等价。当前阶段应从“边界修复”转向“兼容桥退役收口 + 复杂度持续下降”。

## 主要问题（P0-P3）

- P0（阻断级）：未发现。
  - 证据：`dep_rules` + `regression` 双绿，核心层未出现全局 API 回流。

- P1（高优先级）：`MonopolyEvents` 兼容桥仍存在，需完成最终退役闭环。
  - 证据：`src/game/core/runtime/MonopolyEvents.lua` 仍保留 thin-forwarder。
  - 风险：长期保留会形成路径双轨认知。

- P2（中优先级）：复杂度热点仍集中在部分大文件（虽已下降）。
  - 证据：`ActionAnimUnits.lua` 已降至 26 行、`LandRules.lua` 已降至 159 行；但 `ActionAnimUnitOverlay.lua`（226 行）等仍有进一步切片空间。

- P3（改进项）：契约测试覆盖已扩展，但 read-model/use-case 边界仍可继续扩面。
  - 证据：`read_model_contract` 与 `usecase_boundary_contract` 已纳入回归；可继续覆盖更多跨模块语义约束。

## 重构方案（最小可落地顺序）

1. 兼容桥退役收口：删除 `src/game/core/runtime/MonopolyEvents.lua`，并在 `dep_rules` 改为“禁止文件存在 + 禁止旧路径引用”。
   - 影响范围：兼容桥文件、`tests/internal/dep_rules.lua`。
   - 预期收益：完成事件契约路径单一化。
   - 回归风险：低（当前内部引用已清零）。

2. 继续热点切片：针对 `ActionAnimUnitOverlay` 与 `LandRentResolver` 再拆为“计算函数 + 副作用函数”。
   - 影响范围：`src/presentation/render/*`、`src/game/systems/land/*`。
   - 预期收益：降低单模块认知负担，提升可测试性。
   - 回归风险：中。

3. 契约测试扩面：增加“跨模块一致性”用例（事件契约、租金链路、动画桥接语义）。
   - 影响范围：`tests/suites/*contract*.lua`。
   - 预期收益：防止后续重构造成语义漂移。
   - 回归风险：低。

## 测试建议

- 用例级测试（必须）：继续覆盖 `TurnDispatch`、`GameplayLoop`、`LandRules` 关键路径。
- 边界契约测试（必须）：
  - 保持 `read_model_contract` 与 `usecase_boundary_contract`。
  - 新增事件契约与兼容桥退役后的路径约束测试。
- 依赖规则测试（必须）：
  - 继续执行 `dep_rules`，将兼容桥治理升级为“禁止文件存在”。
- 回归测试（保持）：
  - `lua tests/regression.lua` 以 199 为当前基线。

## 权衡说明

- 短期成本：继续切片与契约扩面会增加模块和测试条目。
- 长期收益：边界路径更单一、复杂度更低、回归定位更快。
- 取舍建议：优先完成“兼容桥退役”这一低风险高收益动作，再推进下一轮复杂度切片。

## 最终评审结论

R6 已执行完成，架构从“边界受控”进入“边界收口 + 持续降复杂度”阶段。下一轮建议以兼容桥彻底退役为里程碑起点，并保持契约测试与依赖规则同步增强。
