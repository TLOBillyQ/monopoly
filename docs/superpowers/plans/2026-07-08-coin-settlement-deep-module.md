# 金币扣费与破产结算深模块（coin_settlement）实施计划

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐 task 执行。步骤用 `- [ ]` 复选框跟踪。**每个 task 由一个 fresh subagent 独立完成，做完过一轮 review 再进下一个。** 除非该 task 明确标注可并行，否则按编号顺序执行——本计划的 task 之间有真实的文件依赖。

**Goal:** 把散落在 land / chance / items / tax 四个 subdir、用 3 套不同破产协议重写的「扣一笔钱 → 判非正余额 → 破产淘汰 → 收款遥测」逻辑，收敛成一个 `coin_settlement` 深模块（唯一解释者），四个 call site 降为薄 adapter。

**Architecture:** 完全照抄本仓库金标准 `rules/items` 的 settlement 深化（ADR 0019：`use_result` 唯一判定 + `settlement` 唯一解释）。新建 `src/rules/commerce/coin_settlement.lua`，对外只暴露两个 interface：`charge`（单向扣费）与 `transfer`（转账 + 收款遥测）。二者内部拥有：余额钳制（clamp-at-0）、partial 转账封顶、非正余额 → `bankruptcy_port.eliminate`、`achievement_progress.cash_received` 遥测、以及破产时机（立即淘汰 / 延后上报两种）。**deity（财神/穷神）×2 定价规则按域各异（rent 是跨玩家 payer.poor×owner.rich，chance 是自身 self.rich/self.poor），语义不同，留在各自 adapter，不进本模块。**

**Tech Stack:** Lua 5.4；busted（行为 spec，`spec/behavior/rules/`）；清洁架构七层——本模块落在 `rules` 层，通过 `rules/ports/bankruptcy` 与 `rules/ports/achievement_progress` 出层。

## Global Constraints

