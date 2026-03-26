# 配置数据升级计划：xlsx 设计表同步到 Lua 配置

## TL;DR

> **目标**: 将 `docs/design/*.xlsx` 设计表数据完整同步到 `src/config/content/*.lua`，建立可维护的导出流程
> 
> **范围**: 
> - ✅ 扩展 xlsx 表：道具表新增 `offer_in_phases` 列
> - ✅ 扩展导出工具：支持 vehicles、offer_in_phases、新 timing 映射
> - ✅ 修改游戏引擎：新增 `pre_move` 阶段支持
> - ✅ 重新生成所有配置：tiles, items, chance_cards, roles, constants, market, skins, vehicles
> 
> **Estimated Effort**: Large (3-4 天)
> **Parallel Execution**: YES - 5 waves (含前置修复)
> **Critical Path**: xlsx_reader修复 → xlsx扩展 → 引擎修改 → 导出工具扩展 → 配置生成 → 回归测试

---

## Context

### Original Request
对比旧版数据，分析对项目的影响，给出详尽的升级方案，以新数据为准。

### Interview Summary
**关键决策** (用户已确认):
1. ✅ `offer_in_phases` → **A: 加到xlsx表里** (道具表新增列)
2. ✅ 骰子加倍卡 timing → **以xlsx为准 (pre_move)** (需要引擎支持)
3. ✅ 道具文案 → **全部覆盖为xlsx值** (手工编辑文本将被覆盖)
4. ✅ vehicles.lua → **扩展导出工具** (新增座驾表读取)
5. ✅ skins.lua → **生成并提交** (新增配置文件)

### Metis Review Findings
**已解决的关键风险**:
- `offer_in_phases` 字段当前在 items.lua 中存在但 xlsx 中缺失 → 决策：新增 xlsx 列
- `pre_move` timing 引擎不支持 → 决策：以 xlsx 为准，需要引擎修改 (详见任务 8-9)
- 手工编辑的道具文案 → 决策：全部覆盖
- 导出工具缺少 vehicles 支持 → 决策：扩展工具

**阻塞问题**:
- [关键] `pre_move` 阶段在引擎中不存在，需要在 `timing.item_phase_queue` 和 `availability.phase_timing` 中新增

---

## Work Objectives

### Core Objective
建立从 xlsx 设计表到 Lua 配置文件的完整自动化导出流程，确保 "以新数据为准" 可执行且不破坏游戏功能。

### Concrete Deliverables
1. 扩展后的 `蛋仔--大富翁--道具表.xlsx` (新增 offer_in_phases 列)
2. 扩展后的 `tools/data/export_xlsx.lua` (支持 vehicles, offer_in_phases, pre_move)
3. 修改后的游戏引擎 (支持 pre_move 阶段)
4. 重新生成的 8 个配置文件
5. 回归测试全部通过

### Definition of Done
- [ ] `lua tools/data/export_xlsx.lua` 成功导出所有 8 个文件
- [ ] `lua tests/regression.lua` 0 失败
- [ ] `lua -e "require('src.config.gameplay.config_sanity').validate(); print('OK')"` 打印 OK

### Must Have
- 所有道具的 `offer_in_phases` 正确导出
- `pre_move` 阶段在引擎中可用
- vehicles 表纳入导出流程
- skins.lua 生成并提交

### Must NOT Have (Guardrails)
- 不修改道具效果逻辑 (post_effects.lua)
- 不修改地块、机会卡的游戏规则
- 不删除 constants 中的硬编码默认值 (只覆盖 xlsx 中定义的)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: YES (bun test 框架，回归测试套件)
- **Automated tests**: YES (Tests after) - 每个 commit 后运行回归
- **Framework**: `lua tests/regression.lua`
- **Agent-Executed QA**: 每个任务包含具体 QA 场景

### QA Policy
Every task MUST include agent-executed QA scenarios:
- **Config validation**: `lua -e "require('src.config.gameplay.config_sanity').validate()"`
- **Regression**: `lua tests/regression.lua` → expect 0 failures
- **Export dry-run**: `lua tools/data/export_xlsx.lua --output-dir tmp/generated` → exits 0
- **File diff**: 验证预期字段存在且格式正确

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 0 (Prerequisite — must complete first):
└── Task 0: 修复 xlsx_reader 读取路径问题 [deep]

Wave 1 (Foundation — after Wave 0):
├── Task 1: 扩展道具表xlsx (新增 offer_in_phases 列) [xlsx]
└── Task 2: 验证常量表xlsx与导出工具兼容性 [quick]

Wave 2 (Engine Support — after Wave 1):
├── Task 3: 新增 pre_move 到 timing.item_phase_queue [quick]
├── Task 4: 新增 pre_move 到 availability.phase_timing [quick]
└── Task 5: 实现 pre_move 阶段处理器 [unspecified-high]

Wave 3 (Export Tool — after Wave 1):
├── Task 6: 导出工具新增 vehicles 表读取 [quick]
├── Task 7: 导出工具新增 offer_in_phases 读取 [quick]
└── Task 8: 导出工具新增 pre_move timing 映射 [quick]

Wave 4 (Config Generation — after Wave 2 & 3):
├── Task 9: 重新生成所有配置文件 [quick]
└── Task 10: 提交 skins.lua [quick]

Wave FINAL (Verification):
├── Task F1: 完整回归测试 [unspecified-high]
├── Task F2: 验证骰子加倍卡在 pre_move 阶段可用 [unspecified-high]
└── Task F3: 验证所有道具 offer_in_phases 正确 [unspecified-high]

