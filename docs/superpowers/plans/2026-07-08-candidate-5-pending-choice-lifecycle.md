# 候选 ⑤ pending choice 生命周期 —— scope 分类孪生收敛计划（安全核心）+ 生命周期收编（设计先行）

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 执行。步骤用 `- [ ]` 复选框跟踪。**本计划的安全核心为并行编排：Task 1 是串行前置（建共享模块），Task 2 / 3 互不依赖、改两个不同文件、只只读消费 Task 1，可 fan-out 给两个 subagent；Task 4 是 barrier。** 见「并行执行编排」。

> **⚠️ 执行互斥（与候选 ④ waits.blocking）：** 本计划的安全核心 Task 2 改 `src/turn/waits/choice_tracking.lua`，与候选 ④（`turn/waits/blocking`）共享 `turn/waits/` 文件面；文末「设计先行」段更是重度改 `turn/waits/` + `turn/deadlines/`。**规划可并行，执行互斥**——④ 与 ⑤ 落在同一 swarm stream 时必须串行其一，不可同时对 `turn/waits/` 落 commit（避免 index/文本冲突）。

**Goal:** 把「pending choice 按 kind 落到一个 deadline scope 桶（`market_buy` / `choice`）」这段**字节级/语义等价、被复制 2 处**的分类，收敛到唯一的 `src/turn/deadlines/choice_scope.lua`——`turn/waits/choice_tracking._scope_for_choice` 与 `turn/deadlines/choice_resolution._choice_timeout_scope` 两个私有拷贝降为对它的委托并删除。

**Architecture:** 评审 ⑤ 的大标题是「一个 `choice` deep module 拥有整条生命周期（open→track→auto/timeout/force-skip→resolve→dispatch+close），interface `step_pending_choice` / `resolve_choice`」。**探源后，这个『大』半是架构级重写、且评审点名的 4 对『孪生』里只有 1 对真的字节等价**（详见「全貌与分期」的逐对核实）。本计划只完整展开那 1 对真孪生的收敛（零行为变化、可立即执行），其余 3 对孪生与生命周期收编作为**设计先行后续项**，附探源证据移交。

**Tech Stack:** Lua 5.4；busted（`spec/behavior/turn/` + `spec/behavior/turn/deadlines/`）；清洁架构七层，落在 `turn` 层的 `waits` / `deadlines` 两个 subdir。

## Global Constraints

