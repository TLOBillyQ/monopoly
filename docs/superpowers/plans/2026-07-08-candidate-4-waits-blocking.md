# 候选 ④ 阻塞/等待判定 —— waits.blocking 深模块收敛计划

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐 task 执行。步骤用 `- [ ]` 复选框跟踪。**Task 1 是串行前置（建模块，TDD 先红后绿）；Task 2 / Task 3 改两个不同文件、只读依赖 Task 1，可 fan-out 并行（worktree 隔离）；Task 4 是 barrier。** 见「并行执行编排」。

> ⚠️ **执行互斥（务必先读）：候选 ④ 与候选 ⑤（pending choice 生命周期）都改 `src/turn/waits/`。规划可并行，执行必须串行其一。** 本计划 Task 1 会在 `src/turn/waits/` 新建 `blocking.lua`（新文件，与 ⑤ 现有文件不重名、无文本重叠），但同一 swarm stream 里 ④ 与 ⑤ 仍须排序（选 ④→⑤ 或 ⑤→④），不得同时跑——两者都可能刷新 `turn/waits/` 目录下文件的 mutation manifest 并跑同一批 turn 行为 spec，并发 commit 会撞 `index.lock` 且互相污染门禁基线。

**Goal:** 把「回合此刻被什么挡住、带着一个目标 intent 该进入哪个 wait 态并如何挂 resume 回调」这段被 `land.lua` 手搓的 anim×hold×move_anim×action_anim 组合路由（约 130 行 + 一个孪生 router），收敛进唯一的 `src/turn/waits/blocking.lua` 深模块（`next_wait_state` = 唯一等待判定器 + `current_block` = 唯一「卡在什么上」查询），`land.lua` 降为薄委托，保留其被 36+ 条 characterization 断言钉死的两个导出 seam。

**Architecture:** 照金标准 `rules/items` 的 `use_result`（唯一判定）+ 先例 ADR 0025 的 `src/turn/optional_action_completion.lua`（query + command 的 turn deep module）。新建 `blocking.lua` 只暴露两个领域 interface：`next_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)`（今日 `land._resolve_wait_state` 逻辑逐字节迁入）与 `current_block(game) -> nil | { kind }`（新的纯查询，命名「回合停在哪个 wait」）。`land.lua` 的 `_resolve_wait_state`/`resolve_wait_state` 导出改为 **直接指向 `blocking.next_wait_state`**（签名相同），其手搓的 `_resolve_finished_landing_state` 孪生 router 折叠为一行 `blocking.next_wait_state(game, "post_action", {player=player}, true, false)`（byte 等价，见 Task 2 证明）。

**Tech Stack:** Lua 5.4；busted（`spec/behavior/turn/`）；清洁架构七层，模块落在 `turn/waits`。

## Global Constraints

