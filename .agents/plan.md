# Monopoly Clean Architecture 执行计划（R7 执行版）

本计划遵循 `.agents/harness/PLANS.md`，以 `.agents/research.md`（2026-03-02，R6 执行后）为唯一事实输入。  
R7（M29-M31）已执行完成并通过回归验证；本文件为执行闭环记录。

## 目标

围绕 research 中“重构方案（最小可落地顺序）”落地三项动作：
1. 兼容桥退役收口：删除 `src/game/core/runtime/MonopolyEvents.lua`，并升级规则为“禁止文件存在 + 禁止旧路径引用”。
2. 热点继续切片：对 `ActionAnimUnitOverlay` 与 `LandRentResolver` 做“计算函数 / 副作用函数”分离。
3. 契约测试扩面：补齐事件契约、租金链路、动画桥接语义的跨模块一致性测试。

## 里程碑（R7：M29-M31）

- M29（低风险高收益）：`MonopolyEvents` 兼容桥彻底退役。
- M30（中风险）：`ActionAnimUnitOverlay` 与 `LandRentResolver` 二次切片，控制文件复杂度与副作用边界。
- M31（低风险）：新增跨模块契约测试并接入 `tests/regression.lua`。

## 执行范围

- 代码：
  - `src/game/core/runtime/MonopolyEvents.lua`（删除）
  - `src/presentation/render/*`（以 `ActionAnimUnitOverlay` 为核心）
  - `src/game/systems/land/*`（以 `LandRentResolver` 为核心）
- 测试与规则：
  - `tests/internal/dep_rules.lua`
  - `tests/suites/*contract*.lua`
  - `tests/regression.lua`（仅做接入，不改测试语义）

## 详细步骤

1. M29 兼容桥退役
   - 删除 `src/game/core/runtime/MonopolyEvents.lua`。
   - 在 `dep_rules` 增加“文件不存在”断言。
   - 继续保留并强化“旧路径 require 禁止”规则。
   - 验证：
     - `Get-ChildItem src,tests -Recurse -File -Filter '*.lua' | Select-String -Pattern 'src\\.game\\.core\\.runtime\\.MonopolyEvents'`
     - `lua tests/internal/dep_rules.lua`

2. M30 热点二次切片
   - `ActionAnimUnitOverlay`：拆分纯计算（坐标/文案/可见性决策）与渲染副作用（节点创建/更新/销毁）。
   - `LandRentResolver`：拆分纯计算（租金链路、所有权、连锁加成）与状态读取/外部访问。
   - 保持现有入口 API 与返回结构不变，避免调用方改造。
   - 验证：
     - 目标模块单测/套件（若存在）
     - `lua tests/regression.lua`

3. M31 契约测试扩面
   - 新增或扩展以下契约测试：
     - 事件契约：事件名、载荷字段、触发时序（最小集合）。
     - 租金链路：`LandRules` 与 `LandRentResolver` 对同一输入语义一致。
     - 动画桥接：UI 动画触发条件与 use-case 输出语义一致。
   - 纳入 regression 聚合执行。
   - 验证：
     - `lua tests/regression.lua`
     - 输出基线不低于当前 `199`（允许因新增测试上升）。

## 验收标准

1. `src/game/core/runtime/MonopolyEvents.lua` 不存在。
2. 全仓无旧路径 `src.game.core.runtime.MonopolyEvents` 引用。
3. `dep_rules` 对“旧路径引用 + 桥文件存在”均可拦截。
4. `ActionAnimUnitOverlay`、`LandRentResolver` 完成“计算/副作用”边界分离且外部行为不变。
5. 新增契约测试通过，`lua tests/regression.lua` 全绿，且总通过数 `>= 199`。

## 风险与回退

- 风险 A：外部仍隐式依赖兼容桥路径。
  - 缓解：先做全仓搜索与 `dep_rules` 守护，再删除文件。
- 风险 B：热点切片引发行为漂移。
  - 缓解：保持入口签名不变，先抽纯函数再收拢副作用，分步提交验证。
- 风险 C：契约测试过度绑定实现细节。
  - 缓解：仅断言对外语义与跨模块一致性，不断言内部实现顺序。

## 执行记录（已完成）

- [x] (2026-03-02) 根据最新 `research.md` 重写 R7 计划（M29-M31）。
- [x] (2026-03-02) M29：删除 `src/game/core/runtime/MonopolyEvents.lua`，`dep_rules` 升级为“禁止文件存在 + 禁止旧路径引用”守护。
- [x] (2026-03-02) M30：完成 `ActionAnimUnitOverlay` 与 `LandRentResolver` 二次切片，新增 `ActionAnimOverlayCompute/ActionAnimOverlayRuntime/LandRentMath`，保留入口 API。
- [x] (2026-03-02) M31：新增 `tests/suites/cross_module_contract.lua`（事件契约、租金链路、动画桥接）并接入 `tests/regression.lua`。
- [x] (2026-03-02) 全量验证通过：`dep_rules ok`，`All regression checks passed (202)`，`tick ok`，`forbidden_globals ok`。

## 本次修订记录

- 修订：以 R6 研究结论为输入，重写下一轮执行计划为 R7（M29-M31）。
  原因：用户要求“根据研究的下一步重构方案，撰写新 plan”。
  日期/作者：2026-03-02 / Codex GPT-5。
