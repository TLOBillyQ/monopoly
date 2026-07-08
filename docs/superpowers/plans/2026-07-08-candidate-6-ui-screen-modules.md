# 候选 ⑥ 每个选择屏一个 Screen 深模块 —— 逐屏归位（locality）计划

> **For agentic workers / swarm agents:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 执行。步骤用 `- [ ]` 复选框跟踪。**本计划是「试点定型（串行）→ 逐屏并行 fan-out（worktree 隔离）→ barrier」三段式。** Task 1（试点 + registry seam）与 Task 2（第二试点）**必须串行先做**——它们定死 recipe 并拆掉「共享派发表」这个并行瓶颈；只有 seam 落地后，剩余屏才真正互相独立、可 fan-out。见「并行执行编排」。

**Goal:** 把「一个选择屏」被抹在 6–7 个 module 里的横切碎片（schema 节点名 + input 意图 + open/close + 按钮同步 + canvas 映射 + view model），归位成 **每屏一个 Screen 深模块** `src/ui/screens/<key>.lua`，对外 interface：`screen.open(state, choice, choice_id)` / `screen.build_route_specs(state)`（= on_click 映射） / `screen.descriptor()`（= build_choice_screens 条目） / `screen.canvas`。改一个屏 = 动一个文件；`schema`（数据）与 `route`（输入）降为它唯一的卫星。

**Architecture:** 现状：4 个选择屏（`player` / `target` / `remote` / `secondary_confirm`）各自的组合逻辑被 5 张**共享派发/工厂表**拆散——`node_ops.build_choice_screens`（屏描述符工厂）、`choice_openers._screen_openers`（开屏派发表）、`routes.canvas_builders`（意图构建列表）、`choice_helpers.screen_canvases`（canvas 映射表）、`ui_state`（装配）。新建 `src/ui/screens/` 目录 + `registry.lua`；每个 Screen 模块**自注册**其 descriptor / opener / route_specs / canvas；那 5 张共享表**一次性**改为向 registry 委托。此后新增/迁移一个屏只动**它自己的新文件** + registry 的 append-only require 清单——这正是让「逐屏并行」从口号变成现实的 seam。产出必须与既有 5 张表**逐点等价**（`node_ops_spec` 钉死 `build_choice_screens()` 的 4 屏字段，`choice_routes_spec` 钉死路由——见各 task 护栏）。

**Tech Stack:** Lua 5.4；busted（`spec/behavior/ui/`）；清洁架构七层，落在 `ui` 层（presentation）。Eggy 宿主节点名为中文字符串常量（`"位置选择屏"` 等），`Fixed` 参数用浮点——本计划只搬 Lua 组合逻辑，不新建节点、不碰 `Fixed`。

## Global Constraints

- 命名 `snake_case`，模块表名小写下划线；每个 Screen 文件顶部一段中文 doc 注释说明「本屏的唯一归宿」职责。
- `src/` 禁用 `tonumber` / `type(x)=="number"`；如需数字工具用 `NumberUtils`（`src.foundation.number`）。本计划的判定都是 `screen_key` 字符串比较与表存在性判定，不涉数字。
- **这是重构，观测行为零变化**：registry 聚合输出必须与既有 5 张表逐点等价（屏描述符字段、开屏副作用、route spec 顺序、canvas 映射）。每屏迁移前先跑既有 pin 做 characterization 基线。
- 迭代/每个 task 结尾门禁 `make verify`（本仓库 verify 即完整门禁，~7–8s）。UI 面广，**Task 末必跑相关 UI 行为单文件**：`busted --run behavior spec/behavior/ui/action_status/choice_routes_spec.lua spec/behavior/ui/node_ops_spec.lua spec/behavior/ui/choice_state_spec.lua`。
- 单文件 spec：`busted --run behavior spec/behavior/ui/<path>_spec.lua`。
- **不改** `EggyAPI.lua`、`tools/acceptance/generated/*`（生成物）。行为不变则验收自动保持绿。
- manifest 刷新：`lua tools/quality/mutate.lua <file> --update-manifest`（只动文件尾 `--[[ mutate4lua-manifest ]]` 注释块）。

---

## 候选 ⑥ 全貌与分期（务必先读）

**这是 locality 缺陷（放错位），不是 depth 缺陷。** deletion test 成立：本计划涉及的每个碎片都不是可删的浅转发——`_open_target_screen`、`sync_target_choice_buttons`、`route_target_choice.build`、`build_choice_screens.target` 各自承担真实职责，删任一片只是把份额挪进别处。复杂度真实、总量不变；本计划**只搬家不减量**——把「一个屏的份额」从 5 个共享文件收拢进 1 个屏文件。

**探源核实（评审常夸大，逐条核对）：**

1. **横切实况确认（以 `target` 屏为标本）。** 一个 target 选择屏的碎片分布：
   - `ui/schema/target_choice.lua` — 节点名常量（canvas/title/body/confirm/cancel/7×slot_buttons/slot_labels/slot_projections）。
   - `ui/input/route_target_choice.lua` — 点击意图（confirm/cancel/slot）。
   - `ui/render/node_ops.lua:74-82` `sync_target_choice_buttons` + `:117-152` `build_choice_screens` 的 `target` 条目 + `:4` require schema。
   - `ui/coord/choice_openers.lua:153-161` `_open_target_screen` + `:53-59` `_store_target_button_labels` + `:192` `_screen_openers.target`。
   - `ui/coord/choice_helpers.lua:10-15` `screen_canvases.target`。
   - `ui/state/modal.lua:9` `open_choice`（**共享**，非 target 独有）+ `ui/view/choice_slice.lua`（**共享** build model）。
   > 「改一个屏动 5 个文件」属实。

2. **确认键是 inert stub，属实且更糟。** `route_target_choice.lua:12` 的 confirm `build_intent = function() return nil end`（cancel 同）——点击确认键产生 nil 意图、无副作用。而它的「启用/文案/可见性」住在**三个别处**：`choice_openers._store_target_button_labels`（设 `screen.confirm_label="确定"`）、`choice_openers._open_target_screen` 尾调 `node_ops.sync_target_choice_buttons`（**把 confirm/cancel 直接隐藏**——target 屏是**点槽位即确认**，故确认键刻意 inert）、`node_ops.build_choice_screens.target`（挂 confirm/cancel 节点名）。**问「确认键干嘛」要开 4 文件**才拼得出「它被隐藏、点槽位自动确认」。属实。

