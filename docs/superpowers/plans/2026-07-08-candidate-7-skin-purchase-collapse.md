# 候选 ⑦ 皮肤购买 —— 折叠死适配器 skin_purchase，删复活的 on_success 闭包

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐 task 执行。步骤用 `- [ ]` 复选框跟踪。**每个 task 由一个 fresh subagent 独立完成，做完过一轮 review 再进下一个。本候选是删除/折叠型，task 间有硬串行依赖（pin → unwire → delete），按编号顺序执行，不要并行。** 见下方「并行执行编排」的诚实评估。

**Goal:** 删掉 `src/app/host_integrations/skin_purchase.lua`（含它复活的 UI `on_success` 闭包），并让 `host_install` 停止把皮肤交易流程 wire 到 `skin_panel.configure_purchase`。`transaction_purchase` **自带的原生 paid 路径**（`_start_via_paid_port` + `_purchase_entry`，目前是死代码）在生产中接管——皮肤付费购买的观测行为逐点不变。总逻辑**减少**：重复的 entry-builder 与一跳 on_success 闭包消失。

**Architecture:** 这是**补齐 ADR 0021 已裁定之事**，不是重开设计。ADR 0021 §Adapter 明文：「`skin_purchase.lua` 应被折叠为 transaction implementation 内部 adapter，或保留为很薄的 paid-purchase adapter。**它不再接受 UI 传入的 `on_success` fulfillment callback**」；「`host_install.lua` 只安装 adapters……**它不把多段交易流程直接接在 `skin_panel.configure_*` 上**」。代码漂回了旧形态：`skin_purchase.start` 仍收 `on_success`（:98），`_on_purchase_success` 仍在 pcall 包 UI 闭包（:32），`host_install:108` 仍 `skin_purchase.configure(skin_panel)`。因为 `transaction_purchase` **早已内建**一条 ADR-compliant 的原生 paid 路径（`_purchase_entry` 内部直接调 `complete_purchase`，无 UI 闭包），本候选 = 删掉旧 wiring，让原生路径接管。

**Tech Stack:** Lua 5.4；busted（行为 spec，`spec/behavior/app/`）；清洁架构七层——改动落在 `app`（host_install / host_integrations）与其行为 spec，**不碰** `rules` / `ui` / `host`。

## Global Constraints

- 命名 `snake_case`，类名 `CamelCase`。
- `src/` 禁用 `tonumber` / `type(x) == "number"`，用 `NumberUtils`（`src.foundation.number`）。本候选是删除 + 去 wiring，不新增数字判定。
- **这是删除/折叠型重构，皮肤付费购买的观测行为零变化**（见各 task「行为保持」小节，对照真实 pin）。
- 迭代门禁 `make verify`（本仓库 verify 即完整门禁，~7-8s）；**每个 task 结尾都跑它**。
- 单文件行为 spec：`busted --run behavior spec/behavior/app/<file>_spec.lua`。
- 验收 `make acceptance`（先从 feature 重生成 gitignored 生成物再跑）。**`skin_shop` / `skin_persistence` 验收在套件里**——但它们 wire **自己的** `configure_purchase`（见下「探源实况」），不经 `skin_purchase`，故本候选不应回归验收。
- manifest 刷新用 `lua tools/quality/mutate.lua <file> --update-manifest`（只动文件底部 `--[[ mutate4lua-manifest ]]` 注释块）。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`（生成物）。
- 每个 task 结尾 gate + commit。无占位符。

---

## 候选 ⑦ 全貌与分期（务必先读——探源实况，已用 grep 核对调用链）

评审说「deletion test 直接通过」，属实——但**评审对『死代码是哪条』的表述要精确**，否则会删错东西。以下每条都已核对真实源码：

### 1. 复活的 on_success 闭包 —— 真实，就在 `skin_purchase.lua`

- `skin_purchase.lua:32-45` `_on_purchase_success(on_success, skin)`：pcall 包一层 UI 传入的 `on_success`，返回给 paid entry 的 `on_purchase`。
- `skin_purchase.lua:47-56` `_entry_for_skin(skin, on_success)`：把 skin 拼成 paid entry，`on_purchase = _on_purchase_success(on_success, skin)`。
- `skin_purchase.lua:98` `skin_purchase.start(state, role_id, skin, on_success)`：**签名收 UI `on_success`**。
- `skin_purchase.lua:108` `pcall(paid_purchase_port.start, game, player, _entry_for_skin(skin, on_success))`。
- `skin_purchase.lua:116-120` `skin_purchase.configure(skin_panel)` → `skin_panel.configure_purchase(fn)`，fn 转发 `on_success` 到 `skin_purchase.start`。

**这正是 ADR 0021 §Adapter 明令退役的形态**（「不再接受 UI 传入的 `on_success` fulfillment callback」）。评审无夸大。

### 2. `transaction_purchase` 自己的 paid 路径确是**死代码**（生产不可达）

调用链（已 grep 核对）：

```
transaction_actions.lua:75  purchase.start(root_state, panel, role_id, skin, complete_skin_purchase)
  └─ transaction_purchase.start(:151)
       └─ _start_request(:142)
            ├─ _start_via_legacy_adapter(:55)   ← 先试这条
            │    adapter = transaction_context.purchase_adapter()   (:56)
            │    若 adapter 非 nil → 调它 → 返回非 nil started → _start_request 提前返回
            └─ _start_via_paid_port(:40)         ← 原生路径，仅当 legacy 返回 nil,nil 才到达
                 entry = _purchase_entry(...)     (:147, :23 内部直接调 complete_purchase)
