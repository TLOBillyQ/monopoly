# Monopoly 代码库 Clean Architecture 重写研究（2026-03-02，R7 执行后）

技能使用：`clean-architecture-reviewer`

## 研究范围与证据

- 扫描范围：`src/*`、`tests/internal/*`、`tests/suites/*`、`.agents/plan.md`。
- 执行证据：
  - `rg -n "src\\.game\\.core\\.runtime\\.MonopolyEvents" src tests` -> 无命中。
  - `lua tests/internal/dep_rules.lua` -> `dep_rules ok`。
  - `lua tests/regression.lua` -> `All regression checks passed (202)` + `dep_rules ok / tick ok / forbidden_globals ok`。
- 热点模块规模（R7 后）：
  - `src/presentation/render/ActionAnimUnitOverlay.lua`：63 行。
  - `src/game/systems/land/LandRentResolver.lua`：108 行。

## 架构结论

R7 完成后，事件契约路径已收敛为单一路径，`MonopolyEvents` 兼容桥完成退役。  
热点模块完成“计算函数 + 副作用函数”二次切片，且回归与依赖规则保持全绿。  
当前架构满足 Dependency Rule 底线，并进入“持续降复杂度 + 扩边界契约”阶段。

## 主要问题（P0-P3）

- P0（阻断级）：未发现。
  - 证据：`dep_rules` 与 `regression` 全绿，无核心层依赖回流。

- P1（高优先级）：未发现。
  - 说明：R6 遗留的 `MonopolyEvents` 兼容桥问题已在 R7（M29）闭环。

- P2（中优先级）：部分跨模块语义仍可继续契约化。
  - 证据：已新增 `cross_module_contract`，但事件目录完整性与更多 use-case 时序仍有扩展空间。

- P3（改进项）：热点模块虽然降复杂度，但仍可继续局部纯函数化与命名收敛。
  - 证据：`ActionAnimUnitOverlay`、`LandRentResolver` 已显著收敛，但仍承担入口编排职责。

## R7 实施结果（对应 M29-M31）

1. M29 兼容桥退役收口（已完成）
   - 删除：`src/game/core/runtime/MonopolyEvents.lua`。
   - 规则升级：`tests/internal/dep_rules.lua` 将该路径纳入 `forbidden_files`；保留 `src/tests` 对旧 require 路径禁用规则。
   - 结果：旧桥文件不存在，旧路径引用命中为 0。

2. M30 热点二次切片（已完成）
   - `ActionAnimUnitOverlay`：
     - 新增 `src/presentation/render/ActionAnimOverlayCompute.lua`（位置计算）。
     - 新增 `src/presentation/render/ActionAnimOverlayRuntime.lua`（单位创建/销毁等副作用）。
     - 入口 `ActionAnimUnitOverlay` 保持原有对外函数与调用方式。
   - `LandRentResolver`：
     - 新增 `src/game/systems/land/LandRentMath.lua`（连通租金 BFS 纯计算）。
     - `LandRentResolver` 保留缓存与状态读取，调用 `LandRentMath` 承载计算逻辑。

3. M31 契约测试扩面（已完成）
   - 新增 `tests/suites/cross_module_contract.lua`，覆盖：
     - 事件契约：`LandEvents` 到 `MonopolyEvents` 目录键映射。
     - 租金链路：`LandRules.contiguous_rent` 与 `LandRentResolver.contiguous_rent` 一致性。
     - 动画桥接：`ActionAnim.play` 按 `kind` 正确分发到 handler。
   - 接入 `tests/regression.lua`，回归基线由 `199` 提升到 `202`（新增测试条目导致）。

## 测试建议

- 用例级测试（保持）：
  - 继续覆盖 `TurnDispatch`、`GameplayLoop`、`LandRules` 核心路径。
- 边界契约测试（增强）：
  - 保持 `read_model_contract`、`usecase_boundary_contract`、`cross_module_contract`。
  - 下一步可补 `MonopolyEvents` 目录完整性（命名空间/键唯一性）契约。
- 依赖规则测试（必须）：
  - 持续执行 `dep_rules`，保持对退役桥文件的“禁止存在”守护。

## 权衡说明

- 短期成本：
  - 模块数量与测试套件数量增加，维护入口更多。
- 长期收益：
  - 事件路径单一化、热点模块职责清晰化、跨模块语义具备自动化守护。
- 取舍结论：
  - 本轮以低风险动作完成高价值收口，后续可继续以契约扩面驱动增量重构。

## 最终评审结论

R7 已完成并通过全量验证，架构从“兼容桥治理”进入“无桥运行 + 持续契约化”阶段。  
下一轮建议优先扩展事件目录与关键用例时序契约，在保持行为稳定前提下继续降低热点编排复杂度。
