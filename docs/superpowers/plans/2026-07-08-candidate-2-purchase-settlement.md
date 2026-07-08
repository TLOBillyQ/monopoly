# 候选 ② 商店购买结算 —— purchase_result 收敛计划

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐 task 执行。步骤用 `- [ ]` 复选框跟踪。**每个 task 由一个 fresh subagent 独立完成，做完过一轮 review 再进下一个。** 按编号顺序执行——task 间有真实文件依赖。

**Goal:** 把 `purchase.execute` 返回的 **4 种不兼容形状**（`false` / `{ok=false,reason}` / `{ok=true,fulfilled_now}` / `{deferred_fulfillment}`）收敛到一个 `purchase_result.canonicalize` 唯一解码点，让购买结算解释者停止逐处 poke `result.ok`/`.deferred_fulfillment`/`.fulfilled_now`——照抄本仓库金标准 `rules/items` 的 `use_result.canonicalize`。

**Architecture:** 新建 `src/rules/market/purchase_result.lua`（构造器 + `canonicalize`，`use_result` 的孪生），把 4 形状收敛为 4 个终态 status：`fulfilled` / `deferred` / `rejected` / `residual`。`rules/market/choice.lua` 里既有的解释者 `outcome.resolve_purchase` 改为**先 canonicalize 一次、再读 `.status`**，其对外签名、`finish_choice` 契约、intent 分发全部**不变**——因此 944 行既有 resolve_purchase 耦合 spec + `market_purchase_spec` 保持全绿。这是候选 ② 里**风险最低、最贴近 items 金标准**的一刀。

**Tech Stack:** Lua 5.4；busted（`spec/behavior/rules/`）；清洁架构七层，模块落在 `rules/market`。

## Global Constraints