3. **「15 个屏」是夸大——核实后清点如下。** 真正吃「本 recipe（schema + route + open + descriptor + canvas）」的**干净选择屏恰好 4 个**：`player` / `target` / `remote` / `secondary_confirm`——由 `node_ops_spec.lua:225-263` 精确钉死（`build_choice_screens()` 断言这 4 个 key 及其字段）。评审的「15」来自宽松清点 `routes.canvas_builders`（11 个 builder）或 `ui/schema/`（16 个 schema 文件，其中 `dice`/`status3d`/`bankruptcy`/`permanent`/`market_layout`/`base_contract` 是纯数据、非交互屏）。**另有 ~5 个大型 canvas 面**（`market` / `skin_panel` / `item_atlas` / `item_slots` / `popup`）有各自的 schema+route，但它们**各带独立 coordinator**（`skin_panel.lua` 16.8K、`item_atlas.lua` 14K、`item_slots.lua` 8K），是「各自一份 plan」的大工程，**不是**模板套用。
   > 诚实结论：**干净模板集 = 4 屏**（本计划 Phase A/B）；**大面尾巴 = ~5 面**（Phase C，每面独立 plan，形同候选 ③-大）。本计划完整交付 4 屏 + 定死可复用 recipe + 大面清单入口。

4. **`player` 与 `remote` 共享同一 opener**（`choice_openers._open_player_or_remote_screen`，`:189-190`）——**并非每屏完全独立**。Screen 模块要把这段共享开屏逻辑保留成 `screens/_option_screen.lua` 共享 helper，两个屏各自 `open` 委托它，而非复制。这是「逐屏归位」里必须诚实处理的一处共享。

**并行性核实（关键，评审说「天然高度并行」需修正）：** 4 个屏当前**不是** disjoint 文件——它们全部汇流进上述 **5 张共享派发/工厂表**。**朴素地「一屏一 subagent 各改各的」会在这 5 个文件上撞车**（同文件多屏改动 = 文本冲突 + `index.lock` 竞争）。要让并行成立，**必须先用试点引入 registry**，把 5 张表改成向 registry 委托；此后每个屏 = 一个**全新自包含文件** + registry 的 **append-only** require 清单，屏与屏之间才真正零重叠写。**这是本候选与候选 ③ 的关键差异**：③ 天生 3 个 disjoint 文件、并行只赚「并行 review」不赚壁钟；⑥ 需先付一次 seam 成本，之后并行**能赚真实壁钟**（尤其 Phase C 的大面尾巴）。

**分期结论：**
- **Phase A（串行·定型）** = Task 1（试点 `target` + registry seam）+ Task 2（第二试点 `remote`，验证 recipe 在 N=2 成立、registry 无回归）。
- **Phase B（并行 fan-out）** = 剩余干净屏 `player` / `secondary_confirm` 各一个 subagent（worktree 隔离），套 recipe。
- **Phase C（后续独立 plan，非本计划步骤）** = 大面尾巴 `market`/`skin_panel`/`item_atlas`/`item_slots`/`popup`，每面一份 plan，壁钟并行价值最高。文末给入口。
- **Barrier（Task B-final）** = 合并后 deletion-test 复核 + 5 张共享表清死 + 多文件 manifest 刷新 + 完整门禁 + 验收。

---

## Phase A/B 文件结构

**新建（Screen 深模块 + registry seam）：**
- `src/ui/screens/registry.lua` — 屏注册表。聚合各 Screen 的 `descriptor` / `opener` / `route_specs` / `canvas`，供 5 张共享表委托。
- `src/ui/screens/_option_screen.lua` — `player`/`remote` 共享的选项开屏 helper（承接现 `_open_player_or_remote_screen`）。
- `src/ui/screens/target_choice.lua` —（Task 1）target 屏唯一归宿。
- `src/ui/screens/remote_choice.lua` —（Task 2）remote 屏。
- `src/ui/screens/player_choice.lua` —（Phase B）player 屏。
- `src/ui/screens/secondary_confirm.lua` —（Phase B）secondary_confirm 屏。
- `spec/behavior/ui/screens/target_choice_screen_spec.lua`、`remote_choice_screen_spec.lua`（各屏模块直测）。

**一次性改为向 registry 委托（Task 1 内改一遍，之后不再逐屏改）：**
- `src/ui/render/node_ops.lua` — `build_choice_screens()`（:117-152）改为 `registry.build_choice_screens()`；迁移完成后删对应 schema require（:3-6）与 `sync_target_choice_buttons`（:74-82，随 target 屏收进 screen 模块）。
- `src/ui/coord/choice_openers.lua` — `M.open_choice_modal`（:128-141）的 `_screen_openers[screen_key]` 改查 `registry.opener_for(screen_key)`；各 `_open_*` 函数随对应屏迁走。
- `src/ui/input/routes.lua` — `canvas_builders` 里 4 个 choice 屏 builder 改为 `registry.build_route_specs`（保序拼接）。
- `src/ui/coord/choice_helpers.lua` — `screen_canvases`（:10-15）改为 `registry.canvas_for(screen_key)`。

**保持不变（共享底座，Screen 模块委托它们，勿删）：**
- `src/ui/coord/choice_openers.lua` 的 `_open_screen` / `_fill_option_nodes` / `_set_action_button` / `_sync_slot_label` / `_sync_projection_node`（真·共享渲染原语，多屏复用）。
- `src/ui/state/modal.lua`（`open_choice` 等，屏无关的选择态）、`src/ui/view/choice_slice.lua`（屏无关的 model 构建）。
- `src/ui/coord/ui_state.lua:23`（继续调 `ui_nodes.build_choice_screens()`，其内部换成 registry 委托，此处不改）。

**护栏 spec（保持绿）：**
- `spec/behavior/ui/action_status/choice_routes_spec.lua`（驱动 `modal_presenter.open_choice_modal`，钉 `active_choice_screen_key` + canvas 节点可见 —— 4 屏路由）。
- `spec/behavior/ui/node_ops_spec.lua`（`build_choice_screens` 4 屏字段 + `sync_target_choice_buttons` 行为）。
- `spec/behavior/ui/choice_state_spec.lua`、`spec/behavior/ui/interaction_spec.lua`（热点，选择交互整链）。

---

## Task 1（试点 · 串行）：target 屏收进 Screen 深模块 + 引入 registry seam

> **本 task 一箭双雕：** ① 定死 Screen 模块 recipe（以评审的标本 `target` 屏 + inert 确认键为例，完整展开）；② 引入 registry 并把 5 张共享表改为委托——拆掉并行瓶颈。**必须最先做、串行。**

**Files:**
- Create: `src/ui/screens/registry.lua`、`src/ui/screens/target_choice.lua`
- Create test: `spec/behavior/ui/screens/target_choice_screen_spec.lua`
- Modify: `src/ui/render/node_ops.lua`、`src/ui/coord/choice_openers.lua`、`src/ui/input/routes.lua`、`src/ui/coord/choice_helpers.lua`
- Pin（保持绿，勿改）：`spec/behavior/ui/action_status/choice_routes_spec.lua`、`spec/behavior/ui/node_ops_spec.lua`、`spec/behavior/ui/choice_state_spec.lua`