```

`purchase_adapter` 在**生产**中由谁 wire？唯一链条（grep 确认）：

```
host_install.lua:108  skin_purchase.configure(skin_panel)
  └─ skin_panel.configure_purchase(fn)                     (skin_purchase.lua:117)
       └─ transaction.configure_purchase(fn)               (skin_panel.lua:110)
            └─ transaction_context.configure_purchase(fn)  (transaction.lua:43)
                 └─ state.purchase_adapter = fn            (transaction_context.lua:80)
```

因此**生产中 `purchase_adapter` 恒非 nil**（= 转发到 `skin_purchase.start` 的闭包），`_start_via_legacy_adapter` 恒胜，`_start_via_paid_port` + `_purchase_entry` **永不执行**。评审「module 自己的 paid 路径成了死代码」属实。

### 3. 折叠后原生路径接管，观测行为逐点不变（关键：`source` 字段被丢弃）

删 `skin_purchase` + 去 `host_install` wiring 后，生产中 `purchase_adapter == nil` → `_start_via_legacy_adapter` 返回 `nil, nil` → `_start_request` 落到 `_start_via_paid_port` → 原生 `_purchase_entry`。两条路径的**唯一差异**：

| | legacy 路径（现状） | 原生路径（折叠后） |
|---|---|---|
| entry.on_purchase 来源 | `skin_purchase._on_purchase_success` 包 `_start_via_legacy_adapter` 的 on_success（`transaction_purchase.lua:61`） | `_purchase_entry.on_purchase`（`transaction_purchase.lua:30`） |
| 履约调用 | `complete_purchase(..., { source = "purchase_callback" })` | `complete_purchase(..., { source = "paid_purchase" })` |
| pcall 包裹 | skin_purchase 多包一层 pcall（UI 闭包防御） | 无（内部调用，返回结构化结果） |

**`source` 字段是否可观测？——否。** 已核对：`transaction.complete_skin_purchase(state, role_id, product_id)`（`transaction.lua:14`）与 `actions.complete_skin_purchase(root_state, role_id, product_id)`（`transaction_actions.lua:205`）→ `completion.complete_skin_purchase(root_state, role_id, product_id)`（`transaction_completion.lua:31`）**全是 3 参签名，`context`/`source` 表根本没被接收**。故 `source = "purchase_callback"` vs `"paid_purchase"` 是**被丢弃的字段，零观测差异**。pcall 那层差异只在「UI 闭包抛错」这种病理场景才有别，而原生路径根本没有 UI 闭包（`on_purchase` 直接调内部 `complete_purchase`）——这正是 ADR 想要的简化。

### 4. 死代码 `_start_via_legacy_adapter` 本身**保留**，不在本候选删除范围

评审说「折叠」，但**别顺手删掉 `transaction_purchase._start_via_legacy_adapter` 与整条 `configure_purchase` seam**——它们不是 `skin_purchase` 的重复，而是通用 seam，被真实 pin 钉住：

- `cosmetics_transaction_spec.lua:329` `locked_purchase_rejects_legacy_adapter_failure_paths`：configure 一个抛错/返 false 的 adapter，断言 `purchase_callback_failed` / `purchase_callback_rejected`（reason 仅出自 `_start_via_legacy_adapter:73,78`）。
- `cosmetics_transaction_spec.lua:362` `locked_purchase_legacy_adapter_completion_uses_on_success_status`：configure 一个同步调 `on_success()` 的 adapter，断言 `purchase_complete`。
- **验收** `tools/acceptance/steps/skin_shop.lua:337,346`：付费购买步骤 wire **自己的** `skin_panel.configure_purchase(function(_, _, on_success) on_success() end)`——不经 `skin_purchase`。

所以 legacy seam 删除后生产不可达、但被 spec + 验收钉住，属于**独立的、更大的**重构（要迁移 `skin_panel_spec` ~10 处 configure_purchase + 2 处 cosmetics_transaction_spec legacy 用例 + 验收 step）。**本候选只删 `skin_purchase` 这一层 wiring**，legacy seam 原样保留。这是对评审「折叠」的**审慎收窄**：`skin_purchase` 折叠 = 删除（其职责 `_purchase_entry` 已在 `transaction_purchase` 内），legacy seam 是另一个话题。

**分期结论：本候选 = 单一 Level A 折叠（删 skin_purchase + 去 host_install wiring），完整可执行、零观测行为变化、验收不回归。** 无 Level B（删 legacy seam）——那需另开 `writing-plans`，文末给入口。

---

## 探源确证清单（写代码前 subagent 应复读，全部已核对）

- ✅ `skin_purchase.lua` 的 on_success 闭包在 :32 / :98 / :108 / :117——真实。
- ✅ `transaction_purchase._start_via_legacy_adapter`（:55-81）先于 `_start_via_paid_port`（:40-53）被 `_start_request`（:142-149）尝试。
- ✅ legacy 确实 wire 到 `skin_purchase.start`（`host_install:108` → `skin_panel.configure_purchase` → `transaction_context.purchase_adapter`）。
- ✅ `host_install.lua:11`（require）+ `:108`（configure 调用）是 `skin_purchase` 的唯一生产引用。
- ✅ 全仓 `require`/调用 `skin_purchase` 者：仅 `host_install.lua`（生产）+ `spec/behavior/app/skin_purchase_spec.lua`（模块直测）。折叠后无悬空引用。
- ✅ `complete_skin_purchase` 是 3 参签名，丢弃 `source` context → legacy/原生 zero 观测差异。
- ✅ pin：`cosmetics_transaction_spec.lua:379` `complete_skin_purchase_rejects_duplicate_or_mismatched_callback` **不 configure_purchase**（`before_each` 调 `transaction.reset_for_tests()` 把 `purchase_adapter` 清 nil），因此它**已经**在跑原生 `_start_via_paid_port` 路径 + `captured.on_purchase()` 履约——**这就是折叠后生产路径，现状已绿**。
- ✅ 验收 `skin_shop` / `skin_persistence` wire 自己的 `configure_purchase`，不经 `skin_purchase` → `make acceptance` 不受影响。

---

## File Structure

**删除：**
- `src/app/host_integrations/skin_purchase.lua`（含其 mutation manifest）
- `spec/behavior/app/skin_purchase_spec.lua`（该 module 的直测——module 删了，测试随之删）

**修改：**
- `src/app/host_install.lua`：删 `:11` require、删 `:108` `skin_purchase.configure(skin_panel)`；刷新 manifest。
- `spec/behavior/app/cosmetics_transaction_spec.lua`：**新增**一个 pin，锁「原生 paid 路径把 skin 拼成 paid entry 并履约」的观测行为（Task 1）。

**保持不变（护栏，勿删勿改）：**
- `src/app/cosmetics/transaction_purchase.lua`——**本候选一字不改**。原生 `_start_via_paid_port` + `_purchase_entry` 早已在场，折叠只是让它在生产可达。legacy `_start_via_legacy_adapter` 保留（被 spec + 验收钉）。
- `src/ui/coord/skin_panel.lua`、`src/app/cosmetics/transaction*.lua`（除新增 pin 的 spec）、`src/host/paid_purchase_gateway.lua`。
- `tools/acceptance/steps/skin_shop.lua`、`features/v102/skin_shop.feature`、`features/v102/skin_persistence.feature`。

---

## 并行执行编排（诚实评估：本候选**基本串行**，无并行收益）

```
 Task 1  pin 原生 paid 路径观测行为   (cosmetics_transaction_spec)
    │  必须先绿（characterization 基线）
    ▼
 Task 2  去 host_install wiring       (host_install.lua)
    │  翻转生产到原生路径；此后 skin_purchase 仅剩自测引用
    ▼
 Task 3  删 skin_purchase + 其 spec + 刷 host_install manifest + 完整门禁 + 验收