- 命名 `snake_case`；文件顶部中文 doc 注释说明「唯一解码点」职责（照抄 `src/rules/items/use_result.lua:1-5` 风格）。
- `src/` 禁用 `tonumber` / `type(x)=="number"`；用 `NumberUtils`（`src.foundation.number`）。本模块只做形状分类，不需要数字判定。
- **这是重构，观测行为零变化**。`purchase.execute` 与所有生产者**继续返回原 4 形状**（`market_purchase_spec` 硬钉了它们，见下）；canonicalize 只在**解释者内部**发生。
- `outcome.resolve_purchase` 的**对外签名与 `finish_choice` 契约不得改**（Phase 1）。移除 `finish_choice` 泄漏是 Phase 2 的独立计划。
- 迭代门禁 `make verify --smoke`（~8s，Makefile 目标为 `make verify` → `verify_full.lua`）；本计划每个 task 结尾跑 `make verify`（本仓库 verify 即完整门禁，~7-8s）。
- 单文件 spec 跑法：`busted --run behavior spec/behavior/rules/<file>_spec.lua`。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`。

---

## 候选 ② 全貌与分期（务必先读）

评审给候选 ② 列了 3 个「病灶」，但**落到代码上三者的风险与既有测试耦合度差异极大**——探源后必须分期，不能一把梭：

| 病灶（评审） | 是否真实 | 风险 / 阻力 | 归属 |
|---|---|---|---|
| **① `purchase.execute` 返回 4 种不兼容形状** | ✅ 真实 | **低**。canonicalize 可只在解释者内部发生，对外零改动 | **本计划（Phase 1）** |
| **② `finish_choice` 被 choice 层塞进 market 模块（泄漏）** | ✅ 真实 | **高**。`resolve_purchase` 已有 **944 行**专测钉死其 `(...,finish_choice)` 签名 + `{stay}`/finish 契约 + intent 分发 + 「nil finish_choice 必 raise」不变量。抽出 `purchase_settlement`、去 finish_choice = 重写这 944 行 spec | **Phase 2（独立计划）** |
| **③ `auto.lua:39` 丢弃结果、AI 与人类解释不同** | ⚠️ 真实但近乎 no-op | **中/低收益**。AI 到黑市直接买最便宜项，**没有 pending market modal**，走解释者也只会 `rebuild_pending`→false→不留屏。行为几乎不变，价值主要是结构统一 | **Phase 2（独立计划）** |

**关键探源发现（决定本计划形状）：**
- `resolve_purchase` **不是**评审说的「被拆开」——它已是一个**单一、契约完整、被 944 行 spec 钉死**的人类路径解释者（`market_choice_outcome_spec` 238 行 + `market_choice_extra_survivors` 514 行 + `market_choice_residual_closure` 192 行）。
- 这些 spec **直接驱动** `choice.outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)`，并**显式测试** `{ok=nil, intent={kind="need_choice"}}` 的 intent 分发路径（该路径在生产中因无生产者设 `.intent` 而 dead，但**测试是活的**）。
- `market_purchase_spec`（第 66-406 行）**硬钉** `purchase.execute` 的 4 原始形状：`result.ok==true and result.deferred_fulfillment==true`、`result.fulfilled_now==true`、`result.reason=="charge_failed"` 等约 15 处。**任何改 `purchase.execute` 返回形状的动作都会撞碎它。**

**结论：本计划 = Phase 1（canonicalizer），完整展开、可立即执行、零 spec 破坏。** Phase 2（去 finish_choice 泄漏 + 统一 auto + 迁移 944 行 spec）在文末给出**限定范围的后续计划入口**，需用 `writing-plans` 单独展开——它是一个独立子项目，不在本计划的 no-placeholder 步骤里硬塞。

---

## Phase 1 文件结构

**新建：**
- `src/rules/market/purchase_result.lua` — 构造器 + `canonicalize`（`use_result` 孪生）。唯一解码点。
- `spec/behavior/rules/market/purchase_result_spec.lua` — 模块直测，逐形状钉死（照抄 `spec/behavior/rules/items/use_result_spec.lua` 风格）。

**改为「读 canonical status」（行为保持，签名不变）：**
- `src/rules/market/choice.lua`：
  - 顶部加 `purchase_result` require
  - `_is_purchase_failure`（:303-305）
  - `_should_keep_market_open`（:307-315）
  - `_handle_keep_open`（:317-323）
  - `outcome.resolve_purchase`（:339-346）先 canonicalize 一次

**保持不变（护栏，勿删勿改）：**
- `src/rules/market/purchase.lua`、`purchase_fulfillment.lua`、`paid_purchase_flow.lua`、`auto.lua`、`choice_handlers/market.lua`（Phase 1 全不碰）
- `spec/behavior/rules/market_purchase_spec.lua`、`market_choice_outcome_spec.lua`、`market_choice_extra_survivors_spec.lua`、`market_choice_residual_closure_spec.lua`（全部保持绿）

---

## Task 1：新建 purchase_result（构造器 + canonicalize）

**Files:**
- Create: `src/rules/market/purchase_result.lua`
- Test: `spec/behavior/rules/market/purchase_result_spec.lua`

**Interfaces:**
- Produces（Task 2 依赖）：
  - `purchase_result.canonicalize(raw, fallback_reason) -> result`，`result.status ∈ {fulfilled, deferred, rejected, residual}`
  - 字段：`.status`、`.reason`（rejected）、`.kind`、`.product_id`、`.fulfilled_now`（fulfilled 恒 true）、`.inventory_full_after`（fulfilled）、`.raw`（原值）
  - `purchase_result.is_result(v)`、`.fulfilled(fields)`、`.deferred(fields)`、`.rejected(reason, fields)`、`.residual(raw)`
- 形状映射（**按 market 既有契约，非照抄 items**——注意非表映射到 `residual`→收尾，而非 items 的 `rejected`→失败留屏）：

| raw | → status |
|---|---|
| 已是 result | 原样返回 |
| 非 table（`false` / 字符串 / nil） | `residual` |
| `{ ok=false, reason }` | `rejected`（reason 保留，缺则 fallback） |
| `{ ok=true, deferred_fulfillment=true }` | `deferred` |
| `{ ok=true, fulfilled_now=true, inventory_full_after? }` | `fulfilled` |
| 其它（`{ok=nil}`、`{ok=nil,intent=...}`、`{ok=true}` 裸） | `residual` |

- [ ] **Step 1：写失败测试**

创建 `spec/behavior/rules/market/purchase_result_spec.lua`：

```lua
-- purchase_result 构造器与 canonicalize 直测。
-- purchase.execute 的 4 种历史 raw 形状逐一钉死,不依赖活流量。
local purchase_result = require("src.rules.market.purchase_result")