**Interfaces:**
- Produces（Task 2 / Phase B 依赖）：
  - Screen 模块契约：`screen.key`（string）、`screen.canvas`（canvas 常量）、`screen.descriptor() -> table`（build_choice_screens 条目）、`screen.open(state, choice, choice_id)`、`screen.build_route_specs(state) -> specs`（{name, build_intent} 列表）。
  - `registry.register(screen)`；`registry.build_choice_screens() -> { [key] = descriptor }`；`registry.opener_for(key) -> fn|nil`；`registry.build_route_specs(state) -> specs`（按注册序拼接）；`registry.canvas_for(key) -> canvas`。
- Consumes（既有共享原语，签名已核对）：`choice_openers` 的 `_open_screen` / `_fill_option_nodes` / `_order_target_options` / `_store_target_button_labels`、`node_ops.sync_target_choice_buttons`、`modal_state.open_choice`、`canvas.CANVAS_TARGET_CHOICE`。

**行为保持（逐点）：**
- `build_choice_screens()` 迁移后仍返回含 `target = { key="target", root, title, body, option_buttons, slot_labels, slot_projections, confirm, cancel }` 的表（`node_ops_spec.lua:243,255` 精确钉这些字段）——由 `target_choice.descriptor()` 逐字段产出。
- `_open_target_screen` 的副作用序列（`_open_screen` → `_fill_option_nodes(..., {clear_button_text=true})` → `_store_target_button_labels` → `modal_state.open_choice` → `sync_target_choice_buttons`）**逐句保留**，只是搬进 `target_choice.open`。inert 确认键行为不变：`build_route_specs` 里 confirm/cancel 仍 `build_intent=function() return nil end`，`sync_target_choice_buttons` 仍隐藏它们（`choice_routes_spec` 钉 target 屏 confirm 隐藏 + 点槽位路由）。
- `screen_canvases.target` → `target_choice.canvas = canvas.CANVAS_TARGET_CHOICE`，`registry.canvas_for("target")` 回同值。

- [ ] **Step 1：确认既有 pin 全绿（characterization 基线）**

Run: `busted --run behavior spec/behavior/ui/action_status/choice_routes_spec.lua spec/behavior/ui/node_ops_spec.lua spec/behavior/ui/choice_state_spec.lua`
Expected: PASS（这三份就是本 task 的护栏；重构后必须仍全绿）。

- [ ] **Step 2：写 registry + target Screen 模块的失败测试**

创建 `spec/behavior/ui/screens/target_choice_screen_spec.lua`：

```lua
-- target 选择屏 Screen 深模块直测:descriptor 字段 + 路由意图 + inert 确认键。
-- 用 shared_support 的 choice_modal fixture(与 choice_routes_spec 同款)。
local registry = require("src.ui.screens.registry")
local target_screen = require("src.ui.screens.target_choice")
local schema = require("src.ui.schema.target_choice")

describe("ui.screens.target_choice", function()
  it("exposes a descriptor with the pinned target fields", function()
    local d = target_screen.descriptor()
    assert(d.key == "target", "descriptor key is target")
    assert(d.root ~= nil, "has root/canvas node")
    assert(d.title ~= nil and d.body ~= nil, "has title and body")
    assert(d.option_buttons ~= nil, "has option_buttons")
    assert(d.slot_labels ~= nil and d.slot_projections ~= nil, "has slot label/projection nodes")
    assert(d.confirm ~= nil and d.cancel ~= nil, "has confirm and cancel nodes")
  end)

  it("registers itself into the registry under its key", function()
    assert(registry.build_choice_screens().target ~= nil, "registry aggregates target descriptor")
    assert(registry.canvas_for("target") == target_screen.canvas, "registry maps target canvas")
    assert(registry.opener_for("target") == target_screen.open, "registry maps target opener")
  end)

  it("keeps the confirm key inert (build_intent returns nil) — target auto-confirms on slot", function()
    local specs = target_screen.build_route_specs({})
    local confirm_spec
    for _, s in ipairs(specs) do
      if s.name == schema.confirm then confirm_spec = s end
    end
    assert(confirm_spec ~= nil, "confirm node has a route spec")
    assert(confirm_spec.build_intent() == nil, "confirm intent is inert nil by design")
  end)

  it("builds a choice_select intent for a slot button when a choice is present", function()
    -- slot 路径与既有 route_target_choice 等价:借 runtime model 注入 choice。
    -- 具体 fixture 复用 shared_support(见 choice_routes_spec 的 _build_choice_modal_state)。
    local specs = target_screen.build_route_specs({})
    local has_slot = false
    for _, s in ipairs(specs) do
      if s.name == schema.slot_buttons[1] then has_slot = true end
    end
    assert(has_slot, "first slot button has a route spec")
  end)
end)
```

- [ ] **Step 3：跑测试确认失败**

Run: `busted --run behavior spec/behavior/ui/screens/target_choice_screen_spec.lua`
Expected: FAIL —`module 'src.ui.screens.registry' not found`。

- [ ] **Step 4：写 registry（最小实现）**

创建 `src/ui/screens/registry.lua`：

```lua
-- 选择屏注册表:每个 Screen 深模块 require 时自注册,共享派发/工厂表
-- (node_ops.build_choice_screens / choice_openers._screen_openers /
--  routes.canvas_builders / choice_helpers.screen_canvases)统一向此委托。
-- 引入此 seam 后,新增/迁移一个屏只动它自己的文件 + 下方 require 清单,
-- 屏与屏之间零重叠写 —— 这是「逐屏并行」成立的前提。
local registry = {}

local _screens = {}       -- 按注册序保留(route spec 拼接需保序)
local _by_key = {}

function registry.register(screen)
  assert(type(screen) == "table" and type(screen.key) == "string", "screen needs a string key")
  assert(_by_key[screen.key] == nil, "duplicate screen key: " .. screen.key)
  _screens[#_screens + 1] = screen
  _by_key[screen.key] = screen
end

-- 强制加载所有屏模块(它们在 require 时自注册)。清单是唯一的 append-only 共享点。
local function _load_all()
  require("src.ui.screens.target_choice")
  -- Task 2 追加: require("src.ui.screens.remote_choice")
  -- Phase B 追加: player_choice / secondary_confirm
end
_load_all()

function registry.build_choice_screens()
  local out = {}
  for _, s in ipairs(_screens) do
    out[s.key] = s.descriptor()
  end
  return out
end

function registry.opener_for(key)
  local s = _by_key[key]
  return s and s.open or nil
end

function registry.canvas_for(key)
  local s = _by_key[key]
  return s and s.canvas or nil
end

function registry.build_route_specs(state)
  local specs = {}
  for _, s in ipairs(_screens) do
    if s.build_route_specs then
      for _, spec in ipairs(s.build_route_specs(state) or {}) do
        specs[#specs + 1] = spec
      end
    end
  end
  return specs
end

return registry
```

