# Monopoly Clean Architecture 执行计划（R5 重写版）

本计划遵循 `.agents/harness/PLANS.md`，以 `.agents/research.md` 为唯一事实输入。
本轮目标：按 research 中“重构方案（最小可落地顺序）”完整落地，并回填可验证证据。
R5 已执行完毕；当前需根据最新 `research.md` 追加下一轮（R6）计划，不在本次计划修订中执行实现。

## 目的 / 全局视角

当前代码库已完成 R4 收口，但仍存在一条 `presentation -> game/core` 依赖与若干复杂度热点。  
本轮聚焦四件事：
1. 抽离 `MonopolyEvents` 到共享契约层，消除 `presentation -> game/core` 直连。
2. 将 `PresentationPorts` 按职责切片，保持对外 API 不变。
3. 为 `GameplayReadPort` 补契约测试，锁定与领域规则一致性。
4. 继续推进热点分段治理（本轮落地 `GameActionDispatcher` 进一步拆分）。

## 进度

- [x] (2026-03-01 16:10Z) 重写计划并锁定 R5 执行范围（M22-M25）。
- [x] (2026-03-01 16:15Z) M22：新增 `src/core/events/MonopolyEvents.lua` 共享契约；全仓 require 迁移到 `src.core.events.MonopolyEvents`；保留 `src/game/core/runtime/MonopolyEvents.lua` 兼容桥。
- [x] (2026-03-01 16:20Z) M23：`PresentationPorts` 切分为 `Common/Modal/Anim/UISync/Debug/State` 六个子模块，入口 `PresentationPorts.build()` 对外签名保持不变。
- [x] (2026-03-01 16:23Z) M24：新增 `tests/suites/read_model_contract.lua`，验证 `GameplayReadPort.total_land_invested` 与 `LandPricing.total_invested` 等价、`resolve_vehicle_seat_id` 与特性开关一致。
- [x] (2026-03-01 16:26Z) M25：将 `GameActionDispatcher` 拆分为 `PreConfirmFlow` 与 `ItemPhaseAskFlow` 协作模块，降低单文件复杂度。
- [x] (2026-03-01 16:28Z) 全量验证通过：`dep_rules ok`，`All regression checks passed (193)`，`tick ok`，`forbidden_globals ok`。
- [x] (2026-03-01 16:35Z) 已根据 `research.md` 追加 R6 下一轮里程碑（M26-M28），仅写计划不执行。
- [x] (2026-03-02 02:10Z) M26：已为 `MonopolyEvents` 兼容桥补充退役注释，并在 `dep_rules` 增加 `src/tests` 旧路径禁用规则与桥接文件薄转发守护。
- [x] (2026-03-02 02:17Z) M27：已完成 `ActionAnimUnits` 与 `LandRules` 一轮切片（抽出 `ActionAnimUnitOverlay/ActionAnimTipText/LandRentResolver`）。
- [x] (2026-03-02 02:20Z) M28：已扩展契约测试（`read_model_contract` 增补 2 条 + 新增 `usecase_boundary_contract` 4 条）并纳入 regression。
- [x] (2026-03-02 02:22Z) 全量验证通过：`dep_rules ok`，`All regression checks passed (199)`，`tick ok`，`forbidden_globals ok`。

## 意外与发现

1. 回归基线由 190 提升到 193，原因是新增了 3 条 `read_model_contract` 测试，不是行为变更导致。
2. `MonopolyEvents` 迁移若直接删除旧路径会放大外部调用风险；保留一层兼容桥可避免一次性路径切换冲击。
3. `PresentationPorts` 切片后 API 兼容性良好，现有 `presentation_ui` 套件未出现调用签名回归。
4. `research.md` 已将后续主线明确为“兼容桥退役 + 复杂度治理 + 契约测试扩展”，适合形成独立下一轮计划而非并入 R5。
5. `ActionAnimUnits` 可稳定拆为“覆盖物生成/清理”与“提示文案构建”两个子模块；入口保留薄封装即可保持外部行为不变。
6. `LandRules` 的高复杂度主要集中在租金 BFS 与所有权判定，抽出 `LandRentResolver` 后对外接口 (`safe_tile_state/resolve_rent_owner/contiguous_rent`) 可保持兼容。
7. 契约测试扩展后回归基线从 193 提升到 199，提升来自测试数量增长而非行为变化。

## 决策日志

- 决策：采用“共享契约 + 兼容桥”的双轨迁移 `MonopolyEvents`。
  理由：先消除依赖方向问题，再降低路径迁移风险。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：`PresentationPorts` 优先做“文件内职责分段”，不改构建入口与返回结构。
  理由：最小化行为风险，先降复杂度再考虑更深层抽象。
  日期/作者：2026-03-01 / Codex GPT-5。

- 决策：先补 `GameplayReadPort` 契约测试，再继续切分热点模块。
  理由：先锁定语义一致性，再做结构演进，避免“重构后语义漂移”。
  日期/作者：2026-03-01 / Codex GPT-5。

## 结果与复盘