```

**为何不能并行（硬串行依赖）：**

1. **Task 1 → Task 2**：Task 2 去掉 wiring 会把生产切到原生路径。**必须先有 Task 1 的 pin 钉死原生路径观测行为**（characterization），否则切换后无护栏。这是 TDD 纪律，不是文件冲突。
2. **Task 2 → Task 3**：`skin_purchase.lua` 被 `host_install.lua:11` require。**若先删 `skin_purchase.lua`，`host_install` 加载即报 `module not found`**——`make verify` 直接崩。必须**先**在 Task 2 去掉 require + 调用，**再**在 Task 3 删文件。顺序不可交换。

**冲突矩阵（照候选 ③ 结构；此处证明的是『无独立并行分片』）：**

| | 改/删的文件 | 依赖前一 task 产出？ | 可与他 task 并行？ |
|---|---|---|---|
| Task 1 | `spec/behavior/app/cosmetics_transaction_spec.lua`（+pin） | 否（基线） | 否——Task 2/3 语义上须等它绿 |
| Task 2 | `src/app/host_install.lua`（删 2 行） | 是（等 Task 1 pin 绿） | 否——删文件前必须先去 require |
| Task 3 | 删 `skin_purchase.lua` + `skin_purchase_spec.lua`；刷 `host_install` manifest | 是（等 Task 2 去 wiring） | 否——依赖 Task 2 |

**结论：不开 worktree、不 fan-out。** 单一工作树里顺序 1→2→3。本候选面极小（一个 pin + 删两文件 + 去两行 wiring），并行 orchestration 无壁钟收益，反而 Task 2/3 的 require 依赖会让并发 subagent 在中间态撞 `make verify` 崩溃。**唯一可分离的动作**是 Task 1 的 pin 与 Task 3 的最终验收，但它们被 characterization 纪律强制排在两端。诚实说：这是一条串行流，交给**一个** subagent 顺序做，或 subagent-driven 三段各配一次 review 即可。

> 与其它候选的关系：本候选文件面在 `app/host_integrations`、`app/host_install`、`app/cosmetics`，与候选 ①（`rules/commerce`）②（`rules/market`）③④⑤（`turn`）⑥（`ui`）**零重叠**——因此**候选 ⑦ 整体可与其它候选并行分派**给独立 subagent（跨候选并行），只是**候选 ⑦ 内部**三 task 串行。

---

## Task 1：pin 原生 paid 路径的观测行为（折叠前先钉死）

**Files:**
- Modify: `spec/behavior/app/cosmetics_transaction_spec.lua`（新增一个 pin `it`）

**Interfaces:**
- Consumes（既有，已核对签名）：
  - `transaction.handle_skin_transaction(state, role_id, { type = "open" | "equip_slot", slot_index })` — 未持有购买类皮肤触发 `purchase.start`。
  - `paid_purchase_port.start(game, player, entry)` — 付费网关入口（用 `with_patches` 捕获 entry）。
  - `entry.on_purchase() -> boolean` — 履约回调，内部走 `complete_skin_purchase`。
- Produces: 无新对外接口——纯 characterization pin。

**行为保持（锁的是什么）：** 本 pin 在 `purchase_adapter == nil`（`before_each` 的 `transaction.reset_for_tests()` 已清）下运行，因此走的是 `_start_via_paid_port` **原生路径**——即折叠后的生产路径。它钉死三件观测事实：(1) 未持有购买类皮肤触发 `paid_purchase_port.start`，entry 带 `kind="skin"` + product_id/name/currency/price；(2) `entry.on_purchase()` 返回 `true` 并履约（皮肤转为 owned + equipped）；(3) 履约不依赖任何 UI `on_success` 闭包。已有的 `complete_skin_purchase_rejects_duplicate_or_mismatched_callback`（:379）已隐式覆盖这条路径；本 pin 把 entry 形状与履约结果**显式**钉死，作为折叠护栏。

- [ ] **Step 1：读现有 pin 与 `_state()` fixture，确认 catalog / role**

Run: `grep -n "_state\b\|_catalog\|configure_equip\|product_id" spec/behavior/app/cosmetics_transaction_spec.lua | head -30`
Expected: 看到 `_state()`（第 41 行附近）与 catalog fixture（`skin_1` 为 slot 1 的购买类皮肤），确认新 pin 复用同款 fixture。

- [ ] **Step 2：新增 pin（放在 `complete_skin_purchase_rejects_duplicate_or_mismatched_callback` 之后）**

在 `spec/behavior/app/cosmetics_transaction_spec.lua` 顶层 `describe("app.cosmetics.transaction", ...)` 内、`complete_skin_purchase_rejects_duplicate_or_mismatched_callback` 用例（:405 结束）之后追加：

```lua
  it("PIN: native paid path builds a skin paid entry and fulfills without any UI on_success", function()
    -- purchase_adapter 未 configure(before_each 已 reset 为 nil)=> 走 transaction_purchase
    -- 的原生 _start_via_paid_port,即删除 skin_purchase 后的生产路径。
    local state = _state()
    transaction.configure_equip(function() return true end)
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    local captured = nil
    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function(_, _, entry)
          captured = entry
          return true
        end,
      },
    }, function()
      local started = transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 })
      assert(started.accepted == true, "native paid path should accept the purchase start")
      _assert_eq(started.action, "purchase_start", "start returns pending purchase_start")
      _assert_eq(started.pending_purchase, true, "start marks pending purchase")
    end)

    -- entry 由 transaction_purchase._purchase_entry 拼出,携带 skin 商品信息。
    _assert_eq(captured ~= nil, true, "native path must reach paid_purchase_port.start")
    _assert_eq(captured.kind, "skin", "entry is tagged as skin")
    _assert_eq(captured.product_id, "skin_1", "entry carries the pending product id")
    assert(captured.name ~= nil, "entry carries display name")
    assert(captured.on_purchase ~= nil, "entry carries an on_purchase fulfillment")

    -- 履约:on_purchase 走内部 complete_skin_purchase,无 UI on_success 闭包。
    local fulfilled = captured.on_purchase()
    _assert_eq(fulfilled, true, "fulfillment reports success")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], "skin_1",
      "native fulfillment equips the purchased skin")
  end)
