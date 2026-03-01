# Monopoly 代码库 Clean Architecture 重写研究（2026-03-01，R5 同步）

技能使用：`clean-architecture-reviewer`

## 研究范围与证据

- 扫描范围：`src/*`、`tests/internal/*`、`tests/suites/*`、`.agents/plan.md`。
- 实测基线：
  - `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
  - `lua tests/regression.lua` -> `All regression checks passed (193)` + `dep_rules ok / tick ok / forbidden_globals ok`
- 代码规模（Lua）：
  - `src/core`：13 文件 / 1270 行
  - `src/game/core`：19 文件 / 1455 行
  - `src/game/flow`：19 文件 / 2541 行
  - `src/game/runtime`：2 文件 / 147 行
  - `src/game/runtime_coroutine`：5 文件 / 442 行
  - `src/game/systems`：52 文件 / 5062 行
  - `src/presentation`：113 文件 / 6858 行
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

当前依赖方向已满足“向内依赖”底线，边界违例由 `dep_rules` 守护。

## 架构结论

R5 执行后，Clean Architecture 的核心约束已满足：`presentation` 不再直连 `game/core|flow|systems`，关键边界均有自动化验证。当前阶段从“修复依赖方向错误”转入“复杂度治理与语义一致性守护”。

## 主要问题（P0-P3）

- P0（阻断级）：未发现。
  - 证据：`dep_rules` 与回归均通过，未出现核心层直连框架全局回流。

- P1（高优先级）：无依赖方向级阻断问题，但兼容桥仍存在生命周期管理需求。
  - 证据：`src/game/core/runtime/MonopolyEvents.lua` 当前为兼容桥（转发到 `src/core/events/MonopolyEvents.lua`）。
  - 风险：若长期保留无治理，可能造成路径认知分裂。

- P2（中优先级）：复杂度热点仍在少数模块，建议继续切片。
  - 证据：`PresentationPorts` 入口虽已变薄，但 `ActionAnimUnits`、`LandRules` 仍是高复杂度中心。

- P3（改进项）：`GameplayReadPort` 与领域规则存在镜像语义，需要持续契约守护。
  - 证据：已新增 `read_model_contract` 测试；后续规则变更需同步检查。

## 重构方案（最小可落地顺序）

1. 兼容桥治理：为 `MonopolyEvents` 旧路径兼容桥设置退役里程碑与 dep_rules 守护。
   - 影响范围：`src/game/core/runtime/MonopolyEvents.lua`、`tests/internal/dep_rules.lua`。
   - 预期收益：完成路径收敛，减少历史路径认知成本。
   - 回归风险：低。

2. 继续模块切片：优先 `ActionAnimUnits` 与 `LandRules`。
   - 影响范围：对应模块及其调用点。
   - 预期收益：降低单点拥塞，提升并行开发效率。
   - 回归风险：中。

3. 契约测试扩展：继续补齐 read-model 与 use-case 边界契约。
   - 影响范围：`tests/suites/*`。
   - 预期收益：防止“结构重构后语义漂移”。
   - 回归风险：低。

## 测试建议

- 用例级测试（必须）：覆盖 `TurnDispatch` 与关键回合流转的输入输出契约。
- 边界契约测试（必须）：保持 `read_model_contract`，并增加更多领域规则映射用例。
- 依赖规则测试（必须）：继续执行 `dep_rules`，新增兼容桥退役守护。
- 回归测试（保持）：`lua tests/regression.lua` 基线更新为 193。

## 权衡说明

- 短期成本：继续切片会带来模块数量增加与少量样板代码。
- 长期收益：边界稳定、职责清晰、回归定位成本持续下降。
- 取舍建议：优先做低风险高收益的“兼容桥治理 + 契约测试扩展”，再推进高复杂度模块切片。

## 最终评审结论

R5 已完成且验证通过，代码库已进入“边界稳定、持续降复杂度”的阶段。下一轮应以复杂度治理和兼容桥退役为主线，保持回归与依赖规则双绿。
