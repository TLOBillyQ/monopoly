# 候选 ③ 回合序列 —— phase_res→wait_state 微映射收敛计划

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 执行。步骤用 `- [ ]` 复选框跟踪。**本计划为并行编排：Task 1 / 2 / 3 三者互不依赖、改三个不同文件，可同时 fan-out 给三个 subagent（各自 worktree 隔离）；Task 4 是 barrier，等三者合并后单独跑。** 见下方「并行执行编排」。

**Goal:** 把「`phase_res` → `wait_action_anim` / `wait_choice` 打包（含 `next_state` / `next_args`）」这段被**复制 4 次**的微映射，收敛到唯一的 `src/turn/phases/phase_wait.lua` `resolve_result`——`roll` / `registry` / `start` 三处内联/重复拷贝降为对它的一行委托。

**Architecture:** `phase_wait.resolve_result(phase_res, default_next_state, player, total, raw_total)` 已是抽出的规范实现，但只有 `pre_move` 一个 caller；`roll._resolve_phase_wait_result`（字节级重复）、`registry._resolve_post_phase_wait`、`start._run_pre_action_item_phase` 的尾段各自把同一段逻辑重写了一遍。本计划让这三处都委托 `phase_wait.resolve_result`，**逐点字节等价**（默认值 + fallback `next_args` 已核对一致）。

**Tech Stack:** Lua 5.4；busted；清洁架构七层，落在 `turn/phases`。

## Global Constraints