```

> 注：若 fixture 里 slot 1 的 product_id 不是字符串 `"skin_1"`，用 Step 1 grep 出的真实值替换（`captured.product_id` 与 `selected_by_role["1"]` 两处一并对齐）。`configure_equip` 让履约后的自动装备成立；若 fixture 已在别处 configure_equip，可省。`with_patches` / `_assert_eq` 均为本 spec 顶部已有 helper。

- [ ] **Step 3：跑 pin 确认当前通过（characterization 基线，折叠前就绿）**

Run: `busted --run behavior spec/behavior/app/cosmetics_transaction_spec.lua`
Expected: PASS（新 pin + 既有全部用例绿——现状下原生路径本就可达，因为该 case 不 configure_purchase）。

- [ ] **Step 4：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add spec/behavior/app/cosmetics_transaction_spec.lua
git commit -m "test(cosmetics): pin 原生 paid 路径 —— skin paid entry + 无 UI on_success 履约(折叠护栏)"
```

---

## Task 2：host_install 去 skin_purchase wiring（翻转生产到原生路径）

**Files:**
- Modify: `src/app/host_install.lua`（删 `:11` require、删 `:108` configure 调用）
- Pin（保持绿，勿改）：`spec/behavior/app/cosmetics_transaction_spec.lua`（Task 1 pin + legacy 用例）、`spec/behavior/ui/skin_panel_spec.lua`