> **循环 require 注意：** Screen 模块顶部 `require("src.ui.screens.registry")` 并在文件尾 `registry.register(M)`；registry 的 `_load_all` 也 require 各屏。Lua 的 `require` 缓存使「registry 先被某屏 require → registry 执行 `_load_all` → 再 require 该屏」时，该屏尚未 `return`，拿到 nil。**规避：`_load_all` 放在 registry 文件**末尾 `return registry` **之前的最后一步**，且屏模块**在文件尾**才 `registry.register`——首个进入点无论是 registry 还是某屏，注册都发生在各屏模块体执行完 `register(M)` 那行。若 busted 下仍触发环，改为「registry 不主动 `_load_all`，由 `ui_state`/`routes` 显式 require 各屏一次」——Step 8 验证时若报环即切此方案（已在 Self-Review 列为已知风险）。

- [ ] **Step 5：写 target Screen 模块（把 5 处碎片搬进来）**

创建 `src/ui/screens/target_choice.lua`：

```lua
-- target(位置)选择屏的唯一归宿:schema 引用 + 开屏 + 按钮同步 + 点击意图。
-- 收编自 node_ops.build_choice_screens.target / choice_openers._open_target_screen
-- (+_store_target_button_labels)/ node_ops.sync_target_choice_buttons /
-- route_target_choice.build。确认键刻意 inert:target 屏点槽位即确认,确认/取消键被隐藏。
local registry = require("src.ui.screens.registry")
local schema = require("src.ui.schema.target_choice")
local canvas = require("src.ui.coord.canvas_coordinator")
local openers = require("src.ui.coord.choice_openers")        -- 共享开屏原语
local node_ops = require("src.ui.render.node_ops")            -- 共享按钮同步原语
local modal_state = require("src.ui.state.modal")
local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local M = { key = "target", canvas = canvas.CANVAS_TARGET_CHOICE }

-- 屏描述符:逐字段等价 node_ops.build_choice_screens.target(node_ops_spec 钉死)。
function M.descriptor()
  return {
    key = "target",
    root = schema.canvas,
    title = schema.title,
    body = schema.body,
    option_buttons = schema.slot_buttons,
    slot_labels = schema.slot_labels,
    slot_projections = schema.slot_projections,
    confirm = schema.confirm,
    cancel = schema.cancel,
  }
end

-- 开屏:逐句保留 _open_target_screen 的副作用序列。
function M.open(state, choice, choice_id)
  local ui, screen = openers.open_screen(state, "target", choice, choice_id)
  local option_ids, selected = openers.fill_option_nodes(
    ui, screen, openers.order_target_options(choice), { clear_button_text = true })
  openers.store_target_button_labels(screen, choice)
  modal_state.open_choice(state, choice_id, option_ids, selected)
  node_ops.sync_target_choice_buttons(state)  -- 隐藏 confirm/cancel(点槽位即确认)
end

-- 点击意图:confirm/cancel 刻意 inert;slot 建 choice_select。等价 route_target_choice.build。
function M.build_route_specs(state)
  local specs = {
    { name = schema.confirm, build_intent = function() return nil end },
    { name = schema.cancel, build_intent = function() return nil end },
  }
  for index, name in ipairs(schema.slot_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local model = runtime_state.get_ui_model(state)
        local choice = model and model.choice or nil
        if not choice then logger.warn("target_select without choice"); return nil end
        local options = choice.options
        local resolve_index = (type(options) == "table" and #options == 1) and 1 or index
        local option_id = ui_event_intents.resolve_option_id(choice, { index = resolve_index }, state)
        if not option_id then logger.warn("target_select missing option:", tostring(resolve_index)); return nil end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end
  return specs
end

registry.register(M)
return M
```

> **前置：把 `choice_openers` 的共享原语升为 module-public。** 现 `_open_screen` / `_fill_option_nodes` / `_order_target_options` / `_store_target_button_labels` 是 local。在 `choice_openers.lua` 末尾（`return M` 前）加导出别名，供 Screen 模块调用：
> ```lua
> M.open_screen = _open_screen
> M.fill_option_nodes = _fill_option_nodes
> M.order_target_options = _order_target_options
> M.store_target_button_labels = _store_target_button_labels
> ```
> `node_ops.sync_target_choice_buttons` 已是 module-public（`node_ops.lua:162`），直接用。

- [ ] **Step 6：5 张共享表改为向 registry 委托**

**(a) `node_ops.build_choice_screens`（:117-152）** 改为委托——但 registry require node_ops（Step 5）会成环。**规避：`build_choice_screens` 保留为薄壳，改从 registry 取；registry 由 `ui_state` 首次装配时驱动**。具体：把 `node_ops.build_choice_screens` 改为：

```lua
local function build_choice_screens()
  return require("src.ui.screens.registry").build_choice_screens()
end
```

（`require` 内联进函数体，避免 module-load 期成环——调用发生在 `ui_state` 运行期，registry 已装配。删除 `node_ops.lua:3-6` 中仅供旧 `build_choice_screens` 用的 `player_choice_nodes`/`target_choice_nodes`/`remote_choice_nodes`/`secondary_confirm_nodes` require 留到 Barrier 统一清——Task 1 只迁 target，其余屏描述符仍需旧 require 直到各自迁完。**Task 1 阶段：`build_choice_screens` 委托 registry，但 registry 只注册了 target；其余 3 屏描述符 registry 尚无** → 见下方分步策略。）

> **分步迁移策略（关键，避免中途破 pin）：** `node_ops_spec` 要求 `build_choice_screens()` 同时含 4 屏。Task 1 只迁 target，故 registry 此刻只有 target。**解法：`build_choice_screens` 在过渡期合并「registry 已注册的屏」+「尚未迁移屏的旧内联描述符」**：
> ```lua
> local function build_choice_screens()
>   local screens = require("src.ui.screens.registry").build_choice_screens()  -- 已迁移屏
>   screens.player = screens.player or { key="player", root=player_choice_nodes.canvas,
>     title=player_choice_nodes.title, option_buttons=player_choice_nodes.slots }
>   screens.remote = screens.remote or { key="remote", root=remote_choice_nodes.canvas,
>     title=remote_choice_nodes.title, body=remote_choice_nodes.body, option_buttons=remote_choice_nodes.options }
>   screens.secondary_confirm = screens.secondary_confirm or { key="secondary_confirm",
>     root=secondary_confirm_nodes.canvas, title=secondary_confirm_nodes.title,
>     body=secondary_confirm_nodes.body, confirm=secondary_confirm_nodes.confirm, cancel=secondary_confirm_nodes.cancel }
>   return screens
> end
> ```
> 每迁完一屏，删它对应的 `or {...}` 兜底与旧 require。Barrier 时 4 屏全走 registry，兜底与旧 require 全清空。