- 命名 `snake_case`；委托保留各处原有的**函数名与导出 seam**（`roll._resolve_phase_wait_result` 被 spec 直接钉，不能删签名，只换实现）。
- `src/` 禁用 `tonumber` / `type(x)=="number"`。本计划只搬转移逻辑，不引入数字判定。
- **这是重构，观测行为零变化**：三处委托与原内联逻辑逐点字节等价（见各 task「行为保持」）。
- 门禁 `make verify`（本仓库 verify 即完整门禁，~7-8s）；每个 task 结尾跑。回合序列面广，**Task 末必跑 turn_flow 场景套**：`busted --run behavior spec/behavior/scenarios/turn_flow`。
- 单文件 spec：`busted --run behavior spec/behavior/turn/<file>_spec.lua`。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`。

---

## 候选 ③ 全貌与分期（务必先读）

评审 ③ 的标题是「把回合序列做成一张**声明式 phase graph**（`phase → default_next`），phase 只返回 outcome（moved/needs_choice）」。**探源后，这个标题的『大』半是一次架构级、且与现有语义不完全吻合的重写，不适合从 schematic 直接写成机械 TDD 计划。** 关键发现：

1. **driver 已经是 generic 的**。`timing.lua` 的 `_step_script`/`_run_phase`/`_run_wait` 已按 `state_name` 查「phase 处理器或 wait 处理器」、跑它、取 `(next_state, next_args)`、循环。没有「driver 不读图」的问题——序列本就由各 phase 返回的字符串驱动。
2. **转移不是扁平的 `phase → default_next`，而是数据依赖的分支 + wait 夹层**：
   - `start` 依运行时状态返回 `end_turn`（已出局）/ `detained_wait`（被扣留）/ `wait_action`（正常，且把真正后继 `roll` 埋进 wait 的 `next_args`）。一张 `phase→default_next` 表**无法**表达这种一对多分支。
   - 几乎每个 phase→phase 都**经过一个 wait 态**（`wait_action_anim` / `wait_choice` / `wait_action`），真正的后继 state 藏在 wait 的 `args.next_state` 里，由 wait 处理器完成后吐出。「图的边」是 `phase → wait_X → next_phase`，`wait_X` 由 `wait_action_anim` 标志选。
   - 结论：把它压成 `phase→default_next` 会**丢失分支与 wait 夹层语义**；真做需要一个远比「默认边表」丰富的结构（per-outcome 边 + wait 夹层规则），并重写每个 phase 返回抽象 outcome + 一层把 outcome 还原成现有 `(next_state, next_args, 埋入 args)` 的映射。这是**架构改造**，且踩着 `turn_flow` 场景套 + gameplay hotspot 的密集测试面。
3. **评审明确点到、且真实安全的一刀**是它顺带提的那句：「吸收被复制 4 次的 `phase_res→wait_state` 微映射」。`phase_wait.lua`「只 1 个 caller」（`pre_move`）正是因为另外 3 处把它重写了。**这一刀低风险、边界清楚、逐点字节等价**——就是本计划。

**分期结论：**
- **本计划 = ③-安全（微映射收敛）**，完整展开、可立即执行、零行为变化。
- **③-大（声明式 phase graph）= 设计先行的后续项**，必须先过 `superpowers:brainstorming` + `codebase-design`（把「分支 + wait 夹层」设计成一个够表达力的结构，并评估 `turn_flow` 场景套的迁移面）**再**写 TDD 计划。文末给出该后续项的入口与我探到的约束，省下一位规划者重新发现「扁平 default_next 语义有损」。

---

## Phase 3-安全 文件结构

**规范实现（保持，作为唯一归宿）：**
- `src/turn/phases/phase_wait.lua` — `resolve_result(phase_res, default_next_state, player, total, raw_total)`。不动。

**降为一行委托（各保留原函数名/导出 seam）：**
- `src/turn/phases/roll.lua:74-94` `_resolve_phase_wait_result`（字节级重复，默认 `"move"`；被 `roll_spec` + scenario 直接钉）
- `src/turn/phases/registry.lua:28-35` `_resolve_post_phase_wait`（内联，默认 `"post_action"`）
- `src/turn/phases/start.lua:86-91` `_run_pre_action_item_phase` 尾段（内联，默认 `"roll"`）

**已是好公民（不动，作参照）：**
- `src/turn/phases/pre_move.lua:6-7` 已委托 `phase_wait.resolve_result(phase_res, "pre_move", ...)`。

**护栏 spec（保持绿）：**
- `spec/behavior/turn/roll_spec.lua`（直接钉 `roll._resolve_phase_wait_result` 四断言）
- `spec/support/scenario_suites/shared/helpers.lua` + `spec/support/scenario_suites/turn_flow/interrupts.lua`（3 个 `_test_resolve_phase_wait_result_*` case）
- `spec/behavior/scenarios/turn_flow/*`（整圈序列）

---

## 并行执行编排

```
        ┌─ Task 1  roll.lua      ─┐
 (fan out) ─┼─ Task 2  registry.lua  ─┼─→  Task 4  barrier
        └─ Task 3  start.lua     ─┘   (合并后：deletion-test + manifest + 完整门禁 + 验收)
```

**为何可并行（冲突矩阵）：**

| | 改的文件 | 加的 require | 委托目标 | 消费别的 task 产出? | 改的 manifest |
|---|---|---|---|---|---|
| Task 1 | `turn/phases/roll.lua` | `phase_wait` | `resolve_result(…,"move",…)` | 否 | roll.lua 尾 |
| Task 2 | `turn/phases/registry.lua` | `phase_wait` | `resolve_result(…,"post_action",…)` | 否 | registry.lua 尾 |
| Task 3 | `turn/phases/start.lua` | `phase_wait` | `resolve_result(…,"roll",…)` | 否 | start.lua 尾 |

- **三个不同源文件，零重叠写**；各自的 mutation manifest 也在各自文件尾，不冲突。
- 委托目标 `phase_wait.resolve_result` **本计划不改**（既有规范实现），三者都是只读依赖 → 无「共享可变状态」。
- `registry.lua` 在 module-load 时 `require` `roll`/`start`——这是**既有**依赖，且三处编辑都不改 require 图的形状（只各加一行 `require phase_wait`），故 Task 2 不需要等 Task 1/3。

**swarm 分派方式：**
1. **同一条消息里 fan-out 三个 subagent**，每个 `isolation: "worktree"`（隔离 git，避免并发 commit 撞 index.lock）。各 subagent 只做自己 Task 的 Step 1–5，在自己 worktree 内 `make verify` 自证 + commit。
2. 三者全绿后**合并**三个 worktree（不同文件，无文本冲突）。
3. **再单独跑 Task 4**（barrier）：合并后的树上做 deletion-test 复核、三文件 manifest 刷新、完整门禁 + 验收。manifest 刷新必须在合并后做（Task 4 会同时 `--update-manifest` 三个文件）。

**若不想开 worktree**（顺序更省事）：三 task 面都极小（各一行委托），也可在单一工作树里顺序 1→2→3→4 执行，成本几乎等同——并行的收益主要是「三个 reviewer 并行 gate」而非壁钟时间。

---

## Task 1：roll._resolve_phase_wait_result 委托 phase_wait（默认 move）

**Files:**
- Modify: `src/turn/phases/roll.lua`（顶部 require + `_resolve_phase_wait_result` 函数体）
- Pin: `spec/behavior/turn/roll_spec.lua`、`spec/behavior/scenarios/turn_flow/interrupts_spec.lua`

**Interfaces:**
- Consumes: `phase_wait.resolve_result`（既有）。
- Produces: `roll._resolve_phase_wait_result(phase_res, player, total, raw_total)` 签名/导出**不变**，仅换实现。

**行为保持：** `roll.lua:74-94` 与 `phase_wait.lua:3-23` **字节级相同**，唯一差异是 roll 硬编码默认 `"move"`、`phase_wait` 取参数 `default_next_state`。故 `roll._resolve_phase_wait_result(phase_res, player, total, raw_total)` ≡ `phase_wait.resolve_result(phase_res, "move", player, total, raw_total)`：默认 `"move"`、fallback `next_args={player,total,raw_total}`、`wait_action_anim?wait_action_anim:wait_choice` 全一致。

- [ ] **Step 1：确认既有 pin 全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/turn/roll_spec.lua`
Expected: PASS（含 `roll._resolve_phase_wait_result(nil, player, 5, 5)` 等四断言）。

- [ ] **Step 2：加 require（若 roll.lua 尚未 require phase_wait）**

先查：

Run: `grep -n "phase_wait" src/turn/phases/roll.lua`
Expected: 空 → 在 roll.lua 顶部 require 区加一行：

```lua
local phase_wait = require("src.turn.phases.phase_wait")
```

- [ ] **Step 3：函数体降为委托**

将 `src/turn/phases/roll.lua:74-94`：

```lua
local function _resolve_phase_wait_result(phase_res, player, total, raw_total)
  local next_state = phase_res and phase_res.next_state or "move"
  local next_args = phase_res and phase_res.next_args or nil
  if next_args == nil then
    next_args = {
      player = player,
      total = total,
      raw_total = raw_total,
    }
  end
  if phase_res and phase_res.wait_action_anim == true then
    return "wait_action_anim", {
      next_state = next_state,
      next_args = next_args,
    }
  end
  return "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }
end
```

改为：

```lua
local function _resolve_phase_wait_result(phase_res, player, total, raw_total)
  return phase_wait.resolve_result(phase_res, "move", player, total, raw_total)
end
```

（`roll._resolve_phase_wait_result = _resolve_phase_wait_result` 导出行不动。）

- [ ] **Step 4：跑 pin + turn_flow 场景确认保持绿**

Run: `busted --run behavior spec/behavior/turn/roll_spec.lua spec/behavior/scenarios/turn_flow/interrupts_spec.lua`
Expected: PASS（四断言 + 3 个 `_test_resolve_phase_wait_result_*` case 全绿）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/phases/roll.lua
git commit -m "refactor(turn): roll 的 phase_res→wait_state 映射委托 phase_wait,删字节级重复"
```

---

## Task 2：registry._resolve_post_phase_wait 委托 phase_wait（默认 post_action）

**Files:**
- Modify: `src/turn/phases/registry.lua`（顶部 require + `_resolve_post_phase_wait`）
- Pin: `spec/behavior/scenarios/turn_flow/*`、`spec/behavior/turn/*`（post_action 序列）

**Interfaces:**
- Consumes: `phase_wait.resolve_result`。
- Produces: `_resolve_post_phase_wait(player, phase_res)` 行为不变（本地函数，被 `_phase_post` 调用）。

**行为保持：** `_resolve_post_phase_wait` 仅在 `_phase_post` 里 `phase_res and phase_res.waiting` 为真时调用（`phase_res` 非 nil）。它用 `phase_res.next_args or { player = player }` 作 fallback；`phase_wait.resolve_result` 的 fallback 是 `{ player=player, total=nil, raw_total=nil }`——因 `total`/`raw_total` 传 nil、Lua 表不设 nil 键，二者**等价**为 `{player=player}`。默认 `"post_action"`、`wait_action_anim` 分支一致。

- [ ] **Step 1：加 require**

Run: `grep -n "phase_wait" src/turn/phases/registry.lua`
Expected: 空 → registry.lua 顶部 require 区加：

```lua
local phase_wait = require("src.turn.phases.phase_wait")
```

- [ ] **Step 2：函数体降为委托**

将 `src/turn/phases/registry.lua:28-35`：

```lua
local function _resolve_post_phase_wait(player, phase_res)
  local next_state = phase_res.next_state or "post_action"
  local next_args = phase_res.next_args or { player = player }
  if phase_res.wait_action_anim then
    return "wait_action_anim", { next_state = next_state, next_args = next_args }
  end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end
```

改为：

```lua
local function _resolve_post_phase_wait(player, phase_res)
  return phase_wait.resolve_result(phase_res, "post_action", player)
end
```

- [ ] **Step 3：跑 post_action 相关行为 + turn_flow**

Run: `busted --run behavior spec/behavior/turn spec/behavior/scenarios/turn_flow`
Expected: PASS（post_action → wait → end_turn 整段序列不变）。

- [ ] **Step 4：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/phases/registry.lua
git commit -m "refactor(turn): registry post_action 的 wait 映射委托 phase_wait,删内联拷贝"
```

---

## Task 3：start._run_pre_action_item_phase 尾段委托 phase_wait（默认 roll）

**Files:**
- Modify: `src/turn/phases/start.lua`（顶部 require + `_run_pre_action_item_phase` 尾段）
- Pin: `spec/behavior/turn/*`、`spec/behavior/ui/main_turn_pre_action_button_spec.lua`、`spec/behavior/scenarios/turn_flow/*`

**Interfaces:**
- Consumes: `phase_wait.resolve_result`。
- Produces: `_run_pre_action_item_phase(turn_mgr, player)` 行为不变（非 waiting 返 nil；waiting 返 wait 映射）。

**行为保持：** 只替换**尾段**（86-91 的 wait 打包），前面的 guard `if not (phase_res and phase_res.waiting) then return nil end` 不动。尾段默认 `"roll"`、fallback `{player=player}`——与 `phase_wait.resolve_result(phase_res, "roll", player)`（fallback `{player=player,total=nil,raw_total=nil}`=`{player=player}`）逐点等价。此处 `phase_res` 已由 guard 保证非 nil。

- [ ] **Step 1：加 require**

Run: `grep -n "phase_wait" src/turn/phases/start.lua`
Expected: 空 → start.lua 顶部 require 区加：

```lua
local phase_wait = require("src.turn.phases.phase_wait")
```

- [ ] **Step 2：尾段降为委托**

将 `src/turn/phases/start.lua:83-92`：

```lua
  if not (phase_res and phase_res.waiting) then
    return nil
  end
  local next_state = phase_res.next_state or "roll"
  local next_args = phase_res.next_args or { player = player }
  if phase_res.wait_action_anim then
    return "wait_action_anim", { next_state = next_state, next_args = next_args }
  end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end
```

改为：

```lua
  if not (phase_res and phase_res.waiting) then
    return nil
  end
  return phase_wait.resolve_result(phase_res, "roll", player)
end
```

- [ ] **Step 3：跑 start / pre-action / turn_flow**

Run: `busted --run behavior spec/behavior/turn spec/behavior/ui/main_turn_pre_action_button_spec.lua spec/behavior/scenarios/turn_flow`
Expected: PASS（回合开局 pre_action 道具阶段 → wait → roll 序列不变）。

- [ ] **Step 4：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/phases/start.lua
git commit -m "refactor(turn): start pre_action 尾段的 wait 映射委托 phase_wait,删内联拷贝"
```

---

## Task 4（barrier —— Task 1/2/3 全部合并后再执行）：deletion-test 复核 + manifest 刷新 + 完整门禁

**Files:**
- Modify（manifest 刷新）: `src/turn/phases/{roll,registry,start}.lua`
- 全仓验证

> **前置：Task 1/2/3 三个 worktree 已合并进同一树。** 本 task 不可与前三者并行——manifest 刷新与完整门禁要在「三处委托都在场」的合并态上做。

- [ ] **Step 1：deletion-test 复核（口头）**

删 `phase_wait.resolve_result` → `pre_move`/`roll`/`registry`/`start` 四处同时失去「`phase_res` → wait 态 + `next_state`/`next_args` 打包」。微映射集中一处、非冗余。评审的「复制 4 次」归零。

- [ ] **Step 2：确认零残留内联拷贝**

Run: `grep -rn 'return "wait_action_anim", {' src/turn/phases/ | grep -v manifest`
Expected: 只剩 `land.lua` / `roll.lua:_build_anim_wait_result` 等**语义不同**的专用打包（它们不是 `phase_res→wait_state` 通用微映射，不在本次收敛范围——`land` 是落地视觉 hold、`roll` 的 `_build_anim_wait_result` 是掷骰动画专用，均带专有 `next_args`，保留）。`phase_wait.resolve_result` 应是通用映射的唯一实现。

- [ ] **Step 3：刷新三个文件的 mutation manifest**

Run:
```bash
lua tools/quality/mutate.lua src/turn/phases/roll.lua --update-manifest
lua tools/quality/mutate.lua src/turn/phases/registry.lua --update-manifest
lua tools/quality/mutate.lua src/turn/phases/start.lua --update-manifest
```
Expected: 三个 `manifest updated`（只动各文件底部 manifest 注释块——`git diff -U0` 核对改动行号 > manifest marker 行号）。

- [ ] **Step 4：完整门禁 + 验收**

Run: `make verify && make acceptance`
Expected: 两者 PASS（`turn_flow` / `movement` / `endgame` 验收不回归）。

- [ ] **Step 5：Commit**

```bash
git add src/turn/phases/roll.lua src/turn/phases/registry.lua src/turn/phases/start.lua
git commit -m "chore(turn): 刷新 roll/registry/start mutation manifest"
```

---

## 后续项（设计先行，非本计划步骤）—— ③-大：声明式 phase graph

> **这一段不是可执行步骤。** ③ 的标题「声明式 phase graph + phase 只返回 outcome」是架构级改造，**必须先过 `superpowers:brainstorming` + `superpowers:codebase-design`**，再写 TDD 计划。以下是我探到的、该设计必须回答的约束（省下重新发现的功夫）：

**为什么不能简单做成 `phase → default_next` 表：**
1. **数据依赖的一对多分支**：`start` → `end_turn`（已出局）/ `detained_wait`（被扣留）/ `roll`（正常）。`roll` → `pre_move` / `move`（`_phase_roll_direct` 跳过 pre_move）/ `wait_action_anim`（掷骰动画）。这些是运行时分支，扁平默认边表达不了。
2. **wait 夹层**：几乎每条 phase→phase 都经 `wait_action_anim` / `wait_choice` / `wait_action`，真正后继埋在 wait 的 `args.next_state`。「边」是 `phase → wait_X → next_phase`。
3. **args 载荷**：每个转移携带 `next_args`（player/total/raw_total/rolls/skip_anim…），graph 若只存 state 名，需要一层把 outcome 还原成带 args 的转移。

**该设计要交付的（建议 brainstorm 产出）：**
- 一个够表达力的序列结构：`phase → { outcome → edge }`，`edge` 含「目标 state、是否经 wait 夹层、wait 类型选择规则、args 构造」。
- phase 函数改为返回抽象 `outcome`（如 `moved` / `needs_choice` / `eliminated` / `detained`）+ 数据，由 graph 层翻成现有 `(next_state, next_args)`——**driver 无需改**（`timing.lua` 已 generic）。
- 迁移面评估：`spec/behavior/scenarios/turn_flow/*`（cases/loop_policies/interrupts/intent_dispatch）+ `spec/behavior/turn/*` 直接钉了各 phase 返回的字符串，改 phase 返回值 = 大面积 spec 迁移。

**与 ④⑤ 的关系：** ③ 改 `turn/phases/`，④⑤ 改 `turn/waits/` + `turn/deadlines/`，文件面不重叠，可并行；但都属 turn 层，建议同一 swarm stream 顺序推进。

---

## Self-Review

**1. Spec 覆盖（评审 ③ 主张）：**
- ✅「吸收被复制 4 次的 `phase_res→wait_state` 微映射」→ Task 1（roll）/ 2（registry）/ 3（start）三处委托，加上既有 `pre_move` 委托，4 拷贝归 1。
- ⏭「声明式 phase graph + phase 返回 outcome」→ **显式移交设计先行的后续项**（附「为何扁平 default_next 有损」的证据 + 迁移面），非遗漏。
- ✅ deletion test（删 resolve_result → 4 处映射重新散落）→ Task 4 Step 1。

**2. Placeholder 扫描：** 三处收敛均给完整 old→new 代码块与预期输出；后续项明确标注「非可执行步骤、设计先行」。✅

**3. 类型/签名一致性：**
- 委托目标 `phase_wait.resolve_result(phase_res, default_next_state, player, total, raw_total)` 三处调用的默认值（move / post_action / roll）逐一对齐各原始默认。✅
- **fallback next_args 等价性**已逐点核对：`{player}` == `{player,total=nil,raw_total=nil}`（Lua 不设 nil 键）——registry/start 传 nil total/raw_total 安全。✅
- roll 保留导出 seam `roll._resolve_phase_wait_result`（`roll_spec` + scenario 直接钉），只换实现不改签名。✅

**已知风险（handoff 要说）：** ① Task 2/3 的 fallback 等价依赖「nil 值不建键」——若某调用点真的把 `total`/`raw_total` 显式传成非 nil 又走 fallback 分支会有别，但这两处签名根本不收 total/raw_total（恒 nil），无此风险；② `turn_flow` 场景套面广，任一 task 若红先核对是否 phase 返回串漂移；③ ③-大是设计题不是计划题，勿从本计划 schematic 直接开写 graph。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-3-phase-wait-dedup.md`.

本计划 = **候选 ③-安全（微映射收敛，4 拷贝归 1）**，完整可执行、零行为变化。③-大（声明式 phase graph）见上一节，**设计先行**，需 `brainstorming` + `codebase-design` 后另写。

两种执行方式：
**1. Subagent-Driven 并行（推荐）** — Task 1/2/3 同一条消息 fan-out 三个 worktree-隔离 subagent 并行做，各自 gate + commit；合并后单跑 Task 4 barrier。见「并行执行编排」。
**2. Inline 顺序** — 本 session 用 `executing-plans`，1→2→3→4 顺序执行（面极小，成本近似）。

选哪个？
