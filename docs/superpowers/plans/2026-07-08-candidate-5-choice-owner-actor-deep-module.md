# 候选⑤-核心 choice owner/actor 解析深模块 + 去 double-decide 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐 task 实施；**跨 task 并行**用 `superpowers:using-git-worktrees` 隔离（见「并行执行编排」）。步骤用 `- [ ]` 复选框跟踪。

**Goal:** 把散在 `turn/waits`·`turn/deadlines`·`turn/policies` 三层的 **3 份 owner 解析 + 2 份 actor 补全**收敛成单一 `src/turn/choice/owner.lua` 深模块，并消除 force-skip 超时路径上 `choice_auto_policy.decide(tick_timeout)` 的第二次冗余调用——**零生产行为变化**（唯一收敛点 = 非生产可达的 bogus/非整数 owner，已由 characterization 收口）。

**Architecture:** 新建 `src/turn/choice/owner.lua` 作为 pending-choice 的 owner/actor 唯一权威（`resolve_role_id` / `resolve_player` / `ensure_actor_role_id` 三动词）。`choice_dispatch`（waits）、`choice_auto`（policies）、`choice_ports`（deadlines）三处旧实现降为委托 shim。`choice_resolution.resolve_choice` 增可选 `precomputed_action` 入参，让 `choice_timeout` 把已算出的超时动作透传进来、跳过第二次 `decide`。owner.lua 落地后，三处委托**文件两两不相交**，在隔离 worktree 中并行执行 → 单一 barrier。

**Tech Stack:** Lua 5.4；busted（`spec/helper.lua` harness，`spec.support.shared_support` 的 `assert_eq`/`with_patches`）；git worktree 隔离；`make test`（behavior-smoke，迭代门禁）+ `make verify`（完整门禁）+ `make acceptance`（验收）。

## Global Constraints

- 命名 `snake_case`，类名 `CamelCase`（沿用仓库）。
- `src/` 禁用 `tonumber` / `type == "number"`；数值判定用 `NumberUtils`（`src.foundation.number`）。owner 归一沿用既有 `choice_contract.resolve_owner_role_id`（内部已走 `number_utils.to_integer`），本计划不新增数值判定。
- 不改 `EggyAPI.lua`、`tools/acceptance/generated/*`。
- **不得编辑**共享 spec-support（`spec/support/scenario_suites/shared/`、`spec/support/shared_support.lua`）或 `tools/`。若某 task 发现必须改，停下上报、退出并行、串行处理该项。
- **零生产行为变化**是本计划红线：唯一有意收敛（`choice_ports` 从 raw owner → 归一+存在性校验）经核证**非生产可达**（所有生产 owner 写入方都赋 live `player.id`），且由 Task 3 的 characterization 显式收口。任何触及生产可观测行为的红测 = 停。
- ADR-0019 barrier：`force_skip._refund_preconsume` 的「先退还→清 pending→advance」时序与退还调用点归属 `rules/items` **不得漂移**；`force_skip_refund_pin_spec` / `target_select_timeout_refunds_preconsume_spec` / `gentle_skip_no_penalty_spec` 全程保绿，本计划不触碰 preconsume。

---

## File Structure

| 文件 | 责任 | 由哪个 task 动 |
|---|---|---|
| `src/turn/choice/owner.lua` | **新建**。pending-choice owner/actor 唯一权威：`resolve_role_id`（→整数 id）、`resolve_player`（→player 对象）、`ensure_actor_role_id`（盖 action.actor_role_id）。 | Task 1（serial 前置） |
| `spec/behavior/turn/choice/owner_spec.lua` | **新建**。owner.lua 三动词的单元 pin。 | Task 1 |
| `src/turn/waits/choice_dispatch.lua` | `resolve_choice_owner_id` / `ensure_action_actor_role_id` 降为委托 owner.lua 的 shim（保导出名，供 `choice_timeout:109` 别名 + 现有 pin）。 | Task 2（fan-out A） |
| `src/turn/policies/choice_auto.lua` | `_resolve_choice_owner` 降为委托 `owner.resolve_player`；移除随之空转的 `choice_contract` require。 | Task 2（fan-out A） |
| `src/turn/deadlines/choice_ports.lua` | `ensure_actor_role_id` 委托 `owner.ensure_actor_role_id`；删空转私有 `_resolve_owner_actor_id` / `_resolve_current_player_actor_id`。 | Task 3（fan-out B） |
| `spec/behavior/turn/choice/ports_actor_convergence_spec.lua` | **新建**。收口 `choice_ports` actor 补全的**统一后**语义（归一+存在性校验）。 | Task 3（fan-out B） |
| `src/turn/deadlines/choice_resolution.lua` | `resolve_choice` 增可选 `precomputed_action`；`_dispatch_auto_or_fallback` / `_try_choice_auto` 顺延。 | Task 4（fan-out C） |
| `src/turn/waits/choice_timeout.lua` | `_maybe_resolve_timeout` 的 `:78` 透传 decide#1 结果给 `resolve_choice`。 | Task 4（fan-out C） |
| `spec/behavior/turn/choice/double_decide_spec.lua` | **新建**。pin force-skip 超时路径 `decide` 恰调 1 次 + 终态不变。 | Task 4（fan-out C） |