- 命名 `snake_case`，类名 `CamelCase`；文件顶部一段中文 doc 注释说明「唯一归宿」职责。
- `src/` 禁用 `tonumber` / `type(x)=="number"`，用 `NumberUtils`（`src.foundation.number`）。本计划只搬 scope 字符串分类（读 `choice.kind`），不引入数字判定。
- **这是重构，观测行为零变化**：新 `choice_scope.for_choice` 与两处被删私有函数**逐点语义等价**（见 Task 2/3「行为保持」，已两两核对）。
- 门禁 `make verify`（本仓库 verify 即完整门禁，~7-8s）；每个 task 结尾跑。回合序列面广，**barrier task 另跑 deadline + tick 超时套**：`spec/behavior/turn/deadlines/*` 与 `spec/behavior/turn/choice_timeout_spec.lua`。
- 单文件 spec：`busted --run behavior spec/behavior/turn/<file>_spec.lua`。
- manifest 刷新只动文件尾注释块：`lua tools/quality/mutate.lua <file> --update-manifest`（barrier task 含此步）。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`（生成物）。

---

## 候选 ⑤ 全貌与分期（务必先读）

评审 ⑤ 主张：一个行为「等待中推进一个 pending choice」被切到 ~10 文件、跨 3 subdir（`waits`/`deadlines`/`policies`），切出 **4 对并行双胞胎**，应塌成一个拥有整条生命周期的 `choice` deep module。**逐对探源后，评审对『孪生』的判断半数不成立或配错了对**——这正是「评审常夸大」的典型。核实结果：

### 逐对核实（读了真实源码两两对比）

| # | 评审配的孪生对 | 真实情况（探源） | 处置 |
|---|---|---|---|
| **③ scope 分类** | `choice_tracking._scope_for_choice`（waits，5-10）vs `choice_resolution._choice_timeout_scope`（deadlines，10-12） | ✅ **真孪生，语义等价**。前者 `if c and c.kind=="market_buy" then return "market_buy" end; return "choice"`；后者 `return c and c.kind=="market_buy" and "market_buy" or "choice"`——同一真值表，逐点等价 | **安全核心（本计划 Task 1-4）** |
| **② owner 解析** | `choice_dispatch.resolve_choice_owner_id`（waits）vs `choice_ports._resolve_owner_actor_id`（deadlines） | ❌ **评审配错了对，且不等价**。`resolve_choice_owner_id` 走 `choice_contract.resolve_owner_role_id`（经 `number_utils.to_integer` 归一化）+ `find_player_by_id` 校验后返回 `player.id`；`_resolve_owner_actor_id` 只读**原始** `choice.owner_role_id`（无归一化、无存在性校验）。合并会**改变** choice_ports 行为。真正的近孪生是 `choice_dispatch.resolve_choice_owner_id` vs `choice_auto._resolve_choice_owner`（都走 contract+find），但二者仍差「返回 id vs 返回 player 对象」+ fallback 表达式（`turn.current_player_index` vs `game:current_player()`） | **设计先行**（需 characterization，非纯 dedup） |
| **① 补 actor role** | `choice_dispatch.ensure_action_actor_role_id`（waits）vs `choice_ports.ensure_actor_role_id`（deadlines） | ⚠️ **形近实异**。前者 `if not action or action.actor_role_id~=nil then return action end`（nil-guard action、有返回值），后者 `if action.actor_role_id~=nil then return end`（不 guard action、无返回值）；且底层各自调用不等价的 owner 解析（见 ②）。收敛依赖 ② 先统一 | **设计先行**（依赖 ②） |
| **④ dispatch+关 modal** | tick 的 `dispatch_choice_tick_action` → `opts.dispatch_action_with_close_choice`（= `timeout._dispatch_action_with_close_choice`）vs `choice_ports.dispatch_via_close_choice`（deadlines） | ⚠️ **两套不同机制**。tick 侧经 `turn_dispatch.dispatch_action(game,state,action,{on_close_choice=…})`（真 action dispatcher + modal 关闭回调）；deadline 侧是裸 `pcall(game.dispatch_action,…)` + 手动清 `turn.pending_choice` + 关 modal + 清 output。塌成一个 = 架构级统一 dispatch 通路 | **设计先行**（架构改造） |

### 「tick 路径与 deadline 路径各自跑一遍超时解析」核实

**真实存在，但不是两条独立复制，而是一条委托链。** `choice_timeout._maybe_resolve_timeout`（waits，63-79）在 `elapsed >= timeout` 时先 `opts.build_action(…, {mode="tick_timeout"})`（= `choice_auto_policy.decide` mode=tick_timeout）；若产出可派发动作则 tick 侧自己 dispatch+close；**若产出 nil 或 `choice_force_skip` 则委托 `deadlines.resolve_choice(game,state,choice,"tick_timeout")`**（choice_resolution.lua:78），后者又 `choice_auto_policy.decide(mode="tick_timeout")` 跑一遍（`_try_choice_auto`）。所以 force-skip 超时路径确实会 `decide(tick_timeout)` **两次**（第一次因 force_skip 被丢弃）。这是可优化的重复，但**收编它要触碰 ②①④ 的语义分歧**（owner 解析、dispatch 机制），属设计先行。

### 「resolve_choice / step_pending_choice 能否干净收编」核实

- 评审提议的 `resolve_choice(game, choice, reason)` **已经存在**：`deadlines.resolve_choice`（由 `choice_resolution.install` 装到 `M`，deadlines.lua:14）。签名多一个 `state`（`resolve_choice(game, state, choice, reason)`）。
- 评审提议的 `step_pending_choice(game, state, dt)` ≈ 现有 `tick_choice_timeout.step(game, state, dt, opts)`（choice_timeout.lua:81）。
- 即：deep module 的两个 interface **已各自散落存在于 deadlines / waits 两侧**，评审要的是把它们**合并进一个模块并去掉中段重复**。合并的中段（build action + 补 role + dispatch+close）正是 ②①④ 分歧所在，且踩着密集 pin 面（见下）。**这是架构收编，不是机械 dedup。**

### 分期结论

- **本计划 = ⑤-安全（scope 分类真孪生收敛，2 拷贝归 1）**，完整展开、可立即执行、零行为变化。
- **⑤-大（生命周期 deep module 收编 + ②①④ 三对孪生）= 设计先行后续项**，必须先过 `superpowers:brainstorming` + `superpowers:codebase-design`（先定 owner 解析归一、dispatch 通路统一两个语义决策），再写 TDD 计划。文末给出入口 + 我探到的约束 + pin 面清单，省下一位规划者重新发现。
- **ADR 关联**：`choice/item_preconsume_policy` 与 `items/settlement.lua` 注释里标的『step 4 收归令牌』进行中迁移，与本候选同向、是那条迁移的终点，**不必重开 ADR**（与 ADR 0019 一致）。安全核心不触碰 preconsume；⑤-大是那条迁移的落点，在设计先行段说明。

---

## ⑤-安全 文件结构

**新建（唯一归宿）：**
- `src/turn/deadlines/choice_scope.lua` — `for_choice(choice) -> "market_buy" | "choice"`。scope 名即 `deadlines.start/peek/cancel` 的 scope 键，故落在 `deadlines/` subdir。
- `spec/behavior/turn/choice_scope_spec.lua` — 模块直测，逐 kind 钉死（照 `waits_choice_tracking_spec.lua` 的「真值表 + mutation 注释」风格）。

**降为委托并删私有拷贝：**
- `src/turn/waits/choice_tracking.lua`：删私有 `_scope_for_choice`（5-10），`sync_deadline_for_choice` 内 `_scope_for_choice(active_choice)`（13）改 `choice_scope.for_choice(active_choice)`；顶部加 require。
- `src/turn/deadlines/choice_resolution.lua`：删私有 `_choice_timeout_scope`（10-12），`_resolve_choice_elapsed` 内 `_choice_timeout_scope(choice)`（26）改 `choice_scope.for_choice(choice)`；顶部加 require。

**护栏 spec（保持绿，勿改）：**
- `spec/behavior/turn/waits_choice_tracking_spec.lua`（`sync_deadline_for_choice` 的 market_buy/choice scope 选择、other-scope cancel、start guard——间接钉 `_scope_for_choice`）。
- `spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua`、`market_buy_60s_timeout_spec.lua`、`non_market_15s_timeout_spec.lua`（deadline resolve/超时路径——间接钉 `_choice_timeout_scope` 的 `api.peek(scope)`）。

**依赖无环确认：** `choice_scope.lua` 不 require 任何模块（叶子）。`choice_tracking` 已 require `src.turn.deadlines`；`choice_resolution` 已在 `deadlines/` 内——两者各加一行 require 叶子模块，不成环、不改 require 图形状。

---

## 并行执行编排

```
 Task 1  choice_scope.lua + spec   (串行前置：建共享模块，无 caller,行为中性)
        │
        ├─────────────┬─────────────┐  (fan out)
        ▼             ▼             │
   Task 2         Task 3           │
 choice_tracking  choice_resolution│
   (waits)         (deadlines)     │
        └─────────────┴────────────┘
                      ▼
              Task 4  barrier
   (合并后：deletion-test + 3 文件 manifest + 完整门禁 + 验收)