Critical Path: Task 0 → Task 1-2 → Task 3-5 (引擎) + Task 6-8 (工具) → Task 9-10 → F1-F3
```

### Dependency Matrix

- **0**: — — 1-10, 0
- **1, 2**: 0 — 3-8, 1
- **3-5**: 1, 2 — 9, 2
- **6-8**: 1, 2 — 9, 2
- **9-10**: 3-5, 6-8 — F1-F3, 3
- **F1-F3**: 9-10 — Done, 4

---

## TODOs

- [x] 0. 修复 xlsx_reader 读取路径问题 (前置任务)

  **What to do**:
  - 诊断 `tools/shared/lib/xlsx_reader.lua` 当前报错: `Failed to read zip entry: xl/workbook.xml`
  - 问题可能与 Windows 下路径编码（中文路径）或 zip 解压工具兼容性有关
  - 修复方案 (优先级排序):
    1. 检查 xlsx_reader 使用的 zip 解压命令是否在当前环境可用 (tar/unzip/powershell)
    2. 如使用外部命令解压，确保路径正确转义（中文字符）
    3. 可能需要切换到 PowerShell 的 `Expand-Archive` 或 Python zipfile 作为后端
  - 验证修复: 成功运行 `lua tools/data/export_xlsx.lua --output-dir tmp/prereq-test`

  **Must NOT do**:
  - 不要修改 xlsx 文件本身
  - 不要修改导出工具的业务逻辑，只修复底层读取

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: 需要诊断跨平台兼容性问题，可能涉及系统命令差异

  **Parallelization**:
  - **Can Run In Parallel**: NO (所有后续任务依赖此修复)
  - **Blocks**: Task 1, 2, 3-10, F1-F3 (全部)
  - **Blocked By**: None

  **References**:
  - `tools/shared/lib/xlsx_reader.lua` — 待修复的 xlsx 读取库
  - `tools/data/export_xlsx.lua` — 导出工具主文件，调用 xlsx_reader
  - `docs/design/蛋仔--大富翁--道具表.xlsx` — 用于测试修复的 xlsx 文件

  **Acceptance Criteria**:
  - [ ] `lua tools/data/export_xlsx.lua --output-dir tmp/prereq-test` 退出码 0
  - [ ] tmp/prereq-test/ 下生成 7 个 .lua 文件 (tiles, items, chance_cards, roles, constants, market, skins)
  - [ ] 无 `Failed to read zip entry` 报错

  **QA Scenarios**:
  ```
  Scenario: 导出工具可正常运行
    Tool: Bash (lua)
    Steps:
      1. lua tools/data/export_xlsx.lua --output-dir tmp/prereq-test
    Expected Result: 退出码 0，生成配置文件
    Failure Indicators: "Failed to read zip entry" 或任何 traceback
    Evidence: .sisyphus/evidence/task-0-xlsx-reader-fix.txt

  Scenario: 生成文件数量正确
    Tool: Bash (ls)
    Steps:
      1. ls tmp/prereq-test/*.lua
    Expected Result: 至少 7 个 .lua 文件
    Evidence: .sisyphus/evidence/task-0-file-count.txt
  ```

  **Commit**: YES - W0
  - Message: `fix(tools): 修复 xlsx_reader 在 Windows 环境下的读取问题`
  - Files: `tools/shared/lib/xlsx_reader.lua`

- [x] 1. 扩展道具表xlsx (新增 offer_in_phases 列)

  **What to do**:
  - 在 `蛋仔--大富翁--道具表.xlsx` 中新增一列 `offer_in_phases`
  - 为每个道具填写正确的阶段数组值，例如:
    - 2001(免费卡): `"post_action"` (该道具在支付租金时触发，不是阶段选择)
    - 2002(遥控骰子卡): `"pre_action"`
    - 2003(骰子加倍卡): `"pre_move"` (用户选择以xlsx为准)
    - 2004(路障卡): `"pre_action","post_action"`
    - 2005(地雷卡): `"pre_action","post_action"`
    - 2006(清障卡): `"pre_action"`
    - 2007(偷窃卡): `"pass_player"` (该道具在路过玩家时触发)
    - 2008(怪兽卡): `"pre_action","post_action"`
    - 2009(强征卡): `"post_action"`
    - 2010(免税卡): `"tax_prompt"`
    - 2011(均富卡): `"pre_action","post_action"`
    - 2012(流放卡): `"pre_action","post_action"`
    - 2013(导弹卡): `"pre_action","post_action"`
    - 2014(查税卡): `"pre_action","post_action"`
    - 2015(请神卡): `"pre_action","post_action"`
    - 2016(送神卡): `"post_action"`
    - 2017-2019(神卡): `"pre_action","post_action"`
  - 确保列名与导出工具读取的 header 一致

  **Must NOT do**:
  - 不要修改道具的其他列
  - 不要删除任何现有数据行

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: [`xlsx`]
  - Reason: xlsx skill 专门处理 Excel 文件读写

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 2 并行)
  - **Blocks**: Task 6-8 (导出工具需要此列)

  **References**:
  - `docs/design/蛋仔--大富翁--道具表.xlsx` - 待修改文件
  - `src/config/content/items.lua` - 当前 offer_in_phases 值参考
  - `tools/data/export_xlsx.lua:381-389` - timing 映射表参考

  **Acceptance Criteria**:
  - [ ] xlsx 文件成功保存，包含 offer_in_phases 列
  - [ ] 列值为有效的 Lua 数组格式字符串 (如 `"pre_action","post_action"`)
  - [ ] 所有 19 个道具都有值

  **QA Scenarios**:
  ```
  Scenario: 验证xlsx包含offer_in_phases列 (通过xlsx skill)
    Tool: xlsx skill (读取 xlsx 文件内容)
    Steps:
      1. 使用 xlsx skill 打开 docs/design/蛋仔--大富翁--道具表.xlsx
      2. 读取第一行 header，确认包含 "offer_in_phases" 列名
      3. 读取所有数据行，确认 19 个道具每个都有 offer_in_phases 值
    Expected Result: header 包含 offer_in_phases，19 条数据全部有值
    Failure Indicators: 缺少列或有空值行
    Evidence: .sisyphus/evidence/task-1-xlsx-column.txt (将验证结果写入)

  Scenario: 验证offer_in_phases值格式正确
    Tool: xlsx skill (读取 xlsx 文件内容)
    Steps:
      1. 使用 xlsx skill 读取 offer_in_phases 列的所有值
      2. 确认 item 2003 (骰子加倍卡) 的值包含 "pre_move"
      3. 确认值为逗号分隔格式 (如 "pre_action,post_action")
    Expected Result: 所有值为有效的逗号分隔 phase 名称
    Evidence: .sisyphus/evidence/task-1-xlsx-values.txt
  ```

  **Commit**: YES - W1
  - Message: `chore(config): 扩展道具表xlsx，新增 offer_in_phases 列`
  - Files: `docs/design/蛋仔--大富翁--道具表.xlsx`

- [x] 2. 验证常量表xlsx与导出工具兼容性

  **What to do**:
  - 验证 `蛋仔--大富翁--常量表.xlsx` 中的现有常量名称与导出工具 `name_to_key` 映射一致
  - 确认导出工具可正确读取常量表并生成 `constants.lua`
  - 此任务不新增常量（当前 exporter 的 `name_to_key` 只支持 5 个固定映射，扩展需要改导出工具，不在本计划范围内）
  - 验证现有常量表数据无损

  **Must NOT do**:
  - 不要新增常量到 xlsx（exporter 不支持）
  - 不要修改现有常量值

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 纯验证任务

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 1 并行)
  - **Blocks**: None (验证任务不阻塞后续)

  **References**:
  - `docs/design/蛋仔--大富翁--常量表.xlsx` — 数据源
  - `tools/data/export_xlsx.lua:536-550` — name_to_key 映射，当前只支持 5 个常量名

  **Acceptance Criteria**:
  - [ ] 常量表可被导出工具正确读取
  - [ ] 生成的 constants.lua 与当前版本一致（或仅有合理变化）

  **QA Scenarios**:
  ```
  Scenario: 验证常量表导出不变
    Tool: Bash (lua)
    Steps:
      1. lua tools/data/export_xlsx.lua --output-dir tmp/task2-test
      2. lua -e "local f1=io.open('src/config/content/constants.lua','r'); local f2=io.open('tmp/task2-test/constants.lua','r'); local c1=f1:read('*a'); local c2=f2:read('*a'); f1:close(); f2:close(); if c1==c2 then print('IDENTICAL') else print('CHANGED'); print('--- current length: '..#c1); print('+++ generated length: '..#c2) end"
    Expected Result: 输出 "IDENTICAL" 或显示合理变化
    Evidence: .sisyphus/evidence/task-2-constants.txt
  ```

  **Commit**: NO (纯验证，无文件变更)

- [x] 3. 新增 pre_move 到 timing.item_phase_queue

  **What to do**:
  - 在 `src/config/gameplay/timing.lua:15` 的 `item_phase_queue` 数组中，在 `"pre_action"` 之后、`"post_action"` 之前插入 `"pre_move"`
  - 修改前: `item_phase_queue = { "pre_action", "post_action" }`
  - 修改后: `item_phase_queue = { "pre_action", "pre_move", "post_action" }`

  **Must NOT do**:
  - 不要修改 timing.lua 中的其他字段
  - 不要改变 pre_action 和 post_action 的相对顺序

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 单行修改，只需编辑一个数组

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 4, Task 5 并行)
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: Task 9 (配置生成依赖阶段注册)
  - **Blocked By**: Task 1, 2

  **References**:
  - `src/config/gameplay/timing.lua:15` — 待修改行: `item_phase_queue = { "pre_action", "post_action" }`
  - `src/rules/items/availability.lua:12-15` — phase_timing 表使用 item_phase_queue 中的 key，Task 4 需要与此同步

  **Acceptance Criteria**:
  - [ ] `item_phase_queue` 包含 3 个元素: `"pre_action"`, `"pre_move"`, `"post_action"`
  - [ ] `lua -e "local t=require('src.config.gameplay.timing'); for _,v in ipairs(t.item_phase_queue) do print(v) end"` 输出 3 行

  **QA Scenarios**:
  ```
  Scenario: 验证 item_phase_queue 包含 pre_move
    Tool: Bash (lua)
    Steps:
      1. lua -e "local t=require('src.config.gameplay.timing'); local q=t.item_phase_queue; assert(#q==3, 'expected 3 phases, got '..#q); assert(q[1]=='pre_action'); assert(q[2]=='pre_move'); assert(q[3]=='post_action'); print('PASS')"
    Expected Result: 输出 "PASS"
    Failure Indicators: AssertionError 或缺少 pre_move
    Evidence: .sisyphus/evidence/task-3-timing-queue.txt

  Scenario: 验证不破坏现有 timing 配置
    Tool: Bash (lua)
    Steps:
      1. lua -e "local t=require('src.config.gameplay.timing'); assert(t.turn_countdown_seconds, 'missing turn_countdown'); assert(t.item_phase_queue, 'missing queue'); print('PASS')"
    Expected Result: 输出 "PASS"
    Evidence: .sisyphus/evidence/task-3-timing-intact.txt
  ```

  **Commit**: YES - W2
  - Message: `feat(turn): 新增 pre_move 到 item_phase_queue`
  - Files: `src/config/gameplay/timing.lua`

- [x] 4. 新增 pre_move 到 availability.phase_timing 和 phase.lua

  **What to do**:
  - **availability.lua**: 在 `src/rules/items/availability.lua:12-15` 的 `phase_timing` 表中新增:
    ```lua
    pre_move = { pre_move = true, turn = true },
    ```
    添加在 `pre_action` 和 `post_action` 条目之间
  - **phase.lua**: 在 `src/rules/items/phase.lua` 中新增 3 处:
    - `phase_titles` 新增: `pre_move = "掷骰后：使用道具？"` (约 line 16-20)
    - `phase_confirm_titles` 新增: `pre_move = "掷骰后"` (约 line 21-25)
    - `repeatable_phases` 新增: `pre_move = true` (约 line 26-29)

  **Must NOT do**:
  - 不要修改 pre_action、post_action 的现有值
  - 不要修改 `_filter_available_items` 逻辑

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 在两个文件的已知位置添加表条目

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 3, Task 5 并行)
  - **Parallel Group**: Wave 2 (with Tasks 3, 5)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1, 2

  **References**:
  - `src/rules/items/availability.lua:12-15` — phase_timing 表，需要新增 pre_move 条目
  - `src/rules/items/phase.lua:16-29` — phase_titles, phase_confirm_titles, repeatable_phases 三个表
  - `src/rules/items/availability.lua:17-40` — `_filter_available_items()` 函数，用来理解 phase_timing 如何被消费（只读参考，不修改）

  **Acceptance Criteria**:
  - [ ] `phase_timing.pre_move` 存在且值为 `{ pre_move = true, turn = true }`
  - [ ] `phase_titles.pre_move` == `"掷骰后：使用道具？"`
  - [ ] `phase_confirm_titles.pre_move` == `"掷骰后"`
  - [ ] `repeatable_phases.pre_move` == `true`

  **QA Scenarios**:
  ```
  Scenario: 验证 phase_timing 包含 pre_move
    Tool: Bash (lua)
    Steps:
      1. lua -e "local a=require('src.rules.items.availability'); -- availability 模块需要间接验证"
      2. grep -n "pre_move" src/rules/items/availability.lua
    Expected Result: 找到 pre_move = { pre_move = true, turn = true }
    Evidence: .sisyphus/evidence/task-4-phase-timing.txt

  Scenario: 验证 phase.lua 三处配置
    Tool: Bash (grep)
    Steps:
      1. grep -c "pre_move" src/rules/items/phase.lua
    Expected Result: 至少 3 处匹配 (phase_titles, phase_confirm_titles, repeatable_phases)
    Evidence: .sisyphus/evidence/task-4-phase-config.txt
  ```

  **Commit**: YES - W2 (与 Task 3 合并)
  - Files: `src/rules/items/availability.lua`, `src/rules/items/phase.lua`

- [x] 5. 实现 pre_move 阶段处理器 (turn flow 集成)

  **What to do**:
  - **registry.lua**: 在 `src/turn/phases/registry.lua:73-83` 的 phase 注册表中新增 `pre_move` 阶段
    - 注册位置在 `roll` 之后、`move` 之前
    - 参考 `pre_action` 的注册模式 (`start.lua` 中的 `_run_pre_action_item_phase`)
  - **roll.lua**: 修改 `src/turn/phases/roll.lua:104-123`
    - 当前逻辑: roll 完成后直接跳到 `move` 阶段
    - 修改后: roll 完成后跳到 `pre_move` 阶段，`pre_move` 完成后再跳到 `move`
    - 关键: `pre_move` 阶段需要调用道具阶段系统 (`phase.lua` 的 `run_item_phase`)
  - **pre_move 处理器实现**:
    - 创建 `src/turn/phases/pre_move.lua` 或在 `roll.lua` 中内联处理
    - 参考 `start.lua` 中 `_run_pre_action_item_phase` 的模式:
      1. 检查玩家是否有 pre_move 阶段可用道具
      2. 如果有，显示道具选择 UI
      3. 等待玩家选择或跳过
      4. 应用道具效果
      5. 继续到 move 阶段

  **关键实现细节 (骰子加倍卡)**:
  - 当前: 骰子加倍卡在 `pre_action` 阶段使用，设置 `pending_dice_multiplier = 2`
  - 新行为: 在 `pre_move` 阶段使用（即掷骰之后、移动之前）
  - 由于掷骰已完成，`pending_dice_multiplier` 需要通过 `dice_multiplier.apply_roll_total()` 修改已出的骰子结果
  - `dice_multiplier.apply_roll_total()` 在 `roll.lua:46` 已存在，但当前在 roll 阶段内调用
  - 需要确保 pre_move 阶段使用道具后，重新调用 `apply_roll_total()` 或等效方法

  **Must NOT do**:
  - 不要修改 `post_effects.lua` 中的道具效果逻辑
  - 不要改变现有 pre_action、post_action 的行为
  - 不要修改骰子投掷动画或 UI

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: 涉及状态机流程修改，需要深入理解 turn flow 和道具系统交互

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 3, 4 并行，但建议在 3, 4 之后或同时)
  - **Parallel Group**: Wave 2 (with Tasks 3, 4)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1, 2

  **References**:
  - `src/turn/phases/registry.lua:73-83` — 阶段注册表，需要在 roll 和 move 之间插入 pre_move
  - `src/turn/phases/roll.lua:104-123` — roll 完成后的跳转逻辑，需要改为跳到 pre_move
  - `src/turn/phases/roll.lua:46` — `dice_multiplier.apply_roll_total()` 调用位置
  - `src/turn/phases/start.lua` — `_run_pre_action_item_phase` 函数，pre_move 处理器的设计参考
  - `src/rules/items/phase.lua` — `run_item_phase()` 函数，pre_move 需要调用此函数
  - `src/turn/phases/dice_multiplier.lua` — 骰子乘数应用逻辑（只读参考）
  - `src/rules/items/post_effects.lua:164` — 骰子加倍卡效果设置 `pending_dice_multiplier`（只读参考，不修改）

  **Acceptance Criteria**:
  - [ ] `pre_move` 阶段在 registry 中注册
  - [ ] turn flow: start → pre_action → roll → **pre_move** → move → landing → post_action → end_turn
  - [ ] 骰子加倍卡在 pre_move 阶段可被使用
  - [ ] 使用骰子加倍卡后，骰子结果正确翻倍

  **QA Scenarios**:
  ```
  Scenario: 验证 pre_move 阶段在 turn flow 中正确注册
    Tool: Bash (lua)
    Steps:
      1. grep -n "pre_move" src/turn/phases/registry.lua
    Expected Result: 找到 pre_move 阶段注册条目
    Failure Indicators: 无匹配
    Evidence: .sisyphus/evidence/task-5-registry.txt

  Scenario: 验证 roll 后跳转到 pre_move
    Tool: Bash (grep)
    Steps:
      1. grep -A5 "pre_move" src/turn/phases/roll.lua
    Expected Result: roll 完成后引用 pre_move 阶段
    Evidence: .sisyphus/evidence/task-5-roll-flow.txt

  Scenario: 验证回归测试不被破坏
    Tool: Bash (lua)
    Steps:
      1. lua tests/regression.lua
    Expected Result: 0 failures
    Failure Indicators: 任何 FAIL 输出
    Evidence: .sisyphus/evidence/task-5-regression.txt
  ```

  **Commit**: YES - W2 (与 Task 3, 4 合并)
  - Message: `feat(turn): 实现 pre_move 阶段处理器，支持掷骰后使用道具`
  - Files: `src/turn/phases/registry.lua`, `src/turn/phases/roll.lua`, `src/turn/phases/pre_move.lua` (新文件)

- [x] 6. 导出工具新增 vehicles 表读取

  **What to do**:
  - 在 `tools/data/export_xlsx.lua` 中新增读取 `蛋仔--大富翁--座驾表.xlsx` 的逻辑
  - 参考现有的 `_table_from_sheet()` 调用模式（如 tiles 的读取，约 line 392-400）
  - vehicles 表字段映射:
    - `座驾id` → `id`
    - `座驾名称` → `name`
    - `座驾等级` → `level`
    - `骰子数` → `dice_count`
    - `是否不可摧毁（免疫导弹、台风等效果）` → `indestructible` (注意: 实际 header 包含括号说明)
  - 调用 `_write_lua_table()` 输出到 `vehicles.lua`
  - field_order: `{ "id", "name", "level", "dice_count", "indestructible" }`
  - 确保输出格式与现有 `src/config/content/vehicles.lua` 一致

  **Must NOT do**:
  - 不要修改现有的 tiles/items/chance_cards 等读取逻辑
  - 不要删除 market.lua 中过滤 vehicles 的逻辑 (`kind ~= "vehicle"`)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 照搬现有模式添加新表读取，不涉及复杂逻辑

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 7, 8 并行)
  - **Parallel Group**: Wave 3 (with Tasks 7, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1, 2

  **References**:
  - `tools/data/export_xlsx.lua:392-412` — tiles/items 的导出模式，vehicles 需要复制此模式
  - `tools/data/export_xlsx.lua:350-365` — `_write_lua_table()` 函数签名和用法
  - `tools/data/export_xlsx.lua:330-348` — `_table_from_sheet()` 函数，读取 xlsx sheet 数据
  - `docs/design/蛋仔--大富翁--座驾表.xlsx` — 数据源
  - `src/config/content/vehicles.lua` — 预期输出格式参考（12 辆座驾，5 个字段）

  **Acceptance Criteria**:
  - [ ] export_xlsx.lua 包含读取座驾表的代码
  - [ ] `lua tools/data/export_xlsx.lua` 成功生成 vehicles.lua
  - [ ] 生成的 vehicles.lua 包含 12 条记录
  - [ ] 字段顺序为 id, name, level, dice_count, indestructible

  **QA Scenarios**:
  ```
  Scenario: 导出工具生成 vehicles.lua
    Tool: Bash (lua)
    Steps:
      1. lua tools/data/export_xlsx.lua --output-dir tmp/test-export
      2. grep -c "id =" tmp/test-export/vehicles.lua
    Expected Result: 输出 "12" (12 条座驾记录)
    Failure Indicators: 文件不存在或记录数不对
    Evidence: .sisyphus/evidence/task-6-vehicles-export.txt

  Scenario: 验证字段顺序正确
    Tool: Bash (grep)
    Steps:
      1. head -20 tmp/test-export/vehicles.lua
    Expected Result: 第一条记录包含 id, name, level, dice_count, indestructible 字段
    Evidence: .sisyphus/evidence/task-6-vehicles-fields.txt
  ```

  **Commit**: YES - W3
  - Message: `feat(tools): 导出工具支持座驾表读取`
  - Files: `tools/data/export_xlsx.lua`

- [x] 7. 导出工具新增 offer_in_phases 列解析

  **What to do**:
  - 在 `tools/data/export_xlsx.lua` 的 items 导出逻辑中:
    1. 从 xlsx 读取 `offer_in_phases` 列的原始字符串值
    2. 解析逗号分隔格式: `"pre_action,post_action"` → `{ "pre_action", "post_action" }`
    3. 将解析后的 Lua table 写入 items.lua 的每条记录中
  - 在 `_write_lua_table()` 调用的 field_order 中添加 `"offer_in_phases"` (约 line 410-412)
  - 注意: `_write_lua_table` 需要能处理 table 类型的值（不是字符串），确认或扩展序列化逻辑

  **Must NOT do**:
  - 不要硬编码 offer_in_phases 值，必须从 xlsx 读取
  - 不要修改其他字段的读取逻辑

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 添加一列的解析逻辑，模式已有参考

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 6, 8 并行)
  - **Parallel Group**: Wave 3 (with Tasks 6, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1 (需要 xlsx 中已添加 offer_in_phases 列)

  **References**:
  - `tools/data/export_xlsx.lua:410-412` — items 的 field_order，需要添加 `"offer_in_phases"`
  - `tools/data/export_xlsx.lua:392-409` — items 导出流程，需要在此处添加解析逻辑
  - `tools/data/export_xlsx.lua:350-365` — `_write_lua_table()` 序列化逻辑，需确认支持 table 值
  - `src/config/content/items.lua` — 目标输出格式，每条记录的 `offer_in_phases` 为 Lua 数组

  **Acceptance Criteria**:
  - [ ] items.lua 中每条记录包含 `offer_in_phases` 字段
  - [ ] 字段值为 Lua 数组 (如 `{ "pre_action", "post_action" }`)
  - [ ] item 2003 的 `offer_in_phases` 包含 `"pre_move"`

  **QA Scenarios**:
  ```
  Scenario: 验证 items.lua 包含 offer_in_phases
    Tool: Bash (lua)
    Steps:
      1. lua tools/data/export_xlsx.lua --output-dir tmp/test-export
      2. lua -e "local items=dofile('tmp/test-export/items.lua'); for _,v in ipairs(items) do assert(v.offer_in_phases, 'item '..v.id..' missing offer_in_phases') end; print('ALL ITEMS HAVE offer_in_phases')"
    Expected Result: 输出 "ALL ITEMS HAVE offer_in_phases"
    Failure Indicators: AssertionError 指出缺少字段的 item id
    Evidence: .sisyphus/evidence/task-7-offer-in-phases.txt

  Scenario: 验证 item 2003 的 pre_move timing
    Tool: Bash (lua)
    Steps:
      1. lua -e "local items=dofile('tmp/test-export/items.lua'); for _,v in ipairs(items) do if v.id==2003 then for _,p in ipairs(v.offer_in_phases) do if p=='pre_move' then print('PASS: 2003 has pre_move'); return end end; error('2003 missing pre_move') end end"
    Expected Result: 输出 "PASS: 2003 has pre_move"
    Evidence: .sisyphus/evidence/task-7-item-2003.txt
  ```

  **Commit**: YES - W3 (与 Task 6 合并)
  - Files: `tools/data/export_xlsx.lua`

- [x] 8. 验证导出工具 pre_move timing 映射

  **What to do**:
  - 验证 `tools/data/export_xlsx.lua:384` 已有映射: `["骰子生效前触发"] = "pre_move"`
  - 如果映射已存在且正确 → 此任务为 no-op（仅验证）
  - 如果映射不存在或不正确 → 添加/修复映射
  - 同时验证导出工具在遇到 "骰子生效前触发" 这个 timing 值时能正确输出 `timing = "pre_move"`

  **Must NOT do**:
  - 不要修改其他 timing 映射

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 可能是纯验证任务

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 6, 7 并行)
  - **Parallel Group**: Wave 3 (with Tasks 6, 7)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1, 2

  **References**:
  - `tools/data/export_xlsx.lua:381-389` — timing_map 表，预期包含 `["骰子生效前触发"] = "pre_move"`

  **Acceptance Criteria**:
  - [ ] timing_map 中存在 `["骰子生效前触发"] = "pre_move"`
  - [ ] 验证通过或修复已应用

  **QA Scenarios**:
  ```
  Scenario: 验证 timing 映射存在
    Tool: Bash (grep)
    Steps:
      1. grep "pre_move" tools/data/export_xlsx.lua
    Expected Result: 找到 "骰子生效前触发" → "pre_move" 映射
    Evidence: .sisyphus/evidence/task-8-timing-map.txt
  ```

  **Commit**: YES - W3 (与 Task 6, 7 合并，如有修改)
  - Message: `feat(tools): 导出工具支持 vehicles、offer_in_phases 和 pre_move timing`
  - Files: `tools/data/export_xlsx.lua`

- [x] 9. 运行导出工具，重新生成所有配置文件

  **What to do**:
  - 运行 `lua tools/data/export_xlsx.lua` 重新生成所有配置文件
  - 预期生成/更新的文件:
    - `src/config/content/tiles.lua` — 45 tiles (预期无变化或微小变化)
    - `src/config/content/items.lua` — 19 items (新增 offer_in_phases 字段)
    - `src/config/content/chance_cards.lua` — 28 cards (预期无变化)
    - `src/config/content/roles.lua` — 3 roles (预期无变化)
    - `src/config/content/constants.lua` — 12+ constants (可能新增 pre_move 相关)
    - `src/config/content/market.lua` — 25 entries (预期无变化)
    - `src/config/content/vehicles.lua` — 12 vehicles (新: 由导出工具生成)
    - `src/config/content/skins.lua` — 6 skins (新文件)
  - 对比每个生成文件与当前文件的 diff，确认变更合理
  - 运行 `lua -e "require('src.config.gameplay.config_sanity').validate(); print('OK')"` 验证

  **Must NOT do**:
  - 不要手动编辑生成的文件
  - 不要删除 `runtime_refs.lua`（此文件不由导出工具管理）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 运行命令并验证输出

  **Parallelization**:
  - **Can Run In Parallel**: NO (依赖 Wave 2 + Wave 3 全部完成)
  - **Parallel Group**: Wave 4 (with Task 10)
  - **Blocks**: F1-F3
  - **Blocked By**: Task 3, 4, 5, 6, 7, 8

  **References**:
  - `tools/data/export_xlsx.lua` — 导出工具主文件
  - `src/config/content/` — 输出目录
  - `src/config/gameplay/config_sanity.lua` — 运行时配置校验器
  - `src/config/content/items.lua` — 对比变更前后，确认 offer_in_phases 已添加
  - `src/config/content/vehicles.lua` — 对比变更前后，确认由工具生成且内容一致

  **Acceptance Criteria**:
  - [ ] 导出工具退出码 0
  - [ ] 8 个配置文件全部生成
  - [ ] config_sanity 验证通过
  - [ ] items.lua 每条记录包含 offer_in_phases
  - [ ] vehicles.lua 包含 12 条记录
  - [ ] skins.lua 包含 6 条记录 (id 5001-5006)

  **QA Scenarios**:
  ```
  Scenario: 导出工具成功运行
    Tool: Bash (lua)
    Steps:
      1. lua tools/data/export_xlsx.lua
    Expected Result: 退出码 0，无错误输出
    Failure Indicators: 任何 error/traceback
    Evidence: .sisyphus/evidence/task-9-export-run.txt

  Scenario: config_sanity 验证通过
    Tool: Bash (lua)
    Steps:
      1. lua -e "require('src.config.gameplay.config_sanity').validate(); print('OK')"
    Expected Result: 输出 "OK"
    Failure Indicators: 任何 assert 失败
    Evidence: .sisyphus/evidence/task-9-config-sanity.txt

  Scenario: 验证 items.lua 变更合理
    Tool: Bash (lua)
    Steps:
      1. lua -e "local items=require('src.config.content.items'); local count=0; for _,v in ipairs(items) do if v.offer_in_phases then count=count+1 end end; assert(count==19, 'expected 19 items with offer_in_phases, got '..count); print('PASS')"
    Expected Result: 输出 "PASS"
    Evidence: .sisyphus/evidence/task-9-items-check.txt

  Scenario: 验证 skins.lua 生成
    Tool: Bash (lua)
    Steps:
      1. lua -e "local skins=require('src.config.content.skins'); local count=0; for _ in pairs(skins) do count=count+1 end; assert(count>=6, 'expected >=6 skins, got '..count); print('PASS: '..count..' skins')"
    Expected Result: 输出 "PASS: 6 skins"
    Evidence: .sisyphus/evidence/task-9-skins-check.txt
  ```

  **Commit**: YES - W4
  - Message: `chore(config): 重新生成所有配置文件 (items+vehicles+skins)`
  - Files: `src/config/content/tiles.lua`, `src/config/content/items.lua`, `src/config/content/chance_cards.lua`, `src/config/content/roles.lua`, `src/config/content/constants.lua`, `src/config/content/market.lua`, `src/config/content/vehicles.lua`, `src/config/content/skins.lua`

- [x] 10. 提交 skins.lua 并验证 git 状态

  **What to do**:
  - 确认 `src/config/content/skins.lua` 已由 Task 9 生成
  - 验证内容: 6 条皮肤记录 (id 5001-5006)，字段包含 id, name, price 等
  - 确认 `Data/Prefab.lua` 中的皮肤 id 与 skins.lua 一致
  - 运行 `git status` 确认所有变更文件
  - 此任务主要是验证性质，实际 commit 在 Task 9 中一起完成

  **Must NOT do**:
  - 不要手动编辑 skins.lua
  - 不要修改 Data/Prefab.lua

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: 纯验证任务

  **Parallelization**:
  - **Can Run In Parallel**: YES (与 Task 9 串行，但同属 Wave 4)
  - **Parallel Group**: Wave 4 (after Task 9)
  - **Blocks**: F1-F3
  - **Blocked By**: Task 9

  **References**:
  - `src/config/content/skins.lua` — 待验证的新文件
  - `Data/Prefab.lua` — 皮肤 id 交叉验证参考（搜索 5001-5006）
  - `docs/design/蛋仔--大富翁--皮肤表.xlsx` — 数据源

  **Acceptance Criteria**:
  - [ ] skins.lua 存在于 `src/config/content/`
  - [ ] 包含 6 条记录 (5001, 5002, 5003, 5004, 5005, 5006)
  - [ ] Data/Prefab.lua 中引用的皮肤 id 在 skins.lua 中都存在

  **QA Scenarios**:
  ```
  Scenario: 验证 skins.lua 与 Prefab.lua 一致
    Tool: Bash (lua + grep)
    Steps:
      1. lua -e "local skins=require('src.config.content.skins'); local ids={}; for _,s in ipairs(skins) do ids[s.id]=true end; for _,expected in ipairs({5001,5002,5003,5004,5005,5006}) do assert(ids[expected], 'missing skin '..expected) end; print('ALL 6 SKINS PRESENT')"
    Expected Result: 输出 "ALL 6 SKINS PRESENT"
    Evidence: .sisyphus/evidence/task-10-skins-verify.txt

  Scenario: 验证 Prefab.lua 皮肤 id 覆盖
    Tool: Bash (grep)
    Steps:
      1. grep -o "500[1-6]" Data/Prefab.lua | sort -u
    Expected Result: 列出 5001-5006 中在 Prefab.lua 中引用的 id
    Evidence: .sisyphus/evidence/task-10-prefab-skins.txt
  ```

  **Commit**: YES - W4 (与 Task 9 合并)

---

## Final Verification Wave

> 3 review agents run in PARALLEL. ALL must APPROVE.
> Present results to user and get explicit "okay" before completing.

- [ ] F1. **完整回归测试 + Config Sanity** — `unspecified-high`

  **What to do**:
  1. Run `lua tests/regression.lua` — capture full output (this runs ALL test suites including item_availability and config_sanity)
  2. Run `lua -e "require('src.config.gameplay.config_sanity').validate(); print('OK')"`
  3. Check ALL test outputs for FAIL/ERROR/ASSERT

  **QA Scenarios**:
  ```
  Scenario: 回归测试全部通过 (包含 item_availability 和 config_sanity 套件)
    Tool: Bash (lua)
    Steps:
      1. lua tests/regression.lua 2>&1
    Expected Result: 0 failures, exit code 0 (回归测试运行器已包含所有域测试套件)
    Failure Indicators: 任何 FAIL, ERROR, assert
    Evidence: .sisyphus/evidence/final-regression-output.txt

  Scenario: Config sanity 独立验证
    Tool: Bash (lua)
    Steps:
      1. lua -e "require('src.config.gameplay.config_sanity').validate(); print('OK')" 2>&1
    Expected Result: 输出 "OK"
    Evidence: .sisyphus/evidence/final-config-sanity.txt
  ```

  Output: `Regression [PASS/FAIL] | Config Sanity [PASS/FAIL] | Item Availability [PASS/FAIL] | VERDICT: APPROVE/REJECT`

- [ ] F2. **骰子加倍卡 pre_move 端到端验证** — `unspecified-high`

  **What to do**:
  1. 验证 items.lua 中 item 2003 的 `offer_in_phases` 包含 `"pre_move"`
  2. 验证 `timing.item_phase_queue` 包含 `"pre_move"`
  3. 验证 `availability.phase_timing` 包含 `pre_move` 条目
  4. 验证 `phase.lua` 中 pre_move 的 title/confirm_title/repeatable 配置
  5. 验证 `registry.lua` 中 pre_move 阶段注册
  6. 验证 roll.lua 中 pre_move 跳转逻辑

  **QA Scenarios**:
  ```
  Scenario: item 2003 timing 为 pre_move
    Tool: Bash (lua)
    Steps:
      1. lua -e "local items=require('src.config.content.items'); for _,v in ipairs(items) do if v.id==2003 then local found=false; for _,p in ipairs(v.offer_in_phases) do if p=='pre_move' then found=true end end; assert(found, '2003 missing pre_move in offer_in_phases'); print('PASS'); return end end"
    Expected Result: 输出 "PASS"
    Evidence: .sisyphus/evidence/final-2003-pre-move.txt

  Scenario: 引擎 pre_move 配置完整性
    Tool: Bash (lua)
    Steps:
      1. lua -e "local t=require('src.config.gameplay.timing'); local found=false; for _,v in ipairs(t.item_phase_queue) do if v=='pre_move' then found=true end end; assert(found, 'pre_move not in item_phase_queue'); print('PASS: timing OK')"
      2. grep "pre_move" src/rules/items/availability.lua
      3. grep -c "pre_move" src/rules/items/phase.lua
      4. grep "pre_move" src/turn/phases/registry.lua
    Expected Result: timing PASS + availability 有 pre_move + phase.lua 至少 3 处 + registry 有 pre_move
    Failure Indicators: 任何缺失
    Evidence: .sisyphus/evidence/final-pre-move-config.txt

  Scenario: turn flow 正确
    Tool: Bash (grep)
    Steps:
      1. grep -A3 "pre_move" src/turn/phases/roll.lua
    Expected Result: roll 后引用 pre_move，pre_move 后引用 move
    Evidence: .sisyphus/evidence/final-turn-flow.txt
  ```

  Output: `Item 2003 [OK/FAIL] | Timing [OK/FAIL] | Availability [OK/FAIL] | Phase [OK/FAIL] | Registry [OK/FAIL] | Flow [OK/FAIL] | VERDICT: APPROVE/REJECT`

- [ ] F3. **offer_in_phases + vehicles + skins 完整性验证** — `unspecified-high`

  **What to do**:
  1. 验证所有 19 个道具都有 offer_in_phases 字段
  2. 验证 offer_in_phases 的值与 xlsx 源数据一致
  3. 验证 vehicles.lua 包含 12 条记录且由导出工具生成
  4. 验证 skins.lua 包含 6 条记录 (5001-5006)
  5. 验证导出工具可重复运行（幂等性）

  **QA Scenarios**:
  ```
  Scenario: 所有道具 offer_in_phases 完整
    Tool: Bash (lua)
    Steps:
      1. lua -e "local items=require('src.config.content.items'); local missing={}; for _,v in ipairs(items) do if not v.offer_in_phases or #v.offer_in_phases==0 then table.insert(missing, v.id) end end; if #missing>0 then error('missing offer_in_phases: '..table.concat(missing,',')) end; print('ALL '..#items..' ITEMS OK')"
    Expected Result: 输出 "ALL 19 ITEMS OK"
    Evidence: .sisyphus/evidence/final-offer-in-phases-all.txt

  Scenario: vehicles.lua 完整
    Tool: Bash (lua)
    Steps:
      1. lua -e "local v=require('src.config.content.vehicles'); local count=0; for _ in pairs(v) do count=count+1 end; assert(count==12, 'expected 12, got '..count); print('PASS: 12 vehicles')"
    Expected Result: 输出 "PASS: 12 vehicles"
    Evidence: .sisyphus/evidence/final-vehicles.txt

  Scenario: skins.lua 完整
    Tool: Bash (lua)
    Steps:
      1. lua -e "local s=require('src.config.content.skins'); local count=0; for _,v in ipairs(s) do count=count+1 end; assert(count>=6, 'expected >=6, got '..count); print('PASS: '..count..' skins')"
    Expected Result: 输出 "PASS: 6 skins"
    Evidence: .sisyphus/evidence/final-skins.txt

  Scenario: 导出工具幂等性
    Tool: Bash (lua)
    Steps:
      1. lua tools/data/export_xlsx.lua --output-dir tmp/idempotent-1
      2. lua tools/data/export_xlsx.lua --output-dir tmp/idempotent-2
      3. lua -e "local files={'tiles.lua','items.lua','chance_cards.lua','roles.lua','constants.lua','market.lua','vehicles.lua','skins.lua'}; local ok=true; for _,f in ipairs(files) do local h1=io.open('tmp/idempotent-1/'..f,'r'); local h2=io.open('tmp/idempotent-2/'..f,'r'); if not h1 or not h2 then print('MISSING: '..f); ok=false else local c1=h1:read('*a'); local c2=h2:read('*a'); h1:close(); h2:close(); if c1~=c2 then print('DIFF: '..f); ok=false end end end; if ok then print('IDEMPOTENT: all files identical') else error('NOT IDEMPOTENT') end"
    Expected Result: 输出 "IDEMPOTENT: all files identical"
    Failure Indicators: DIFF 或 MISSING 输出
    Evidence: .sisyphus/evidence/final-idempotent.txt
  ```

  Output: `Items [19/19] | Vehicles [12/12] | Skins [6/6] | Idempotent [YES/NO] | VERDICT: APPROVE/REJECT`

---

## Commit Strategy

每个 Wave 作为一个独立 commit:

- **W0**: `fix(tools): 修复 xlsx_reader 在 Windows 环境下的读取问题`
- **W1**: `chore(config): 扩展道具表xlsx，新增 offer_in_phases 列`
- **W2**: `feat(turn): 新增 pre_move 阶段支持`
- **W3**: `feat(tools): 导出工具支持 vehicles 和 offer_in_phases`
- **W4**: `chore(config): 重新生成所有配置文件`
- **F**: `test(config): 验证配置完整性和回归测试`

---

## Success Criteria

### Verification Commands
```bash
# 导出工具正常工作
lua tools/data/export_xlsx.lua --output-dir tmp/generated

# 回归测试通过
lua tests/regression.lua

# Config sanity 通过
lua -e "require('src.config.gameplay.config_sanity').validate(); print('OK')"

# 验证 pre_move 在 item_phase_queue 中
lua -e "local t=require('src.config.gameplay.timing'); local found=false; for _,v in ipairs(t.item_phase_queue) do if v=='pre_move' then found=true end end; assert(found, 'pre_move not in item_phase_queue'); print('OK')"
```

### Final Checklist
- [ ] 道具表xlsx包含 offer_in_phases 列
- [ ] 常量表xlsx与导出工具兼容 (现有常量无损)
- [ ] timing.lua 的 item_phase_queue 包含 pre_move
- [ ] availability.lua phase_timing 包含 pre_move
- [ ] 导出工具读取 vehicles.xlsx
- [ ] 导出工具读取 offer_in_phases 列
- [ ] 导出工具映射 "骰子生效前触发" → "pre_move"
- [ ] skins.lua 已提交到仓库
- [ ] vehicles.lua 由导出工具生成
- [ ] items.lua 包含所有道具的 offer_in_phases
- [ ] 回归测试 0 失败