**为何 `spec/behavior/turn/choice/` 新目录：** 新 pin 聚在一处，与被收编的 `src/turn/choice/` 深模块对应；不碰现有 `waits_choice_*` / `deadlines/*` 目录里那些 structure-pin（各 fan-out task 只在自己文件面内改）。

---

## 并行执行 DAG

```
Task 1  owner.lua + owner_spec          （serial 前置，落 main）
            │  （3 处委托目标就位）
            ▼
   ┌────────┴─────────┬──────────────────┐
Task 2 (worktree A)  Task 3 (worktree B)  Task 4 (worktree C)
choice_dispatch      choice_ports         choice_resolution
+ choice_auto        actor 收敛           + choice_timeout
（行为中性抽取）      （唯一收敛点）        （去 double-decide）
   └────────┬─────────┴──────────────────┘
            ▼
        Barrier：merge A+B+C → make verify && make acceptance
            │
        Task 5  cohesion：删死码 + deletion-test + 终局门禁
```

- **Task 2/3/4 文件两两不相交**（见 File Structure 表）→ worktree 隔离并行、无文本冲突。
- 唯三共享**目录**（`turn/waits`、`turn/deadlines`）但**文件不相交**：A 动 `waits/choice_dispatch`，C 动 `waits/choice_timeout`；B 动 `deadlines/choice_ports`，C 动 `deadlines/choice_resolution`。
- **软耦合**：三者都 require `owner.lua`（只读依赖，Task 1 已冻结），无写争用。
- 保守退路：若不想开 worktree，可 Task 1→2→3→4→5 **纯串行**执行，每 task 后 `make verify` + commit，归因最清。

---

## Task 1：owner.lua 深模块（serial 前置）

**Files:**
- Create: `src/turn/choice/owner.lua`
- Test: `spec/behavior/turn/choice/owner_spec.lua`

**Interfaces:**
- Consumes: `src.config.choice.contract`（`resolve_owner_role_id(choice)`，已存在）。
- Produces（Task 2/3/4 依赖）：
  - `owner.resolve_role_id(game, choice) -> integer|nil` — 归一(contract)+`game:find_player_by_id` 校验→`player.id`；失败→索引式 current-player fallback `game.players[game.turn.current_player_index].id`。
  - `owner.resolve_player(game, choice) -> player|nil` — 同上但返回 player 对象；fallback 走方法式 `game:current_player()`，带 `game==nil` 守卫。
  - `owner.ensure_actor_role_id(game, choice, action) -> action` — nil-guard action、仅当 `actor_role_id==nil` 时用 `resolve_role_id` 盖入、返回 action。

- [ ] **Step 1：写失败测试**

`spec/behavior/turn/choice/owner_spec.lua`：

```lua
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local owner = require("src.turn.choice.owner")

describe("turn.choice.owner.resolve_role_id", function()
  it("resolves via find_player_by_id, not the current-player fallback", function()
    local game = {
      find_player_by_id = function(_, id) return { id = 700 + id } end,
      turn = { current_player_index = 1 },
      players = { { id = 11 } },
    }
    _assert_eq(owner.resolve_role_id(game, { owner_role_id = 7 }), 707,
      "a resolvable owner resolves through find_player_by_id")
  end)

  it("falls back to the current player id when find is absent", function()
    local game = {
      find_player_by_id = nil,
      turn = { current_player_index = 1 },
      players = { { id = 11 } },
    }
    _assert_eq(owner.resolve_role_id(game, { owner_role_id = 7 }), 11,
      "a missing find_player_by_id short-circuits to the current-player fallback")
  end)
end)

describe("turn.choice.owner.resolve_player", function()
  it("returns the found player object", function()
    local found = { id = 42 }
    local game = { find_player_by_id = function() return found end }
    assert(owner.resolve_player(game, { owner_role_id = 42 }) == found,
      "resolve_player returns the player object, not its id")
  end)

  it("falls back to game:current_player() via method call", function()
    local cur = { id = 9 }
    local game = { current_player = function() return cur end }
    assert(owner.resolve_player(game, {}) == cur,
      "no owner resolves through the current_player() method fallback")
  end)
end)

describe("turn.choice.owner.ensure_actor_role_id", function()
  it("returns a nil action untouched without resolving", function()
    assert(owner.ensure_actor_role_id({}, {}, nil) == nil, "a nil action is returned as-is")
  end)

  it("does not overwrite an already-set actor", function()
    local action = { actor_role_id = 3 }
    owner.ensure_actor_role_id({ find_player_by_id = function() return { id = 99 } end }, { owner_role_id = 1 }, action)
    _assert_eq(action.actor_role_id, 3, "a present actor_role_id is preserved")
  end)

  it("fills actor from the resolved owner id when absent", function()
    local action = {}
    local game = { find_player_by_id = function(_, id) return { id = id } end }
    owner.ensure_actor_role_id(game, { owner_role_id = 5 }, action)
    _assert_eq(action.actor_role_id, 5, "an absent actor is filled from resolve_role_id")
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted spec/behavior/turn/choice/owner_spec.lua`
Expected: FAIL —`module 'src.turn.choice.owner' not found`。