**(b) `choice_openers.M.open_choice_modal`（:134）** 的 `_screen_openers[screen_key]` 改为：

```lua
  local open = require("src.ui.screens.registry").opener_for(screen_key) or _screen_openers[screen_key]
```

（registry 命中已迁移屏；未迁移屏仍走旧 `_screen_openers`。删 `_screen_openers.target = _open_target_screen`（:192）与 `_open_target_screen` 函数体——已搬进 screen 模块。）

**(c) `routes.canvas_builders`（:14-26）** 把 `target_choice_intents.build` 替换为 registry 聚合：在 `registry.build_route_specs(state)` 里已含 target 的 specs。过渡期做法——`routes.build_route_specs` 末尾追加 `registry.build_route_specs`，并从 `canvas_builders` **移除已迁移屏的 builder**（Task 1 移除 `target_choice_intents.build`）：

```lua
function registry.build_route_specs(state)   -- 在 routes.lua 内
  local specs = {}
  for _, build in ipairs(canvas_builders) do          -- 尚未迁移屏
    for _, spec in ipairs(build(state) or {}) do specs[#specs+1] = spec end
  end
  for _, spec in ipairs(screen_registry.build_route_specs(state) or {}) do  -- 已迁移屏
    specs[#specs+1] = spec
  end
  return specs
end
```

（顶部 `local screen_registry = require("src.ui.screens.registry")`；从 `canvas_builders` 删 `target_choice_intents.build` 与其 require。**保序注意**：意图按 node name 匹配，顺序不影响命中，但为稳妥把 registry specs 追加在末尾。）

**(d) `choice_helpers.screen_canvases`（:10-15）** 的 `M.resolve_canvas_for_screen` 改为先查 registry：

```lua
function M.resolve_canvas_for_screen(screen_key)
  local from_registry = require("src.ui.screens.registry").canvas_for(screen_key)
  return from_registry or screen_canvases[screen_key] or canvas.CANVAS_BASE
end
```

（删 `screen_canvases.target` 行。）

- [ ] **Step 7：跑屏模块直测 + 三份 pin 确认全绿**

Run: `busted --run behavior spec/behavior/ui/screens/target_choice_screen_spec.lua spec/behavior/ui/action_status/choice_routes_spec.lua spec/behavior/ui/node_ops_spec.lua spec/behavior/ui/choice_state_spec.lua`
Expected: PASS（屏直测 4 用例 + target 路由/描述符/inert 确认键在 pin 中逐点保持）。

- [ ] **Step 8：完整门禁**

Run: `make verify`
Expected: PASS（若报循环 require，按 Step 4 备注切「显式 require 各屏」方案；`interaction_spec`/`gameplay_t6_hotspot` 等热点全绿）。

- [ ] **Step 9：Commit**

```bash
git add src/ui/screens/registry.lua src/ui/screens/target_choice.lua \
  spec/behavior/ui/screens/target_choice_screen_spec.lua \
  src/ui/render/node_ops.lua src/ui/coord/choice_openers.lua \
  src/ui/input/routes.lua src/ui/coord/choice_helpers.lua
git commit -m "refactor(ui): 引入 screen registry seam,target 选择屏收进 Screen 深模块"
```

---

## Task 2（第二试点 · 串行）：remote 屏收进 Screen 深模块（验证 recipe 在 N=2 成立）

> **目的：** 用一个**更简单的屏**（remote：无 inert 确认键、无 target 的按钮隐藏怪癖）复跑 recipe，证明 registry seam 在 2 个屏共存时无回归，并为 Phase B 并行定死「一屏一文件」模板。remote 与 player 共享 opener，Task 2 顺带抽出 `_option_screen` 共享 helper。

**Files:**
- Create: `src/ui/screens/_option_screen.lua`、`src/ui/screens/remote_choice.lua`
- Create test: `spec/behavior/ui/screens/remote_choice_screen_spec.lua`
- Modify: `src/ui/screens/registry.lua`（`_load_all` 追加 remote）、`src/ui/render/node_ops.lua`（删 remote 兜底 + require）、`src/ui/coord/choice_openers.lua`（`_screen_openers.remote` 删除，`_open_player_or_remote_screen` 抽共享）、`src/ui/input/routes.lua`（删 `remote_choice_intents.build`）、`src/ui/coord/choice_helpers.lua`（删 `screen_canvases.remote`）
- Pin：同 Task 1 三份 + `spec/behavior/ui/interaction_spec.lua`

**Interfaces:**
- Consumes: Task 1 的 registry 契约、`choice_openers` 共享原语。
- Produces: `_option_screen.open(state, screen_key, choice, choice_id)`（承接 `_open_player_or_remote_screen`，供 remote/player 复用）。

**行为保持：** remote 描述符 = `{ key="remote", root, title, body, option_buttons }`（`node_ops_spec` 钉）。开屏副作用 = `_open_screen` → `_fill_option_nodes`（无 clear_button_text）→ `_set_action_button(confirm, true,true,"确定")` → `_set_action_button(cancel, allow_cancel...)` → `modal_state.open_choice`。route specs 逐个 slot 建 `choice_select`（等价 `route_remote_choice.build`）。`resolve_canvas_for_screen("remote")` 回 `CANVAS_REMOTE_CHOICE`。

- [ ] **Step 1：确认 pin 基线全绿**

Run: `busted --run behavior spec/behavior/ui/action_status/choice_routes_spec.lua spec/behavior/ui/node_ops_spec.lua spec/behavior/ui/interaction_spec.lua`
Expected: PASS。

- [ ] **Step 2：抽共享 `_option_screen` helper**

创建 `src/ui/screens/_option_screen.lua`——把 `choice_openers._open_player_or_remote_screen`（:143-151）搬来，参数化 `screen_key`：

```lua
-- player / remote 共享的选项开屏 helper(两屏 open 委托它,避免复制)。
local openers = require("src.ui.coord.choice_openers")
local modal_state = require("src.ui.state.modal")

local M = {}

function M.open(state, screen_key, choice, choice_id)
  local ui, screen = openers.open_screen(state, screen_key, choice, choice_id)
  local option_ids, selected = openers.fill_option_nodes(
    ui, screen, openers.resolve_player_or_remote_options(choice, screen_key))
  openers.set_action_button(ui, screen.confirm, true, true, "确定")
  local allow_cancel = choice.allow_cancel ~= false
  openers.set_action_button(ui, screen.cancel, allow_cancel, allow_cancel, choice.cancel_label or "取消")
  modal_state.open_choice(state, choice_id, option_ids, selected)
end

return M
```

> 前置：在 `choice_openers.lua` 尾把 `_set_action_button` / `_resolve_player_or_remote_options` 也升为 `M.set_action_button` / `M.resolve_player_or_remote_options`（同 Task 1 Step 5 的导出手法）。