M22-M25 已完成并通过全量回归。  
边界方面：`presentation -> game/core` 的 `MonopolyEvents` 直连已替换为共享契约路径。  
复杂度方面：`PresentationPorts` 与 `GameActionDispatcher` 已进一步模块化。  
质量方面：新增契约测试后回归基线更新为 193，全仓规则与行为检查保持全绿。
根据 `research.md` 建议，M26-M28 已全部执行完成：兼容桥治理规则落地、`ActionAnimUnits/LandRules` 完成一轮切片、契约测试覆盖扩面并纳入 regression。计划状态更新为“R6 完成，待研究下一轮里程碑”。

## 工作计划（R5 已执行）

### 第十一阶段（M22-M25）

- M22：共享事件契约上提 + require 路径收敛。
- M23：`PresentationPorts` 职责切片（modal/anim/ui_sync/debug/state）。
- M24：`GameplayReadPort` 契约测试。
- M25：`GameActionDispatcher` 继续切分。

### 第十二阶段（R6：M26-M28，已执行完成）

- M26：兼容桥治理（`MonopolyEvents` 旧路径退役与规则守护）。
- M27：复杂度治理（`ActionAnimUnits`、`LandRules` 按纯函数/骨架切片）。
- M28：契约扩展（read-model 与 use-case 边界契约覆盖扩面）。

## 具体步骤（本轮执行命令）

1. 迁移事件契约与 require：

    (PowerShell) Get-ChildItem src,tests -Recurse -File -Filter '*.lua' | Select-String -Pattern 'MonopolyEvents'

2. 边界与规则验证：

    lua tests/internal/dep_rules.lua

3. 全量回归验证：

    lua tests/regression.lua

关键输出：
- `dep_rules ok`
- `All regression checks passed (193)`
- `tick ok`
- `forbidden_globals ok`

## 下一轮执行步骤（R6 实际执行记录）

1. M26 兼容桥治理：

    (PowerShell) Get-ChildItem src,tests -Recurse -File -Filter '*.lua' | Select-String -Pattern 'src\\.game\\.core\\.runtime\\.MonopolyEvents'

    实际关键输出：
    命中为 0；`dep_rules` 对旧路径引用与桥文件薄转发均已守护。

    lua tests/internal/dep_rules.lua

2. M27 复杂度切片：

    (PowerShell) Get-Item src/presentation/render/ActionAnimUnits.lua,src/game/systems/land/LandRules.lua | ForEach-Object { \"{0}`t{1}\" -f $_.Length, $_.FullName }

    实际关键输出：
    `ActionAnimUnits.lua` 降至 26 行，`LandRules.lua` 降至 159 行；入口语义保持不变。

    lua tests/regression.lua

3. M28 契约扩展：

    (PowerShell) Get-ChildItem tests/suites -Recurse -File -Filter '*.lua' | Select-String -Pattern 'read_model_contract|contract'

    实际关键输出：
    `read_model_contract` 新增 2 条、`usecase_boundary_contract` 新增 4 条，regression 全量通过。

    lua tests/regression.lua

## 验证与验收

本轮验收标准：
1. `presentation` 不再直接依赖 `src.game.core.runtime.MonopolyEvents`。
2. `PresentationPorts.build()` 对外行为不变（回归通过作为证据）。
3. `GameplayReadPort` 存在独立契约测试并纳入 regression。
4. 全量回归通过且基线不下降（当前基线 193）。
5. R6（M26-M28）验收结果：
   - M26：已达成（旧路径命中清零 + dep_rules 退役守护）。
   - M27：已达成（模块切片完成且行为等价）。
   - M28：已达成（契约测试覆盖扩面，回归保持全绿）。

## 可重复性与恢复

- 若某一步失败，优先回滚该里程碑局部改动，不跨里程碑混合修复。
- `MonopolyEvents` 旧路径兼容桥保留，可作为快速恢复点。
- 契约测试失败时，优先修复 `GameplayReadPort` 语义，不回退依赖边界。

## 产物与备注

本轮产物：
- `src/core/events/MonopolyEvents.lua`
- `src/presentation/api/presentation_ports/*` 切片模块
- `tests/suites/read_model_contract.lua`
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`
- `src/presentation/interaction/ui_intent_dispatcher/ItemPhaseAskFlow.lua`

## 接口与依赖

- `MonopolyEvents` 契约路径：`src.core.events.MonopolyEvents`。
- `src/game/core/runtime/MonopolyEvents.lua` 仅作为兼容桥，不再承载真实定义。
- `PresentationPorts.build()` 返回结构保持：`modal/anim/ui_sync/debug/state`。
- `GameplayReadPort` 与 `LandPricing` 的语义一致性由测试守护。
- R6 完成结果：在不破坏行为的前提下完成桥接治理与热点切片；当前回归基线更新为 199。

## 本次修订记录

- 修订：重写 `.agents/plan.md` 为 R5 执行闭环版本，并回填 M22-M25 全部执行结果。
  原因：用户要求“重写计划，落地重构方案”。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：基于最新 `research.md` 追加 R6 下一轮计划（M26-M28），仅补里程碑与验收，不执行实现。
  原因：用户要求“根据 research 建议写入下一轮计划”。
  日期/作者：2026-03-01 / Codex GPT-5。

- 修订：执行并回填 R6（M26-M28）结果，含桥接治理、热点切片、契约测试扩展与 199 基线验证。
  原因：用户要求“执行计划，根据执行结果重写 research”。
  日期/作者：2026-03-02 / Codex GPT-5。