- [ ] **Step 3：写最小实现**

`src/turn/choice/owner.lua`：

```lua
-- pending-choice owner/actor 解析唯一权威。
-- 收编原 waits/choice_dispatch.resolve_choice_owner_id、
-- policies/choice_auto._resolve_choice_owner、deadlines/choice_ports 的
-- actor 补全三份散落实现——同一「这个 choice 归谁」问题只在此有一份答案。
local choice_contract = require("src.config.choice.contract")

local owner = {}

function owner.resolve_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player.id
    end
  end
  local current = game.turn and game.turn.current_player_index or nil
  local player = current and game.players and game.players[current] or nil
  return player and player.id or nil
end

function owner.resolve_player(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player
    end
  end
  if game and game.current_player then
    return game:current_player()
  end
  return nil
end

function owner.ensure_actor_role_id(game, choice, action)
  if not action or action.actor_role_id ~= nil then
    return action
  end
  local owner_id = owner.resolve_role_id(game, choice)
  if owner_id ~= nil then
    action.actor_role_id = owner_id
  end
  return action
end

return owner
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted spec/behavior/turn/choice/owner_spec.lua`
Expected: PASS（7 examples）。

- [ ] **Step 5：整仓门禁**

Run: `make test`
Expected: behavior-smoke 全绿（新模块无 caller，不改任何现有行为）。

- [ ] **Step 6：Commit**

```bash
git add src/turn/choice/owner.lua spec/behavior/turn/choice/owner_spec.lua
git commit -m "feat(turn/choice): 立 owner 深模块（resolve_role_id/resolve_player/ensure_actor_role_id）"
```

---

## Task 2：委托 choice_dispatch + choice_auto（fan-out A · 行为中性）

**Files:**
- Modify: `src/turn/waits/choice_dispatch.lua:5-27`
- Modify: `src/turn/policies/choice_auto.lua:2`（删 require）、`:9-21`（改 `_resolve_choice_owner`）
- Test: `spec/behavior/turn/waits_choice_dispatch_spec.lua`（现有 pin 保绿，无需改）

**Interfaces:**
- Consumes: `owner.resolve_role_id`、`owner.resolve_player`、`owner.ensure_actor_role_id`（Task 1）。
- Produces: `choice_dispatch.resolve_choice_owner_id` / `ensure_action_actor_role_id` 行为不变（转调 owner）；`choice_auto_policy.resolve_choice_owner` 导出不变。

> **本 task 零行为变化**：`choice_dispatch.resolve_choice_owner_id` 与 `owner.resolve_role_id` 逐行相同；`choice_auto._resolve_choice_owner` 与 `owner.resolve_player` 逐行相同。纯抽取。

- [ ] **Step 1：确认现有 pin 覆盖（不新增测试，先跑基线）**

Run: `busted spec/behavior/turn/waits_choice_dispatch_spec.lua`
Expected: PASS（现有 owner/ensure/dispatch 三组 pin 即本 task 的护栏）。

- [ ] **Step 2：改 `choice_dispatch.lua`——委托 owner**

把 `src/turn/waits/choice_dispatch.lua:1-27` 改为：

```lua
local owner = require("src.turn.choice.owner")

local choice_dispatch = {}

function choice_dispatch.resolve_choice_owner_id(game, choice)
  return owner.resolve_role_id(game, choice)
end

function choice_dispatch.ensure_action_actor_role_id(game, choice, action)
  return owner.ensure_actor_role_id(game, choice, action)
end
```

（`dispatch_choice_tick_action:29-38` 及以下 manifest 原样保留。）

- [ ] **Step 3：改 `choice_auto.lua`——委托 owner.resolve_player**

`src/turn/policies/choice_auto.lua:2` 删掉 `local choice_contract = require("src.config.choice.contract")`（本文件仅 `_resolve_choice_owner` 用它），改为 `local owner = require("src.turn.choice.owner")`。

`src/turn/policies/choice_auto.lua:9-21` 的 `_resolve_choice_owner` 改为：

```lua
local function _resolve_choice_owner(game, choice)
  return owner.resolve_player(game, choice)
end
```

（`choice_auto_policy.resolve_choice_owner = _resolve_choice_owner` 别名导出 `:122` 原样保留。）