**Interfaces:**
- Consumes: 无新增。`_load_required_modules` 仍 `paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))`（:94）——**原生 paid 网关本就独立配置，不依赖 skin_purchase**。
- Produces: `M.install` 行为不变——只是不再 wire `purchase_adapter`，`transaction_purchase` 落到原生 paid 路径。

**行为保持：** `host_install:108` 的 `skin_purchase.configure(skin_panel)` 是生产中唯一 wire `purchase_adapter` 者（已 grep 确认）。删掉它后 `purchase_adapter == nil` → `_start_via_legacy_adapter` 返回 `nil, nil` → `_start_via_paid_port` 接管。paid 网关（`:94`）、equip / unequip adapter（`:96-107`）、成就、sign-in 全部不动。观测行为：付费购买仍经 `paid_purchase_port.start` 发起、履约仍经 `complete_skin_purchase`（`source` 字段被丢弃，无差异）。**此 task 先只去 wiring，不删文件**——`skin_purchase.lua` 暂留（下一 task 删），避免 require 悬空。

- [ ] **Step 1：确认 host_install 引用面**

Run: `grep -n "skin_purchase" src/app/host_install.lua`
Expected: 恰两行——`:11`（require）与 `:108`（`skin_purchase.configure(skin_panel)`）。

- [ ] **Step 2：删 require（第 11 行）**