- [ ] **Step 3：写 remote Screen 模块 + 失败测试**

创建 `src/ui/screens/remote_choice.lua`：

```lua
local registry = require("src.ui.screens.registry")
local schema = require("src.ui.schema.remote_choice")
local canvas = require("src.ui.coord.canvas_coordinator")
local option_screen = require("src.ui.screens._option_screen")
local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local M = { key = "remote", canvas = canvas.CANVAS_REMOTE_CHOICE }

function M.descriptor()
  return { key = "remote", root = schema.canvas, title = schema.title,
    body = schema.body, option_buttons = schema.options }
end

function M.open(state, choice, choice_id)
  option_screen.open(state, "remote", choice, choice_id)
end

function M.build_route_specs(state)
  local specs = {}
  for index, name in ipairs(schema.options) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local model = runtime_state.get_ui_model(state)
        local choice = model and model.choice or nil
        if not choice then logger.warn("remote_select without choice"); return nil end
        local option_id = ui_event_intents.resolve_option_id(choice, { index = index }, state)
        if not option_id then logger.warn("remote_select missing option:", tostring(index)); return nil end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end
  return specs
end

registry.register(M)
return M
```

创建 `spec/behavior/ui/screens/remote_choice_screen_spec.lua`（照 target 直测的结构：descriptor 字段 `key/root/title/body/option_buttons`、registry 注册、每个 option 有 route spec、`canvas_for("remote")==M.canvas`）。

- [ ] **Step 4：registry `_load_all` 追加 remote + 清 node_ops/openers/routes/helpers 的 remote 旧片**

- `registry.lua` `_load_all` 取消注释 `require("src.ui.screens.remote_choice")`。
- `node_ops.build_choice_screens` 删 `screens.remote = screens.remote or {...}` 兜底；若 `remote_choice_nodes` 仅此处用，删其 require（`:5`）。
- `choice_openers.lua` 删 `_screen_openers.remote = _open_player_or_remote_screen`（:190）；`_open_player_or_remote_screen` 若仅剩 player 用则保留至 Phase B player 迁完。
- `routes.canvas_builders` 删 `remote_choice_intents.build`（:20）与其 require（:6）。
- `choice_helpers` 删 `screen_canvases.remote`（:13）。

- [ ] **Step 5：跑屏直测 + pin**

Run: `busted --run behavior spec/behavior/ui/screens/remote_choice_screen_spec.lua spec/behavior/ui/action_status/choice_routes_spec.lua spec/behavior/ui/node_ops_spec.lua spec/behavior/ui/interaction_spec.lua`
Expected: PASS。

- [ ] **Step 6：门禁 + Commit**

Run: `make verify`
Expected: PASS。

```bash
git add src/ui/screens/_option_screen.lua src/ui/screens/remote_choice.lua \
  spec/behavior/ui/screens/remote_choice_screen_spec.lua src/ui/screens/registry.lua \
  src/ui/render/node_ops.lua src/ui/coord/choice_openers.lua \
  src/ui/input/routes.lua src/ui/coord/choice_helpers.lua
git commit -m "refactor(ui): remote 选择屏收进 Screen 深模块,抽 _option_screen 共享 helper"
```

---

## 逐屏迁移 Recipe（Phase B 各屏套用；每屏一个 subagent）

> **不为 player / secondary_confirm 写 no-placeholder 步骤**——它们与 target/remote 同构，套下方 recipe。recipe 是 Task 1/2 定型后的机械模板。

**每屏迁移 = 一个新文件 `src/ui/screens/<key>.lua` + registry 一行注册 + 清 5 张共享表里的该屏旧片。步骤：**

1. **确认 pin 基线绿**：`busted --run behavior spec/behavior/ui/action_status/choice_routes_spec.lua spec/behavior/ui/node_ops_spec.lua`。
2. **写屏直测** `spec/behavior/ui/screens/<key>_screen_spec.lua`：断言 `descriptor()` 字段与 `node_ops_spec` 对该屏的既有断言逐字段一致、registry 注册、每个交互节点有 route spec、`canvas_for(key)==M.canvas`。跑，确认 FAIL。
3. **写屏模块** `src/ui/screens/<key>.lua`，实现 4 个契约成员：
   - `M.key` / `M.canvas`（从 `choice_helpers.screen_canvases[key]` 抄）。
   - `M.descriptor()` —— 逐字段抄 `node_ops.build_choice_screens.<key>`。
   - `M.open(state, choice, choice_id)` —— 逐句搬 `choice_openers` 里该屏的 `_open_*` 函数体（用 `openers.*` 共享原语；player 委托 `_option_screen.open`）。
   - `M.build_route_specs(state)` —— 逐句搬 `route_<key>.build` 的 specs。
   - 文件尾 `registry.register(M)`。
4. **registry `_load_all` 追加** `require("src.ui.screens.<key>")`。
5. **清该屏旧片**（5 张表）：`node_ops` 删兜底/require；`choice_openers` 删 `_screen_openers.<key>` 与 `_open_*` 函数体；`routes` 删 `<key>_intents.build` 与 require；`choice_helpers` 删 `screen_canvases.<key>`。
6. **跑屏直测 + pin + `make verify`**，全绿后 commit：`refactor(ui): <key> 选择屏收进 Screen 深模块`。

**特殊处理清单（迁移时必须照顾）：**
- **`secondary_confirm`** 最复杂：除 `open_secondary_confirm_screen` 外还有 `open_pre_confirm_screen`（`choice_openers.lua:178-187`，item-phase 预确认变体）与 `modal.lua` 的 `_refresh_secondary_confirm_copy` / `_open_item_phase_pre_confirm`。其确认键**是活的**（`route_secondary_confirm.lua` → `choice_confirm_intent`），与 target 的 inert 相反。这两个变体开屏与 copy 刷新一并收进 `secondary_confirm.lua`（或其 `_pre_confirm` 卫星），`modal.lua` 侧降为调用屏模块。**此屏建议留到 Phase B 最后、单独 review。**
- **`player`** 与 `remote` 共享 `_option_screen.open`；player 迁完后 `choice_openers._open_player_or_remote_screen` 变死 → 删除。

---

## 并行执行编排（本候选重点 —— 需先付 seam 成本，之后赚真实壁钟）

```
Phase A(串行·定型 + 拆瓶颈)          Phase B(并行 fan-out)         Barrier
┌───────────────┐  ┌───────────────┐   ┌─ player_choice   ─┐   ┌──────────────┐
│ Task 1        │→ │ Task 2        │ → │─ secondary_confirm─│ → │ Task B-final │
│ target+registry│  │ remote+recipe │   └────(各一 worktree)┘   │ 清死+manifest│
└───────────────┘  └───────────────┘                            │ +门禁+验收   │
   registry seam 落地 → 5 张共享表委托                            └──────────────┘
```