- [ ] **Step 4：跑护栏 + 相关 policy 测试**

Run: `busted spec/behavior/turn/waits_choice_dispatch_spec.lua spec/behavior/turn/choice_timeout_spec.lua`
Expected: PASS（`_resolve_choice_owner_id` 别名、tick 派发 actor 盖章行为不变）。

- [ ] **Step 5：整仓门禁**

Run: `make test`
Expected: behavior-smoke 全绿。

- [ ] **Step 6：Commit**

```bash
git add src/turn/waits/choice_dispatch.lua src/turn/policies/choice_auto.lua
git commit -m "refactor(turn): choice_dispatch/choice_auto 的 owner 解析委托 owner 深模块（行为中性）"
```

---

## Task 3：委托 choice_ports actor 补全（fan-out B · 唯一收敛点）

**Files:**
- Modify: `src/turn/deadlines/choice_ports.lua:26-38`（删两私有 + 改 `ensure_actor_role_id`）
- Test: `spec/behavior/turn/choice/ports_actor_convergence_spec.lua`（新建）
- 护栏（仅补充 `find_player_by_id` mock，断言与意图不变）：`spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua`

**Interfaces:**
- Consumes: `owner.ensure_actor_role_id`（Task 1）。
- Produces: `choice_ports.ensure_actor_role_id(game, choice, action)` 语义 = 归一+存在性校验（原为 raw 字段）。返回契约仍为 void（`choice_resolution:47` 忽略返回值）。

> **本 task 是全计划唯一行为收敛点。** 旧 `choice_ports.ensure_actor_role_id` 用 raw `choice.owner_role_id`；改后走 `owner.resolve_role_id`（归一 + `find_player_by_id` 校验）。**生产等价**（所有生产 owner = live `player.id` 整数，raw==find 结果）；差异仅在 **bogus/非整数 owner**（非生产可达）：旧原样盖入、新跌落 current。核证详见对抗验证 owner-unify 判定（未找到生产反例）。故用 characterization 显式收口「统一后」语义。

- [ ] **Step 1：写收口测试（钉统一后语义）**

`spec/behavior/turn/choice/ports_actor_convergence_spec.lua`：

```lua
-- 收口 choice_ports actor 补全的【统一后】语义：归一 + 存在性校验。
-- 生产 owner(=live player.id 整数)下与旧 raw 行为逐值相等；差异仅在
-- 非生产可达的 bogus owner —— 见对抗核证 owner-unify（未找到生产反例）。
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local choice_ports = require("src.turn.deadlines.choice_ports")

describe("choice_ports.ensure_actor_role_id (unified via owner)", function()
  it("fills a production owner (live player id) unchanged", function()
    local game = { find_player_by_id = function(_, id) return { id = id } end }
    local action = { type = "choice_select" }
    choice_ports.ensure_actor_role_id(game, { owner_role_id = 42 }, action)
    _assert_eq(action.actor_role_id, 42, "a live owner id is filled unchanged")
  end)

  it("drops a bogus (non-existent) owner to the current player", function()
    -- 收敛点：旧 raw 会原样盖 999；统一后 find 失败 → 跌落 current。
    local game = {
      find_player_by_id = function() return nil end,
      turn = { current_player_index = 1 },
      players = { { id = 7 } },
    }
    local action = { type = "choice_select" }
    choice_ports.ensure_actor_role_id(game, { owner_role_id = 999 }, action)
    _assert_eq(action.actor_role_id, 7, "a bogus owner converges to the current player id")
  end)

  it("does not overwrite an already-set actor", function()
    local action = { type = "choice_select", actor_role_id = 3 }
    choice_ports.ensure_actor_role_id({}, { owner_role_id = 1 }, action)
    _assert_eq(action.actor_role_id, 3, "a present actor is preserved")
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted spec/behavior/turn/choice/ports_actor_convergence_spec.lua`
Expected: FAIL — 「drops a bogus owner」红：当前 raw 实现盖入 999，断言期望 7。

- [ ] **Step 3：改 `choice_ports.lua`——委托 owner + 删死码**

`src/turn/deadlines/choice_ports.lua:1` 后加 `local owner = require("src.turn.choice.owner")`。

删除 `_resolve_owner_actor_id`（:26-28）与 `_resolve_current_player_actor_id`（:30-33）两私有（收编进 owner 后无其它 caller）。

`ensure_actor_role_id`（:35-38）改为：

```lua
function choice_ports.ensure_actor_role_id(game, choice, action)
  owner.ensure_actor_role_id(game, choice, action)
end
```

（`is_action_dispatchable` / `_dispatch_to_game` / `dispatch_via_close_choice` 等原样保留——**dispatch 通路本计划不动**，见「范围外」。）

- [ ] **Step 4：跑收口测试 + 生产护栏**

