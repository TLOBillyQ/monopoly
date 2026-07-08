# 候选 ② Phase 2 —— 抽出 purchase_settlement、去 finish_choice 泄漏、统一 auto

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐 task 执行。步骤用 `- [ ]` 复选框跟踪。按编号顺序执行——task 间有真实文件依赖。**前置：Phase 1（`purchase_result.canonicalize`，见 `2026-07-08-candidate-2-purchase-settlement.md`）必须已 merge。**

**Goal:** 把购买结算解释者从 `rules/market/choice.lua` 的 `outcome` 表抽成独立深模块 `rules/market/purchase_settlement.lua`，interface 改为**返回结构化 verdict `{ keep_open = bool }`、不再接收 `finish_choice`**——`finish_choice` 就此只留在 `choice_handlers/market.lua` 这一个 adapter，停止内泄进 market 深模块。同时把 `auto.execute` 接上同一解释者，AI 与人类穿同一 `purchase_settlement`。

**Architecture:** `purchase_settlement.resolve(game, choice, player, entry, result) -> { keep_open }` 承接现 `resolve_purchase` 的全部判定（canonicalize → keep-open / failure-stay / intent 分发），把两处 `finish_choice(game,false)` 收尾改为 `{ keep_open = false }`、`{stay=true}` 改为 `{ keep_open = true }`。副作用（`session.rebuild_pending`、`feedback.emit_inventory_full`、`intent_output.open_choice/push_popup`）**全部留在深模块内**；只有「把 verdict 翻成 choice 框架的 `{stay=true}` / `finish_choice(game,false)`」这一步留在 adapter。`purchase_settlement` 单向 require `choice`（取 `session`/`feedback` 卫星）+ `intent_output` + `purchase_result`——已核对 `choice.lua` 不 require 本模块，无环。

**Tech Stack:** Lua 5.4；busted；清洁架构七层，模块落在 `rules/market`。

## Global Constraints