将 `src/app/host_install.lua` 顶部：

```lua
local skin_purchase = require("src.app.host_integrations.skin_purchase")
```

**整行删除。**（其上下的 `skin_equip` / `achievement_runtime` require 不动。）

- [ ] **Step 3：删 `_load_required_modules` 里的 wiring（第 108 行）**

将 `src/app/host_install.lua:105-108` 段：

```lua
  skin_panel.configure_unequip(function(role_id)
    return skin_equip.unequip(role_id, runtime_assets.default_skin_model().asset_id)
  end)
  skin_purchase.configure(skin_panel)
  _wire_sign_in_rewards(opts)
```

改为（**只删 `skin_purchase.configure(skin_panel)` 一行**，其余原样）：

```lua
  skin_panel.configure_unequip(function(role_id)
    return skin_equip.unequip(role_id, runtime_assets.default_skin_model().asset_id)
  end)
  _wire_sign_in_rewards(opts)
```

- [ ] **Step 4：确认 skin_purchase 生产引用已清零（自测引用暂留）**

Run: `grep -rn "skin_purchase" src/ --include="*.lua" | grep -v "pending_skin_purchase\|complete_skin_purchase\|skin_purchase_by_role"`
Expected: **空**（生产源码里已无 `host_integrations.skin_purchase` 引用；`pending_skin_purchase_by_role` / `complete_skin_purchase` 是同名不同物，属 `transaction_*`，保留）。

- [ ] **Step 5：跑相关行为 spec 确认原生路径接管、无回归**

Run: `busted --run behavior spec/behavior/app/cosmetics_transaction_spec.lua spec/behavior/ui/skin_panel_spec.lua`
Expected: PASS（Task 1 pin 绿；legacy adapter 用例仍绿——它们自己 configure_purchase，不依赖 host_install wiring；skin_panel adapter 测试绿）。

- [ ] **Step 6：完整门禁 + Commit**

Run: `make verify`
Expected: PASS（`skin_purchase.lua` 仍在文件树，只是无生产引用；其自测 `skin_purchase_spec.lua` 仍绿——下一 task 才删）。

```bash
git add src/app/host_install.lua
git commit -m "refactor(host): host_install 停止 wire skin_purchase,皮肤付费落到 transaction 原生 paid 路径(补齐 ADR 0021)"
```

---

## Task 3：删 skin_purchase.lua + 其自测 + 刷 manifest + 完整门禁 + 验收

**Files:**
- Delete: `src/app/host_integrations/skin_purchase.lua`
- Delete: `spec/behavior/app/skin_purchase_spec.lua`
- Modify（manifest 刷新）: `src/app/host_install.lua`
- 全仓验证

**Interfaces:** Produces: 无——纯删死 module + 收口验证。

**行为保持：** Task 2 后 `skin_purchase.lua` 已无任何生产引用（Task 2 Step 4 已确认）；`skin_purchase_spec.lua` 是该 module 的**直测**（`spec/behavior/app/skin_purchase_spec.lua:4` require 它）——module 删除，其直测随之删除（该测试的所有断言都是对 `skin_purchase.start` / `.configure` 的白盒钉死，无独立价值；折叠后的观测行为已由 Task 1 pin + `cosmetics_transaction_spec` 覆盖）。