**为何必须先串行两步（诚实核心）：** 4 个屏当前**共享 5 张派发/工厂表**（`node_ops.build_choice_screens`、`choice_openers._screen_openers`、`routes.canvas_builders`、`choice_helpers.screen_canvases`、`ui_state`）。**未引入 registry 前，任何两屏并行都改同一批文件 → 冲突**。Task 1 引入 registry 并把 5 张表改成委托（一次性）；Task 2 用第二屏证明 seam 在 N=2 不回归。**只有 Task 1/2 合并后，剩余屏才各自 = 一个新文件 + append-only 注册 + 删各自旧片**，此时才能安全 fan-out。这与候选 ③ 根本不同：③ 天生 3 个 disjoint 文件、可直接并行；⑥ 的并行是「seam 换来的」。

**Phase B 冲突矩阵（Task 1/2 合并后）：**

| 屏 subagent | 新增文件（零冲突） | registry 清单（append-only） | 删旧片的共享文件（残余冲突面） | 消费别 task 产出？ |
|---|---|---|---|---|
| player_choice | `screens/player_choice.lua` + spec | +1 行 require | `node_ops`/`choice_openers`/`routes`/`choice_helpers` 各删 player 片 | 用 Task 2 的 `_option_screen`（只读） |
| secondary_confirm | `screens/secondary_confirm.lua`(+`_pre_confirm`) + spec | +1 行 require | 同上 + `modal.lua` 删 pre-confirm 内联 | 否 |

**残余冲突面（诚实）：** 新文件与 registry 注册可无冲突并行；但**每屏仍要从 4~5 个共享文件里删自己那片**（disjoint 函数/行，git 多能自动合并同文件的 disjoint hunk，但比候选 ③「完全不同文件」风险高）。缓解：
1. **每屏 worktree 隔离**（`isolation: "worktree"`），各自 `make verify` 自证 + commit。
2. **删旧片限定在各屏专属的 disjoint 行段**（player 只删 `_screen_openers.player`/player 兜底/`route_player_choice` builder；secondary_confirm 只删自己那些）——不碰别屏的行。
3. **合并顺序**：先合 player（删片少），再合 secondary_confirm（删片多，含 `modal.lua`）——减少同文件二次冲突。若自动合并失败，barrier 时手工 reconcile（都是删除，语义无歧义）。

**swarm 分派方式：**
1. **串行先做 Task 1 → Task 2**（同一工作树，或各自 worktree 顺序合并）。这两步是 recipe + seam 的唯一权威来源，不可并行、不可跳过。
2. **Task 1/2 合并后，同一条消息 fan-out 2 个 subagent**（player / secondary_confirm），各 `isolation: "worktree"`，各做 recipe 全流程 + `make verify` + commit。
3. **合并两个 worktree**（先 player 后 secondary_confirm）。
4. **单独跑 Task B-final（barrier）**。

**壁钟收益（诚实，与候选 ③ 不同）：**
- **Phase B（4 屏干净集）壁钟收益有限**：付掉 Task 1/2 串行成本后只剩 2 屏，并行省不了多少壁钟——主要赚「2 个 reviewer 并行 gate」。
- **真实壁钟价值在 Phase C 的大面尾巴**（`market` / `skin_panel` 16.8K / `item_atlas` 14K / `item_slots` 8K / `popup`）：这些是**彼此独立的大模块**，registry seam 已就位后每面一个 subagent 并行迁移，**壁钟收益显著**——这才是评审「天然高度并行」真正兑现的地方。**结论：本候选并行确有壁钟价值，但价值集中在 Phase C，前提是先在 Phase A 一次性付清 registry seam。**

---

## Task B-final（Barrier —— Phase B 全部合并后）：清死 + manifest + 完整门禁 + 验收

**Files:** Modify（清死片 + manifest）：`src/ui/render/node_ops.lua`、`src/ui/coord/choice_openers.lua`、`src/ui/input/routes.lua`、`src/ui/coord/choice_helpers.lua`、`src/ui/screens/*.lua`。全仓验证。

> **前置：Phase B 两个 worktree 已合并进同一树，4 屏（target/remote/player/secondary_confirm）全走 registry。**

- [ ] **Step 1：deletion-test 复核（口头）**

删 `src/ui/screens/target_choice.lua` → target 屏的 schema 引用 + 开屏 + 按钮同步 + 点击意图**同时消失**，且**无别处冗余承接**（旧碎片已删）。改一个屏现在 = 动一个文件。评审的「locality 缺陷」归零：一个屏的份额集中在一处、非冗余。

- [ ] **Step 2：确认 5 张共享表已无逐屏死片**

Run: `grep -rn "_screen_openers\|_open_target_screen\|_open_player_or_remote_screen\|screen_canvases\." src/ui/coord/ | grep -v manifest`
Expected: `_screen_openers` 表应已空或删除；`_open_*` 屏专属开屏函数应已删；`screen_canvases` 仅剩非 choice-屏兜底（若有）。残留即漏迁。

Run: `grep -n "target_choice_nodes\|remote_choice_nodes\|player_choice_nodes\|secondary_confirm_nodes" src/ui/render/node_ops.lua`
Expected: 空（4 屏 schema require 已随描述符迁走）。若 `sync_target_choice_buttons` 已只被 `target_choice.lua` 调 → 可将其搬进 target screen 模块并从 node_ops 删除（连带 `node_ops_spec` 的 `sync_target_choice_buttons` describe 迁到 target 屏直测——**此项若触碰 node_ops_spec 需谨慎，作为可选收尾**）。

- [ ] **Step 3：刷新受影响文件的 mutation manifest**

Run:
```bash
for f in src/ui/render/node_ops.lua src/ui/coord/choice_openers.lua \
  src/ui/input/routes.lua src/ui/coord/choice_helpers.lua \
  src/ui/screens/target_choice.lua src/ui/screens/remote_choice.lua \
  src/ui/screens/player_choice.lua src/ui/screens/secondary_confirm.lua \
  src/ui/screens/registry.lua; do
  lua tools/quality/mutate.lua "$f" --update-manifest
done
```
Expected: 每个 `manifest updated`（只动各文件尾 manifest 注释块——`git diff -U0` 核对最早改动行号 > 该文件 `mutate4lua-manifest` marker 行号）。

- [ ] **Step 4：完整门禁 + 验收**

Run: `make verify && make acceptance`
Expected: 两者 PASS（`choice_routes` / `node_ops` / `interaction` / `gameplay_t6_hotspot` 全绿；验收 `items`/`chance`/`movement` 不回归——UI 观测行为零变化）。

- [ ] **Step 5：Commit**

```bash
git add -A
git commit -m "chore(ui): 清 4 选择屏迁移后共享表死片 + 刷新 screens/node_ops/openers manifest"
```