- 命名 `snake_case`；`purchase_settlement.lua` 顶部中文 doc 注释说明「唯一解释者、返回 verdict、不吃 finish_choice」职责（照抄 `src/rules/items/settlement.lua:1-5` 风格）。
- `src/` 禁用 `tonumber` / `type(x)=="number"`；用 `NumberUtils`。
- **这是重构，人类购买路径观测行为零变化**；AI 路径行为**近乎**零变化（见 Task 3 的行为保持说明——AI 无 pending market modal，走解释者是 no-op）。
- verdict 契约必须覆盖既有全部分支，逐点对齐 Phase 1 保留的 `market_choice_outcome_spec` 十个用例（本计划把它们迁到新模块的 verdict 形态）。
- 门禁 `make verify`（本仓库 verify 即完整门禁，~7-8s）；每个 task 结尾跑。
- 单文件 spec：`busted --run behavior spec/behavior/rules/<file>_spec.lua`。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`、`purchase.execute` 的返回形状（`market_purchase_spec` 仍钉着它）。

---

## 决策记录（Phase 1 遗留的 3 个决策点，本计划取定）

| 决策点 | 取定 | 理由 |
|---|---|---|
| **intent 分发路径去留** | **保留**（随解释者迁入 `purchase_settlement`，不删） | 生产中 dead 但被变异存活专测钉活；删它要连带删 spec 并需产品确认扩展点无未来用途——超出「去泄漏」目标，另案处理 |
| **auto 统一的收益** | **做**（route through settlement） | 评审明列「AI 与人类穿同一解释者」；AI 无 pending modal，行为近乎零变化，风险低、结构收敛真实 |
| **verdict 契约** | `{ keep_open = boolean }` | 最小充分：`true`→adapter 返 `{stay=true}`；`false`→adapter 返 `finish_choice(game,false)`。既有「keep-open 但 rebuild 失败 → finish」由深模块内部 rebuild 失败时返 `keep_open=false` 表达 |
| **旧 `outcome` 表 + 944 行 spec** | **迁移并删除**（不留长期 shim） | 留 shim = 测试测的是 scaffolding 而非真模块；迁移是机械统一变换，Task 4 给 recipe + 代表样例 |

---

## Phase 2 文件结构

**新建：**
- `src/rules/market/purchase_settlement.lua` — 唯一解释者，`resolve(...) -> {keep_open}`。承接 `choice.lua` 现 `outcome` 全部逻辑 + 4 helper + intent 分发。
- `spec/behavior/rules/market/purchase_settlement_spec.lua` — verdict 契约直测（把 `market_choice_outcome_spec` 十个用例迁成 `verdict.keep_open` 形态 + 副作用断言）。

**改：**
- `src/rules/market/choice.lua` — 删 `outcome` 表 + 其 4 个 local helper + `_dispatch_intent`/`_INTENT_HANDLERS`（迁往新模块）；`return { ... }` 去掉 `outcome`。`session`/`feedback`/`builder` 保留（新模块的卫星）。
- `src/rules/choice_handlers/market.lua` — `_handle_market_buy` 降为 adapter：调 `purchase_settlement.resolve`，翻 verdict → `{stay=true}` / `finish_choice(game,false)`。`finish_choice` 留在此处。
- `src/rules/market/auto.lua` — `auto.execute` 尾段接上 `purchase_settlement.resolve`。

**迁移/删除（944 行，Task 4）：**
- `spec/behavior/rules/market_choice_outcome_spec.lua`（238）→ 大部分迁入新 `purchase_settlement_spec`，删原文件或留纯 builder/session 部分
- `spec/behavior/rules/market_choice_extra_survivors_spec.lua`（514）→ 变异存活专测，签名机械迁移
- `spec/behavior/rules/market_choice_residual_closure_spec.lua`（192）→ 同上

---

## Task 1：新建 purchase_settlement.resolve（返回 verdict，不吃 finish_choice）

**Files:**
- Create: `src/rules/market/purchase_settlement.lua`
- Test: `spec/behavior/rules/market/purchase_settlement_spec.lua`

**Interfaces:**
- Consumes: `purchase_result.canonicalize`（Phase 1）、`choice.session`/`choice.feedback`、`intent_output`。
- Produces: `purchase_settlement.resolve(game, choice, player, entry, result) -> { keep_open = boolean }`
  - `keep_open=true`：deferred / item-fulfilled / failure+rebuild-ok / need_choice-intent
  - `keep_open=false`：非 item fulfilled / failure+rebuild-fail / keep-open-but-rebuild-fail / 无 intent 收尾 / 非表
  - 副作用（rebuild、emit_inventory_full、dispatch intent）在内部完成。

**行为保持：** 逐点等价于 Phase 1 后的 `outcome.resolve_purchase`，仅把返回从「`{stay}` / `finish_choice(game,false)`」换成「`{keep_open=true}` / `{keep_open=false}`」，并删去 `finish_choice` 形参与「nil finish_choice 必 raise」不变量（该 assert 移出深模块——adapter 侧 `finish_choice` 恒为框架注入的函数，无需运行时校验；Task 2 的 adapter 直接调用）。

- [ ] **Step 1：写失败测试（verdict 契约，含副作用）**

创建 `spec/behavior/rules/market/purchase_settlement_spec.lua`（沿用 `market_choice_outcome_spec` 的 `_reload_module` + overrides 手法，但目标模块换成 `purchase_settlement`，断言换成 `verdict.keep_open`）：

```lua
-- purchase_settlement.resolve verdict 契约直测。
-- 由 market_choice_outcome_spec 十用例迁来:{stay}/finish_called → keep_open true/false。
local function _with_modules(overrides, fn)
  local saved = {}
  for key, value in pairs(overrides) do
    saved[key] = package.loaded[key]
    package.loaded[key] = value
  end
  for _, key in ipairs({ "src.rules.market.choice", "src.rules.market.purchase_settlement" }) do
    saved[key] = saved[key] or package.loaded[key]
    package.loaded[key] = nil
  end
  local ok, result = pcall(function()
    local choice = require("src.rules.market.choice")
    return fn(require("src.rules.market.purchase_settlement"), choice)
  end)
  for key, value in pairs(saved) do package.loaded[key] = value end
  if not ok then error(result, 2) end
  return result