- [ ] **Step 1：删除前最后一次全仓引用核对**

Run: `grep -rn "host_integrations.skin_purchase\|host_integrations/skin_purchase" . --include="*.lua" --include="*.md" 2>/dev/null | grep -v "docs/superpowers/plans"`
Expected: 只剩 `spec/behavior/app/skin_purchase_spec.lua:4`（require）——即将连同 module 一起删。若出现任何 `src/` 或 `tools/` 引用，**停止**并回查（Task 2 应已清零）。

- [ ] **Step 2：删除 module 与其自测**

```bash
git rm src/app/host_integrations/skin_purchase.lua
git rm spec/behavior/app/skin_purchase_spec.lua
```

- [ ] **Step 3：刷新 host_install 的 mutation manifest**

Run: `lua tools/quality/mutate.lua src/app/host_install.lua --update-manifest`
Expected: `manifest updated: src/app/host_install.lua`（`_load_required_modules` 少一行调用，semanticHash 变；只动文件底部 `--[[ mutate4lua-manifest ]]` 注释块）。

> 验证只动注释：`git diff -U0 src/app/host_install.lua` 的最早改动行号应 > `grep -n "mutate4lua-manifest" src/app/host_install.lua` 的行号。

- [ ] **Step 4：完整门禁**

Run: `make verify`
Expected: PASS（~7-8s；全套 src 七层 + foundation 行为 spec 绿；删掉的 `skin_purchase_spec` 不再被收集）。

- [ ] **Step 5：验收套件（皮肤流程不回归）**

Run: `make acceptance`
Expected: PASS（从 feature 重生成 gitignored 生成物再跑；`skin_shop` / `skin_persistence` wire 自己的 `configure_purchase`，不经 `skin_purchase`，观测行为零变化，不回归）。

- [ ] **Step 6：deletion-test 复核（口头，非代码）**

确认候选 ⑦ 的 deletion test 现在成立：`skin_purchase.lua` 已删，付费皮肤购买仍工作——`transaction_purchase` 自带的 `_purchase_entry` + `_start_via_paid_port` 接管，重复的 entry-builder 与一跳 `on_success` 闭包消失，总逻辑减少。ADR 0021 §Adapter 要求的坍缩落地：`host_install` 只安装 adapters、不再把交易流程接在 `skin_panel.configure_purchase` 上；paid adapter 不再经 UI 闭包履约。

- [ ] **Step 7：Commit**

```bash
git add src/app/host_install.lua
git commit -m "refactor(cosmetics): 删死适配器 skin_purchase + 复活的 on_success 闭包,折叠进 transaction 原生 paid 路径"
```

---

## Self-Review（写完对着评审 + ADR 复核）

**1. Spec 覆盖（评审候选 ⑦ 的每条主张）：**
- ✅「两个 adapter 各建同一个 paid entry、调同一个 port」→ 删 `skin_purchase._entry_for_skin`（重复的 entry-builder），保留唯一的 `transaction_purchase._purchase_entry`。
- ✅「transaction_purchase 先试 legacy、legacy wire 到 skin_purchase.start → 自己的 paid 路径成死代码」→ 已 grep 核对调用链（探源实况 §2）；Task 2 去 wiring 让原生路径复活。
- ✅「ADR 0021 已退役的 UI on_success 闭包从 skin_purchase 复活（:32,98,108）」→ 删 `skin_purchase.lua` 整体，闭包随之消失（探源实况 §1）。
- ✅「让 host_install 直接 wire transaction module 自带的 paid port」→ **精确化**：原生 paid 路径本就直接调 `paid_purchase_port.start`（`_start_via_paid_port`），paid 网关本就在 `host_install:94` 独立 configure；无需新增 wire，**去掉** `skin_purchase.configure` 即让原生路径接管。评审「直接 wire 原生 paid port」= 去掉旧 wiring 后原生路径可达，非新增一条 wire。
- ⚠️「折叠 skin_purchase 进 transaction_purchase」→ **审慎收窄为删除**：`transaction_purchase` 已内建等价的 `_purchase_entry`，无需搬运任何逻辑进去，折叠 = 删除。legacy `_start_via_legacy_adapter` seam **有意保留**（被 `cosmetics_transaction_spec` + 验收钉），删它是独立更大重构（见文末入口）。已在探源实况 §4 显式说明——**这是对评审「折叠」的审慎偏离，需在 handoff 向 reviewer 点明**。