---

## Phase C（后续独立 plan，非本计划步骤）—— 大面尾巴逐面归位

> **不是可执行步骤，是给后续 `writing-plans` 的入口与约束。** 每面各带独立 coordinator、体量大（`skin_panel` 16.8K / `item_atlas` 14K），**各自一份 plan**，形同候选 ③-大。registry seam（Task 1）已就位 → 这些面可**真正并行 fan-out**，壁钟收益最高。

**候选面清单与阻力：**

| 面 | canvas schema | 主 coordinator | 体量 | 阻力 / 特殊性 |
|---|---|---|---|---|
| `market` | `schema/market` + `market_layout` | `coord/market.lua` + `route_market`（build_items/build_controls 双 builder）| 中 | 有 tab/分页/双 route builder；与候选 ② purchase 结算有交叉 |
| `skin_panel` | `schema/skin` | `coord/skin_panel.lua`(16.8K)+`skin_gallery`+`skin_panel_actions/state` | 大 | 多子模块已拆，宜整组收进 `screens/skin_panel/` |
| `item_atlas` | `schema/item_atlas` | `coord/item_atlas.lua`(14K) | 大 | 图鉴翻页/详情，交互多 |
| `item_slots` | `schema/base`(slots) | `coord/item_slots*.lua`(4 文件) | 大 | highlight/options/events 已分文件，非单屏 |
| `popup` | `schema/popup` | `coord/popup.lua`+`popup_assets` | 中 | 卡片弹窗 + 队列，`modal.lua` 深度耦合 |

**每面 plan 需先回答：** ① 该面是否真适合 `screen.open/build_route_specs/descriptor` 四契约（`item_slots` 可能不吃 descriptor 工厂，需扩展 registry 契约）；② coordinator 拆分边界；③ 迁移面（该面的 pin spec：`skin_panel_spec` 64K、`item_atlas_spec` 35K、`market_panel_spec` 31K——大面 pin 迁移是主阻力）。

---

## Self-Review（写完对着评审复核）

**1. Spec 覆盖（评审候选 ⑥ 每条主张）：**
- ✅「一个屏的 schema+intents+开/关+按钮同步抹在 5-6 个 module」→ 探源逐点核实（target 标本：schema/route/node_ops×2/choice_openers×3/choice_helpers/共享 state+view）。Task 1/2 把 target/remote 收进单文件 + recipe 覆盖 player/secondary_confirm。
- ✅「确认键 inert stub（build_intent 返回 nil），启用/文案/可见性住三个 module 之外」→ 核实属实（route:12 返回 nil；label 在 `_store_target_button_labels`、隐藏在 `sync_target_choice_buttons`、节点名在 `build_choice_screens`）。Task 1 把这四处收进 `target_choice.lua`，inert 语义保留（点槽位即确认）。
- ✅「给每个屏一个 deep module，interface `screen:open`/`screen:on_click`，schema+route 作唯一卫星」→ 落为 `screen.open` / `screen.build_route_specs`（on_click 映射）/ `descriptor` / `canvas`，schema+route 降为卫星。
- ⚠️「15 个 UI 屏」→ **核实为夸大**：干净 recipe 集 = **4 屏**（`node_ops_spec` 钉死），另 ~5 大面各自独立 plan（Phase C）。已在「全貌与分期」诚实清点，非遗漏——大面显式移交 Phase C。
- ✅ deletion test（删任一屏文件 → 该屏份额消失且无冗余承接）→ Barrier Step 1 复核。

**2. Placeholder 扫描：** 试点 Task 1（target）/ Task 2（remote）给完整 old→new 代码 + 命令 + 预期 + commit，无占位。Phase B（player/secondary_confirm）**按纪律给 recipe 而非伪步骤**（面同构，逐屏 no-placeholder 不现实且冗余）。Phase C 明确标注「非可执行步骤、后续 plan 入口」。✅

**3. 类型/签名一致性：**
- Screen 契约四成员 `key/canvas/descriptor()/open(state,choice,choice_id)/build_route_specs(state)` 在 Task 1 定义，Task 2 + recipe 逐屏对齐。✅
- registry 五 API `register/build_choice_screens/opener_for/canvas_for/build_route_specs` 在 Task 1 定义，5 张共享表逐一按此委托。✅
- **过渡期兜底**（`build_choice_screens` 合并「registry 已迁移屏 + 未迁移屏内联描述符」）确保**每一步中途都不破 `node_ops_spec` 的 4 屏断言**——已在 Task 1 Step 6 分步策略显式给出。✅

**已知风险（handoff 要说）：**
1. **循环 require**：registry ↔ screen 模块 ↔ node_ops/choice_openers 互 require。已用「函数体内联 require」+「文件尾 register」规避；若 busted 下仍成环，切「registry 不主动 `_load_all`、由 `ui_state`/`routes` 显式 require 各屏一次」方案（Task 1 Step 4 备注）。**这是本计划头号风险，Task 1 Step 8 若门禁报环立即切方案。**
2. **同文件删片的残余冲突**：Phase B 各屏从 4-5 个共享文件删自己那片，比候选 ③ 全 disjoint 文件冲突风险高——靠 worktree 隔离 + disjoint 行段 + 顺序合并缓解，barrier 手工 reconcile（都是删除，语义无歧义）。
3. **`secondary_confirm` 最复杂**（活确认键 + pre_confirm 变体 + `modal.lua` copy 刷新耦合）——建议 Phase B 最后单独做、单独 review，别塞进机械 recipe 一把梭。
4. **壁钟收益诚实定位**：4 屏干净集并行省壁钟有限（主要赚并行 review）；真实壁钟价值在 Phase C 大面尾巴——别把「4 屏并行」当成主要卖点。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-08-candidate-6-ui-screen-modules.md`.

本计划 = **候选 ⑥ 的 4 个干净选择屏（player/target/remote/secondary_confirm）逐屏归位 + registry seam**，完整可执行、零观测行为变化。大面尾巴（market/skin_panel/item_atlas/item_slots/popup）见 Phase C，各需独立 `writing-plans` 展开。

执行结构：**Task 1（target + registry seam）→ Task 2（remote，定型 recipe）串行** → **Phase B（player / secondary_confirm）worktree 隔离并行 fan-out** → **Task B-final barrier**。

两种执行方式：
**1. Subagent-Driven（推荐）** — Task 1/2 各一个 fresh subagent 串行（定 seam + recipe）；Phase B 同一条消息 fan-out 2 个 worktree-隔离 subagent；合并后单跑 barrier。契合本计划「先定型后并行」结构。
**2. Inline 顺序** — 本 session 用 `executing-plans`，Task 1→2→player→secondary_confirm→barrier 顺序执行（4 屏面不大，成本可接受，放弃并行壁钟）。

选哪个？