Run: `busted spec/behavior/turn/choice/ports_actor_convergence_spec.lua spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua`
Expected: PASS —收口 3 例绿；`force_resolve_dispatch_spec`（owner=42→actor=42、无 owner→current=7）保绿证明生产等价。若护栏因 mock 缺少 `find_player_by_id` 而红，为其中带显式 `owner_role_id` 的 `game` mock 补充 `find_player_by_id = function(_, id) return { id = id } end`（仅补 mock 方法，不改断言）。

- [ ] **Step 5：整仓门禁**

Run: `make test`
Expected: behavior-smoke 全绿。**若 `deadlines/*` 或 scenario 红** → 说明有生产可达的非整数/bogus owner（与核证矛盾）→ 停、上报、退出并行。

- [ ] **Step 6：Commit**

```bash
# 包含 choice_ports manifest 刷新与 force_resolve_dispatch_spec 的 mock 补充
git add src/turn/deadlines/choice_ports.lua spec/behavior/turn/choice/ports_actor_convergence_spec.lua spec/behavior/turn/deadlines/force_resolve_dispatch_spec.lua
git commit -m "refactor(turn): choice_ports actor 补全委托 owner 深模块（归一+校验，bogus owner 收敛）"
```

> 注：commit 前用 `lua tools/quality/mutate.lua src/turn/deadlines/choice_ports.lua --update-manifest` 刷新删除死码后的 mutate4lua manifest。

---

## Task 4：去 double-decide（fan-out C）

**Files:**
- Modify: `src/turn/deadlines/choice_resolution.lua:30-38, 59-78`
- Modify: `src/turn/waits/choice_timeout.lua:77-78`
- Test: `spec/behavior/turn/choice/double_decide_spec.lua`（新建）
- 护栏（不改，保绿）：`spec/behavior/turn/tick_timeout_spec.lua`、`choice_timeout_spec.lua`

**Interfaces:**
- Consumes: 无新依赖。
- Produces: `api.resolve_choice(game, state, choice, reason, precomputed_action?)` — 末位新增可选 `precomputed_action`；非 nil 时跳过 `choice_auto_policy.decide(tick_timeout)`、直接用之。

> **本 task 零行为变化。** 到 `choice_timeout.lua:78` 时 decide#1 结果恒为 `choice_force_skip`（可派发者已在 `:71-75` 就地派发；`_dispatch_timeout_mode` 在 tick_timeout 模式从不返 nil）。透传该 force_skip 与 resolve_choice 内重算同一 force_skip 走同一 `_resolve_fallback_choice_action`→`fallback_registry`→`api.force_skip`，退款/modal/pending/事件时序不变；tick_timeout 模式 `decide` 不读 elapsed，故两次确定性相等。核证详见对抗验证 double-decide 判定（未找到反例）。

- [ ] **Step 1：写测试——decide 恰调一次 + 终态不变**

`spec/behavior/turn/choice/double_decide_spec.lua`：

```lua
-- pin：force-skip 超时路径把已算出的 action 透传给 resolve_choice，
-- choice_auto_policy.decide 恰调 1 次（非 2 次），终态仍走 force_skip。
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local deadlines = require("src.turn.deadlines")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

describe("resolve_choice precomputed_action passthrough", function()
  before_each(function() fallback_registry.reset() end)

  it("skips re-deciding when a precomputed force_skip is passed", function()
    local decide_calls = 0
    local state = {}
    runtime_state.ensure_all(state)
    local advanced = false
    local game = {
      players = { { id = 7 } },
      turn = { current_player_index = 1, pending_choice = nil },
      advance_turn = function() advanced = true end,
    }
    function game:dispatch_action() end
    local choice = { id = "c1", kind = "unregistered_kind", owner_role_id = 7, options = {} }

    _with_patches({
      { target = choice_auto_policy, key = "decide",
        value = function() decide_calls = decide_calls + 1
          return { type = "choice_force_skip", choice_id = "c1" } end },
    }, function()
      deadlines.resolve_choice(game, state, choice, "tick_timeout",
        { type = "choice_force_skip", choice_id = "c1" })
    end)

    _assert_eq(decide_calls, 0, "a precomputed action must skip choice_auto_policy.decide")
    assert(advanced == true, "an unresolved force_skip still advances the turn")
  end)

  it("still decides when no precomputed action is passed", function()
    local decide_calls = 0
    local state = {}
    runtime_state.ensure_all(state)
    local game = {
      players = { { id = 7 } },
      turn = { current_player_index = 1, pending_choice = nil },
      advance_turn = function() end,
    }
    function game:dispatch_action() end
    local choice = { id = "c2", kind = "unregistered_kind", owner_role_id = 7, options = {} }

    _with_patches({
      { target = choice_auto_policy, key = "decide",
        value = function() decide_calls = decide_calls + 1
          return { type = "choice_force_skip", choice_id = "c2" } end },
    }, function()
      deadlines.resolve_choice(game, state, choice, "tick_timeout")
    end)

    _assert_eq(decide_calls, 1, "without a precomputed action, decide is called once")
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted spec/behavior/turn/choice/double_decide_spec.lua`
Expected: FAIL —「skips re-deciding」红：现 `resolve_choice` 忽略第 5 参、内部仍调 `decide`（`decide_calls == 1`，期望 0）。