**2. Placeholder 扫描：** 无 TBD / 「加适当处理」。Task 1 给完整 pin 代码块（含 product_id fixture 对齐提示）；Task 2 给完整 old→new 两段；Task 3 给完整 `git rm` + manifest 命令。✅

**3. 类型/签名一致性：**
- 折叠后生产路径 = `transaction_purchase._start_via_paid_port` → `_purchase_entry`，signature 与 legacy 路径产出的 entry 同形（`kind/product_id/name/currency/price/on_purchase`）。✅
- `complete_skin_purchase` 3 参签名丢弃 `source` → legacy/原生 zero 观测差异，已核对 `transaction.lua:14` / `transaction_actions.lua:205` / `transaction_completion.lua:31`。✅
- Task 顺序 pin→unwire→delete 的硬依赖（require 悬空 / characterization）已在「并行执行编排」证明不可交换。✅

**已知风险（handoff 要说）：**
1. **legacy seam 未删**（`_start_via_legacy_adapter` + `configure_purchase`）——生产不可达但被 spec + 验收钉，属独立更大重构，本候选有意不碰。若 reviewer 期望「彻底删死代码」，需说明这是范围外的 Level B。
2. **Task 1 pin 的 fixture product_id**——若 `_state()` catalog 的 slot 1 product_id 不是 `"skin_1"`，Step 1 grep 出真实值替换两处断言。
3. **`make acceptance` 若因无关生成物波动报错**——先重跑 `make acceptance`（它先重生成生成物）再判断；本候选不改验收 step / feature。

---

## 后续项（范围外，非本计划步骤）—— Level B：删 legacy adapter seam

> **这一段不是可执行步骤，是给下一份 `writing-plans` 的范围与阻力清单。**

**目标：** 删 `transaction_purchase._start_via_legacy_adapter` + `_start_request` 的 legacy 分支 + 整条 `configure_purchase` seam（`skin_panel.configure_purchase` / `transaction.configure_purchase` / `transaction_context.configure_purchase` / `purchase_adapter`），让皮肤购买只剩原生 paid 一条路径。

**阻力（为何不在本候选做）：**
- `cosmetics_transaction_spec.lua:329,362` 两个 legacy 用例（`purchase_callback_failed` / `_rejected` / `on_success` 完成）须迁移或删除。
- `spec/behavior/ui/skin_panel_spec.lua` ~10 处 `configure_purchase(...)` 用例须重写为原生路径断言。
- 验收 `tools/acceptance/steps/skin_shop.lua:337,346` 付费步骤 wire 自己的 `configure_purchase` → 须改走原生 paid 网关注入（`paid_currency.lua` 已有 `paid_purchase_port.configure(paid_purchase_gateway)` 的先例）。
- 需产品确认 legacy adapter seam 确无宿主侧未来用途（黑市/道具商店走 `paid_purchase_flow`，不经此 seam——ADR 0021 §范围外）。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-7-skin-purchase-collapse.md`.

本计划 = **候选 ⑦ Level A 折叠**（删 `skin_purchase` + 去 `host_install` wiring），完整可执行、零观测行为变化、验收不回归。Level B（删 legacy seam）见上一节，需单独 `writing-plans` 展开。

**执行方式：单一工作树、顺序 1→2→3（硬串行，见「并行执行编排」）。** 候选 ⑦ 整体文件面与其它候选零重叠，可作为独立 subagent 与其它候选**跨候选并行**分派；但候选 ⑦ **内部**三 task 因 require 悬空 + characterization 纪律必须串行。

两种执行方式：
**1. Subagent-Driven（推荐）** — 一个 subagent 顺序做 Task 1→2→3，每 task 后一段 review。契合本候选「小、串行、删除型」。
**2. Inline Execution** — 本 session 用 `executing-plans` 顺序执行，带 checkpoint。

选哪个？