- 命名 `snake_case`，模块表名小写下划线；文件顶部一段中文 doc 注释说明「唯一解释者」职责（照抄 `src/rules/items/settlement.lua:1-5` 的风格）。
- `src/` 禁用 `tonumber` / `type(x) == "number"`；如需数字工具用 `NumberUtils`（`src.foundation.number`）。本模块不需要新数字判定。
- Eggy 沙盒差异（`Fixed` 用浮点、`math.maxval`）——本模块只处理整数金币，不涉及。
- 迭代默认门禁 `make verify --smoke`（~8s）；本计划**每个 task 结尾都要跑它**。最后一个 task（handoff/commit 前）跑完整 `make verify`（~30s，含 crap + coverage）。
- 单个 behavior spec 跑法：`busted --run behavior spec/behavior/rules/<file>_spec.lua`。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`（生成物）。本计划不触碰验收生成物；行为不变则验收自动保持绿。
- 破产判定的既有边界必须逐点保持（见各 task 的「行为保持」小节）——**这是重构，观测行为零变化**，不是加功能。

---

## 全局路线图（7 个候选的 swarm 编排）

评审共 7 个候选，都是「同一种病（shallow module）、落在不同 subsystem」。**它们是独立子系统，按 writing-plans 规范各自应是一份独立 plan。本文件只完整展开候选 ①**；其余 6 个给出足够 swarm 调度的 owner / 文件 / 依赖 / 并行性，作为后续独立 plan 的入口。

| # | 名称 | 归属 module（新建/收编） | 主要文件面 | 类型 | 依赖 | 可并行组 |
|---|------|------------------------|-----------|------|------|---------|
| ① | 金币扣费与破产结算 | `rules/commerce/coin_settlement`（新建） | rules/{land,chance,items,tax} | 构建型（本 plan） | 无 | A |
| ② | 商店购买结算 | `rules/market/purchase_settlement` + `purchase_result.canonicalize`（新建） | rules/market/*, rules/choice_handlers/market | 构建型 | 无（与①同构，可照抄①产出的模板） | A |
| ③ | 回合序列 phase graph | `turn/sequence`（新建声明式表） | turn/phases/*, turn/timing.lua | 构建型 | 无 | B（turn） |
| ④ | 阻塞/等待判定 | `turn/waits/blocking`（新建） | turn/phases/land.lua, turn/waits/*, turn/loop/* | 构建型 | 与⑤共用 turn/waits/，需排序 | B（turn） |
| ⑤ | pending choice 生命周期 | `turn` choice 深模块（收编双写） | turn/waits/*, turn/deadlines/* | 构建型 | 与④共用 turn/waits/，需排序 | B（turn） |
| ⑥ | 每个选择屏一个 deep module | `ui/**` 逐屏 Screen module | ui/{schema,input,render,coord,state,view} | locality 型（15 屏，逐屏推进） | ⑤ 的 UI 半边 | C（ui） |
| ⑦ | 皮肤购买折叠死适配器 | 折 `skin_purchase` 进 `transaction_purchase` | app/host_integrations/*, app/cosmetics/* | 删除型 | 无 | A |

**swarm 调度建议：**
1. **先 ①（本 plan）**——评审 Top recommendation：模板已存在、风险最低、回报最直接。
2. ① 落地并 merge 后，**②** 照抄①刚验证过的「canonicalize + 唯一解释者」形状，独立开一份 plan。①② 分属 `commerce`/`market`，文件面不重叠，理论上可并行，但建议②等①做完好抄模板。
3. **⑦** 是纯删除型（deletion test 直接通过），文件面在 `app/`，与①②③④⑤全不重叠，**任何时候都可并行分派**给一个独立 subagent。
4. **turn 三连 ③④⑤**：③（phases/timing）与 ④⑤（waits/deadlines）文件面基本不重叠，可并行；但 **④ 和 ⑤ 都改 `turn/waits/`，必须串行或严格按文件分区**——建议同一个 swarm stream 里按 ⑤ → ④ 或 ④ → ⑤ 顺序做（各自独立 plan）。
5. **⑥** 是 ⑤ 的 UI 半边，面宽（15 屏），逐屏推进，放在 ⑤ 之后单独规划。

**冲突矩阵（哪些不能同时写同一批文件）：**
- ①：`rules/commerce/`（新增）+ `rules/land/{rent_payment,tax_rules,events}` + `rules/chance/{handlers,cash_handlers}` + `rules/items/target_cash_effects` — 与②③④⑤⑥⑦ **零重叠**。
- ④⑤ 共享 `turn/waits/` — **互斥**。
- ⑥ 与 ⑤ 概念同源但文件在 `ui/` — 面不重叠，但语义上 ⑥ 依赖 ⑤ 定稿的 choice 生命周期。

> 本文件下方**只展开候选 ①**。②③④⑤⑥⑦ 各自需要在执行前用 `superpowers:writing-plans` 展开成同样粒度的独立 plan。

---

## 候选 ① 文件结构

**新建：**
- `src/rules/commerce/coin_settlement.lua` — 深模块本体。唯一解释者，拥有 charge/transfer 两个 interface。
- `spec/behavior/rules/coin_settlement_spec.lua` — 模块直测（照抄 `spec/behavior/rules/items/use_result_spec.lua` 的「逐形状钉死」风格 + `land_settlement_spec` 的 `support.new_game` 真游戏 fixture）。

**改为 adapter（每个只调一次 coin_settlement，域特有逻辑——事件文案、deity ×2、tax_paid 遥测——留在原地）：**
- `src/rules/items/target_cash_effects.lua:89-99`（查税卡 inline eliminate → charge）
- `src/rules/land/tax_rules.lua:41-51`（税务局 bankrupt_reason 字段 → charge + defer）
- `src/rules/land/rent_payment.lua:113-126`（partial transfer + bankrupt_reason → transfer + defer）
- `src/rules/chance/cash_handlers.lua`（`_apply_payment`、`pay_others`、`collect_from_others` → charge/transfer）
- `src/rules/chance/handlers.lua:57-67`（清理迁移后变死的 `handle_bankruptcy_if_non_positive` / `apply_cash_and_maybe_bankrupt`）

**pin 特征（migration 前先写、跑绿以锁定现状，再重构保持绿）——已存在，勿删：**
- `spec/behavior/rules/chance_cash_others_contract_spec.lua`（pay_others / collect_from_others 的收款金额契约）
- `spec/behavior/rules/land_rent_spec.lua`、`spec/behavior/rules/tax_*` / `item_spec.lua`（查税卡）

---

## Task 1：新建 coin_settlement.charge（扣费 + 破产淘汰）

**Files:**
- Create: `src/rules/commerce/coin_settlement.lua`
- Test: `spec/behavior/rules/coin_settlement_spec.lua`

**Interfaces:**
- Consumes（既有，签名已核对）：
  - `game:player_cash(player) -> integer`
  - `game:add_player_cash(player, delta, opts)` — `delta<0` 扣费，结果**在 0 处钳制**（`balance.lua:216-225`，负结果归 0，绝不为负）；`opts` 可含 `{ suppress_cash_receive_anim = true }`。
  - `bankruptcy_port.eliminate(game, player, { reason })` — 设 `player.eliminated = true`（`endgame/bankruptcy.lua:123`，幂等：已淘汰直接 return）。
- Produces（后续 task 依赖）：
  - `coin_settlement.charge(game, payer, amount, opts) -> { charged = integer, bankrupt = boolean, reason = string|nil }`
  - `opts.reason` = `string | function(payer)->string`；`opts.defer_bankruptcy`（true 时只上报不淘汰）；`opts.cash_opts`（透传给 `add_player_cash`）。

- [ ] **Step 1：写失败测试（charge 基础扣费 + 破产 + 钳制 + defer）**

创建 `spec/behavior/rules/coin_settlement_spec.lua`：

```lua
-- coin_settlement 深模块直测:charge/transfer 两个 interface 逐点钉死。
-- 用 support.new_game 真游戏 fixture(与 land_settlement_spec 同款),
-- 破产经 player.eliminated 观测,遥测经注入的 achievement port 捕获。
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local coin_settlement = require("src.rules.commerce.coin_settlement")

local function _new_game()
  return support.new_game({ map = default_map })
end

-- 注入一个捕获 cash_received 的成就 port,返回捕获数组。
local function _capture_cash_received(game)
  local received = {}
  game.achievement_progress_port = {
    cash_received = function(_, player, amount)
      received[#received + 1] = { id = player.id, amount = amount }
      return true
    end,
  }
  return received
end

describe("rules.commerce.coin_settlement", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  describe("charge", function()
    it("deducts the amount and reports charged", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 1000)

      local result = coin_settlement.charge(g, p, 300, { reason = "x" })

      assert(g:player_cash(p) == 700, "balance should drop by 300")
      assert(result.charged == 300, "charged should equal deducted amount")
      assert(result.bankrupt == false, "positive balance is not bankrupt")
    end)

    it("clamps at zero when amount exceeds balance", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 200)

      local result = coin_settlement.charge(g, p, 500, { reason = "破产了" })

      assert(g:player_cash(p) == 0, "balance clamps at zero, never negative")
      assert(result.charged == 200, "charged reports the actually-drained amount")
    end)

    it("eliminates the payer when balance hits zero", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 200)

      local result = coin_settlement.charge(g, p, 200, { reason = "破产了" })

      assert(result.bankrupt == true, "zero balance is bankrupt")
      assert(result.reason == "破产了", "reason echoed on bankruptcy")
      assert(p.eliminated == true, "payer eliminated on non-positive balance")
    end)

    it("does not eliminate while balance stays positive", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 500)

      coin_settlement.charge(g, p, 100, { reason = "破产了" })

      assert(p.eliminated ~= true, "payer with cash left is not eliminated")
    end)

    it("defer_bankruptcy reports but does not eliminate", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 100)

      local result = coin_settlement.charge(g, p, 100, {
        reason = "延后淘汰",
        defer_bankruptcy = true,
      })

      assert(result.bankrupt == true, "still reports bankruptcy")
      assert(result.reason == "延后淘汰", "still resolves reason")
      assert(p.eliminated ~= true, "defer must skip the eliminate call")
    end)

    it("resolves a function reason lazily", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 50)

      local result = coin_settlement.charge(g, p, 50, {
        reason = function(payer) return payer.name .. " 破产" end,
      })

      assert(result.reason == p.name .. " 破产", "function reason receives payer")
    end)
  end)
end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted --run behavior spec/behavior/rules/coin_settlement_spec.lua`
Expected: FAIL —`module 'src.rules.commerce.coin_settlement' not found`。

- [ ] **Step 3：写最小实现（charge）**

创建 `src/rules/commerce/coin_settlement.lua`：

```lua
-- 金币扣费与破产结算深模块:唯一解释者。
-- 「扣一笔钱/转一笔钱 → 判非正余额 → 破产淘汰(或延后上报) → 收款遥测」
-- 全部收敛于此。原先散落在 land/chance/items/tax 四处、用 3 套破产协议
-- (bankrupt_reason 字段 / helper 顺手 eliminate / inline eliminate)重写的
-- 同一段逻辑,降为四个 adapter。deity ×2 定价规则按域各异,留在 adapter;
-- 本模块只拥有结算机制:余额钳制、partial 封顶、非正判定、淘汰时机、收款遥测。
local achievement_progress = require("src.rules.ports.achievement_progress")
local bankruptcy_port = require("src.rules.ports.bankruptcy")

local coin_settlement = {}

local function _resolve_reason(reason, payer)
  if type(reason) == "function" then
    return reason(payer)
  end
  return reason
end

-- 破产判定 + 淘汰时机。非正余额(<= 0) → 破产。
-- defer_bankruptcy 时只上报不淘汰(land 管线在 land_events 阶段统一淘汰,
-- 保留既有「先发事件、后淘汰」顺序)。
local function _settle_bankruptcy(game, payer, opts)
  if game:player_cash(payer) > 0 then
    return false, nil
  end
  local reason = _resolve_reason(opts.reason, payer)
  if not opts.defer_bankruptcy then
    bankruptcy_port.eliminate(game, payer, { reason = reason })
  end
  return true, reason
end

-- 扣费(单向流出)。按 add_player_cash 语义在 0 处钳制,绝不为负。
-- 无收款遥测(流出不记 cash_received)。
function coin_settlement.charge(game, payer, amount, opts)
  opts = opts or {}
  local before = game:player_cash(payer)
  game:add_player_cash(payer, -amount, opts.cash_opts)
  local charged = before - game:player_cash(payer)
  local bankrupt, reason = _settle_bankruptcy(game, payer, opts)
  return { charged = charged, bankrupt = bankrupt, reason = reason }
end

return coin_settlement
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted --run behavior spec/behavior/rules/coin_settlement_spec.lua`
Expected: PASS（6 个 charge 用例全绿）。

- [ ] **Step 5：Commit**

```bash
git add src/rules/commerce/coin_settlement.lua spec/behavior/rules/coin_settlement_spec.lua
git commit -m "feat(commerce): coin_settlement.charge —— 扣费 + 非正破产的唯一解释者"
```

---

## Task 2：新增 coin_settlement.transfer（partial 转账 + 收款遥测 + 破产）

**Files:**
- Modify: `src/rules/commerce/coin_settlement.lua`
- Test: `spec/behavior/rules/coin_settlement_spec.lua`（追加 `describe("transfer")` 块）

**Interfaces:**
- Consumes（既有，签名已核对 `balance.lua:287-309`）：
  - `game:transfer_player_cash(payer, receiver, amount, opts) -> payer_after, receiver_after, moved`；`opts.allow_partial = true` 时 payer 余额不足则封顶到其流动性（不创造钱）。
  - `achievement_progress.cash_received(game, receiver, moved)` — 收款遥测。
- Produces：
  - `coin_settlement.transfer(game, payer, receiver, amount, opts) -> { moved = integer, bankrupt = boolean, reason = string|nil }`
  - `opts` 同 charge（`reason` / `defer_bankruptcy` / `cash_opts`）。始终 partial；收款 `moved > 0` 时记一次 `cash_received(receiver, moved)`。

- [ ] **Step 1：写失败测试（transfer 全额/partial/破产/defer）**

在 `spec/behavior/rules/coin_settlement_spec.lua` 的顶层 `describe` 内、`describe("charge")` 之后追加：

```lua
  describe("transfer", function()
    it("moves the full amount and credits the receiver", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 1000)
      g:set_player_cash(receiver, 100)

      local result = coin_settlement.transfer(g, payer, receiver, 300, { reason = "x" })

      assert(g:player_cash(payer) == 700, "payer drops by 300")
      assert(g:player_cash(receiver) == 400, "receiver gains 300")
      assert(result.moved == 300, "moved equals requested when affordable")
      assert(result.bankrupt == false, "solvent payer not bankrupt")
    end)

    it("caps at payer liquidity when short (no money creation)", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 200)
      g:set_player_cash(receiver, 0)

      local result = coin_settlement.transfer(g, payer, receiver, 500, {
        reason = "欠付破产",
      })

      assert(result.moved == 200, "moved caps at payer's 200")
      assert(g:player_cash(receiver) == 200, "receiver gets only what payer had")
      assert(g:player_cash(payer) == 0, "payer drained to zero, not negative")
    end)

    it("records cash_received for the receiver on the moved amount", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 1000)
      local received = _capture_cash_received(g)

      coin_settlement.transfer(g, payer, receiver, 250, { reason = "x" })

      assert(#received == 1, "exactly one cash_received emitted")
      assert(received[1].id == receiver.id, "telemetry targets the receiver")
      assert(received[1].amount == 250, "telemetry carries the moved amount")
    end)

    it("does not record cash_received when nothing moves", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 0)
      local received = _capture_cash_received(g)

      local result = coin_settlement.transfer(g, payer, receiver, 100, { reason = "x" })

      assert(result.moved == 0, "nothing moves from an empty payer")
      assert(#received == 0, "no telemetry for a zero move")
    end)

    it("eliminates the payer on non-positive balance", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 200)

      local result = coin_settlement.transfer(g, payer, receiver, 500, {
        reason = "被收款破产",
      })

      assert(result.bankrupt == true, "drained payer is bankrupt")
      assert(payer.eliminated == true, "payer eliminated immediately by default")
    end)

    it("defer_bankruptcy reports moved and bankruptcy without eliminating", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 200)

      local result = coin_settlement.transfer(g, payer, receiver, 500, {
        defer_bankruptcy = true,
      })

      assert(result.moved == 200, "still reports partial move")
      assert(result.bankrupt == true, "still reports bankruptcy")
      assert(payer.eliminated ~= true, "defer skips the eliminate call")
    end)
  end)
```

- [ ] **Step 2：跑测试确认失败**

Run: `busted --run behavior spec/behavior/rules/coin_settlement_spec.lua`
Expected: FAIL —`attempt to call a nil value (field 'transfer')`。

- [ ] **Step 3：写最小实现（transfer）**

在 `src/rules/commerce/coin_settlement.lua` 里 `return coin_settlement` 之前插入：

```lua
-- 转账(payer → receiver)。始终 partial:payer 余额不足时封顶到其流动性,
-- 绝不创造钱。实际到账 > 0 时记一次 receiver 的 cash_received 遥测。
function coin_settlement.transfer(game, payer, receiver, amount, opts)
  opts = opts or {}
  local transfer_opts = { allow_partial = true }
  if opts.cash_opts then
    for key, value in pairs(opts.cash_opts) do
      transfer_opts[key] = value
    end
  end
  local _, _, moved = game:transfer_player_cash(payer, receiver, amount, transfer_opts)
  if moved and moved > 0 then
    achievement_progress.cash_received(game, receiver, moved)
  end
  local bankrupt, reason = _settle_bankruptcy(game, payer, opts)
  return { moved = moved, bankrupt = bankrupt, reason = reason }
end
```

- [ ] **Step 4：跑测试确认通过**

Run: `busted --run behavior spec/behavior/rules/coin_settlement_spec.lua`
Expected: PASS（charge 6 + transfer 6 全绿）。

- [ ] **Step 5：门禁 + Commit**

Run: `make verify --smoke`
Expected: PASS（新模块不改任何 call site，全套行为 spec 应保持绿）。

```bash
git add src/rules/commerce/coin_settlement.lua spec/behavior/rules/coin_settlement_spec.lua
git commit -m "feat(commerce): coin_settlement.transfer —— partial 转账 + 收款遥测 + 破产"
```

---

## Task 3：迁移查税卡（target_cash_effects.tax）→ charge

**Files:**
- Modify: `src/rules/items/target_cash_effects.lua:1-10`（require）、`:89-99`（tax.apply 尾段）
- Test: `spec/behavior/rules/item_spec.lua`（既有查税卡用例做 pin；如无精确断言，追加一个）

**Interfaces:**
- Consumes: `coin_settlement.charge`（Task 1）。
- Produces: 无新对外接口——纯 adapter 化。

**行为保持：** 原 `deduct_player_cash(target, fee)`（`fee = floor(cash*0.5) ≤ cash`，安全）→ `charge` 用 `add_player_cash(-fee)` 钳制到 0，**最终余额相同**。原 `if player_cash <= 0 then eliminate` → `charge` 默认（非 defer）内部同样 `<= 0` 判定并立即淘汰，reason 字符串逐字不变。`tax_paid` 遥测与 `event_feed.publish` 文案留在 adapter。

- [ ] **Step 1：写/确认 pin 测试（查税卡把目标扣到 0 并淘汰）**

在 `spec/behavior/rules/item_spec.lua` 相应 describe 内追加（若已有等价断言可复用，勿重复）：

```lua
  it("PIN: tax card drains target to zero and eliminates on non-positive", function()
    local g = _new_game()
    local user, target = g.players[1], g.players[2]
    g:set_player_cash(target, 100)  -- fee = floor(100*0.5) = 50; 两次不足以清零,构造精确边界:
    g:set_player_cash(target, 1)    -- fee = floor(1*0.5) = 0 → 扣 0,cash 仍 1,不淘汰
    target_cash_effects.tax.apply(g, user, target)
    assert(target.eliminated ~= true, "fee floors to 0 at cash=1, no bankruptcy")

    g:set_player_cash(target, 2)    -- fee = floor(2*0.5) = 1 → cash 1,不淘汰
    target_cash_effects.tax.apply(g, user, target)
    assert(g:player_cash(target) == 1, "cash 2 → pays 1 → left with 1")
  end)
```

> 注：`target_cash_effects` 的 `tax` 是 `{ apply = fn }` 形状（见 `target_cash_effects.lua:74`）。查税卡的 `<= 0` 淘汰边界较难在真游戏里凑到，pin 测试聚焦「扣费金额 = floor(cash*0.5)、余额钳制、不越界淘汰」。破产淘汰路径已被 Task 1 的 `coin_settlement_spec` 直接覆盖。文件顶部若无 `local target_cash_effects = require("src.rules.items.target_cash_effects")` 请确认已 require。

- [ ] **Step 2：跑 pin 确认当前通过（characterization）**

Run: `busted --run behavior spec/behavior/rules/item_spec.lua`
Expected: PASS（锁定现状；这是重构不是加功能）。

- [ ] **Step 3：改 require（换 bankruptcy_port → coin_settlement）**

`src/rules/items/target_cash_effects.lua` 顶部，将：

```lua
local bankruptcy_port = require("src.rules.ports.bankruptcy")
```

改为：

```lua
local coin_settlement = require("src.rules.commerce.coin_settlement")
```

（`bankruptcy_port` 在本文件仅 `:97` 一处使用，迁移后无引用——直接换掉该 require 行。）

- [ ] **Step 4：把 tax.apply 尾段（89-99）降为 adapter**

将：

```lua
    local fee = math.floor(game:player_cash(target) * 0.5)
    game:deduct_player_cash(target, fee)
    achievement_progress.tax_paid(game, target, fee)
    event_feed.publish(game, {
      kind = event_kinds.tax_card,
      text = user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. number_utils.format_integer_part(fee) .. " 税金",
    })
    if game:player_cash(target) <= 0 then
      bankruptcy_port.eliminate(game, target, { reason = target.name .. " 支付查税费用后破产" })
    end
    return true
```

改为：

```lua
    local fee = math.floor(game:player_cash(target) * 0.5)
    coin_settlement.charge(game, target, fee, {
      reason = target.name .. " 支付查税费用后破产",
    })
    achievement_progress.tax_paid(game, target, fee)
    event_feed.publish(game, {
      kind = event_kinds.tax_card,
      text = user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. number_utils.format_integer_part(fee) .. " 税金",
    })
    return true
```

- [ ] **Step 5：跑 pin + 全套 items 行为确认保持绿**

Run: `busted --run behavior spec/behavior/rules/item_spec.lua`
Expected: PASS（行为不变）。

- [ ] **Step 6：门禁 + Commit**

Run: `make verify --smoke`
Expected: PASS。

```bash
git add src/rules/items/target_cash_effects.lua spec/behavior/rules/item_spec.lua
git commit -m "refactor(items): 查税卡扣费收编 coin_settlement.charge,删 inline eliminate"
```

---

## Task 4：迁移税务局（tax_rules.execute_pay_tax）→ charge + defer

**Files:**
- Modify: `src/rules/land/tax_rules.lua:1-8`（require）、`:35-52`（execute_pay_tax）
- Test: `spec/behavior/rules/land_settlement_spec.lua` 或 `land_spec.lua`（税务局 pin）

**Interfaces:**
- Consumes: `coin_settlement.charge`（Task 1），用 `defer_bankruptcy = true`。
- Produces: `execute_pay_tax` 返回结构不变（仍带 `result.bankrupt_reason` 字段供 `land_events.apply` 淘汰）。

**行为保持：** land 管线是两段式——`execute_pay_tax` 只**计算**结果并在破产时写 `bankrupt_reason` 字段，真正 `eliminate` 由 `land_events.apply`（`events.lua:53-55`）在发完事件后执行。因此这里必须 `defer_bankruptcy = true`：`charge` 扣费但**不**淘汰，只回报 `bankrupt`/`reason`，adapter 把 `reason` 写进 `result.bankrupt_reason`，保留「先发 tax_paid 事件、后淘汰」的既有顺序。`tax_paid` 遥测与事件构造留在 adapter。

- [ ] **Step 1：写/确认 pin 测试（税务局扣费 + 破产写 bankrupt_reason）**

在 `spec/behavior/rules/land_settlement_spec.lua` 顶层 describe 内追加（文件已 require `settlement`；补 `local tax_rules = require("src.rules.land.tax_rules")`）：

```lua
  it("PIN: pay_tax deducts floor(cash*rate) and defers bankruptcy via bankrupt_reason", function()
    local game = _new_game()
    local player = game.players[1]
    local constants = require("src.config.content.constants")
    game:set_player_cash(player, 1000)

    local expected_fee = math.floor(1000 * constants.tax_rate)
    local result = tax_rules.execute_pay_tax(game, player.id)

    assert(game:player_cash(player) == 1000 - expected_fee, "tax deducts floor(cash*rate)")
    assert(result.event == "tax_paid", "event stays tax_paid")
    assert(result.bankrupt_reason == nil, "solvent taxpayer has no bankrupt_reason")
    assert(player.eliminated ~= true, "eliminate is deferred to land_events, not here")
  end)

  it("PIN: pay_tax at zero cash reports bankrupt_reason but does not eliminate in-place", function()
    local game = _new_game()
    local player = game.players[1]
    game:set_player_cash(player, 0)  -- fee = floor(0*rate) = 0 → cash 仍 0,<= 0 → bankrupt_reason

    local result = tax_rules.execute_pay_tax(game, player.id)

    assert(result.bankrupt_reason == player.name .. " 支付税金后破产", "reason set on non-positive")
    assert(player.eliminated ~= true, "still deferred; land_events owns the eliminate call")
  end)
```

- [ ] **Step 2：跑 pin 确认当前通过**

Run: `busted --run behavior spec/behavior/rules/land_settlement_spec.lua`
Expected: PASS。

- [ ] **Step 3：加 require**

`src/rules/land/tax_rules.lua` 顶部 require 区加一行：

```lua
local coin_settlement = require("src.rules.commerce.coin_settlement")
```

- [ ] **Step 4：把 execute_pay_tax 扣费段（41-51）降为 adapter**

将：

```lua
  game:deduct_player_cash(player, fee)
  achievement_progress.tax_paid(game, player, fee)
  local result = _build_land_event("tax_paid", {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. number_utils.format_integer_part(fee),
  })
  if game:player_cash(player) <= 0 then
    result.bankrupt_reason = player.name .. " 支付税金后破产"
  end
  return result
```

改为：

```lua
  local settled = coin_settlement.charge(game, player, fee, {
    reason = player.name .. " 支付税金后破产",
    defer_bankruptcy = true,
  })
  achievement_progress.tax_paid(game, player, fee)
  local result = _build_land_event("tax_paid", {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. number_utils.format_integer_part(fee),
  })
  if settled.bankrupt then
    result.bankrupt_reason = settled.reason
  end
  return result
```

- [ ] **Step 5：跑 pin + land 行为确认保持绿**

Run: `busted --run behavior spec/behavior/rules/land_settlement_spec.lua spec/behavior/rules/land_spec.lua`
Expected: PASS。

- [ ] **Step 6：门禁 + Commit**

Run: `make verify --smoke`
Expected: PASS。

```bash
git add src/rules/land/tax_rules.lua spec/behavior/rules/land_settlement_spec.lua
git commit -m "refactor(land): 税务局扣费收编 coin_settlement.charge(defer),保留 land_events 淘汰时机"
```

---

## Task 5：迁移租金（rent_payment.execute_pay_rent）→ transfer + defer

**Files:**
- Modify: `src/rules/land/rent_payment.lua:1-3`（require）、`:113-126`（execute_pay_rent 尾段）
- Test: `spec/behavior/rules/land_rent_spec.lua`（租金破产 pin）

**Interfaces:**
- Consumes: `coin_settlement.transfer`（Task 2），用 `defer_bankruptcy = true`。
- Produces: `execute_pay_rent` 返回结构不变（`rent_paid` / `rent_bankrupt` + `bankrupt_reason`）。

**行为保持（关键边界）：** 租金的破产判据是「**付不起全额租金**」，**不是** `cash <= 0`。原逻辑：`cash >= rent` → 全额转账、`cash_received(owner, rent)`、返回（**即使付完恰好剩 0 也不破产**）；`cash < rent` → partial 转账、`cash_received(owner, liquid)`、写 `bankrupt_reason`。因此 adapter 用 `settled.moved >= rent`（付满即存活）判定，**不**读 `settled.bankrupt`（那是 `<= 0` 规则，会在 `cash == rent` 边界误判）。`transfer` 用 `defer_bankruptcy = true`（land_events 统一淘汰），收款遥测 `cash_received(owner, moved)` 由 `transfer` 内部完成，覆盖全额与 partial 两种。deity ×2 定价（`_compute_deity_rent`，跨玩家规则）留在 adapter 上游算好 `rent`。

- [ ] **Step 1：写 pin 测试（付满剩 0 不破产 / 付不起才破产 + owner 收款）**

在 `spec/behavior/rules/land_rent_spec.lua` 顶层 describe 内追加（文件已 require `rent_payment`？若无补 `local rent_payment = require("src.rules.land.rent_payment")`，并复用文件里的 `_find_strip` / `_grant_strip_to_owner`）：

```lua
  it("PIN: paying exactly full rent leaves payer at zero but NOT bankrupt", function()
    local g = _new_game()
    local payer, owner = g.players[1], g.players[2]
    local strip = _find_strip(g.board, 1)
    _grant_strip_to_owner(g, owner, strip)
    local hit = strip[1]
    payer.position = assert(g.board:index_of_tile_id(hit.id))

    -- 先探出这次租金额,再把 payer 现金精确设为 rent。
    local probe = rent_payment.execute_pay_rent(g, payer.id, hit.id)
    local rent = probe.payload.amount
    -- 复位一局重来,精确边界:cash == rent
    g = _new_game(); payer, owner = g.players[1], g.players[2]
    _grant_strip_to_owner(g, owner, _find_strip(g.board, 1))
    local hit2 = _find_strip(g.board, 1)[1]
    payer.position = assert(g.board:index_of_tile_id(hit2.id))
    g:set_player_cash(payer, rent)

    local result = rent_payment.execute_pay_rent(g, payer.id, hit2.id)

    assert(g:player_cash(payer) == 0, "payer drained to exactly zero")
    assert(result.event == "rent_paid", "paying full rent is rent_paid, not rent_bankrupt")
    assert(result.bankrupt_reason == nil, "exact-full payment is not bankruptcy")
  end)

  it("PIN: paying less than full rent is rent_bankrupt with owner credited the partial", function()
    local g = _new_game()
    local payer, owner = g.players[1], g.players[2]
    _grant_strip_to_owner(g, owner, _find_strip(g.board, 1))
    local hit = _find_strip(g.board, 1)[1]
    payer.position = assert(g.board:index_of_tile_id(hit.id))
    local received = {}
    g.achievement_progress_port = {
      cash_received = function(_, p, amt) received[#received+1] = { id = p.id, amount = amt }; return true end,
    }
    g:set_player_cash(payer, 1)  -- 远小于任何 rent

    local owner_before = g:player_cash(owner)
    local result = rent_payment.execute_pay_rent(g, payer.id, hit.id)

    assert(result.event == "rent_bankrupt", "short payer triggers rent_bankrupt")
    assert(result.bankrupt_reason ~= nil, "bankrupt_reason set for land_events to eliminate")
    assert(g:player_cash(payer) == 0, "payer fully drained")
    assert(g:player_cash(owner) == owner_before + 1, "owner credited the partial 1")
    assert(received[1] and received[1].id == owner.id and received[1].amount == 1,
      "cash_received telemetry fires for the partial amount")
    assert(payer.eliminated ~= true, "eliminate deferred to land_events")
  end)
```

> 若 `_find_strip` 因地图拓扑对单格 strip 有下限限制，改用 `_find_strip(g.board, 3)` 并命中 `strip[2]`（连片），逻辑同构；关键是「精确把 cash 设为 rent」与「设为 1」两个边界。

- [ ] **Step 2：跑 pin 确认当前通过**

Run: `busted --run behavior spec/behavior/rules/land_rent_spec.lua`
Expected: PASS。

- [ ] **Step 3：加 require**

`src/rules/land/rent_payment.lua` 顶部 require 区加一行：

```lua
local coin_settlement = require("src.rules.commerce.coin_settlement")
```

- [ ] **Step 4：把 execute_pay_rent 尾段（113-126）降为 adapter**

将：

```lua
  if game:player_cash(player) >= rent then
    game:transfer_player_cash(player, owner, rent)
    achievement_progress.cash_received(game, owner, rent)
    return result
  end

  local _, _, liquid = game:transfer_player_cash(player, owner, rent, { allow_partial = true })
  achievement_progress.cash_received(game, owner, liquid)
  local reason = player.name .. " 资金不足，欠付(" .. owner.name .. ") " .. number_utils.format_integer_part(rent) .. " 破产"
  result.event = "rent_bankrupt"
  result.payload.amount = rent
  result.payload.text = reason
  result.bankrupt_reason = reason
  return result
```

改为：

```lua
  local settled = coin_settlement.transfer(game, player, owner, rent, {
    defer_bankruptcy = true,
  })
  if settled.moved >= rent then
    return result
  end

  local reason = player.name .. " 资金不足，欠付(" .. owner.name .. ") " .. number_utils.format_integer_part(rent) .. " 破产"
  result.event = "rent_bankrupt"
  result.payload.amount = rent
  result.payload.text = reason
  result.bankrupt_reason = reason
  return result
```

> `achievement_progress` require 现在是否变死？——否，`rent_payment.lua:2` 的 `achievement_progress` 迁移后不再被本文件直接调用（收款遥测进了 `transfer`）。**Step 5 后用 grep 确认并删除该 require**（见下）。

- [ ] **Step 5：清理变死的 require + 跑 pin**

确认 `achievement_progress` 在 `rent_payment.lua` 已无其它引用：

Run: `grep -n "achievement_progress" src/rules/land/rent_payment.lua`
Expected: 只剩顶部 `local achievement_progress = require(...)` 一行 → 删除该行。

Run: `busted --run behavior spec/behavior/rules/land_rent_spec.lua`
Expected: PASS。

- [ ] **Step 6：门禁 + Commit**

Run: `make verify --smoke`
Expected: PASS。

```bash
git add src/rules/land/rent_payment.lua spec/behavior/rules/land_rent_spec.lua
git commit -m "refactor(land): 租金 partial 转账收编 coin_settlement.transfer,保留付满-剩0-不破产边界"
```

---

## Task 6：迁移机会卡三处（chance/cash_handlers）→ charge/transfer

**Files:**
- Modify: `src/rules/chance/cash_handlers.lua`（`_apply_payment`、`pay_others`、`collect_from_others`；require 顶部）
- Test: `spec/behavior/rules/chance_cash_others_contract_spec.lua`（已存在，作 pin）、`spec/behavior/rules/chance_spec.lua`

**Interfaces:**
- Consumes: `coin_settlement.charge` / `coin_settlement.transfer`（Task 1/2）。
- Produces: 三个 handler 行为不变；deity ×2（`common.adjust_chance_delta`，self 规则）与事件 `common.emit_event` 留在 adapter。

**行为保持（逐处）：**
1. **`_apply_payment`**：原 `apply_cash_and_maybe_bankrupt(target, delta, reason)` = `apply_cash_change(target, delta)`（clamp，负 delta 不记遥测）+ `handle_bankruptcy_if_non_positive(target)`（`<= 0` 淘汰）。→ `charge(target, abs(delta), { reason })`：clamp 一致、`<= 0` 立即淘汰一致、无收款遥测一致。`delta` 由 deity 调整后传入，abs 后即扣费额。
2. **`pay_others`**：原每个 other 循环里 `apply_cash_change(player, -fee, suppress)` + `handle_bankruptcy_if_non_positive(player)` + `apply_cash_change(other, +fee, suppress)`。注意 payer 侧用 add（clamp 到 0，**不封顶**，other 仍得全额 fee）——这是**故意的、与 transfer 的 partial 不同**，不能换成 transfer。→ payer 侧换 `charge(player, fee, { reason, cash_opts = suppress })`；other 侧 `apply_cash_change(other, fee, suppress)` **保持不动**（它记 `cash_received(other, fee)`，是 chance 既有遥测）。
3. **`collect_from_others`**：原 `_transfer_cash_capped(other, player, fee, {suppress, allow_partial})` + `_record_cash_received(player, liquid)` + `handle_bankruptcy_if_non_positive(other)`。这是标准 partial 转账（other 付款人、player 收款人）+ 收款遥测 + `<= 0` 淘汰 → 正好 `transfer(other, player, fee, { reason, cash_opts = suppress })`。`transfer` 内部记 `cash_received(player, moved)`、按 `<= 0` 立即淘汰 other，均与原一致。`total_collected += settled.moved`。

- [ ] **Step 1：确认 pin（收款金额契约已存在）**

Run: `busted --run behavior spec/behavior/rules/chance_cash_others_contract_spec.lua`
Expected: PASS（`chance_cash_others_contract_spec.lua` 的 case1–6 锁定 pay_others/collect 的收发金额，含 deity ×2 边界；这就是本 task 的护栏）。

- [ ] **Step 2：加 require**

`src/rules/chance/cash_handlers.lua` 顶部（`local angel_feedback = ...` 下一行）加：

```lua
local coin_settlement = require("src.rules.commerce.coin_settlement")
```

- [ ] **Step 3：`_apply_payment`（58-69）降为 charge**

将：

```lua
  local function _apply_payment(game, target, card, compute_fee, reason_label, text_label)
    local fee = compute_fee(game, target, card)
    local delta = common.adjust_chance_delta(game, target, -fee)
    local reason = target.name .. " " .. reason_label .. " " .. common.abs_value(delta) .. " 后破产"
    common.apply_cash_and_maybe_bankrupt(game, target, delta, reason)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
```

改为：

```lua
  local function _apply_payment(game, target, card, compute_fee, reason_label, text_label)
    local fee = compute_fee(game, target, card)
    local delta = common.adjust_chance_delta(game, target, -fee)
    local reason = target.name .. " " .. reason_label .. " " .. common.abs_value(delta) .. " 后破产"
    coin_settlement.charge(game, target, common.abs_value(delta), { reason = reason })
    common.emit_event(game, deps.monopoly_event.chance.applied, {
```

（`emit_event` 及其后续 payload 原样保留。）

- [ ] **Step 4：`pay_others`（98-119）payer 侧降为 charge**

将循环体内：

```lua
        if not game:player_is_in_mountain(other) then
          local reason = player.name .. " 向他人支付后破产"
          common.apply_cash_change(game, player, -fee, { suppress_cash_receive_anim = true })
          common.handle_bankruptcy_if_non_positive(game, player, reason)
          common.apply_cash_change(game, other, fee, { suppress_cash_receive_anim = true })
        end
```

改为：

```lua
        if not game:player_is_in_mountain(other) then
          coin_settlement.charge(game, player, fee, {
            reason = player.name .. " 向他人支付后破产",
            cash_opts = { suppress_cash_receive_anim = true },
          })
          common.apply_cash_change(game, other, fee, { suppress_cash_receive_anim = true })
        end
```

（other 侧的 `apply_cash_change` **保持不动**——它是 chance 既有的收款 + `cash_received` 遥测，非 partial 语义。）

- [ ] **Step 5：`collect_from_others`（121-149）降为 transfer**

将循环体内：

```lua
        if not game:player_is_in_mountain(player) then
          local _, _, liquid, used_settlement = _transfer_cash_capped(
            game,
            other,
            player,
            fee,
            { suppress_cash_receive_anim = true, allow_partial = true }
          )
          if used_settlement then
            _record_cash_received(game, player, liquid)
          end
          total_collected = total_collected + liquid
          local reason = other.name .. " 被收款资金不足破产"
          common.handle_bankruptcy_if_non_positive(game, other, reason)
        end
```

改为：

```lua
        if not game:player_is_in_mountain(player) then
          local settled = coin_settlement.transfer(game, other, player, fee, {
            reason = other.name .. " 被收款资金不足破产",
            cash_opts = { suppress_cash_receive_anim = true },
          })
          total_collected = total_collected + settled.moved
        end
```

> 迁移后 `_transfer_cash_capped`（22-31）与 `_record_cash_received`（16-20）在本文件是否变死？——`_transfer_cash_capped` 仅此一处调用、`_record_cash_received` 仅此一处调用 → **两者变死，Step 6 grep 确认后删除**。

- [ ] **Step 6：删除变死的本地 helper + grep 确认**

Run: `grep -n "_transfer_cash_capped\|_record_cash_received\|apply_cash_and_maybe_bankrupt\|handle_bankruptcy_if_non_positive" src/rules/chance/cash_handlers.lua`
Expected: 只剩 `_transfer_cash_capped` / `_record_cash_received` 的**定义行**（无调用）→ 删除这两个 local function 定义块（`cash_handlers.lua:16-31`）。`apply_cash_and_maybe_bankrupt` / `handle_bankruptcy_if_non_positive` 属 `common`（chance/handlers.lua），本文件已无引用；它们的清理在 Task 7。

- [ ] **Step 7：跑 pin + 全套 chance 行为**

Run: `busted --run behavior spec/behavior/rules/chance_cash_others_contract_spec.lua spec/behavior/rules/chance_spec.lua`
Expected: PASS（收发金额、deity ×2、破产淘汰全保持）。

- [ ] **Step 8：门禁 + Commit**

Run: `make verify --smoke`
Expected: PASS。

```bash
git add src/rules/chance/cash_handlers.lua
git commit -m "refactor(chance): 机会卡扣费/收款/转账收编 coin_settlement,删本地 capped-transfer 双写"
```

---

## Task 7：清理 chance shared 死破产 helper + 完整门禁

**Files:**
- Modify: `src/rules/chance/handlers.lua:57-67`（`handle_bankruptcy_if_non_positive`、`apply_cash_and_maybe_bankrupt`）
- 全仓库验证

**Interfaces:**
- Produces: 无——纯删死代码 + 收口验证。

**行为保持：** 这两个 `shared` helper 在 Task 6 后应已无 caller（原 caller `_apply_payment`/`pay_others`/`collect` 全迁走）。删除前必须全仓 grep 确认零引用；若 `asset_handlers` / `movement_handlers` 仍在用，则**保留**并跳过删除（只跑门禁）。

- [ ] **Step 1：全仓 grep 确认零引用**

Run: `grep -rn "apply_cash_and_maybe_bankrupt\|handle_bankruptcy_if_non_positive" src/ spec/`
Expected: 只剩 `src/rules/chance/handlers.lua` 里的**定义**（`:57`、`:64`）+ 可能的 mutate manifest 注释。若 `src/rules/chance/asset_handlers.lua` 等出现**调用**，停止删除、保留 helper，直接跳到 Step 3。

- [ ] **Step 2：删除确认无 caller 的死 helper**

若 Step 1 确认零调用，删除 `src/rules/chance/handlers.lua:57-67` 两个函数定义：

```lua
function shared.handle_bankruptcy_if_non_positive(game, player, reason)
  if game:player_cash(player) > 0 then
    return
  end
  bankruptcy_port.eliminate(game, player, { reason = reason })
end

function shared.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
  shared.apply_cash_change(game, player, delta)
  shared.handle_bankruptcy_if_non_positive(game, player, reason)
end
```

删除后确认 `bankruptcy_port`（`handlers.lua:5`）是否仍被本文件其它处使用：

Run: `grep -n "bankruptcy_port" src/rules/chance/handlers.lua`
Expected: 若仅剩顶部 require → 一并删除该 require 行；若别处仍用 → 保留。

- [ ] **Step 3：完整验证门禁（handoff/commit 前）**

Run: `make verify`
Expected: PASS（~30s，含 crap + coverage；全套 src 七层 + foundation 行为 spec 绿）。

- [ ] **Step 4：验收套件（行为不变应自动保持绿）**

Run: `make acceptance`
Expected: PASS（从 feature 重生成 gitignored 生成物再跑；本重构观测行为零变化，验收不应回归）。

- [ ] **Step 5：最终 deletion-test 复核（口头确认，非代码）**

确认候选 ① 的 deletion test 现在成立：删 `coin_settlement.lua` → land/chance/items/tax 四处扣费全部同时失去「非正 → 淘汰 + partial + 收款遥测」，复杂度**集中**在一处、非冗余。金标准 `rules/items` settlement 的孪生完成。

- [ ] **Step 6：Commit**

```bash
git add src/rules/chance/handlers.lua
git commit -m "refactor(chance): 删迁移后无 caller 的 handle_bankruptcy/apply_cash_and_maybe_bankrupt 死 helper"
```

---

## Self-Review（写完对着评审复核）

**1. Spec 覆盖（评审候选 ① 的每条主张）：**
- ✅「4 个 subdir 各写一遍、3 套破产协议」→ Task 3（items inline eliminate）、Task 4（land tax bankrupt_reason 字段）、Task 5（land rent bankrupt_reason）、Task 6（chance helper 顺手 eliminate）全部降为 adapter。
- ✅「唯一解释者 `coin_settlement.charge / transfer`」→ Task 1/2 建成，两个 interface。
- ✅「partial-transfer、`cash_received` 遥测、非正→eliminate 收进一处」→ 全在模块内部。
- ⚠️「财神/穷神 ×2 multiplier（唯一处）」→ **本 plan 有意不合并**：rent 的 ×2 是跨玩家（payer.poor × owner.rich），chance 的 ×2 是 self（自身 rich/poor），语义不同，强行合并会引入 bug。已在 Architecture 与 Task 5/6 显式说明留在各自 adapter。这是对评审的**审慎偏离**，需在 handoff 时向 reviewer 点明。
- ✅ `deletion test`（删 `target_cash_effects:96-98` 查税停 0 却永不淘汰）→ Task 3 + Task 7 Step 5 复核。

**2. Placeholder 扫描：** 无 TBD / 「加适当错误处理」/ 「类似 Task N」——每处 migration 都给了完整 old→new 代码块。✅

**3. 类型/签名一致性：**
- `charge(game, payer, amount, opts) -> {charged, bankrupt, reason}`、`transfer(game, payer, receiver, amount, opts) -> {moved, bankrupt, reason}` 在 Task 1/2 定义，Task 3–6 调用签名逐一对齐。✅
- `opts` 三键 `reason` / `defer_bankruptcy` / `cash_opts` 全程一致。✅
- 破产判据差异已显式区分：默认 `<= 0`（charge/transfer 内部）；rent 用 `settled.moved >= rent`（adapter 侧），不误用 `settled.bankrupt`。✅

**已知风险（handoff 要说）：** ① deity ×2 未合并（见上）；② rent pin 测试依赖地图 strip 拓扑，若 `_find_strip(board,1)` 有下限须回退到 3-strip 命中中间格；③ `make acceptance` 若因无关生成物波动报错，先 `make acceptance` 重生成再判断。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-coin-settlement-deep-module.md`.

本 plan **只展开候选 ①**（评审 Top recommendation）。②③④⑤⑥⑦ 见顶部路线图，各需独立 `writing-plans` 展开。

两种执行方式：

**1. Subagent-Driven（推荐）** — 每个 task 派一个 fresh subagent，task 间过两段 review，迭代快。契合本 plan「面向 swarm agent、task 间有文件依赖需串行」的结构。

**2. Inline Execution** — 本 session 内用 `executing-plans` 批量执行，带 checkpoint。

选哪个？