```

**为何 Task 2/3 可并行（冲突矩阵）：**

| | 改的文件 | 加的 require | 委托目标 | 消费别 task 产出? | 改的 manifest |
|---|---|---|---|---|---|
| Task 1 | 新建 `deadlines/choice_scope.lua` + 新 spec | 无 | — | 否 | choice_scope.lua 尾 |
| Task 2 | `waits/choice_tracking.lua` | `deadlines.choice_scope` | `for_choice(active_choice)` | **只读** Task 1 模块 | choice_tracking.lua 尾 |
| Task 3 | `deadlines/choice_resolution.lua` | `deadlines.choice_scope` | `for_choice(choice)` | **只读** Task 1 模块 | choice_resolution.lua 尾 |

- **Task 2/3 改两个不同源文件，零重叠写**；manifest 各在各文件尾，不冲突。
- 委托目标 `choice_scope.for_choice` 本计划建成后**不再改**，Task 2/3 均为只读依赖 → 无共享可变状态。
- **Task 1 是硬前置**（Task 2/3 都 require 它）：必须先落地并可 require，才 fan-out Task 2/3。

**swarm 分派方式：**
1. **先单独做 Task 1**（建 `choice_scope.lua` + spec，`make verify` 自证 + commit）。它无 caller、行为中性，独立成立。
2. Task 1 合并后，**同一条消息 fan-out Task 2 / Task 3**（各 `isolation: "worktree"`），各自委托 + 单文件 pin + `make verify` + commit。
3. 两者全绿后合并（不同文件，无文本冲突），**再单独跑 Task 4** barrier（deletion-test 复核、3 文件 manifest 刷新、完整门禁 + 验收）。manifest 必须在合并态做。

**诚实说明收益：** ⑤-安全只收敛**一对 3 行的真孪生**，面极小。并行的收益主要是「Task 2/3 两个 reviewer 并行 gate」，**不是壁钟时间**（单树顺序 1→2→3→4 成本几乎等同）。真正的『大』在设计先行段——那才需要独立规划与串行推进。

---

## Task 1：新建 choice_scope.for_choice（scope 分类唯一归宿）

**Files:**
- Create: `src/turn/deadlines/choice_scope.lua`
- Test: `spec/behavior/turn/choice_scope_spec.lua`

**Interfaces:**
- Produces（Task 2/3 依赖）：`choice_scope.for_choice(choice) -> "market_buy" | "choice"`。`choice.kind == "market_buy"` → `"market_buy"`；其余（含 `nil` choice、无 `kind`、其它 kind）→ `"choice"`。

- [ ] **Step 1：写失败测试**

创建 `spec/behavior/turn/choice_scope_spec.lua`：

```lua
-- src/turn/deadlines/choice_scope.lua 的直测。
-- for_choice 是 pending choice → deadline scope 桶的唯一分类点:
-- market_buy 落 "market_buy",其余一律 "choice"。逐 kind 钉死真值表,
-- 顶掉「market_buy->nil」「and->or」「返回串对调」等变异。
local choice_scope = require("src.turn.deadlines.choice_scope")