- [ ] **Step 3：改 `choice_resolution.lua`——透传 precomputed_action**

`src/turn/deadlines/choice_resolution.lua:30-38` 的 `_try_choice_auto` 改为：

```lua
local function _try_choice_auto(api, game, state, choice, precomputed_action)
  if precomputed_action ~= nil then
    return precomputed_action
  end
  local elapsed = _resolve_choice_elapsed(api, state, choice)
  return choice_auto_policy.decide(game, state, choice, {
    mode = "tick_timeout",
    elapsed_seconds = elapsed,
    min_visible_seconds = 0,
    allow_first_option_fallback = true,
  })
end
```

`:59-66` 的 `_dispatch_auto_or_fallback` 改为：

```lua
local function _dispatch_auto_or_fallback(api, game, state, choice, precomputed_action)
  local action = _try_choice_auto(api, game, state, choice, precomputed_action)
  if _dispatch_choice_action(game, state, choice, action) then
    return true
  end
  local fallback_action = _resolve_fallback_choice_action(game, choice, action)
  return _dispatch_choice_action(game, state, choice, fallback_action)
end
```

`:69-78` 的 `api.resolve_choice` 改为：

```lua
  function api.resolve_choice(game, state, choice, reason, precomputed_action)
    if type(choice) ~= "table" or choice.id == nil then
      api.force_skip(game, state, choice, reason or "no_choice")
      return
    end
    if _dispatch_auto_or_fallback(api, game, state, choice, precomputed_action) then
      return
    end
    api.force_skip(game, state, choice, reason or "tick_timeout")
  end
```

- [ ] **Step 4：改 `choice_timeout.lua`——`:78` 透传 decide#1 结果**

`src/turn/waits/choice_timeout.lua:77-78` 改为：

```lua
  output_ports.set_pending_choice_elapsed(state, 0)
  deadlines.resolve_choice(game, state, active_choice, "tick_timeout", action)
```

（`action` = `:70` 的 `opts.build_action(...)` 结果；到达 `:77` 时恒为 force_skip 或 nil，nil 时 `resolve_choice` 内 `precomputed_action==nil` 退回原重算路径，防御性等价。）

- [ ] **Step 5：跑新 pin + 超时护栏**

Run: `busted spec/behavior/turn/choice/double_decide_spec.lua spec/behavior/turn/tick_timeout_spec.lua spec/behavior/turn/choice_timeout_spec.lua`
Expected: PASS（decide 单调 + 现有超时/闭包 pin 不回归）。

- [ ] **Step 6：整仓门禁**

Run: `make test`
Expected: behavior-smoke 全绿。

- [ ] **Step 7：Commit**

```bash
git add src/turn/deadlines/choice_resolution.lua src/turn/waits/choice_timeout.lua spec/behavior/turn/choice/double_decide_spec.lua
git commit -m "refactor(turn): resolve_choice 透传 precomputed_action，去 force-skip 超时路径第二次 decide"
```

---

## Barrier：合并 fan-out A/B/C + 整仓门禁

> 若走 worktree 并行：三 worktree 全绿返回后，在主树合并。

- [ ] **Step 1：合并三分支（文件不相交，应无文本冲突）**

```bash
cd /Users/billyq/Dev/work/monopoly
git merge --no-ff arch/c5b-dispatch arch/c5b-ports arch/c5b-doubledecide \
  -m "merge: 候选⑤核心 —— owner 深模块委托 + choice_ports 收敛 + 去 double-decide"
```
Expected: 干净合并。若报冲突 → 停、核对 File Structure 表哪个文件被两 task 写。

- [ ] **Step 2：合并态整仓门禁**

Run: `make verify`
Expected: `[verify] PASS failed=0`。**若红**：多半是跨 task 语义交界（如 Task 3 收敛与 Task 4 透传对同一 force_skip 通路的 actor stamp）——按红测定位，回退最小一条改串行。

- [ ] **Step 3：合并态验收**

Run: `make acceptance`
Expected: `RESULT: N ok`（`turn_flow` / `market_cash` / choice 超时相关不回归）。

---

## Task 5：cohesion —— deletion-test + 终局门禁

**Files:** 无源码新增；确认 owner.lua 是唯一权威、死码已清、deletion-test 成立。

**Interfaces:** Consumes：Barrier 后的合并态。Produces：⑤-核心落地、`owner.lua` 深模块 deletion-test 成立。

- [ ] **Step 1：确认无残留私有 owner/actor 解析**