end

local function _base_overrides()
  return {
    ["src.rules.market.query"] = {
      context = {
        entry_by_id = function() return nil end, entry_currency = function() return "金币" end,
        entry_market_enabled = function() return true end, entry_name = function() return "item" end,
        entry_price = function() return 100 end,
      },
      eligibility = {
        sorted_entries = function() return {} end, can_buy_entry = function() return false end,
        is_sold_out = function() return false end,
      },
    },
    ["src.config.choice.contract"] = { resolve_owner_role_id = function(c) return c.owner_role_id end },
    ["src.rules.ports.intent_output"] = { open_choice = function() return {} end, push_popup = function() return true end },
    ["src.state.dirty_tracker"] = { mark = function() end },
  }
end

local function _game() return { dirty = {}, turn = {} } end
local function _choice() return { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 } end
local function _player() return { id = 1, name = "Alice" } end
local function _entry(kind) return { kind = kind or "item", product_id = 101 } end
local function _rebuildable(choice)
  choice.builder.build = function()
    return { title="T", body_lines={}, options={{}}, allow_cancel=true, cancel_label="X",
             active_tab="item", page_index=1, page_count=1, owner_role_id=1, meta={} }
  end
end

describe("market purchase_settlement.resolve", function()
  it("deferred fulfillment keeps market open", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = true, deferred_fulfillment = true })
      assert(v.keep_open == true, "deferred should keep open")
    end)
  end)

  it("item fulfilled_now keeps market open", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = true, fulfilled_now = true })
      assert(v.keep_open == true, "item fulfilled should keep open")
    end)
  end)

  it("non-item fulfilled_now does not keep open", function()
    _with_modules(_base_overrides(), function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("non_item"), { ok = true, fulfilled_now = true })
      assert(v.keep_open == false, "non-item fulfilled should not keep open")
    end)
  end)

  it("item fulfilled with full inventory emits feedback and keeps open", function()
    local emitted = false
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      choice.feedback.emit_inventory_full = function() emitted = true end
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"),
        { ok = true, fulfilled_now = true, inventory_full_after = true })
      assert(v.keep_open == true, "should keep open")
      assert(emitted, "should emit inventory full feedback")
    end)
  end)

  it("failure keeps open when rebuild succeeds", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      _rebuildable(choice)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = false, reason = "not_enough_coins" })
      assert(v.keep_open == true, "failure + rebuild should keep open")
    end)
  end)

  it("failure does not keep open when rebuild fails", function()
    _with_modules(_base_overrides(), function(settlement, choice)
      choice.builder.build = function() return nil end
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = false })
      assert(v.keep_open == false, "failure + failed rebuild should not keep open")
    end)
  end)

  it("need_choice intent dispatches open_choice and keeps open", function()
    local opened = false
    local overrides = _base_overrides()
    overrides["src.rules.ports.intent_output"] = {
      open_choice = function(_, spec) opened = true; return spec end,
      push_popup = function() return true end,
    }
    _with_modules(overrides, function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"),
        { ok = nil, intent = { kind = "need_choice", choice_spec = { kind = "sub" } } })
      assert(v.keep_open == true, "need_choice intent should keep open")
      assert(opened, "should dispatch open_choice")
    end)
  end)

  it("no intent does not keep open", function()
    _with_modules(_base_overrides(), function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), { ok = nil })
      assert(v.keep_open == false, "no intent should not keep open")
    end)
  end)

  it("non-table result does not keep open", function()
    _with_modules(_base_overrides(), function(settlement)
      local v = settlement.resolve(_game(), _choice(), _player(), _entry("item"), "some_string")
      assert(v.keep_open == false, "non-table should not keep open")
    end)
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted --run behavior spec/behavior/rules/market/purchase_settlement_spec.lua`
Expected: FAIL —`module 'src.rules.market.purchase_settlement' not found`。

- [ ] **Step 3：写实现（把 choice.lua 的 outcome 逻辑迁入，finish_choice → verdict）**

创建 `src/rules/market/purchase_settlement.lua`：

```lua
-- 商店购买结算的唯一解释者:一次购买结果 → 一个结构化 verdict { keep_open }。
-- 承接原 choice.outcome.resolve_purchase 的全部判定(经 purchase_result 收敛后
-- 读 canonical status),但不再接收 choice 层的 finish_choice——收尾与否只由
-- verdict.keep_open 表达,由 choice_handlers/market adapter 翻成框架的
-- {stay=true} / finish_choice(game,false)。副作用(rebuild、inventory_full、
-- intent 分发)全部收敛在此;finish_choice 泄漏就此消失。
-- 单向依赖 choice(session/feedback 卫星),choice 不 require 本模块,无环。
local choice = require("src.rules.market.choice")
local purchase_result = require("src.rules.market.purchase_result")
local intent_output_port = require("src.rules.ports.intent_output")

local session = choice.session
local feedback = choice.feedback

local purchase_settlement = {}

local _INTENT_HANDLERS = {
  need_choice = function(game, intent)
    if intent.choice_spec == nil then return false end
    return intent_output_port.open_choice(game, intent.choice_spec, intent.opts) ~= nil
  end,
  push_popup = function(game, intent)
    if intent.payload == nil then return false end
    return intent_output_port.push_popup(game, intent.payload, intent.popup_opts or intent.opts) == true
  end,
}

local function _dispatch_intent(game, intent)
  if type(intent) ~= "table" then return false end
  local handler = _INTENT_HANDLERS[intent.kind]
  if not handler then return false end
  return handler(game, intent)
end

local function _is_purchase_failure(canonical)
  return canonical.status == "rejected"
end

local function _should_keep_market_open(entry, canonical)
  if canonical.status == "deferred" then
    return true
  end
  return entry and entry.kind == "item" and canonical.status == "fulfilled"
end

local function _handle_keep_open(game, choice_state, player, entry, canonical)
  local rebuilt = session.rebuild_pending(game, choice_state, player)
  if not rebuilt then return { keep_open = false } end
  local full_buy = entry and entry.kind == "item"
    and canonical.status == "fulfilled" and canonical.inventory_full_after == true
  if full_buy then feedback.emit_inventory_full(player, entry) end
  return { keep_open = true }
end

local function _try_failure_stay(game, choice_state, player, canonical)
  if not _is_purchase_failure(canonical) then return false end
  return not not session.rebuild_pending(game, choice_state, player)
end

local function _dispatch_and_finish(game, result)
  if type(result) == "table" then
    local intent = result.intent or {}
    _dispatch_intent(game, intent)
    if intent.kind == "need_choice" then return { keep_open = true } end
  end
  return { keep_open = false }
end

function purchase_settlement.resolve(game, choice_state, player, entry, result)
  local canonical = purchase_result.canonicalize(result)
  if _should_keep_market_open(entry, canonical) then
    return _handle_keep_open(game, choice_state, player, entry, canonical)
  end
  if _try_failure_stay(game, choice_state, player, canonical) then return { keep_open = true } end
  return _dispatch_and_finish(game, result)
end

return purchase_settlement
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted --run behavior spec/behavior/rules/market/purchase_settlement_spec.lua`
Expected: PASS（9 用例全绿）。

> 此时 `choice.lua` 的 `outcome` 表仍在（尚未删），旧 944 行 spec 仍绿——新旧并存，无冲突。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/rules/market/purchase_settlement.lua spec/behavior/rules/market/purchase_settlement_spec.lua
git commit -m "feat(market): purchase_settlement.resolve —— 返回 verdict 的唯一解释者(不吃 finish_choice)"
```

---

## Task 2：production adapter 切到 purchase_settlement，finish_choice 收回 adapter

**Files:**
- Modify: `src/rules/choice_handlers/market.lua`（require + `_handle_market_buy`）
- Pin: `spec/behavior/rules/market_choice_session_spec.lua`、`market_purchase_spec.lua`（人类购买整链保持绿）

**Interfaces:**
- Consumes: `purchase_settlement.resolve`（Task 1）。
- Produces: `_handle_market_buy` 返回契约不变（`{stay=true}` 或 `finish_choice(game,false)` 的返回）。

**行为保持：** verdict→框架返回的翻译逐点等价：`keep_open=true`→`{stay=true}`（原 `_handle_keep_open`/`_try_failure_stay` 的 stay 分支）；`keep_open=false`→`finish_choice(game,false)`（原两处 finish 分支）。`finish_choice(game,false)` 的返回值仍被原样 `return`，框架侧行为一致。

- [ ] **Step 1：改 require（`choice.outcome` → `purchase_settlement`）**

`src/rules/choice_handlers/market.lua:4`，将：

```lua
local choice_outcome = require("src.rules.market.choice").outcome
```

改为：

```lua
local purchase_settlement = require("src.rules.market.purchase_settlement")
```

- [ ] **Step 2：`_handle_market_buy`（:100-107）降为 adapter**

将：

```lua
  local function _handle_market_buy(game, choice, action)
    local meta = choice.meta
    local player = _validate_market_player(game, meta)
    local product_id = assert(number_utils.to_integer(action.option_id), "missing product_id")
    local entry = _validate_market_entry(product_id)
    local result = market_service.purchase.execute(game, player, product_id)
    return choice_outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  end
```

改为：

```lua
  local function _handle_market_buy(game, choice, action)
    local meta = choice.meta
    local player = _validate_market_player(game, meta)
    local product_id = assert(number_utils.to_integer(action.option_id), "missing product_id")
    local entry = _validate_market_entry(product_id)
    local result = market_service.purchase.execute(game, player, product_id)
    local verdict = purchase_settlement.resolve(game, choice, player, entry, result)
    if verdict.keep_open then
      return { stay = true }
    end
    return finish_choice(game, false)
  end
```

（`finish_choice = helpers.finish_choice` 仍在 `_build` 顶部，只被本 adapter 使用——泄漏止于此。）

- [ ] **Step 3：跑人类购买整链 pin**

Run: `busted --run behavior spec/behavior/rules/market_choice_session_spec.lua spec/behavior/rules/market_purchase_spec.lua spec/behavior/rules/market_spec.lua`
Expected: PASS（人类路径行为零变化）。

- [ ] **Step 4：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/rules/choice_handlers/market.lua
git commit -m "refactor(market): choice_handlers 改用 purchase_settlement,finish_choice 收回 adapter 不再内泄"
```

---

## Task 3：auto.execute 接上同一解释者（AI 与人类同穿）

**Files:**
- Modify: `src/rules/market/auto.lua`（require + `auto.execute` 尾段）
- Test: `spec/behavior/rules/market_spec.lua` 或新增 auto pin（AI 购买后不崩、不留屏）

**Interfaces:**
- Consumes: `purchase_settlement.resolve`。
- Produces: `auto.execute` 签名不变（无返回值语义）。

**行为保持（AI 近乎 no-op）：** AI 到黑市直接买最便宜项，**无 pending market_buy modal**。`resolve` 内 `session.rebuild_pending(game, pending, player)` 对「无 market_buy pending」返回 false → 不留屏、不重建；rejected/fulfilled 均落 `keep_open=false`，auto 不消费 verdict。故 AI **观测行为不变**，仅结构上与人类穿同一解释者。传入的 `choice_state` 取当前 `game.turn.pending_choice`（可能为 nil / 非 market_buy，`rebuild_pending` 已守卫）。

- [ ] **Step 1：写 pin 测试（AI 购买仍成交、不崩、market 不被留开）**

在 `spec/behavior/rules/market_spec.lua` 内追加（或复用其 game fixture；断言聚焦「AI 买到东西 + turn 无残留 market_buy pending」）：

```lua
  it("PIN: auto purchase fulfills and does not leave a market modal open", function()
    local g = _new_game()  -- 复用文件既有 fixture 构造器
    local player = g.players[1]
    -- 令 player 为 AI 之外的可购买态,或直接驱动 auto 的购买分支;
    -- 关键断言:auto.execute 后无异常,且 game.turn.pending_choice 不是遗留的 market_buy。
    local ok = pcall(function() require("src.rules.market.auto").execute(g, player) end)
    assert(ok, "auto.execute must not error after routing through purchase_settlement")
    local pending = g.turn and g.turn.pending_choice
    assert(pending == nil or pending.kind ~= "market_buy" or pending.owner_role_id ~= player.id,
      "AI purchase must not leave its own market_buy modal open")
  end)
```

> 若 `market_spec.lua` 已有等价 auto 覆盖，改为在既有 auto 用例里补一条「不崩 + 不留屏」断言，避免重复 fixture。

- [ ] **Step 2：跑 pin 确认当前（迁移前）通过**

Run: `busted --run behavior spec/behavior/rules/market_spec.lua`
Expected: PASS（characterization 基线）。

- [ ] **Step 3：加 require**

`src/rules/market/auto.lua` 顶部 require 区加：

```lua
local purchase_settlement = require("src.rules.market.purchase_settlement")
```

- [ ] **Step 4：`auto.execute` 尾段（:37-40）接上解释者**

将：

```lua
  local chosen = list[1]
  if chosen then
    purchase.execute(game, player, chosen.product_id)
  end
```

改为：

```lua
  local chosen = list[1]
  if chosen then
    local result = purchase.execute(game, player, chosen.product_id)
    purchase_settlement.resolve(game, game.turn and game.turn.pending_choice or nil, player, chosen, result)
  end
```

- [ ] **Step 5：跑 pin 确认仍通过**

Run: `busted --run behavior spec/behavior/rules/market_spec.lua`
Expected: PASS（AI 行为不变）。

- [ ] **Step 6：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/rules/market/auto.lua spec/behavior/rules/market_spec.lua
git commit -m "refactor(market): auto 购买接上 purchase_settlement,AI 与人类穿同一解释者"
```

---

## Task 4：删 choice.lua 的 outcome 表 + 迁移 944 行耦合 spec

**Files:**
- Modify: `src/rules/market/choice.lua`（删 `outcome` + 4 helper + `_dispatch_intent`/`_INTENT_HANDLERS`；`return` 去 `outcome`）
- Migrate/Delete: `market_choice_outcome_spec.lua`、`market_choice_extra_survivors_spec.lua`、`market_choice_residual_closure_spec.lua`

**Interfaces:** Produces: 无——删死代码 + 测试搬家。

**迁移变换规则（机械、统一）：** 三个 spec 里每处
```lua
choice.outcome.resolve_purchase(game, ch, player, entry, RESULT, finish_choice)
```
按下表逐一替换为对 `purchase_settlement.resolve(game, ch, player, entry, RESULT)` 的 verdict 断言：

| 原断言 | 新断言 |
|---|---|
| `assert(r and r.stay == true, ...)` | `assert(v.keep_open == true, ...)` |
| `assert(finish_called, ...)`（且无 stay） | `assert(v.keep_open == false, ...)` |
| `assert(not finish_called, ...)` | `assert(v.keep_open == true, ...)`（当该用例语义为留屏时）/ 否则删该行 |
| `open_choice_called` / `inventory_full_emitted` 等副作用断言 | **原样保留**（副作用仍在深模块内发生） |
| `_test_missing_finish_choice_raises`（nil finish_choice 必 raise） | **删除该用例**（finish_choice 已移出深模块，不变量转由 adapter 的框架契约保证） |

`finish_choice` stub（`local finish_called=false; local finish_choice=function() finish_called=true end`）在迁移后不再需要——删除。目标模块从 `require("src.rules.market.choice")` 改 `require("src.rules.market.purchase_settlement")`（builder/session/navigation 相关用例仍留在针对 `choice` 的 spec 里）。

**代表样例（outcome_spec 两例，其余同构套用）：**

原 `_test_deferred_fulfillment_keeps_market_open`（outcome_spec:67-84）:
```lua
      local finish_called = false
      local finish_choice = function() finish_called = true end
      local r = choice.outcome.resolve_purchase(game, ch, player, entry, { ok = true, deferred_fulfillment = true }, finish_choice)
      assert(r and r.stay == true, "deferred_fulfillment should keep market open")
      assert(not finish_called, "finish_choice should not be called on deferred fulfillment")
```
迁移后（并入 Task 1 的 `purchase_settlement_spec` 已覆盖此例——**直接删原用例**）。

原 `_test_purchase_failure_calls_finish_when_rebuild_fails`（outcome_spec:160-173）:
```lua
      choice.outcome.resolve_purchase(game, ch, player, entry, { ok = false }, function() finish_called = true end)
      assert(finish_called, "purchase failure with failed rebuild should call finish_choice")
```
迁移后（Task 1 `purchase_settlement_spec` 的 "failure does not keep open when rebuild fails" 已覆盖——**直接删原用例**）。

> 因 Task 1 的 `purchase_settlement_spec` 已把 outcome_spec 十用例悉数迁为 verdict 形态，**`market_choice_outcome_spec.lua` 整文件可删**（其 builder/session 覆盖若有独立价值则拆到 `market_choice_session_spec`）。`extra_survivors` / `residual_closure` 按上表逐处套变换规则改签名——它们是变异存活专测，改后必须仍杀同样的变异体（行为断言不变，仅接口迁移）。

- [ ] **Step 1：删 choice.lua 的 outcome 表与其私有 helper**

删除 `src/rules/market/choice.lua` 中：`_INTENT_HANDLERS`、`_dispatch_intent`、`_is_purchase_failure`、`_should_keep_market_open`、`_handle_keep_open`、`_try_failure_stay`、`_dispatch_and_finish`、`outcome` 表及其 `resolve_purchase`（现 :285-352 区段）。并把文件末 `return { builder = builder, feedback = feedback, session = session, outcome = outcome }` 改为：

```lua
return {
  builder = builder,
  feedback = feedback,
  session = session,
}
```

删除迁走后变死的 require：`intent_output_port`（现仅被 `_INTENT_HANDLERS` 用）与 `purchase_result`（现仅被 `resolve_purchase` 用）——**用 grep 确认零残留引用后**再删。

Run: `grep -n "intent_output_port\|purchase_result" src/rules/market/choice.lua`
Expected: 删除后仅剩 doc 注释里的文字（若有）→ 一并清理注释。

- [ ] **Step 2：迁移三个耦合 spec（套用上表变换规则）**

- 删除 `spec/behavior/rules/market_choice_outcome_spec.lua`（十用例已由 `purchase_settlement_spec` 覆盖）。
- 对 `market_choice_extra_survivors_spec.lua`、`market_choice_residual_closure_spec.lua`：目标模块改 `purchase_settlement`，逐处按变换表把 `resolve_purchase(...,finish_choice)` + `{stay}`/`finish_called` 断言改成 `resolve(...)` + `keep_open` 断言；删 `finish_choice` stub 与「nil finish_choice raise」用例。

- [ ] **Step 3：跑迁移后的全套 market spec**

Run: `busted --run behavior spec/behavior/rules/market/purchase_settlement_spec.lua spec/behavior/rules/market_choice_extra_survivors_spec.lua spec/behavior/rules/market_choice_residual_closure_spec.lua spec/behavior/rules/market_purchase_spec.lua spec/behavior/rules/market_spec.lua`
Expected: PASS（变异存活专测仍杀同样变异体；无 `resolve_purchase` 残留引用）。

- [ ] **Step 4：全仓确认 outcome/resolve_purchase 零残留**

Run: `grep -rn "\.outcome\b\|resolve_purchase" src/ spec/ | grep -v manifest`
Expected: 空（或仅无关的 `_resolve_purchase_*` host/skin 命名）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/rules/market/choice.lua spec/behavior/rules/market_choice_outcome_spec.lua spec/behavior/rules/market_choice_extra_survivors_spec.lua spec/behavior/rules/market_choice_residual_closure_spec.lua
git commit -m "refactor(market): 删 choice.outcome 表,944 行解释者 spec 迁往 purchase_settlement"
```

---

## Task 5：deletion-test 复核 + manifest 刷新 + 完整门禁

**Files:**
- Modify（manifest 刷新）: `src/rules/market/choice.lua`、`src/rules/choice_handlers/market.lua`、`src/rules/market/auto.lua`
- 全仓验证

- [ ] **Step 1：deletion-test 复核（口头）**

删 `purchase_settlement.lua` → `choice_handlers` adapter 与 `auto` 同时失去「keep-open / failure-stay / intent 分发 / inventory_full」解释，人类与 AI 两条入口的购买解释重新各自散落。复杂度集中一处；`finish_choice` 不再穿入任何 rules/market 深模块。

- [ ] **Step 2：刷新受影响文件的 mutation manifest**

Run:
```bash
lua tools/quality/mutate.lua src/rules/market/choice.lua --update-manifest
lua tools/quality/mutate.lua src/rules/choice_handlers/market.lua --update-manifest
lua tools/quality/mutate.lua src/rules/market/auto.lua --update-manifest
```
Expected: 三个 `manifest updated`（只动各文件底部 manifest 注释块——用 `git diff -U0` 核对改动行号 > manifest marker 行号）。

- [ ] **Step 3：完整门禁 + 验收**

Run: `make verify && make acceptance`
Expected: 两者 PASS（`skin_shop`/`market_cash` 验收不回归）。

- [ ] **Step 4：Commit**

```bash
git add src/rules/market/choice.lua src/rules/choice_handlers/market.lua src/rules/market/auto.lua
git commit -m "chore(market): 刷新 choice/choice_handlers/auto mutation manifest"
```

---

## Self-Review

**1. Spec 覆盖（候选 ② 剩余两半）：**
- ✅「finish_choice 停止内泄」→ `purchase_settlement.resolve` 不吃 finish_choice（Task 1）；`finish_choice` 只留 `choice_handlers/market` adapter（Task 2）；`choice.outcome` 删除（Task 4）。
- ✅「AI 与人类穿同一解释者」→ auto 接 `purchase_settlement.resolve`（Task 3）。
- ✅ deletion test（删 settlement → 两入口解释重新散落）→ Task 5 Step 1。

**2. Placeholder 扫描：** 新模块/adapter/auto 均给完整代码块；944 行 spec 迁移给了**机械变换表 + 两个代表样例 + 绿色不变量**（非新写测试，是既有测试的确定性接口迁移，符合 no-placeholder 精神）。✅

**3. 类型/签名一致性：**
- `resolve(game, choice, player, entry, result) -> {keep_open}` 在 Task 1 定义，Task 2 adapter、Task 3 auto、Task 4 spec 迁移一致。✅
- verdict 两分支翻译（`keep_open`→`{stay}`/`finish_choice`）逐点对齐 Phase 1 后的 `resolve_purchase` 行为。✅
- **无环**：`purchase_settlement` require `choice`（单向，已核 `choice.lua` 不 require 本模块）。✅

**已知风险（handoff 要说）：** ① `extra_survivors` 是变异存活专测，接口迁移后**必须仍杀同样变异体**——若某用例迁后变绿失效（no_sites/漏杀），说明变换漏了副作用断言，需逐条核对而非放过；② auto 统一为近-no-op，若 review 认为不值这点改动面，可只做 Task 1/2/4（去泄漏），Task 3 单独裁；③ Task 4 删 `market_choice_outcome_spec` 前须确认其 builder/session 覆盖已被 `purchase_settlement_spec` 或 `market_choice_session_spec` 承接，勿丢覆盖。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-2-phase2-settlement-leak.md`.

本计划完成候选 ② 的另两半（去 finish_choice 泄漏 + 统一 auto），前置 Phase 1 已 merge。5 个 task 线性依赖。

两种执行方式：
**1. Subagent-Driven（推荐）** — 每 task 一个 fresh subagent，task 间两段 review。Task 4（944 行 spec 迁移）建议单独一个 subagent 专做。
**2. Inline Execution** — 本 session 用 `executing-plans` 批量执行，带 checkpoint。

选哪个？