describe("turn.deadlines.choice_scope.for_choice", function()
  it("maps a market_buy choice to the market_buy scope", function()
    assert(choice_scope.for_choice({ kind = "market_buy" }) == "market_buy",
      "market_buy kind resolves the market_buy scope")
  end)

  it("maps any other kind to the choice scope", function()
    assert(choice_scope.for_choice({ kind = "normal" }) == "choice",
      "a non-market kind resolves the default choice scope")
  end)

  it("maps a choice without kind to the choice scope", function()
    assert(choice_scope.for_choice({}) == "choice",
      "a choice missing kind resolves the default choice scope")
  end)

  it("maps a nil choice to the choice scope without erroring", function()
    assert(choice_scope.for_choice(nil) == "choice",
      "a nil choice falls through to the default choice scope")
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted --run behavior spec/behavior/turn/choice_scope_spec.lua`
Expected: FAIL —`module 'src.turn.deadlines.choice_scope' not found`。

- [ ] **Step 3：写最小实现**

创建 `src/turn/deadlines/choice_scope.lua`：

```lua
-- choice 超时 deadline scope 分类:唯一归宿。
-- pending choice 按 kind 落到一个 deadline scope 桶:market_buy → "market_buy",
-- 其余(含 nil / 无 kind)→ "choice"。scope 名即 deadlines.start/peek/cancel 的
-- scope 键。原先 waits/choice_tracking._scope_for_choice 与
-- deadlines/choice_resolution._choice_timeout_scope 各写了一份字节级重复的
-- 同一分类,二者收敛到此。
local choice_scope = {}

function choice_scope.for_choice(choice)
  if choice and choice.kind == "market_buy" then
    return "market_buy"
  end
  return "choice"
end

return choice_scope
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted --run behavior spec/behavior/turn/choice_scope_spec.lua`
Expected: PASS（4 用例全绿）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS（新模块无 caller，全套行为 spec 保持绿）。

```bash
git add src/turn/deadlines/choice_scope.lua spec/behavior/turn/choice_scope_spec.lua
git commit -m "feat(turn): choice_scope.for_choice —— pending choice deadline scope 分类唯一归宿"
```

---

## Task 2：choice_tracking._scope_for_choice 委托 choice_scope 并删私有拷贝

**Files:**
- Modify: `src/turn/waits/choice_tracking.lua`（顶部 require + 删私有 `_scope_for_choice` + 改 `sync_deadline_for_choice` 调用点）
- Pin（保持绿）: `spec/behavior/turn/waits_choice_tracking_spec.lua`

**Interfaces:**
- Consumes: `choice_scope.for_choice`（Task 1）。
- Produces: `choice_tracking.sync_deadline_for_choice` / `sync_elapsed_choice_id` / `reset_choice_tracking` / `cancel_deadline_when_no_choice` 对外行为**不变**。

**行为保持：** 被删的 `_scope_for_choice(active_choice)`（choice_tracking.lua:5-10）= `if active_choice and active_choice.kind == "market_buy" then return "market_buy" end; return "choice"`，与 `choice_scope.for_choice`（Task 1）**逐字同构**。`sync_deadline_for_choice` 的下游（`other_scope` 取反、`is_active`/`cancel`/`start`）全不动，只把 scope 来源换成共享分类器。`waits_choice_tracking_spec.lua` 的 market_buy→market_buy scope、nil→choice scope、other-scope cancel 三组断言逐条继续成立。

- [ ] **Step 1：确认既有 pin 全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/turn/waits_choice_tracking_spec.lua`
Expected: PASS（含「market_buy choice arms the market_buy scope」「a nil active choice arms the choice scope」等断言）。

- [ ] **Step 2：加 require**

`src/turn/waits/choice_tracking.lua` 顶部，将：

```lua
local deadlines = require("src.turn.deadlines")

local choice_tracking = {}

local function _scope_for_choice(active_choice)
  if active_choice and active_choice.kind == "market_buy" then
    return "market_buy"
  end
  return "choice"
end
```

改为：

```lua
local deadlines = require("src.turn.deadlines")
local choice_scope = require("src.turn.deadlines.choice_scope")

local choice_tracking = {}
```

（私有 `_scope_for_choice` 整段删除。）

- [ ] **Step 3：调用点改委托**

在 `sync_deadline_for_choice` 内，将：

```lua
  local scope = _scope_for_choice(active_choice)
```

改为：

```lua
  local scope = choice_scope.for_choice(active_choice)
```

- [ ] **Step 4：跑 pin 确认保持绿**

Run: `busted --run behavior spec/behavior/turn/waits_choice_tracking_spec.lua`
Expected: PASS（scope 选择、other-scope cancel、start guard、id-change reset 全绿）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/waits/choice_tracking.lua
git commit -m "refactor(turn): choice_tracking scope 分类委托 choice_scope,删私有拷贝"
```

---

## Task 3：choice_resolution._choice_timeout_scope 委托 choice_scope 并删私有拷贝

**Files:**
- Modify: `src/turn/deadlines/choice_resolution.lua`（顶部 require + 删私有 `_choice_timeout_scope` + 改 `_resolve_choice_elapsed` 调用点）
- Pin（保持绿）: `spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua`、`spec/behavior/turn/deadlines/market_buy_60s_timeout_spec.lua`、`spec/behavior/turn/deadlines/non_market_15s_timeout_spec.lua`

**Interfaces:**
- Consumes: `choice_scope.for_choice`（Task 1）。
- Produces: `choice_resolution.install(api)` 装的 `api.resolve_choice` / `api.resolve_target_select` 行为**不变**。

**行为保持：** 被删的 `_choice_timeout_scope(choice)`（choice_resolution.lua:10-12）= `return choice and choice.kind == "market_buy" and "market_buy" or "choice"`——真值表与 `choice_scope.for_choice` **逐点等价**（choice 为 table 且 kind=="market_buy" → "market_buy"，否则 "choice"；`and/or` 短路与 `if` 分支同结果）。唯一调用点在 `_resolve_choice_elapsed` 的 `api.peek(state, _choice_timeout_scope(choice))`（26），换成 `choice_scope.for_choice(choice)` 后 `api.peek` 的 scope 键不变。resolve_choice 的 auto/fallback/force_skip 下游全不动。

- [ ] **Step 1：确认既有 pin 全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua spec/behavior/turn/deadlines/market_buy_60s_timeout_spec.lua spec/behavior/turn/deadlines/non_market_15s_timeout_spec.lua`
Expected: PASS（deadline resolve/超时路径基线）。

- [ ] **Step 2：加 require + 删私有**

`src/turn/deadlines/choice_resolution.lua` 顶部，将：

```lua
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local choice_ports = require("src.turn.deadlines.choice_ports")

local choice_resolution = {}

local function _choice_timeout_scope(choice)
  return choice and choice.kind == "market_buy" and "market_buy" or "choice"
end
```

改为：

```lua
local runtime_state = require("src.state.runtime")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local choice_ports = require("src.turn.deadlines.choice_ports")
local choice_scope = require("src.turn.deadlines.choice_scope")

local choice_resolution = {}
```

（私有 `_choice_timeout_scope` 整段删除。顶部两行注释 `-- Choice resolution deliberately avoids …` 保留不动。）

- [ ] **Step 3：调用点改委托**

在 `_resolve_choice_elapsed` 内，将：

```lua
  local entry_elapsed = _elapsed_from_entry(api.peek(state, _choice_timeout_scope(choice)))
```

改为：

```lua
  local entry_elapsed = _elapsed_from_entry(api.peek(state, choice_scope.for_choice(choice)))
```

- [ ] **Step 4：跑 pin 确认保持绿**

Run: `busted --run behavior spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua spec/behavior/turn/deadlines/market_buy_60s_timeout_spec.lua spec/behavior/turn/deadlines/non_market_15s_timeout_spec.lua`
Expected: PASS。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/turn/deadlines/choice_resolution.lua
git commit -m "refactor(turn): choice_resolution scope 分类委托 choice_scope,删私有拷贝"
```

---

## Task 4（barrier —— Task 1/2/3 全部合并后再执行）：deletion-test 复核 + manifest 刷新 + 完整门禁

**Files:**
- Modify（manifest 刷新）: `src/turn/deadlines/choice_scope.lua`、`src/turn/waits/choice_tracking.lua`、`src/turn/deadlines/choice_resolution.lua`
- 全仓验证

> **前置：Task 1/2/3 已合并进同一树。** 本 task 不可与前三者并行——manifest 刷新与完整门禁要在「共享模块 + 两处委托都在场」的合并态上做。

- [ ] **Step 1：deletion-test 复核（口头，非代码）**

删 `choice_scope.for_choice` → `choice_tracking.sync_deadline_for_choice` 与 `choice_resolution._resolve_choice_elapsed` 两处同时失去「pending choice → deadline scope 桶」分类。分类集中一处、非冗余。评审 ⑤『scope 分类字节级相同的双写』归零（2 → 1）。

- [ ] **Step 2：确认零残留拷贝**

Run: `grep -rn 'kind == "market_buy"' src/turn/ | grep -v manifest`
Expected: 只剩 `src/turn/deadlines/choice_scope.lua` 的唯一实现，以及**语义不同**的专用判定（如 timeout.lua 的 `scope_timeouts[kind]` 是 kind→秒数映射、非 scope 桶分类——保留）。`waits/choice_tracking.lua` 与 `deadlines/choice_resolution.lua` 里应**无** `kind == "market_buy"` 的 scope 分类残留。

- [ ] **Step 3：刷新三个文件的 mutation manifest**

Run:
```bash
lua tools/quality/mutate.lua src/turn/deadlines/choice_scope.lua --update-manifest
lua tools/quality/mutate.lua src/turn/waits/choice_tracking.lua --update-manifest
lua tools/quality/mutate.lua src/turn/deadlines/choice_resolution.lua --update-manifest
```
Expected: 三个 `manifest updated`（只动各文件底部 manifest 注释块）。核对：`git diff -U0 <file>` 的最早改动行号 > `grep -n "mutate4lua-manifest" <file>` 的行号。

- [ ] **Step 4：完整门禁 + deadline/tick 超时套 + 验收**

Run:
```bash
make verify
busted --run behavior spec/behavior/turn/deadlines spec/behavior/turn/choice_timeout_spec.lua spec/behavior/turn/tick_timeout_spec.lua
make acceptance
```
Expected: 三者 PASS（`turn_flow` / `movement` / `endgame` 验收不回归；本重构观测行为零变化）。

- [ ] **Step 5：Commit**

```bash
git add src/turn/deadlines/choice_scope.lua src/turn/waits/choice_tracking.lua src/turn/deadlines/choice_resolution.lua
git commit -m "chore(turn): 刷新 choice_scope/choice_tracking/choice_resolution mutation manifest"
```

---

## 后续项（设计先行，非本计划步骤）—— ⑤-大：pending choice 生命周期 deep module + ②①④ 孪生收编

> **这一段不是可执行步骤。** ⑤ 的大标题「一个 `choice` deep module 拥有整条生命周期、interface `step_pending_choice` / `resolve_choice`、两对 dispatch-and-close 塌成一个」是架构级改造，**必须先过 `superpowers:brainstorming` + `superpowers:codebase-design`**，再写 TDD 计划。以下是我探到的、该设计必须回答的约束与阻力（省下重新发现）：

**必须先定的两个语义决策（合并的真难点）：**
1. **owner 解析归一**：现存 3 个不完全等价的解析器——
   - `choice_dispatch.resolve_choice_owner_id`（contract 归一 + find 校验 → 返回 `player.id`，fallback `turn.current_player_index`）
   - `choice_auto._resolve_choice_owner`（contract 归一 + find 校验 → 返回 **player 对象**，fallback `game:current_player()`）
   - `choice_ports._resolve_owner_actor_id`（**原始** `choice.owner_role_id`，无归一、无校验，fallback `_resolve_current_player_actor_id`）
   合并需先决定统一语义（是否全部走 contract 归一 + find 校验？返回 id 还是对象？），并对 `choice_ports` 的**行为变化**做 characterization——它当前读原始字段，改走 contract 会引入 `number_utils.to_integer` 归一与 find 校验，可能改变 actor_role_id 结果。
2. **dispatch 通路统一**：tick 侧走 `turn_dispatch.dispatch_action(…, {on_close_choice})`，deadline 侧走裸 `pcall(game.dispatch_action)` + 手动清 pending/关 modal/清 output。deep module 若要「两对 dispatch-and-close 塌成一个」，须先定统一走哪条通路，并保证 force-skip 退还（`force_skip._refund_preconsume`）、`_clear_game_pending_choice` 的幂等清理、modal 关闭回调在合并后逐点保留。

**deep module 要交付的（建议 brainstorm 产出）：**
- 一个 `choice` 模块拥有：open→track（现 `choice_tracking` + `choice_ui_sync`）→ auto/timeout（现 `choice_auto_policy.decide` 的 mode 分派）→ force-skip（现 `deadlines/force_skip`）→ resolve（现 `deadlines/choice_resolution`）→ dispatch+close（②①④ 统一后的单一通路）。
- 去掉 tick `_maybe_resolve_timeout` → `deadlines.resolve_choice` 委托链上 `decide(mode=tick_timeout)` 的**两次调用**（force-skip 超时路径当前跑两遍）。
- `step_pending_choice(game, state, dt)` / `resolve_choice(game, state, choice, reason)` 作为对外两个 interface（后者已存在于 `deadlines`，前者 ≈ `tick_choice_timeout.step`）。

**迁移面 / pin 阻力（改内部通路 = 大面积 spec）：**
- `spec/behavior/turn/waits_choice_dispatch_spec.lua`（直接钉 `resolve_choice_owner_id` 的 find/fallback、`ensure_action_actor_role_id` 的 nil-guard、`dispatch_choice_tick_action` 返回契约）
- `spec/behavior/turn/waits_choice_tracking_spec.lua`、`choice_timeout_spec.lua`、`tick_timeout_spec.lua`、`timeout_closure_spec.lua`
- `spec/behavior/turn/deadlines/*`（`force_resolve_dispatch`、`market_buy_60s_timeout`、`non_market_15s_timeout`、`force_skip_refund_pin`、`gentle_skip_no_penalty`、`target_select_timeout_refunds_preconsume`、`force_resolve_no_cancel_no_fallback`、`choice_wait_coroutine_resumes_via_force_skip` 等约 12 个直钉 deadline resolve/force-skip 契约的 spec）
- `spec/behavior/scenarios/deadlines/all_human_no_input_full_game_spec.lua`（整局无输入超时序列）

**与 ADR 关联：** ⑤-大是 `item_preconsume_policy` / `items/settlement.lua` 注释里『step 4 收归令牌』进行中迁移的终点（与 ADR 0019 同向）——force-skip 退还（`force_skip._refund_preconsume`）与 preconsume 结算的收编在此定稿，**不必重开 ADR**，但设计时须把退还时机纳入统一 dispatch/force-skip 通路。

**与 ④ 的关系：** ⑤-大重度改 `turn/waits/` + `turn/deadlines/`，与候选 ④（`turn/waits/blocking`）**执行强互斥**，须同一 swarm stream 串行。

---

## Self-Review（写完对着评审复核）

**1. Spec 覆盖（评审 ⑤ 的每对孪生主张）：**
- ✅ 孪生③「scope 分类字节级相同的双写」→ Task 1 建 `choice_scope.for_choice`，Task 2/3 两处委托 + 删私有，2 拷贝归 1，deletion-test（Task 4 Step 1）复核。
- ⏭ 孪生②「两个 owner 解析」→ **显式移交设计先行**，并**纠正评审配错的对**（真近孪生是 dispatch vs auto，非 dispatch vs ports；ports 是不等价的原始字段变体，合并会改行为）。附证据。
- ⏭ 孪生①「两个补 actor role」→ 设计先行（形近实异：nil-guard/返回值/底层 owner 解析均不同，依赖②先统一）。附证据。
- ⏭ 孪生④「两条 dispatch+关 modal」→ 设计先行（turn_dispatch vs 裸 game.dispatch_action，架构级通路统一）。附证据。
- ⏭「tick / deadline 各跑一遍超时解析」→ 核实为委托链上的 `decide(tick_timeout)` 双调用；收编它触碰②①④，设计先行。附证据。
- ⏭「resolve_choice / step_pending_choice deep module」→ 核实二者已散落存在（`deadlines.resolve_choice` / `tick_choice_timeout.step`）；合并即架构收编，设计先行。附 pin 面清单。

**2. Placeholder 扫描：** ⑤-安全每步给完整 old→new 代码块与预期输出；设计先行段明确标注「非可执行步骤、设计先行」，不伪装成步骤。✅

**3. 类型/签名一致性：**
- `choice_scope.for_choice(choice) -> "market_buy"|"choice"` 在 Task 1 定义，Task 2（`for_choice(active_choice)`）/ Task 3（`for_choice(choice)`）调用签名一致。✅
- 两处被删私有的真值表与新分类器逐点核对等价（Task 2/3「行为保持」）。✅
- 新模块落 `deadlines/` subdir——scope 名是 deadline scope 键，且 `choice_tracking` 已依赖 `src.turn.deadlines`、`choice_resolution` 本在 `deadlines/`，无新跨层边、无环。✅

**已知风险（handoff 要说）：** ① Task 1 是硬前置，Task 2/3 必须等它可 require 才 fan-out；② Task 2 改 `turn/waits/choice_tracking.lua`，与候选 ④ 执行互斥——同 stream 勿并发 commit `turn/waits/`；③ ⑤-大是设计题不是计划题，勿从本计划 schematic 直接开写 deep module——先定 owner 归一 + dispatch 通路两个语义决策；④ Task 4 Step 2 的 grep 会命中 timeout.lua 的 `scope_timeouts[kind]`（语义不同，保留），别误删。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-5-pending-choice-lifecycle.md`.

本计划 = **候选 ⑤-安全（scope 分类真孪生收敛，2 拷贝归 1）**，完整可执行、零行为变化。⑤-大（生命周期 deep module 收编 + ②①④ 三对孪生）见上一节，**设计先行**，需 `brainstorming` + `codebase-design` 后另写。

**执行互斥提醒：** 与候选 ④（waits.blocking）共享 `turn/waits/`——规划可并行，执行须串行其一。

两种执行方式：
**1. Subagent-Driven 并行（推荐）** — Task 1 先单独做并合并；Task 2/3 同一条消息 fan-out 两个 worktree-隔离 subagent 并行做，各自 gate + commit；合并后单跑 Task 4 barrier。见「并行执行编排」。
**2. Inline 顺序** — 本 session 用 `executing-plans`，1→2→3→4 顺序执行（面极小，成本近似）。

选哪个？