Run: `rg -n "owner_role_id" src/turn/waits/choice_dispatch.lua src/turn/deadlines/choice_ports.lua src/turn/policies/choice_auto.lua`
Expected: 三文件均**不再**含 owner 解析逻辑本体（只余对 `owner.*` 的委托）；`choice_ports` 无 `_resolve_owner_actor_id` / `_resolve_current_player_actor_id`。

- [ ] **Step 2：deletion-test（口头 + 结构核）**

删 `src/turn/choice/owner.lua` → `choice_dispatch`（waits）、`choice_ports`（deadlines）、`choice_auto`（policies）三层同时失去 owner/actor 解析、`require` 断链 → 复杂度在 3 个 caller 重新散落。deletion-test 成立：深模块挣得其位。

- [ ] **Step 3：终局整仓门禁 + 验收**

Run: `make verify && make acceptance`
Expected: 两者 PASS。

- [ ] **Step 4：Commit（若 Step 1 有清理动作；否则 Barrier merge 即产物）**

```bash
git add -A
git commit -m "chore(turn/choice): owner 深模块收编收尾 —— 清死码 + deletion-test 成立"
```

---

## 并行执行编排（worktree 隔离）

**前置（serial）：** Task 1 落 `main`（owner.lua 是三 fan-out 的共同只读依赖）。

- [ ] 从 Task 1 之后的 HEAD 建三 worktree：
```bash
cd /Users/billyq/Dev/work/monopoly
for s in c5b-dispatch c5b-ports c5b-doubledecide; do
  git worktree add ".worktrees/$s" -b "arch/$s"
done
```
- [ ] 分派三个 worktree-隔离 subagent（同一消息 fan-out）：
  - A → `.worktrees/c5b-dispatch`，执行 **Task 2**。
  - B → `.worktrees/c5b-ports`，执行 **Task 3**。
  - C → `.worktrees/c5b-doubledecide`，执行 **Task 4**。
  - 指令统一含：只在本 worktree 工作；每 task 结尾 `make verify` + `git commit`；**不得编辑** `spec/support/scenario_suites/shared/`、`spec/support/shared_support.lua`、`tools/`；发现须改则停、上报「需退出并行」。
- [ ] 三流全绿返回后走 **Barrier**；再走 **Task 5**；清 worktree：
```bash
for s in c5b-dispatch c5b-ports c5b-doubledecide; do git worktree remove ".worktrees/$s" && git branch -d "arch/$s"; done
```

> **与候选④执行互斥仍生效**：本计划与 `turn/waits/blocking`（④）共享 `turn/waits/` 目录。④ 未落地时本计划可独立跑；若与④同 swarm，`turn/waits/` 不可并发落 commit（④ 动 `blocking`/`await`，本计划动 `choice_dispatch`/`choice_timeout`——文件不相交但同目录，串其一稳妥）。

---

## 范围外（本计划有意不做 —— 均经调查/对抗核证移出）

- **dispatch 通路统一**（`choice_ports.dispatch_via_close_choice` 裸发 host vs tick 侧 `turn_dispatch` 路由）：**对抗核证 REFUTED（high）**——deadline 路会 auto 产出 `complete_optional_action_phase`，当前裸发 `game.dispatch_action`；收敛到单一 `turn_dispatch._dispatch_action` 底座会改走 `_handle_optional_action_completion`（gate/re-entrant/blocked 语义）= 生产行为变化。需先定「裸发 vs handler 路由」策略（policy 加 `raw_dispatch` 位或按 action.type 分流），**另立设计先行计划**，不在本计划。
- **④-A await 收编**：调查 merge_verdict = **SEPARATE**——await 的 choice-anim park（无回调、arg-unwrap resume 到 post-choice）与 blocking 的 choice 路线（注册回调、resume 回未解析 wait_choice）是状态机相反阶段。应为 `blocking.wait_for_active_action_anim` 窄委托的**独立小计划**（动 `await.lua`/`blocking.lua`，与本计划文件不相交，可另行并行）。
- **lifecycle 整体迁入 `src/turn/choice/`**（`resolve_choice`/`step_pending_choice` 从 deadlines/waits 搬家）：牵动 `deadlines`/`waits` install 接线 + ~12 pin，收益是聚合命名，本计划先只收 owner/actor 权威；迁家另立。
- **owner 收敛的产品确认**：`choice_ports` raw→归一 翻转 bogus/非整数 owner 行为——对抗核证判**非生产可达**（所有生产 owner=live `player.id`），本计划以 characterization 收口即可；若未来出现非整数 owner 生产写入方，需回看 validator_actor 是否依赖 raw 类型/值。
- **`validator_actor` 收编进 owner.lua**：**证伪——留独立**。`turn/actions/validator_actor._resolve_choice_owner_role_id` 是派发器的**独立校验闸**（`validator.validate` → `validate_choice_action`），刻意用 **raw 声明 owner**（不做存在性校验）比对入站 `actor_role_id`。此 raw 语义由 `validator_spec.lua:132-144`、`:297-317` 硬钉：这些 pin 传 **`game = {}`（空）+ 声明 `owner_role_id = 1001`**，断言「actor==声明 owner 通过 / 不等拒绝」。`owner.resolve_role_id`/`resolve_player` 依赖 `game.find_player_by_id` + index/method current fallback，空 game 下返回 `nil` → 校验被跳过 →「wrong owner is refused」翻绿（或 `.id` 崩）。委托 = 破 ~6 gate pin + 把闸从「比声明 owner」改成「比 game 解析 owner」= 削弱独立校验，**非行为中性**。故留独立；其 owner 读已走同一原语 `choice_contract.resolve_owner_role_id`。
- **`ui/ports/ui_sync/choice_state`、`ui/input/pre_confirm` 的 `_resolve_choice_owner_role_id`**：属 `src/ui/` 层（`pre_confirm` 取 `state` 非 `game`），与 `src/turn/choice/owner`（domain 层）跨清洁架构边界；本计划不收，另评是否值得引 domain 权威。