- 命名 `snake_case`；`blocking.lua` 顶部一段中文 doc 注释说明「唯一等待判定器」职责（照抄 `src/turn/optional_action_completion.lua` 风格的领域语言注释）。
- `src/` 禁用 `tonumber` / `type(x)=="number"`；本模块只做 state/flag 分类，不引入数字判定。
- **这是重构，观测行为零变化**：迁移逐点字节等价（见各 task「行为保持」），被 pin 的导出 seam 签名不变。
- 门禁 `make verify`（= `lua tools/quality/verify_full.lua`，~7-8s，本仓库 verify 即完整门禁）；每个 task 结尾跑。回合序列面广，**Task 末必跑 turn 行为套**：`busted --run behavior spec/behavior/turn` 与 `busted --run behavior spec/behavior/scenarios/turn_flow`。
- 单文件 spec：`busted --run behavior spec/behavior/turn/<file>_spec.lua`。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`。
- mutation manifest 刷新：`lua tools/quality/mutate.lua <file> --update-manifest`（只动文件尾 `--[[ mutate4lua-manifest ]]` 注释块；收尾核对改动行号 > marker 行号）。
- ⚠️ **`land.lua` 的现存 manifest 已 stale**（描述一个 301 行的旧版本，实际代码仅 193 行——被 commit `54061d7b`「route landing settlement through rules seam」抽空后未刷新）。Task 4 刷新 `land.lua` manifest 会产生**大 diff**（追平被 gut 的旧 scope），这是**预期且正确**的，不是本次改动引入的回归。

---

## 候选 ④ 全貌与分期（务必先读——评审有夸大，已核实降级）

评审把这刀讲成「一个 `waits.blocking` module，把散落在 13 文件的裸 `game.turn.*` 读全部收编」，并断言 `land.resolve_wait_state` 是**死导出、零 caller、可纯删除**。**探源后，评审的核心事实主张之一是假的，散落面主张半真半虚。** 逐条核实：

| 评审主张 | 是否真实 | 证据 | 归属 |
|---|---|---|---|
| `land.resolve_wait_state` 是「死导出、零 caller、删了什么都不坏」 | ❌ **假** | `resolve_wait_state`（非下划线）被 `land_resolve_spec.lua` **25 条断言**直接钉；`_resolve_wait_state`（下划线）被 `phase_transitions_spec.lua` **11 条**+ `t2_cases.lua`/`interrupts.lua` 场景 **3 条**钉。「零 caller」只对 **src/ 生产代码**成立——它是**被 36+ characterization 断言钉死的主测面**。**删了会同时炸三个 spec 文件。** | 本计划**保留** seam，只换实现（委托），非删除 |
| land 手搓 anim×hold×move_anim×action_anim 组合路由约 130 行，应收进一处 | ✅ 真实 | `land.lua:6-136` 的 `_has_action_anim`/`_is_landing_visual_hold_active`/`_resolve_wait_move_anim`/`_resolve_wait_action_anim_state`/`_route_choice_wait_state`/`_resolve_wait_state`，**外加**一个孪生 router `_resolve_finished_landing_state:138-162`（对固定 `post_action` 目标重推同一 anim×hold 分支） | **本计划安全核心（Task 1-2）** |
| `next_wait_state(intent, game)` + `current_block(game)` 两个 interface | ✅ 真实且合理 | 二者是**不同**关注点：`next_wait_state` = land 的路由器（「进入哪个 wait」写方）；`current_block` = tick_flow/tick_steps/await 问的「此刻停在什么上」读方 | **本计划安全核心（Task 1）建成两者；只迁移 byte 等价的消费点** |
| `await.lua:87` / `tick_flow.lua:25` / `tick_steps.lua:42` 应停止重读裸标志、改走本模块 | ⚠️ **半虚** | `tick_flow._maybe_advance_turn` 的 `phase ~= "wait_landing_visual"` **是** byte 等价的 `current_block` 消费点（Task 3 迁）。但 `await.lua:87` 只读单个 `game.turn.action_anim`（**不**读 queue/hold/effect_idle），与 land 路由器的 flag 集**不等价**——合并会引入行为变化；`tick_steps:42` 读 `move_anim`/`action_anim` 驱动动画步进，是「停在此 wait 里有无 payload 可步进」的另一问题，且在 tick 热路径 | `tick_flow` 迁移进 Task 3；**`await`/`tick_steps` 收编 → 设计先行后续项**（附证据） |
| 裸读计数 action_anim 13 文件、popup_active 10…应统一 | ⚠️ **虚（跨层）** | grep 实测 `game.turn.action_anim` 落在 **11 文件、4 层**（rules/、ui/、turn/policies/、turn/waits/）；`popup_active` 落在 **18 文件**。这些读**各为其用**（`validator_gate` 门禁、`status_signals` 渲染、`settlement` 写 anim），**不是同一个「回合被阻塞吗」问题**。全量统一是架构级跨层改造 | **设计先行后续项**（非本计划步骤） |

**分期结论：**
- **本计划 = ④-安全（`waits.blocking` 深模块 + land 委托 + byte 等价迁移 tick_flow）**，完整展开、可立即执行、零行为变化、保留全部 pinned seam。
- **④-大（await/tick_steps 收编 + 跨层裸读全量统一）= 设计先行的后续项**，须先过 `superpowers:brainstorming` + `codebase-design`（把「await 单标志 vs land 多标志」的语义差、tick 热路径、跨层各自用途设计成一个够表达力且不漂移的 interface），**再**写 TDD 计划。文末给出该后续项入口与我探到的约束。

---

## ④-安全 文件结构

**新建：**
- `src/turn/waits/blocking.lua` — 深模块本体。唯一等待判定器：`next_wait_state`（land 路由逻辑逐字节迁入）+ `current_block`（新纯查询）。
- `spec/behavior/turn/waits_blocking_spec.lua` — 模块直测（成为路由逻辑的**主测面**：把 `land_resolve_spec` 的判定矩阵迁到直测 `blocking.next_wait_state` + 新 `current_block` 逐 kind 钉死）。

**降为薄委托（保留导出 seam，签名不变）：**
- `src/turn/phases/land.lua`：删本地路由子系统（`:6-136` 全部 helper + `_resolve_wait_state`），`_resolve_finished_landing_state` 折叠为一行委托，两个导出 `_resolve_wait_state`/`resolve_wait_state` 直接指向 `blocking.next_wait_state`。

**byte 等价迁移（Task 3，可并行）：**
- `src/turn/loop/tick_flow.lua:23-28`：`_maybe_advance_turn` 的 `phase ~= "wait_landing_visual"` 裸读改走 `blocking.current_block`。

**护栏 spec（保持绿，勿改）：**
- `spec/behavior/turn/land_resolve_spec.lua`（25 条钉 `land_resolve.resolve_wait_state`）
- `spec/behavior/turn/phase_transitions_spec.lua`（11 条钉 `land._resolve_wait_state`）
- `spec/support/scenario_suites/shared/t2_cases.lua` + `spec/support/scenario_suites/turn_flow/interrupts.lua`（3 条 `_test_resolve_wait_state_*` 场景 case，走 land 导出）
- `spec/behavior/turn/loop_runtime_spec.lua`、`landing_spec.lua`、`scheduler_runtime_spec.lua`（tick_flow / advance_turn 路径）
- `spec/behavior/scenarios/turn_flow/*`（整圈序列）

**先例参照（不动）：**
- `src/turn/optional_action_completion.lua`（ADR 0025 的 query+command deep module 模板）。
- `src/turn/policies/action_gate.lua` 的 `_has_active_modal_state`/`resolve_gate_state`（既有的「阻塞谓词收进一处」形状）。

---

## 并行执行编排

```
                 ┌─ Task 2  land.lua      ─┐
 Task 1  blocking.lua ──┤                          ├─→  Task 4  barrier
 (串行前置:建模块 TDD)   └─ Task 3  tick_flow.lua  ─┘   (合并后:deletion-test + manifest×2 + 完整门禁 + 验收)
```

**为何 Task 2 / Task 3 可并行（冲突矩阵）：**

| | 改的源文件 | 加的 require | 消费 Task 1 产出 | 写别的 task 文件? | 改的 manifest |
|---|---|---|---|---|---|
| Task 1 | `turn/waits/blocking.lua`（新建） | runtime_state / runtime_ports / callback_registry | — | 否 | blocking.lua 尾（新建即写） |
| Task 2 | `turn/phases/land.lua` | `blocking` | `next_wait_state`（只读） | 否 | land.lua 尾（Task 4 刷新） |
| Task 3 | `turn/loop/tick_flow.lua` | `blocking` | `current_block`（只读） | 否 | tick_flow.lua 尾（Task 4 刷新） |

- **Task 2 / Task 3 改两个不同源文件，零重叠写**；各自 manifest 在各自文件尾。
- 二者对 `blocking.lua` 都是**只读依赖**（Task 1 定稿后不再改）→ 无共享可变状态。
- `tick_flow` 与 `land` 无 require 环、无相互 import → Task 3 不需等 Task 2。

**swarm 分派方式：**
1. **先串行做 Task 1**（建模块，TDD 先红后绿）——Task 2/3 都依赖它的两个 interface 定稿。Task 1 单独 commit。
2. Task 1 合并后，**同一条消息 fan-out Task 2 + Task 3 两个 subagent**，每个 `isolation: "worktree"`（隔离 git，避免并发 commit 撞 `index.lock`）。各自做 Step 全程 + 在自己 worktree 内 `make verify` 自证 + commit。
3. 两者全绿后**合并**（不同文件，无文本冲突）。
4. **再单独跑 Task 4**（barrier）：deletion-test 复核、`land.lua` + `tick_flow.lua` 两个 manifest 刷新、完整门禁 + 验收。manifest 刷新必须在合并态做。

**并行真实收益（诚实说明）：** 本计划的并行 fan-out 只有 **2 个小文件**（land 一处委托折叠 + tick_flow 一行改），壁钟收益微乎其微；**主要价值是两个 reviewer 并行 gate**，与候选 ③ 同。若不想开 worktree，单一工作树顺序 1→2→3→4 成本几乎等同。**真正的串行硬约束是与候选 ⑤ 的 turn/waits 执行 mutex（见开头 flag），不是本计划内部。**

---

## Task 1：新建 waits.blocking（next_wait_state 迁入 + current_block 新建）

**Files:**
- Create: `src/turn/waits/blocking.lua`
- Test: `spec/behavior/turn/waits_blocking_spec.lua`

**Interfaces:**
- Consumes（既有，签名已核对）：
  - `runtime_state.get_landing_visual_hold_source(state)` / `get_landing_visual_hold_active(state)`（`land.lua:22-24` 现用）。
  - `runtime_ports.is_effect_idle` —— **稳定 dispatcher**（`runtime_ports.lua:77` 由 `_make_port` 造一次，`configure` 只改内部 config，port 内部读当前 config）。故 `local _is_effect_idle = runtime_ports.is_effect_idle` 在 module load 捕获**安全**（`land_resolve_spec` 的 `runtime_ports.configure{is_effect_idle=...}` 仍生效）——**逐字节照搬 land 的捕获模式**。
  - `wait_callbacks.register` / `wait_callbacks.callback_keys`（`land.lua:31,34` 现用）。
- Produces（Task 2/3 依赖）：
  - `blocking.next_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim) -> state_name, args`（今日 `land._resolve_wait_state` 逐字节等价）。
  - `blocking.current_block(game) -> nil | { kind }`，`kind ∈ {landing_visual, action_anim, move_anim, choice, action}`（按 `game.turn.phase` 映射；非 wait 相 → nil）。

**行为保持：** `next_wait_state` 的函数体、私有 helper、require、`_is_effect_idle` 捕获模式与 `land.lua:1-136` **逐字节相同**，仅把顶层 local `_resolve_wait_state` 重命名为模块方法 `blocking.next_wait_state`。因此 `land_resolve_spec`/`phase_transitions_spec` 的判定矩阵在 Task 1 里被**原样复刻为直测**，跑绿即锁定「迁移零漂移」。`current_block` 是**新增**纯查询，无既有行为需保持——TDD 先红后绿。

- [ ] **Step 1：写失败测试**

创建 `spec/behavior/turn/waits_blocking_spec.lua`：

```lua
-- waits.blocking 深模块直测:next_wait_state(等待路由,主测面) + current_block(卡在什么上)。
-- next_wait_state 的判定矩阵复刻自 land_resolve_spec(迁移零漂移的锚),
-- current_block 逐 phase kind 钉死。
local blocking = require("src.turn.waits.blocking")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game(opts)
  opts = opts or {}
  return {
    turn = opts.turn or {},
    dirty = opts.dirty or { any = false, turn = false },
    wait_callback_runtime = opts.wait_callback_runtime,
  }
end

local function _configure_idle(idle)
  runtime_ports.configure({ is_effect_idle = function() return idle end })
end

local function _teardown()
  runtime_ports.reset_for_tests()
end

describe("turn.waits.blocking", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  describe("next_wait_state", function()
    it("no anim no hold returns wait_choice", function()
      _configure_idle(true)
      local game = _make_game()
      local state, args = blocking.next_wait_state(game, "post_action", { player = {} }, false)
      _assert_eq(state, "wait_choice", "no anim/hold -> wait_choice")
      _assert_eq(args.next_state, "post_action", "next_state preserved")
      _teardown()
    end)

    it("anim no hold returns wait_action_anim", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "test" } } })
      local state, args = blocking.next_wait_state(game, "move", {}, false)
      _assert_eq(state, "wait_action_anim", "has anim -> wait_action_anim")
      _assert_eq(args.next_state, "wait_choice", "next_state wait_choice via action_anim")
      _teardown()
    end)

    it("no anim has hold returns wait_landing_visual", function()
      _configure_idle(true)
      local game = _make_game({ turn = { landing_visual_hold_active = true } })
      local state = blocking.next_wait_state(game, "post_action", {}, false)
      _assert_eq(state, "wait_landing_visual", "hold -> wait_landing_visual")
      _teardown()
    end)

    it("wait_action_anim flag with no anim/hold returns next directly", function()
      _configure_idle(true)
      local game = _make_game()
      local state, args = blocking.next_wait_state(game, "done_state", { val = 42 }, true)
      _assert_eq(state, "done_state", "wait_action_anim=true, no anim/hold -> next_state direct")
      _assert_eq(args.val, 42, "next_args returned")
      _teardown()
    end)

    it("wait_action_anim flag with anim returns wait_action_anim carrying next", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "test" } } })
      local state, args = blocking.next_wait_state(game, "post_action", {}, true)
      _assert_eq(state, "wait_action_anim", "anim + wait_action_anim=true -> wait_action_anim")
      _assert_eq(args.next_state, "post_action", "next_state preserved")
      _teardown()
    end)

    it("effects_pending forces wait_landing_visual even with no anim", function()
      _configure_idle(false)
      local game = _make_game()
      local state = blocking.next_wait_state(game, "post_action", {}, false)
      _assert_eq(state, "wait_landing_visual", "effects pending -> wait_landing_visual")
      _teardown()
    end)

    it("queued anim counts as has_anim", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim_queue = { { kind = "queued" } } } })
      local state = blocking.next_wait_state(game, "post_action", {}, false)
      _assert_eq(state, "wait_action_anim", "queued anim -> has_anim")
      _teardown()
    end)

    it("anim and hold routes through landing_visual first, chaining action_anim", function()
      _configure_idle(true)
      local game = _make_game({
        turn = { action_anim = { kind = "test" }, landing_visual_hold_active = true },
      })
      local state, args = blocking.next_wait_state(game, "post_action", {}, true)
      _assert_eq(state, "wait_landing_visual", "anim+hold -> landing_visual first")
      _assert_eq(args.next_state, "wait_action_anim", "landing_visual chains into wait_action_anim")
      _teardown()
    end)

    it("wait_move_anim flag with no anim/hold returns wait_move_anim", function()
      _configure_idle(true)
      local game = _make_game()
      local state, args = blocking.next_wait_state(game, "post_action", { val = 1 }, false, true)
      _assert_eq(state, "wait_move_anim", "wait_move_anim flag -> wait_move_anim")
      _assert_eq(args.next_state, "post_action", "move_anim_args.next_state preserved")
      _teardown()
    end)

    it("wait_move_anim with pending action_anim routes through wait_action_anim first", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "chance", seq = 1 } } })
      local state, args = blocking.next_wait_state(game, "move_followup", { mode = "resolve_landing" }, false, true)
      _assert_eq(state, "wait_action_anim", "pending action_anim drains first")
      _assert_eq(args.next_state, "wait_move_anim", "wrapper chains into wait_move_anim")
      _assert_eq(game.turn.move_followup_pending, true, "move_followup target sets pending eagerly")
      _teardown()
    end)

    it("move_followup next_state sets move_followup_pending", function()
      _configure_idle(true)
      local game = _make_game({ turn = { action_anim = { kind = "test" } } })
      blocking.next_wait_state(game, "move_followup", {}, true)
      _assert_eq(game.turn.move_followup_pending, true, "move_followup -> pending flag")
      _teardown()
    end)
  end)

  describe("current_block", function()
    it("returns nil when turn is not parked in a wait phase", function()
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "roll" } })), nil, "roll -> nil")
      _assert_eq(blocking.current_block(_make_game({ turn = {} })), nil, "no phase -> nil")
      _assert_eq(blocking.current_block(_make_game()), nil, "empty turn -> nil")
    end)

    it("maps wait_landing_visual phase to landing_visual kind", function()
      local block = blocking.current_block(_make_game({ turn = { phase = "wait_landing_visual" } }))
      _assert_eq(block and block.kind, "landing_visual", "wait_landing_visual -> landing_visual")
    end)

    it("maps the anim/move/choice/action wait phases to their kinds", function()
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_action_anim" } })).kind, "action_anim", "action_anim")
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_move_anim" } })).kind, "move_anim", "move_anim")
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_choice" } })).kind, "choice", "choice")
      _assert_eq(blocking.current_block(_make_game({ turn = { phase = "wait_action" } })).kind, "action", "action")
    end)
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted --run behavior spec/behavior/turn/waits_blocking_spec.lua`
Expected: FAIL —`module 'src.turn.waits.blocking' not found`。

- [ ] **Step 3：写实现（next_wait_state 逐字节迁入 + current_block 新建）**

创建 `src/turn/waits/blocking.lua`（`next_wait_state` 及其私有 helper 与 `land.lua:1-136` 逐字节相同，仅顶层 `_resolve_wait_state` 改名为模块方法）：

```lua
-- 回合阻塞/等待判定深模块:唯一判定器。
-- 「回合此刻被什么挡住(current_block)」与「带着一个目标 intent 该进入哪个 wait 态、
-- 如何挂 resume 回调(next_wait_state)」全部收敛于此。原先 land.lua 手搓的
-- anim×hold×move_anim×action_anim 组合路由(约130行 + 孪生 _resolve_finished_landing_state)
-- 迁入本模块;land 降为薄委托,保留其被 characterization 钉死的两个导出 seam。
local runtime_state = require("src.state.runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local wait_callbacks = require("src.turn.waits.callback_registry")

local blocking = {}

local function _has_action_anim(game)
  if not game or not game.turn then
    return false
  end
  if game.turn.action_anim then
    return true
  end
  local queue = game.turn.action_anim_queue
  return type(queue) == "table" and #queue > 0
end

local function _is_landing_visual_hold_active(game)
  if not game then
    return false
  end
  local state = game.landing_visual_hold_state
  if state ~= nil and runtime_state.get_landing_visual_hold_source(state) ~= nil then
    return runtime_state.get_landing_visual_hold_active(state)
  end
  local turn = game.turn or nil
  return turn and turn.landing_visual_hold_active == true or false
end

local _is_effect_idle = runtime_ports.is_effect_idle

local callback_keys = wait_callbacks.callback_keys

local function _register_action_anim_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_action_anim, callback)
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
  end
  return "wait_action_anim", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _register_landing_visual_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_landing_visual, callback)
  return "wait_landing_visual", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _resume_wait_choice(next_state, next_args)
  return "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _wait_for_choice_via(register_fn)
  return function(game, next_state, next_args)
    return register_fn(game, "wait_choice", {
      next_state = next_state,
      next_args = next_args,
    }, function()
      return _resume_wait_choice(next_state, next_args)
    end)
  end
end

local _wait_for_choice_via_action_anim = _wait_for_choice_via(_register_action_anim_resume)
local _wait_for_choice_via_landing_visual = _wait_for_choice_via(_register_landing_visual_resume)

local function _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args)
  local action_anim_state, action_anim_args = _wait_for_choice_via_action_anim(game, next_state, next_args)
  return _register_landing_visual_resume(game, action_anim_state, action_anim_args, function()
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end)
end

local function _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  if next_state == "move_followup" then game.turn.move_followup_pending = true end
  local move_anim_args = { next_state = next_state, next_args = next_args }
  local function _resume() return "wait_move_anim", move_anim_args end
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "wait_move_anim",
        next_args = move_anim_args,
      }, function()
        return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
      end)
    end
    return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
  end
  if has_hold_or_pending then return _register_landing_visual_resume(game, "wait_move_anim", move_anim_args, _resume) end
  return "wait_move_anim", move_anim_args
end

local function _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = next_state,
        next_args = next_args,
      }, function()
        return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
      end)
    end
    return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  if has_hold_or_pending then
    return _register_landing_visual_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  return next_state, next_args
end

local function _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
  if has_anim then
    if has_hold_or_pending then return _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args) end
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end
  if has_hold_or_pending then return _wait_for_choice_via_landing_visual(game, next_state, next_args) end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

-- 唯一等待判定器:给一个目标 (next_state,next_args) 与 wait 标志,
-- 按 action_anim / landing_visual_hold / effect_idle / move_anim 组合,
-- 决定进入哪个 wait 态并挂好 resume 回调。
function blocking.next_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)
  local has_anim = _has_action_anim(game)
  local has_hold_or_pending = _is_landing_visual_hold_active(game) or not _is_effect_idle()
  if wait_move_anim == true then
    return _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  if wait_action_anim == true then
    return _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  return _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
end

local _PARKED_KINDS = {
  wait_landing_visual = "landing_visual",
  wait_action_anim = "action_anim",
  wait_move_anim = "move_anim",
  wait_choice = "choice",
  wait_action = "action",
}

-- 唯一「卡在什么上」查询:回合停在某个 wait 相时回报其 kind,否则 nil。
function blocking.current_block(game)
  local turn = game and game.turn or nil
  local phase = turn and turn.phase or nil
  local kind = phase and _PARKED_KINDS[phase] or nil
  if kind == nil then
    return nil
  end
  return { kind = kind }
end

return blocking
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted --run behavior spec/behavior/turn/waits_blocking_spec.lua`
Expected: PASS（next_wait_state 11 + current_block 3 全绿）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS（新模块无 caller，既有全套保持绿）。

```bash
git add src/turn/waits/blocking.lua spec/behavior/turn/waits_blocking_spec.lua
git commit -m "feat(turn): waits.blocking —— next_wait_state 唯一等待判定器 + current_block 查询"
```

---

## Task 2（Task 1 合并后可与 Task 3 并行）：land.lua 降为 blocking 薄委托

**Files:**
- Modify: `src/turn/phases/land.lua`（删 `:1-136` 路由子系统 + 折叠 `_resolve_finished_landing_state` + 换两个导出）
- Pin（保持绿，勿改）: `spec/behavior/turn/land_resolve_spec.lua`、`spec/behavior/turn/phase_transitions_spec.lua`、`spec/support/scenario_suites/shared/t2_cases.lua`、`spec/behavior/scenarios/turn_flow/*`

**Interfaces:**
- Consumes: `blocking.next_wait_state`（Task 1）。
- Produces: `land._resolve_wait_state` / `land.resolve_wait_state` 签名**不变**（= `blocking.next_wait_state`）；`land.run` 行为不变。

**行为保持（逐点）：**
1. 两个导出改为**直接指向** `blocking.next_wait_state`——签名 `(game, next_state, next_args, wait_action_anim, wait_move_anim)` 逐字相同，`land_resolve_spec`（25）+ `phase_transitions_spec`（11）+ `t2_cases` 场景（3）全部走这两个导出，仍绿。
2. `_resolve_waiting_landing_result` 内的 `_resolve_wait_state(...)` 调用改为 `blocking.next_wait_state(...)`，实参不变。
3. **`_resolve_finished_landing_state` 折叠为 `blocking.next_wait_state(game, "post_action", {player=player}, true, false)`** —— byte 等价证明：`_resolve_finished_landing_state` 是 `wait_action_anim=true` 路径对固定目标 `post_action`/`{player=player}` 的手抄；`blocking.next_wait_state(...,true,false)` 走 `_resolve_wait_action_anim_state(game,"post_action",{player=player},has_anim,has_hold_or_pending)`，其中 `has_hold_or_pending = has_hold or not effect_idle`，与原文 `has_hold or effects_pending` 恒等；两者的 has_anim/hold 三分支结构与 landing_visual→action_anim 链完全一致；resume 回调都最终返回 `"post_action"` + 带 `player` 的表（原文用新建 `{player=player}`，`next_wait_state` 复用传入的 `next_args` 表——消费方只读 `.player`，无可观测差异）。此项由 turn_flow 场景套 + gameplay hotspot 覆盖（非直接单测命名），若任一场景红则回退本 sub-step（保留 `_resolve_finished_landing_state` 为薄函数、其余委托照常）。

- [ ] **Step 1：确认既有 pin 全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/turn/land_resolve_spec.lua spec/behavior/turn/phase_transitions_spec.lua`
Expected: PASS（25 + 11 断言——本 task 的护栏，重构后必须仍全绿）。

- [ ] **Step 2：改写 land.lua**

将 `src/turn/phases/land.lua:1-193`（`require` 区 + 路由子系统 + `_resolve_finished_landing_state` + 后段 + 导出，即整段代码，manifest 注释块 `:195-373` 不动）：

```lua
local runtime_state = require("src.state.runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local settlement = require("src.rules.land.settlement")
local wait_callbacks = require("src.turn.waits.callback_registry")

local function _has_action_anim(game)
  -- ... (land.lua:6-136 的全部路由 helper 与 _resolve_wait_state,略) ...
end

-- ... _resolve_wait_state 定义于 :126-136 ...

local function _resolve_finished_landing_state(game, player)
  local function _resume_post_action()
    return "post_action", { player = player }
  end
  local has_anim = _has_action_anim(game)
  local has_hold = _is_landing_visual_hold_active(game)
  local effects_pending = not _is_effect_idle()
  if has_anim then
    if has_hold or effects_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "post_action",
        next_args = { player = player },
      }, function()
        return _register_action_anim_resume(game, "post_action", { player = player }, _resume_post_action)
      end)
    end
    return _register_action_anim_resume(game, "post_action", { player = player }, _resume_post_action)
  end
  if has_hold or effects_pending then
    return _register_landing_visual_resume(game, "post_action", { player = player }, _resume_post_action)
  end
  return "post_action", { player = player }
end

local function _resolve_landing_wait_args(res, player, move_result)
  return res.next_state or "landing", res.next_args or { player = player, move_result = move_result }
end

local function _resolve_waiting_landing_result(game, res, player, move_result)
  local next_state, next_args = _resolve_landing_wait_args(res, player, move_result)
  return _resolve_wait_state(game, next_state, next_args, res.wait_action_anim, res.wait_move_anim)
end

local function _phase_land(turn_mgr, args)
  local player = args.player
  local move_result = args.move_result
  local game = turn_mgr.game
  local tile = game.board:get_tile(player.position)

  local res = settlement.begin_landing_settlement(game, player.id, {
    tile = tile,
    move_result = move_result,
  })
  if res and res.waiting then
    return _resolve_waiting_landing_result(game, res, player, move_result)
  end
  return _resolve_finished_landing_state(game, player)
end

return {
  run = _phase_land,
  _resolve_wait_state = _resolve_wait_state,
  resolve_wait_state = _resolve_wait_state,
}
```

改为（删掉整个 `:1-136` 路由子系统与本地 `_resolve_finished_landing_state` 实现，只留委托）：

```lua
local settlement = require("src.rules.land.settlement")
local blocking = require("src.turn.waits.blocking")

-- 落地结算完成、无 res.waiting 时进入 post_action 的等待路由。
-- 等价于 wait_action_anim 路径对固定 post_action 目标的委托(见 Task 2 行为保持证明)。
local function _resolve_finished_landing_state(game, player)
  return blocking.next_wait_state(game, "post_action", { player = player }, true, false)
end

local function _resolve_landing_wait_args(res, player, move_result)
  return res.next_state or "landing", res.next_args or { player = player, move_result = move_result }
end

local function _resolve_waiting_landing_result(game, res, player, move_result)
  local next_state, next_args = _resolve_landing_wait_args(res, player, move_result)
  return blocking.next_wait_state(game, next_state, next_args, res.wait_action_anim, res.wait_move_anim)
end

local function _phase_land(turn_mgr, args)
  local player = args.player
  local move_result = args.move_result
  local game = turn_mgr.game
  local tile = game.board:get_tile(player.position)

  local res = settlement.begin_landing_settlement(game, player.id, {
    tile = tile,
    move_result = move_result,
  })
  if res and res.waiting then
    return _resolve_waiting_landing_result(game, res, player, move_result)
  end
  return _resolve_finished_landing_state(game, player)
end

return {
  run = _phase_land,
  _resolve_wait_state = blocking.next_wait_state,
  resolve_wait_state = blocking.next_wait_state,
}
```

> `land.lua` 迁移后不再直接用 `runtime_state` / `runtime_ports` / `wait_callbacks`——删掉这三个 require（`blocking` 内部持有它们）。保留 `settlement`（`_phase_land` 用）。

- [ ] **Step 3：跑 pin（land_resolve + phase_transitions）确认仍全绿**

Run: `busted --run behavior spec/behavior/turn/land_resolve_spec.lua spec/behavior/turn/phase_transitions_spec.lua`
Expected: PASS（25 + 11 断言——两个导出 seam 仍指向等价逻辑，行为零变化）。

- [ ] **Step 4：跑 turn 全套 + turn_flow 场景（护 `_resolve_finished_landing_state` 折叠）**

Run: `busted --run behavior spec/behavior/turn spec/behavior/scenarios/turn_flow`
Expected: PASS（落地→post_action 序列、t2_cases 场景 case 不变）。
> 若某 turn_flow 场景因 `_resolve_finished_landing_state` 折叠红：先核对是否 next_args 表身份被下游误比对——按行为保持第 3 点回退该 sub-step（保留本地 `_resolve_finished_landing_state`，从 blocking 取 helper 或留 land 内），其余委托照常。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/phases/land.lua
git commit -m "refactor(turn): land 等待路由委托 waits.blocking,删本地 130 行组合路由 + 孪生 router"
```

---

## Task 3（Task 1 合并后可与 Task 2 并行）：tick_flow 的停驻查询走 blocking.current_block

**Files:**
- Modify: `src/turn/loop/tick_flow.lua`（require + `_maybe_advance_turn`）
- Pin（保持绿，勿改）: `spec/behavior/turn/loop_runtime_spec.lua`、`spec/behavior/turn/landing_spec.lua`、`spec/behavior/turn/scheduler_runtime_spec.lua`、`spec/behavior/scenarios/turn_flow/*`

**Interfaces:**
- Consumes: `blocking.current_block`（Task 1）。
- Produces: `tick_flow.tick` 行为不变。

**行为保持：** `_maybe_advance_turn` 首行 `if not (game.turn and game.advance_turn) then return end` 保证 `game.turn` 非 nil 才到达 phase 检查；原 `if game.turn.phase ~= "wait_landing_visual" then return end` 与 `local block = blocking.current_block(game); if not (block and block.kind == "landing_visual") then return end` 逐点等价——`current_block` 恰在 `game.turn.phase == "wait_landing_visual"` 时回 `{kind="landing_visual"}`，其余回 nil。这是热路径的**单点 byte 等价**改写，`is_wait_ready` 后置检查与 `game:advance_turn()` 不动。

- [ ] **Step 1：确认既有 pin 全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/turn/loop_runtime_spec.lua spec/behavior/turn/scheduler_runtime_spec.lua`
Expected: PASS（advance_turn / wait_landing_visual 推进路径护栏）。

- [ ] **Step 2：加 require**

Run: `grep -n "blocking" src/turn/loop/tick_flow.lua`
Expected: 空 → `tick_flow.lua` 顶部 require 区（`local wait_callbacks = ...` 下一行）加：

```lua
local blocking = require("src.turn.waits.blocking")
```

- [ ] **Step 3：`_maybe_advance_turn` 改走 current_block**

将 `src/turn/loop/tick_flow.lua:23-28`：

```lua
local function _maybe_advance_turn(game)
  if not (game.turn and game.advance_turn) then return end
  if game.turn.phase ~= "wait_landing_visual" then return end
  if not wait_callbacks.is_wait_ready(game, wait_keys.landing_visual) then return end
  game:advance_turn()
end
```

改为：

```lua
local function _maybe_advance_turn(game)
  if not (game.turn and game.advance_turn) then return end
  local block = blocking.current_block(game)
  if not (block and block.kind == "landing_visual") then return end
  if not wait_callbacks.is_wait_ready(game, wait_keys.landing_visual) then return end
  game:advance_turn()
end
```

- [ ] **Step 4：跑 tick / landing / turn_flow 确认保持绿**

Run: `busted --run behavior spec/behavior/turn spec/behavior/scenarios/turn_flow`
Expected: PASS（landing_visual 推进序列不变）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/loop/tick_flow.lua
git commit -m "refactor(turn): tick_flow 的 wait_landing_visual 停驻判定走 blocking.current_block"
```

---

## Task 4（barrier —— Task 1/2/3 全部合并后再执行）：deletion-test 复核 + manifest 刷新 + 完整门禁

**Files:**
- Modify（manifest 刷新）: `src/turn/phases/land.lua`、`src/turn/loop/tick_flow.lua`
- 全仓验证

> **前置：Task 1/2/3 已合并进同一树。** 本 task 不可与前三者并行——manifest 刷新与完整门禁要在「blocking 建成 + land 委托 + tick_flow 迁移」都在场的合并态做。

- [ ] **Step 1：deletion-test 复核（口头，非代码）**

删 `src/turn/waits/blocking.lua` → `land`（两个导出 + `_resolve_finished_landing_state` + `_resolve_waiting_landing_result`）与 `tick_flow._maybe_advance_turn` 同时失去「等待路由 + 停驻判定」——`land` 必须重新手搓 130 行组合路由与孪生 router，`tick_flow` 重读裸 `game.turn.phase`。复杂度集中一处、非冗余，与 `rules/items/use_result` 同构。评审断言的「`resolve_wait_state` 死导出可纯删」被**证伪并纠正**：它是被 36+ 断言钉死的主测面，本计划保留 seam、只把实现收敛到 `blocking`。

- [ ] **Step 2：确认无残留本地路由拷贝**

Run: `grep -rn 'return "wait_action_anim", {\|_route_choice_wait_state\|_resolve_wait_action_anim_state' src/turn/phases/ src/turn/loop/`
Expected: 空（land 的路由子系统已全部迁走）。通用等待路由的唯一实现是 `blocking.next_wait_state`。
> 注：`src/turn/waits/await.lua` 里 `_wait_for_choice_action_anim` 仍有 `next_state = "wait_action_anim"` 的**专用**打包（单标志、语义不同），**不在**本次收敛范围——见文末设计先行后续项。

- [ ] **Step 3：刷新 land.lua 与 tick_flow.lua 的 mutation manifest**

Run:
```bash
lua tools/quality/mutate.lua src/turn/phases/land.lua --update-manifest
lua tools/quality/mutate.lua src/turn/loop/tick_flow.lua --update-manifest
```
Expected: 两个 `manifest updated`。
> ⚠️ `land.lua` 的 manifest 原本 **stale**（描述 301 行旧版本），本次刷新会产生**大 diff**（追平被 commit `54061d7b` 抽空的旧 scope + 反映委托后的新 scope）——**预期且正确**。核对只动注释块：`git diff -U0 src/turn/phases/land.lua` 的最早改动行号应 > `grep -n "mutate4lua-manifest" src/turn/phases/land.lua` 的行号；`tick_flow.lua` 同理。

- [ ] **Step 4：完整门禁 + 验收**

Run: `make verify && make acceptance`
Expected: 两者 PASS（`turn_flow` / `movement` / `endgame` 验收不回归；本重构观测行为零变化）。

- [ ] **Step 5：Commit**

```bash
git add src/turn/phases/land.lua src/turn/loop/tick_flow.lua
git commit -m "chore(turn): 刷新 land/tick_flow mutation manifest —— 反映 waits.blocking 收敛后 scope"
```

---

## 后续项（设计先行，非本计划步骤）—— ④-大：await/tick_steps 收编 + 跨层裸读统一

> **这一段不是可执行步骤，是给下一份 `writing-plans` / `codebase-design` 的范围与阻力清单。** 必须先过 `superpowers:brainstorming` + `superpowers:codebase-design`，再写 TDD 计划。以下是我探到的、该设计必须回答的约束（省下重新发现的功夫）：

**为什么 `await.lua:87` 不能简单委托 `blocking`：**
- `await._finish_choice_wait`（`:87-100`）只读**单个** `game.turn.action_anim` 决定是否 `_wait_for_choice_action_anim` 包一层，其 arg 形状是 `{next_state="wait_action_anim", next_args={next_state,next_args}}`——与 `blocking.next_wait_state` 的**多标志**（`action_anim_queue` + `landing_visual_hold` + `effect_idle`）判定集**不等价**。直接改走 blocking 会让 await 突然也 consult hold/effect_idle/queue → **行为变化**，须重设计参数化 interface 并补 mutation-pinned characterization（await.lua 现有 3 个 survived 变异 scope，对内部分支敏感）。

**为什么 `tick_steps.lua:42-51` 是另一个问题：**
- `_step_phase_animation` 按 `phase == "wait_move_anim"`/`"wait_action_anim"` gate 后读 `game.turn.move_anim`/`action_anim` **payload** 驱动 `turn_anim.step_*`。这是「停在此 wait 里有无 payload 可步进」，不是「进入哪个 wait」。若引入 `current_block` 消费，只能替换 phase-name 比较那半，payload 读仍在原地；且在 tick 热路径，收益/风险比需评估。

**为什么跨层裸读全量统一是架构题：**
- `game.turn.action_anim` 实测落 **11 文件 4 层**（`rules/effects/mine`、`rules/items/settlement`、`ui/render/status3d/status_signals`、`turn/policies` …），`popup_active` 落 **18 文件**。这些读**各为其用**（写 anim、门禁、渲染），不是同一个「回合被阻塞吗」领域问题。把它们统一到一个 module = 跨层 seam 设计（谁是真源、各层如何 adapter），踩 `ui/` + `rules/` + `policies/` 的密集测试面。属 ADR 0025 式的**领域 seam 设计**，不是机械收敛。

**与候选 ⑤ 的关系：** ④-大与候选 ⑤ 都改 `turn/waits/`（await/deadlines/pending choice），**执行 mutex**——设计阶段就应合并考虑「pending choice 生命周期」与「await 阻塞判定」是否共享一个 turn wait 深模块，避免两次撕扯同一批文件。

---

## Self-Review

**1. Spec 覆盖（评审 ④ 主张，逐条对账）：**
- ✅「一个 `waits.blocking` module，`current_block` + `next_wait_state`」→ Task 1 建成两个 interface，直测成为主测面。
- ✅「land 手搓 ~130 行组合路由收进一处」→ Task 2 删 `land:6-136` 路由子系统 + 折叠孪生 `_resolve_finished_landing_state`，land 降薄委托。
- ❌→纠正「`resolve_wait_state` 死导出、零 caller、可纯删」→ **证伪**：被 `land_resolve_spec`(25) + `phase_transitions_spec`(11) + `t2_cases`/`interrupts`(3) 共 36+ 断言钉死；本计划**保留** seam 只换实现（委托），不删除。已在「全貌与分期」表 + Task 4 Step 1 显式说明。
- ⚠️→降级「await/tick_steps/跨层裸读全量收编」→ **设计先行后续项**（附「await 单标志 vs land 多标志不等价」「tick_steps 是 payload 步进非路由」「跨层各为其用」三条证据），仅迁移 byte 等价的 `tick_flow.current_block`（Task 3）。
- ✅ deletion test（删 blocking → land/tick_flow 路由与停驻判定重新散落）→ Task 4 Step 1。

**2. Placeholder 扫描：** Task 1-4 每步给完整 old→new 代码块与精确命令+预期输出；Task 2 的 old 块对 `:6-136` 路由子系统用 `-- ...(略)` 仅因它与 Task 1 已给的 blocking.lua 逐字节相同（避免重复贴 130 行），new 块完整无省略。后续项明确标注「非可执行步骤、设计先行」。✅

**3. 类型/签名一致性：**
- `blocking.next_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)` 与被 pin 的 `land._resolve_wait_state` 签名逐字相同；land 两个导出直接指向它。✅
- `blocking.current_block(game) -> nil | {kind}` 在 Task 1 定义，Task 3 按 `block.kind == "landing_visual"` 消费。✅
- `_is_effect_idle` 捕获模式（load 时绑定稳定 dispatcher）逐字节照搬 land，`runtime_ports.configure` 测试注入仍生效。✅

**已知风险（handoff 要说）：**
1. **与候选 ⑤ 的 turn/waits 执行 mutex**（开头 flag）——同一 swarm stream 须串行其一。
2. `_resolve_finished_landing_state` 折叠（Task 2 Step 2 第 3 点）非直接单测命名、靠 turn_flow 场景套护，若红按行为保持第 3 点回退该 sub-step。
3. `land.lua` manifest stale → Task 4 刷新大 diff 属预期，勿误判为回归。
4. tick_flow 在热路径，Task 3 改动虽 byte 等价，Task 末必跑 `loop_runtime_spec` + turn_flow 场景。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-4-waits-blocking.md`.

本计划 = **候选 ④-安全（`waits.blocking` 深模块 + land 委托 + byte 等价迁移 tick_flow）**，完整可执行、零行为变化、保留全部 pinned seam。④-大（await/tick_steps 收编 + 跨层裸读统一）见上一节，**设计先行**，需 `brainstorming` + `codebase-design` 后另写。

⚠️ **执行前确认：候选 ④ 与候选 ⑤ 的 turn/waits 执行 mutex 已排序**（本 stream 只跑其一）。

两种执行方式：
**1. Subagent-Driven 并行（推荐）** — 先串行 Task 1（建模块）；合并后同一条消息 fan-out Task 2 + Task 3 两个 worktree-隔离 subagent 并行做，各自 gate + commit；合并后单跑 Task 4 barrier。见「并行执行编排」。
**2. Inline 顺序** — 本 session 用 `executing-plans`，1→2→3→4 顺序执行（面极小，成本近似；并行收益主要是并行 reviewer gate，非壁钟）。

选哪个？