local function _eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

describe("market purchase_result", function()
  it("builds fulfilled results with fulfilled_now forced true", function()
    local r = purchase_result.fulfilled({ kind = "item", product_id = 101, inventory_full_after = true })
    _eq(purchase_result.is_result(r), true, "fulfilled is a result")
    _eq(r.status, "fulfilled", "status")
    _eq(r.fulfilled_now, true, "fulfilled_now forced true")
    _eq(r.inventory_full_after, true, "carries inventory_full_after")
    _eq(r.product_id, 101, "carries product_id")
  end)

  it("builds deferred and residual results", function()
    _eq(purchase_result.deferred({ kind = "item", product_id = 9 }).status, "deferred", "deferred status")
    _eq(purchase_result.residual(false).status, "residual", "residual status")
    _eq(purchase_result.residual("x").raw, "x", "residual carries raw")
  end)

  it("requires a stable reason for rejected", function()
    _eq(purchase_result.rejected("sold_out").status, "rejected", "rejected status")
    _eq(purchase_result.rejected("sold_out").reason, "sold_out", "rejected reason")
    assert(not pcall(purchase_result.rejected), "missing reason must error")
    assert(not pcall(purchase_result.rejected, ""), "empty reason must error")
  end)

  it("canonicalizes non-table raw as residual (NOT rejected)", function()
    _eq(purchase_result.canonicalize(false).status, "residual", "bare false is residual")
    _eq(purchase_result.canonicalize(nil).status, "residual", "nil is residual")
    _eq(purchase_result.canonicalize("s").status, "residual", "string is residual")
  end)

  it("canonicalizes ok=false as rejected preserving reason with fallback", function()
    _eq(purchase_result.canonicalize({ ok = false, reason = "charge_failed" }).reason, "charge_failed", "explicit reason wins")
    _eq(purchase_result.canonicalize({ ok = false }, "insufficient").reason, "insufficient", "bare failure takes fallback")
    _eq(purchase_result.canonicalize({ ok = false }).reason, "purchase_rejected", "default reason when no fallback")
  end)

  it("canonicalizes deferred and fulfilled success shapes", function()
    local deferred = purchase_result.canonicalize({ ok = true, kind = "item", product_id = 7, deferred_fulfillment = true })
    _eq(deferred.status, "deferred", "deferred_fulfillment maps to deferred")
    _eq(deferred.product_id, 7, "deferred carries product_id")

    local fulfilled = purchase_result.canonicalize({ ok = true, kind = "item", product_id = 5, fulfilled_now = true, inventory_full_after = true })
    _eq(fulfilled.status, "fulfilled", "fulfilled_now maps to fulfilled")
    _eq(fulfilled.inventory_full_after, true, "fulfilled carries inventory_full_after")
  end)

  it("canonicalizes ok=nil tables and bare ok=true as residual", function()
    _eq(purchase_result.canonicalize({ ok = nil, intent = { kind = "need_choice" } }).status, "residual",
      "intent-carrier without terminal markers is residual")
    _eq(purchase_result.canonicalize({ ok = true }).status, "residual", "ok=true without fulfilled_now/deferred is residual")
  end)

  it("is idempotent on existing results", function()
    local original = purchase_result.deferred({ product_id = 1 })
    _eq(purchase_result.canonicalize(original), original, "canonicalize passes through results")
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted --run behavior spec/behavior/rules/market/purchase_result_spec.lua`
Expected: FAIL —`module 'src.rules.market.purchase_result' not found`。

- [ ] **Step 3：写最小实现**

创建 `src/rules/market/purchase_result.lua`：

```lua
-- 商店购买结果的全量构造器与唯一形状判定器。
-- purchase.execute 历史返回 4 种不兼容形状:
--   false(非法商品) / { ok=false, reason }(校验/余额/在途/通道失败) /
--   { ok=true, fulfilled_now=true, inventory_full_after }(本地即时成交) /
--   { ok=true, deferred_fulfillment=true }(付费下单、异步履约)。
-- canonicalize 是全模块唯一解码点,收敛为 4 个终态 status:
--   fulfilled / deferred / rejected / residual。
-- residual = 「非可识别终态」(非表、ok=nil、仅带 intent 的表),交由解释者
-- 现有 intent 分发/收尾逻辑处理。与 items 的 use_result 同构,但 residual 的
-- 收尾语义按 market 既有契约(非表 → 收尾而非失败留屏)保留,不照抄 items。
local purchase_result = {}

local RESULT_MT = {}

local function _new(status, fields)
  return setmetatable({
    status = status,
    reason = fields.reason,
    kind = fields.kind,
    product_id = fields.product_id,
    fulfilled_now = fields.fulfilled_now,
    inventory_full_after = fields.inventory_full_after,
    raw = fields.raw,
  }, RESULT_MT)
end

function purchase_result.is_result(value)
  return getmetatable(value) == RESULT_MT
end

function purchase_result.fulfilled(fields)
  fields = fields or {}
  return _new("fulfilled", {
    kind = fields.kind,
    product_id = fields.product_id,
    fulfilled_now = true,
    inventory_full_after = fields.inventory_full_after == true,
    raw = fields.raw,
  })
end

function purchase_result.deferred(fields)
  fields = fields or {}
  return _new("deferred", { kind = fields.kind, product_id = fields.product_id, raw = fields.raw })
end

function purchase_result.rejected(reason, fields)
  assert(type(reason) == "string" and reason ~= "", "rejected requires a stable reason")
  fields = fields or {}
  return _new("rejected", { reason = reason, raw = fields.raw })
end

function purchase_result.residual(raw)
  return _new("residual", { raw = raw })
end

-- 4 种历史 raw 形状的唯一解码点。解释者只认 canonicalize 的产出。
function purchase_result.canonicalize(raw, fallback_reason)
  if purchase_result.is_result(raw) then
    return raw
  end
  if type(raw) ~= "table" then
    return purchase_result.residual(raw)
  end
  if raw.ok == false then
    return purchase_result.rejected(raw.reason or fallback_reason or "purchase_rejected", { raw = raw })
  end
  if raw.ok == true and raw.deferred_fulfillment == true then
    return purchase_result.deferred({ kind = raw.kind, product_id = raw.product_id, raw = raw })
  end
  if raw.ok == true and raw.fulfilled_now == true then
    return purchase_result.fulfilled({
      kind = raw.kind,
      product_id = raw.product_id,
      inventory_full_after = raw.inventory_full_after == true,
      raw = raw,
    })
  end
  return purchase_result.residual(raw)
end

return purchase_result
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted --run behavior spec/behavior/rules/market/purchase_result_spec.lua`
Expected: PASS（8 用例全绿）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify`
Expected: PASS（新模块无 caller，全套绿）。

```bash
git add src/rules/market/purchase_result.lua spec/behavior/rules/market/purchase_result_spec.lua
git commit -m "feat(market): purchase_result.canonicalize —— 4 购买形状的唯一解码点"
```

---

## Task 2：解释者 resolve_purchase 改读 canonical status（行为保持）

**Files:**
- Modify: `src/rules/market/choice.lua`（require + 4 处 local 函数 + `resolve_purchase`）
- Pin（保持绿，勿改）: `spec/behavior/rules/market_choice_outcome_spec.lua`、`market_choice_extra_survivors_spec.lua`、`market_choice_residual_closure_spec.lua`

**Interfaces:**
- Consumes: `purchase_result.canonicalize`（Task 1）。
- Produces: `outcome.resolve_purchase` 签名与返回契约**不变**（`(game, choice, player, entry, result, finish_choice)` → `{stay=true}` 或 `finish_choice(game,false)` 的返回；nil finish_choice 仍 raise）。

**行为保持（逐点对齐既有 944 行 spec）：** 把三个「poke 原始字段」的判定改成读 `canonical.status`，映射等价：
- `_should_keep_market_open`：`deferred_fulfillment==true or (kind=="item" and fulfilled_now==true)` → `status=="deferred" or (kind=="item" and status=="fulfilled")`
- `_is_purchase_failure`：`result.ok==false` → `status=="rejected"`
- `_handle_keep_open` 的 full_buy：`fulfilled_now==true and inventory_full_after==true` → `status=="fulfilled" and inventory_full_after==true`
- **intent 分发路径 `_dispatch_and_finish` 不改**：它继续吃**原始 raw** `result`（读 `result.intent`），因为 canonicalize 把 `{ok=nil,intent=...}` 归为 `residual`，解释者对 residual 仍走 `_dispatch_and_finish(game, result, finish_choice)`。`residual`（含非表）→ 收尾/ intent 分发，与现状逐字一致。

- [ ] **Step 1：确认既有 pin 当前全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/rules/market_choice_outcome_spec.lua spec/behavior/rules/market_choice_extra_survivors_spec.lua spec/behavior/rules/market_choice_residual_closure_spec.lua`
Expected: PASS（这 944 行就是本 task 的护栏；重构后必须仍全绿）。

- [ ] **Step 2：加 require**

`src/rules/market/choice.lua` 顶部 require 区（`local market_query = ...` 下一行）加：

```lua
local purchase_result = require("src.rules.market.purchase_result")
```

- [ ] **Step 3：改三个判定读 canonical status**

将 `_is_purchase_failure`（现 :303-305）：

```lua
local function _is_purchase_failure(result)
  return type(result) == "table" and result.ok == false
end
```

改为：

```lua
local function _is_purchase_failure(canonical)
  return canonical.status == "rejected"
end
```

将 `_should_keep_market_open`（现 :307-315）：

```lua
local function _should_keep_market_open(entry, result)
  if type(result) ~= "table" or result.ok ~= true then
    return false
  end
  if result.deferred_fulfillment == true then
    return true
  end
  return entry and entry.kind == "item" and result.fulfilled_now == true
end
```

改为：

```lua
local function _should_keep_market_open(entry, canonical)
  if canonical.status == "deferred" then
    return true
  end
  return entry and entry.kind == "item" and canonical.status == "fulfilled"
end
```

将 `_handle_keep_open`（现 :317-323）里的 full_buy 行：

```lua
  local full_buy = entry and entry.kind == "item" and result.fulfilled_now == true and result.inventory_full_after == true
```

改为（形参名同步为 `canonical`）：

```lua
  local full_buy = entry and entry.kind == "item" and canonical.status == "fulfilled" and canonical.inventory_full_after == true
```

即 `_handle_keep_open` 整体：

```lua
local function _handle_keep_open(game, choice, player, entry, canonical, finish_choice)
  local rebuilt = session.rebuild_pending(game, choice, player)
  if not rebuilt then return finish_choice(game, false) end
  local full_buy = entry and entry.kind == "item" and canonical.status == "fulfilled" and canonical.inventory_full_after == true
  if full_buy then feedback.emit_inventory_full(player, entry) end
  return { stay = true }
end
```

- [ ] **Step 4：resolve_purchase 先 canonicalize 一次**

将 `outcome.resolve_purchase`（现 :339-346）：

```lua
function outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  assert(type(finish_choice) == "function", "missing finish_choice")
  if _should_keep_market_open(entry, result) then
    return _handle_keep_open(game, choice, player, entry, result, finish_choice)
  end
  if _try_failure_stay(game, choice, player, result) then return { stay = true } end
  return _dispatch_and_finish(game, result, finish_choice)
end
```

改为：

```lua
function outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  assert(type(finish_choice) == "function", "missing finish_choice")
  local canonical = purchase_result.canonicalize(result)
  if _should_keep_market_open(entry, canonical) then
    return _handle_keep_open(game, choice, player, entry, canonical, finish_choice)
  end
  if _try_failure_stay(game, choice, player, canonical) then return { stay = true } end
  return _dispatch_and_finish(game, result, finish_choice)
end
```

> 注意末行 `_dispatch_and_finish(game, result, ...)` 仍传**原始 result**（不是 canonical）——intent 分发读的是 `result.intent`，保持 residual 路径逐字不变。`_try_failure_stay` 内部调用的 `_is_purchase_failure(canonical)` 现吃 canonical（Step 3 已改签名语义），`_try_failure_stay` 本体（`if not _is_purchase_failure(result) then ... rebuild`）无需改动——传入的实参已是 canonical。

- [ ] **Step 5：跑三个 pin spec 确认仍全绿**

Run: `busted --run behavior spec/behavior/rules/market_choice_outcome_spec.lua spec/behavior/rules/market_choice_extra_survivors_spec.lua spec/behavior/rules/market_choice_residual_closure_spec.lua`
Expected: PASS（10 outcome 用例 + extra_survivors + residual_closure 全绿——行为零变化）。

- [ ] **Step 6：跑全套 market 行为**

Run: `busted --run behavior spec/behavior/rules/market_purchase_spec.lua spec/behavior/rules/market_spec.lua`
Expected: PASS（`purchase.execute` 原形状未动，全绿）。

- [ ] **Step 7：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/rules/market/choice.lua
git commit -m "refactor(market): resolve_purchase 改读 purchase_result canonical status,4 形状 poke 收敛"
```

---

## Task 3：deletion-test 复核 + manifest 刷新 + 完整门禁

**Files:**
- Modify（manifest 刷新）: `src/rules/market/choice.lua`
- 全仓库验证

**Interfaces:** Produces: 无——收口验证 + 元数据刷新。

- [ ] **Step 1：deletion-test 复核（口头，非代码）**

确认候选 ② Phase 1 的 deletion test 成立：删 `purchase_result.canonicalize` → `resolve_purchase` 必须重新在 `_should_keep_market_open`/`_is_purchase_failure`/`_handle_keep_open` 三处各自 poke `result.ok`/`.deferred_fulfillment`/`.fulfilled_now`——4 形状解码**重新散落**。复杂度集中于一处、非冗余，与 `items/use_result` 同构。

- [ ] **Step 2：刷新 choice.lua 的 mutation manifest**

Run: `lua tools/quality/mutate.lua src/rules/market/choice.lua --update-manifest`
Expected: `manifest updated: src/rules/market/choice.lua`（重写 scope，反映 `_should_keep_market_open` 等改写后的 semanticHash；只动文件底部 `--[[ mutate4lua-manifest ]]` 注释块）。

> 验证只动注释：`git diff -U0 src/rules/market/choice.lua` 的最早改动行号应 > `grep -n "mutate4lua-manifest" src/rules/market/choice.lua` 的行号。

- [ ] **Step 3：完整门禁**

Run: `make verify`
Expected: PASS。

- [ ] **Step 4：验收套件（行为不变应自动保持绿）**

Run: `make acceptance`
Expected: PASS（重生成 gitignored 生成物再跑；`skin_shop`/`market_cash` 等验收不回归）。

- [ ] **Step 5：Commit**

```bash
git add src/rules/market/choice.lua
git commit -m "chore(market): 刷新 choice mutation manifest —— 反映 purchase_result 收敛后 scope"
```

---

## Phase 2（后续独立计划，非本计划步骤）—— 去 finish_choice 泄漏 + 统一 auto

> **这一段不是可执行步骤，是给下一份 `writing-plans` 的范围与阻力清单。** 它是独立子项目，blast radius 集中在 **944 行既有 spec 的签名迁移**，不宜在本计划里硬塞 no-placeholder 步骤。

**目标：** 把解释者从 `choice.lua` 抽成 `src/rules/market/purchase_settlement.lua`（唯一解释者），interface 改为**返回结构化 verdict `{ keep_open = bool }`**、**不再接收 `finish_choice`**。`choice_handlers/market.lua` 把 verdict 翻成 `{stay=true}` / `finish_choice(game,false)`——`finish_choice` 就此**只留在 choice-handler adapter**，停止内泄进 market 模块。`auto.execute` 也改走同一 `purchase_settlement`，AI 与人类穿同一解释者。

**必须迁移的文件：**
- 新建 `src/rules/market/purchase_settlement.lua`（承接现 `outcome.resolve_purchase` + 4 个 local helper + `_dispatch_intent`）
- `src/rules/market/choice.lua`：删 `outcome` 表（或留薄 shim）
- `src/rules/choice_handlers/market.lua:100-107`：`_handle_market_buy` 降为 adapter，`finish_choice` 留在此处
- `src/rules/market/auto.lua:37-40`：`purchase.execute` 结果改喂 `purchase_settlement`
- **spec 迁移（约 944 行，重点阻力）**：
  - `market_choice_outcome_spec.lua`（238 行）—— 10 个用例从 `choice.outcome.resolve_purchase(...,finish_choice)` 改为新模块的 verdict 断言
  - `market_choice_extra_survivors_spec.lua`（514 行）—— 变异存活专测，逐个改签名
  - `market_choice_residual_closure_spec.lua`（192 行）—— 同上

**风险 / 决策点（Phase 2 计划需先定）：**
1. **intent 分发路径去留**：`_dispatch_intent`/`need_choice` 在生产中 dead（无生产者设 `.intent`），仅被 spec 驱动。Phase 2 可借机 deletion-test 删掉它——但要连带删对应 spec 用例，需产品确认该扩展点确无未来用途。
2. **auto 统一的真实收益**：AI 无 pending market modal，走解释者近乎 no-op；确认是否值得为「结构统一」承担 auto 的 spec 改动，或仅做 `choice_handlers` 侧的去泄漏。
3. verdict 契约要覆盖「keep-open 但 rebuild 失败 → finish」这一既有分支（现 `_handle_keep_open` rebuild 失败调 `finish_choice`）——verdict 需能表达它（`keep_open=false`）。

---

## Self-Review

**1. Spec 覆盖（候选 ② 的评审主张）：**
- ✅「4 种不兼容返回形状 → 1 结构化」→ Task 1 `purchase_result.canonicalize`（4 status）+ Task 2 解释者只读 `.status`。
- ⏭「finish_choice 停止内泄」「AI 与人类穿同一解释者」→ **显式移交 Phase 2 独立计划**（附文件 + 944 行 spec 迁移清单 + 风险），非遗漏。
- ✅ deletion test（删 canonicalize → 4 形状 poke 重新散落）→ Task 3 Step 1 复核。

**2. Placeholder 扫描：** Phase 1 每步给完整代码块与预期输出；Phase 2 明确标注「非可执行步骤、后续计划入口」，不伪装成步骤。✅

**3. 类型/签名一致性：**
- `canonicalize -> {status, reason, kind, product_id, fulfilled_now, inventory_full_after, raw}` 在 Task 1 定义，Task 2 三处判定 + `_handle_keep_open` 逐一按此读取。✅
- Task 2 保持 `resolve_purchase` 对外签名不变、末行传原始 `result` 给 `_dispatch_intent`——已在 Step 4 注记，避免 canonical/raw 混用。✅
- **关键边界**：非表 raw → `residual`（→收尾），**不是** items 的 `rejected`（→失败留屏）；已在 Task 1 映射表 + 单测 `canonicalizes non-table raw as residual` 钉死，防止照抄 items 语义引回归。✅

**已知风险（handoff 要说）：** ① Phase 1 只交付 canonicalizer，评审 ② 的另两半在 Phase 2；② `market_choice_extra_survivors_spec` 是变异存活专测，对内部分支敏感——Task 2 若某用例红，**先核对是否等价改写而非行为漂移**，多半是 `_is_purchase_failure` 形参 canonical/raw 混用所致。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-2-purchase-settlement.md`.

本计划 = **候选 ② Phase 1（purchase_result 收敛器）**，完整可执行、零既有 spec 破坏。Phase 2（去 finish_choice 泄漏 + 统一 auto + 迁移 944 行 spec）见上一节，需单独 `writing-plans` 展开。

两种执行方式：

**1. Subagent-Driven（推荐）** — 每 task 一个 fresh subagent，task 间两段 review。3 个 task 线性依赖，适配。

**2. Inline Execution** — 本 session 用 `executing-plans` 批量执行，带 checkpoint。

选哪个？