---

## 收尾修订（2026-07-08 · 执行后审查）

审查候选⑤落地结果，处理 CLAUDE 点名的两条「仍独立」owner/actor 解析路径。全景发现共 **5 份** `_resolve_choice_owner_role_id`-类实现（owner.lua 权威 + validator_actor + auto_runner + 2 个 UI 层），二者与 owner.lua **不在同一 domain**，采**混合**处置：

- **`auto_runner._resolve_choice_actor_role_id`（已改）**：view-model/env 域，原**裸读** `choice.owner_role_id`（绕过 `choice_contract`，无 `to_integer` 归一）。改为 `choice_contract.resolve_owner_role_id(choice)`，**保留 env fallback**（`env.current_player_id or env.current_player_index`——它拿的是 env 快照，无 `game`）。生产等价（所有 scenario owner=整数 `player.id`），仅归一非整数 owner（非生产可达）。护栏 `auto_runner_policies_spec`/`auto_runner_timeout_spec` + 全 smoke（3539 ok）保绿。
- **`validator_actor`（不改）**：见上「范围外」——独立校验闸，raw 声明 owner 语义被 pin 硬钉，委托非行为中性。留独立并记录理由。

---

## Self-Review

**1. 覆盖：** 调查设计备忘的 4 决策——owner-unify（Task 1-3）、double-decide（Task 4）已落；dispatch-path（REFUTED）、merge-4a（SEPARATE）显式移出范围。owner→actor→double-decide 的 gate 次序体现在 Task 1（前置）→2/3→4。✅

**2. Placeholder 扫描：** 每 task 给完整 old→new 代码块 + 精确 `busted`/`make` 命令 + 预期 red/green；无 TODO/TBD/「类似 Task N」。✅

**3. 类型一致：** `owner.resolve_role_id`/`resolve_player`/`ensure_actor_role_id` 三签名在 Task 1 定义，Task 2/3 引用一致；`resolve_choice(...,precomputed_action)` 在 Task 4 定义并同步 `choice_timeout:78` 调用点。`choice_ports.ensure_actor_role_id` 保 void 契约（`choice_resolution:47` 忽略返回值）。✅

**4. 并行安全：** Task 2/3/4 文件面（`choice_dispatch`+`choice_auto` / `choice_ports` / `choice_resolution`+`choice_timeout`）两两不相交，共享目录不共享文件；barrier 兜语义交界。✅

**已知局限（handoff 要说）：** ① 「零生产行为变化」依赖对抗核证的「bogus owner 非生产可达」结论——Task 3 Step 5 整仓门禁是该结论的兜底，红即证伪、停并上报；② 「文件不相交」保证无文本冲突不保证无语义交互，故 Barrier 的 `make verify` 不可省；③ 本计划只收 owner/actor + double-decide，⑤ 评审原标题的 dispatch 通路 / lifecycle 迁家为显式后续项。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-5-choice-owner-actor-deep-module.md`.

两种执行方式：

**1. Subagent-Driven（推荐）** — 先由主会话跑 **Task 1**（serial 前置，owner.lua 落 main），再 fan-out 3 个 worktree-隔离 subagent 跑 Task 2/3/4，barrier 由编排层合并 + 整仓门禁，收尾 Task 5。REQUIRED SUB-SKILL：`superpowers:subagent-driven-development` + `superpowers:using-git-worktrees`。

**2. Inline 串行** — 放弃并行，Task 1→2→3→4→Barrier→5 逐个执行，每 task 后 `make verify` + commit。慢但归因最清。REQUIRED SUB-SKILL：`superpowers:executing-plans`。

选哪个？（若选并行，我可先跑 Task 1，再起 Task 2/3/4 的三个 worktree-隔离 subagent。）
