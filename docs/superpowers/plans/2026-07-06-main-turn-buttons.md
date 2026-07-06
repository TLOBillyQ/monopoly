# 主回合按钮（main-turn-buttons）实现计划

> **For agentic workers:** REQUIRED SUB-_SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现基础屏主按钮新语义：投骰子前显示“行动”、强制落地选择完成后显示“结束”、道具目标选择阶段显示“取消”。

**Architecture:** 在现有 `panel_controls`/`route_base`/`action_dispatch` 三层 seam 上扩展，新增取消按钮节点与显隐/路由/派发逻辑；复用 `choice_cancel` 命令语义处理取消返回；通过 TDD 补充单元测试与 acceptance step handler。

**Tech Stack:** Lua 5.4, busted, 项目本地 acceptance4lua 流水线。

## Global Constraints

- 项目语言：Lua 5.4，单元测试使用 busted。
- 不修改 `swarmforge/tools.lock`。
- 不使用 `--coverage`/`--crap`/`--full` 跑 `verify_full.lua`；使用 `make test` 与 `make acceptance` 做验证。
- 保持 generated acceptance tests 与 unit tests 分离。
- 每个行为切片先写失败单元测试，再写最小实现。
- 提交前运行 `make test` 与 `make acceptance`。

---

## File Structure

| 文件 | 职责 |
|------|------|
| `src/ui/schema/base.lua` | 基础屏节点名表；新增 `cancel_button`。 |
| `src/ui/render/widgets/panel_controls.lua` | 基础屏行动/结束/取消三按钮显隐与触摸状态。 |
| `src/ui/input/route_base.lua` | 为基础屏按钮构建 intent；新增取消按钮 intent。 |
| `src/turn/actions/action_dispatch.lua` | 将 `ui_button id="cancel"` 转换为 `choice_cancel` 并派发。 |
| `src/ui/input/command_definitions.lua` | 若需要，为 `cancel` ui_button 注册静态命令描述。 |
| `tools/acceptance/steps/base_screen/end_button_steps.lua` | 结束按钮断言；扩展为按钮断言模块。 |
| `tools/acceptance/steps/base_screen/action_completion_steps.lua` | 行动/结束/取消按钮触发与完成状态断言。 |
| `tools/acceptance/steps/base_screen/phase_state_steps.lua` | 阶段状态设置；新增“进入目标选择”。 |
| `tools/acceptance/steps/base_screen/context.lua` | 新增目标选择 choice 构造辅助。 |
| `features/game/main_turn_buttons.feature` | 已存在的行为规格；驱动实现。 |
| `spec/behavior/ui/action_status/player_panels_spec.lua` | panel_controls 行为单元测试。 |
| `spec/behavior/turn/action_dispatch_baseline_spec.lua` | action_dispatch 行为单元测试。 |
| `spec/behavior/ui/route_base_spec.lua` | 新增 route_base 单元测试。 |

---

### Task 1: 在 UI schema 中注册取消按钮节点

**Files:**
- Modify: `src/ui/schema/base.lua:1-36`

**Interfaces:**
- Produces: `base_nodes.cancel_button == "基础_取消按钮"`，供 `panel_controls`、`route_base`、acceptance 使用。

- [ ] **Step 1: 写失败测试**

在 `spec/behavior/ui/schema_base_spec.lua` 新增（若不存在则先创建文件）：

```lua
local base_nodes = require("src.ui.schema.base")

describe("base ui schema", function()
  it("exports cancel_button node", function()
    assert(base_nodes.cancel_button == "基础_取消按钮",
      "cancel_button node must be registered")
  end)
end)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `busted spec/behavior/ui/schema_base_spec.lua`
Expected: FAIL with `attempt to index a nil value (field 'cancel_button')`。

- [ ] **Step 3: 添加 schema 节点**

在 `src/ui/schema/base.lua` 的 `nodes` 表中，在 `end_button` 下方插入：

```lua
cancel_button = "基础_取消按钮",
```

- [ ] **Step 4: 运行测试确认通过**

Run: `busted spec/behavior/ui/schema_base_spec.lua`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add src/ui/schema/base.lua spec/behavior/ui/schema_base_spec.lua
git commit -m "feat(ui): register base cancel_button schema node"
```

---

### Task 2: 让 panel_controls 支持三按钮显隐

**Files:**
- Modify: `src/ui/render/widgets/panel_controls.lua:116-133`
- Test: `spec/behavior/ui/action_status/player_panels_spec.lua`

**Interfaces:**
- Consumes: `base_nodes.cancel_button`；`choice_support.is_optional_action_choice`、`is_cancelable_optional_action_choice`。
- Produces: `panel_controls.apply_base_action_controls(ui, ui_model, base_visible)` 现在设置行动/结束/取消三按钮的 `visible` 与 `touch_enabled`。

- [ ] **Step 1: 写失败测试**

在 `spec/behavior/ui/action_status/player_panels_spec.lua` 末尾的 describe 中新增三个 it：

```lua
  it("_test_panel_controls_target_selection_shows_cancel_button", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local touch = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function(_, name, value)
        touch[name] = value
      end,
    }
    local ui_model = {
      choice = {
        id = 11,
        kind = "item_phase_passive",
        allow_cancel = true,
      },
    }

    panel_controls.apply_base_action_controls(ui, ui_model, true)

    _assert_eq(visible[base_nodes.action_button], false,
      "target selection should hide action button")
    _assert_eq(visible[base_nodes.end_button], false,
      "target selection should hide end button")
    _assert_eq(visible[base_nodes.cancel_button], true,
      "target selection should show cancel button")
    _assert_eq(touch[base_nodes.cancel_button], true,
      "cancel button should be touchable when shown")
  end)

  it("_test_panel_controls_wait_action_hides_cancel_button", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function() end,
    }

    panel_controls.apply_base_action_controls(ui, {}, true)

    _assert_eq(visible[base_nodes.cancel_button], false,
      "wait action should hide cancel button")
    _assert_eq(visible[base_nodes.action_button], true,
      "wait action should show action button")
  end)

  it("_test_panel_controls_non_cancelable_optional_hides_all_main_buttons", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function() end,
    }
    local ui_model = {
      choice = {
        id = 12,
        kind = "item_phase_passive",
        allow_cancel = false,
      },
    }

    panel_controls.apply_base_action_controls(ui, ui_model, true)

    _assert_eq(visible[base_nodes.action_button], false,
      "non-cancelable optional should hide action")
    _assert_eq(visible[base_nodes.end_button], false,
      "non-cancelable optional should hide end")
    _assert_eq(visible[base_nodes.cancel_button], false,
      "non-cancelable optional should hide cancel")
  end)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `busted spec/behavior/ui/action_status/player_panels_spec.lua --filter "_test_panel_controls_target_selection"`
Expected: FAIL with `cancel_button` nil 或 `expected cancel button visible`。

- [ ] **Step 3: 修改 `_resolve_base_action_visibility` 与 `apply_base_action_controls`**

将 `src/ui/render/widgets/panel_controls.lua` 中：

```lua
local function _resolve_base_action_visibility(ui_model, base_visible)
  if base_visible ~= true then
    return false, false
  end
  local choice = ui_model and ui_model.choice
  if not choice_support.is_optional_action_choice(choice) then
    return true, false
  end
  return false, choice_support.is_cancelable_optional_action_choice(choice) == true
end

function panel_controls.apply_base_action_controls(ui, ui_model, base_visible)
  local action_visible, end_visible = _resolve_base_action_visibility(ui_model, base_visible)
  ui:set_visible(base_nodes.action_button, action_visible)
  ui:set_touch_enabled(base_nodes.action_button, action_visible)
  ui:set_visible(base_nodes.end_button, end_visible)
  ui:set_touch_enabled(base_nodes.end_button, end_visible)
end
```

替换为：

```lua
local function _is_item_target_selection(choice)
  return choice and choice.kind == "item_phase_passive"
end

local function _resolve_base_action_visibility(ui_model, base_visible)
  if base_visible ~= true then
    return false, false, false
  end
  local choice = ui_model and ui_model.choice
  if not choice_support.is_optional_action_choice(choice) then
    return true, false, false
  end
  if not choice_support.is_cancelable_optional_action_choice(choice) then
    return false, false, false
  end
  if _is_item_target_selection(choice) then
    return false, false, true
  end
  return false, true, false
end

function panel_controls.apply_base_action_controls(ui, ui_model, base_visible)
  local action_visible, end_visible, cancel_visible = _resolve_base_action_visibility(ui_model, base_visible)
  ui:set_visible(base_nodes.action_button, action_visible)
  ui:set_touch_enabled(base_nodes.action_button, action_visible)
  ui:set_visible(base_nodes.end_button, end_visible)
  ui:set_touch_enabled(base_nodes.end_button, end_visible)
  ui:set_visible(base_nodes.cancel_button, cancel_visible)
  ui:set_touch_enabled(base_nodes.cancel_button, cancel_visible)
end
```

- [ ] **Step 4: 运行测试确认通过**

Run: `busted spec/behavior/ui/action_status/player_panels_spec.lua --filter "_test_panel_controls"`
Expected: PASS（包含已有的 action/end 测试与新 cancel 测试）。

- [ ] **Step 5: 提交**

```bash
git add src/ui/render/widgets/panel_controls.lua spec/behavior/ui/action_status/player_panels_spec.lua
git commit -m "feat(ui): show/hide cancel button for item target selection"
```

---

### Task 3: route_base 为取消按钮构建 choice_cancel intent

**Files:**
- Modify: `src/ui/input/route_base.lua:1-75`
- Create: `spec/behavior/ui/route_base_spec.lua`

**Interfaces:**
- Consumes: `base_nodes.cancel_button`；`route_model.choice(state)`。
- Produces: 当当前 choice 为可取消的 `item_phase_passive` 时，`route_base.build(state)` 返回的 spec 列表中包含 `{ name = base_nodes.cancel_button, build_intent = function() return { type = "choice_cancel", choice_id = <id> } end }`。

- [ ] **Step 1: 写失败测试**

创建 `spec/behavior/ui/route_base_spec.lua`：

```lua
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local route_base = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")

describe("route_base intents", function()
  local function _state_with_choice(choice)
    return {
      ui = {
        runtime = {
          ui_model = { choice = choice },
        },
      },
    }
  end

  it("builds cancel intent for item target selection", function()
    local state = _state_with_choice({
      id = "target_choice_1",
      kind = "item_phase_passive",
      allow_cancel = true,
    })

    local specs = route_base.build(state)
    local cancel_spec = nil
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.cancel_button then
        cancel_spec = spec
        break
      end
    end

    assert(cancel_spec ~= nil, "cancel spec must exist")
    local intent = cancel_spec.build_intent()
    _assert_eq(intent.type, "choice_cancel", "cancel intent type")
    _assert_eq(intent.choice_id, "target_choice_1", "cancel intent targets current choice")
  end)

  it("omits cancel intent when no item target selection", function()
    local state = _state_with_choice({
      id = "optional_1",
      kind = "landing_optional_effect",
      allow_cancel = true,
    })

    local specs = route_base.build(state)
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.cancel_button then
        local intent = spec.build_intent()
        assert(intent == nil, "cancel intent should be nil for landing optional effect")
      end
    end
  end)

  it("keeps action intent for wait-action phase", function()
    local state = _state_with_choice(nil)

    local specs = route_base.build(state)
    local action_spec = nil
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.action_button then
        action_spec = spec
        break
      end
    end

    assert(action_spec ~= nil, "action spec must exist")
    local intent = action_spec.build_intent()
    _assert_eq(intent.type, "ui_button", "action intent type")
    _assert_eq(intent.id, "next", "action intent id")
  end)
end)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `busted spec/behavior/ui/route_base_spec.lua`
Expected: FAIL with `cancel spec must exist`。

- [ ] **Step 3: 在 route_base 中添加取消按钮 intent**

在 `src/ui/input/route_base.lua` 的 `intents.build` 返回的 table 中，在 `end_button` 条目之后新增：

```lua
    {
      name = base_nodes.cancel_button,
      build_intent = function()
        local choice = route_model.choice(state)
        if choice and choice.kind == "item_phase_passive" and choice.allow_cancel ~= false then
          return {
            type = "choice_cancel",
            choice_id = choice.id,
          }
        end
        return nil
      end,
    },
```

- [ ] **Step 4: 运行测试确认通过**

Run: `busted spec/behavior/ui/route_base_spec.lua`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add src/ui/input/route_base.lua spec/behavior/ui/route_base_spec.lua
git commit -m "feat(ui): build choice_cancel intent for base cancel button"
```

---

### Task 4: action_dispatch 处理 ui_button id="cancel"

**Files:**
- Modify: `src/turn/actions/action_dispatch.lua:100-118`
- Test: `spec/behavior/turn/action_dispatch_baseline_spec.lua`

**Interfaces:**
- Consumes: `ui_button` action with `id == "cancel"`。
- Produces: 验证当前玩家后，派发 `{ type = "choice_cancel", choice_id = <pending_choice.id>, actor_role_id = <actor> }`。

- [ ] **Step 1: 写失败测试**

在 `spec/behavior/turn/action_dispatch_baseline_spec.lua` 的 describe `action_dispatch action.type dispatch` 中新增：

```lua
  it("ui_button id=cancel dispatches choice_cancel for current player's item target choice", function()
    local r = _drive("ui_button", {
      id = "cancel",
      pending_choice = {
        id = "target_1",
        kind = "item_phase_passive",
        allow_cancel = true,
      },
    })
    _assert_eq(r.result.status, "applied", "cancel ui_button must apply")
    _assert_eq(r.handle_choice_called, true, "cancel ui_button should dispatch choice_cancel")
  end)

  it("ui_button id=cancel rejects when actor is not current player", function()
    local dispatcher, events, deps = _build()
    deps.validator.validate_actor_role = function(game, action)
      return action.actor_role_id == 1
    end
    deps.validator.validate_choice_action = function() return true end

    local game = {
      turn = {
        phase = "wait_action",
        pending_choice = { id = "target_1", kind = "item_phase_passive", allow_cancel = true },
      },
      dispatch_action = function() end,
      find_player_by_id = function() return { id = 1 } end,
      players = { { id = 1 }, { id = 2 } },
    }
    local action = { type = "ui_button", id = "cancel", actor_role_id = 2 }
    local ctx = _ctx_with_invalidate(events, { pending_choice = game.turn.pending_choice })

    local result = dispatcher.dispatch_action(game, {}, action, nil, ctx)
    _assert_eq(result.status, "rejected", "cancel from non-current player must reject")
  end)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `busted spec/behavior/turn/action_dispatch_baseline_spec.lua --filter "ui_button id=cancel"`
Expected: FAIL with `expected cancel ui_button must apply`。

- [ ] **Step 3: 在 _handle_ui_button 中处理 cancel**

在 `src/turn/actions/action_dispatch.lua` 的 `_handle_ui_button` 中，在 `if action.id == "auto"` 之后、`validate_actor_role` 之前（或之后）插入：

```lua
    if action.id == "cancel" then
      if not validator.validate_actor_role(game, action) then
        return { status = "rejected" }
      end
      local choice = _resolve_pending_choice(game, state, ctx)
      if choice == nil or choice.allow_cancel == false then
        return { status = "rejected" }
      end
      return _dispatch_action(game, state, {
        type = "choice_cancel",
        choice_id = choice.id,
        actor_role_id = action.actor_role_id,
        input_source = action.input_source,
      }, opts, ctx)
    end
```

注意 `_resolve_pending_choice` 是局部函数，已在 `_handle_ui_button` 上方定义？检查文件：`_resolve_pending_choice` 定义在 `_handle_ui_button` 之前（第 33-43 行），可直接使用。

- [ ] **Step 4: 运行测试确认通过**

Run: `busted spec/behavior/turn/action_dispatch_baseline_spec.lua --filter "ui_button id=cancel"`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add src/turn/actions/action_dispatch.lua spec/behavior/turn/action_dispatch_baseline_spec.lua
git commit -m "feat(turn): dispatch choice_cancel from cancel ui_button"
```

---

### Task 5: 为 cancel ui_button 注册命令描述（如需要）

**Files:**
- Modify: `src/ui/input/command_definitions.lua:120-133`
- Test: `spec/behavior/ui/command_policy_spec.lua`

**Interfaces:**
- Produces: `command_policy.reason({ type = "ui_button", id = "cancel" })` 返回稳定 reason（若注册）。

- [ ] **Step 1: 检查当前命令策略是否已支持**

Run: `busted spec/behavior/ui/command_policy_spec.lua`
Expected: PASS（当前未涉及 cancel）。

- [ ] **Step 2: 写失败测试（可选）**

若希望 `ui_button id="cancel"` 有独立 reason，在 `command_policy_spec.lua` 新增：

```lua
  it("describes cancel ui_button with stable reason", function()
    _assert_eq(command_policy.reason({ type = "ui_button", id = "cancel" }), "cancel_button",
      "cancel button reason should be stable")
    _assert_eq(command_policy.game_handler({ type = "ui_button", id = "cancel" }), "basic",
      "cancel button should route as basic turn action")
  end)
```

- [ ] **Step 3: 在 UI_BUTTONS 中注册 cancel**

在 `src/ui/input/command_definitions.lua` 的 `UI_BUTTONS` 表中新增：

```lua
  cancel = {
    reason = "cancel_button",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "turn",
  },
```

- [ ] **Step 4: 运行测试确认通过**

Run: `busted spec/behavior/ui/command_policy_spec.lua`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add src/ui/input/command_definitions.lua spec/behavior/ui/command_policy_spec.lua
git commit -m "feat(ui): register cancel ui_button command policy"
```

---

### Task 6: 扩展 acceptance step handler 支持取消按钮与目标选择

**Files:**
- Modify: `tools/acceptance/steps/base_screen/end_button_steps.lua`
- Modify: `tools/acceptance/steps/base_screen/action_completion_steps.lua`
- Modify: `tools/acceptance/steps/base_screen/phase_state_steps.lua`
- Modify: `tools/acceptance/steps/base_screen/context.lua`
- Modify: `tools/acceptance/steps/base_screen/render_flow_context.lua`

**Interfaces:**
- Consumes: `base_nodes.cancel_button`。
- Produces: Gherkin steps `基础屏取消按钮已隐藏`、`基础屏取消按钮已展示且可点击`、`触发基础屏取消按钮`、`玩家点击道具槽位1进入目标选择`。

- [ ] **Step 1: 新增取消按钮断言 step handler**

在 `tools/acceptance/steps/base_screen/end_button_steps.lua` 中，重命名或扩展模块职责。为最小改动，直接在现有文件中新增两个 handler：

```lua
    ["基础屏取消按钮已隐藏"] = function(world)
      local state = world.base_screen_render_state
      local actual = state and state.ui and state.ui.visibility and state.ui.visibility[base_nodes.cancel_button]
      if actual ~= false then
        return nil, "expected cancel button hidden, got " .. tostring(actual)
      end
      return true
    end,

    ["基础屏取消按钮已展示且可点击"] = function(world)
      return assert_helpers.node_visible_and_touchable(world, base_nodes.cancel_button, "cancel button")
    end,
```

- [ ] **Step 2: 新增“触发基础屏取消按钮”**

在 `tools/acceptance/steps/base_screen/action_completion_steps.lua` 中新增：

```lua
    ["触发基础屏取消按钮"] = function(world)
      local intent = render_flow_context.build_base_intent(world, base_nodes.cancel_button)
      world.base_screen_cancel_button_intent = intent
      if intent and intent.type == "choice_cancel" then
        render_flow_context.cancel_optional_action(world, intent, "user")
      end
      return true
    end,
```

并确保 `render_flow_context` 暴露 `cancel_optional_action`（见 Step 5）。

- [ ] **Step 3: 新增目标选择状态设置**

在 `tools/acceptance/steps/base_screen/phase_state_steps.lua` 中新增：

```lua
    ["玩家点击道具槽位1进入目标选择"] = function(world, example)
      local item_name = tostring(example["道具名"] or "")
      return context.enter_item_target_selection(world, item_name)
    end,
```

在 `tools/acceptance/steps/base_screen/context.lua` 中实现：

```lua
function context.enter_item_target_selection(world, item_name)
  local action_role_id = context.current_action_role_id(world)
  world.base_screen_target_choice = {
    id = 9002,
    kind = "item_phase_passive",
    route_key = "item_phase_passive",
    allow_cancel = true,
    owner_role_id = action_role_id,
    meta = {
      passive_origin = true,
      item_name = item_name,
    },
  }
  return true
end
```

修改 `context.optional_choice_for_world`：若 `world.base_screen_target_choice` 存在则返回它，否则保持原逻辑。

- [ ] **Step 4: 在 render_flow_context 中支持取消完成状态**

在 `tools/acceptance/steps/base_screen/render_flow_context.lua` 中新增：

```lua
function render_flow_context.cancel_optional_action(world, intent, input_source)
  local state = world.base_screen_render_state
  local game = render_flow_context.make_completion_game(world)
  local result = optional_action_completion.complete_optional_action_phase(game, context.role_id(world), state, {
    input_source = input_source,
    choice = world.base_screen_ui_model and world.base_screen_ui_model.choice,
    dispatch_choice_action = function(action)
      world.base_screen_cancel_action = action
      return { status = "applied" }
    end,
  })
  world.base_screen_cancel_result = result
  if result.ok == true then
    world.base_screen_target_choice = nil
    if world.base_screen_ui_model then
      world.base_screen_ui_model.choice = nil
    end
    local ui_model = world.base_screen_render_state
      and world.base_screen_render_state.ui_runtime
      and world.base_screen_render_state.ui_runtime.ui_model
    if ui_model then
      ui_model.choice = nil
    end
  end
  return result
end
```

- [ ] **Step 5: 运行新增 acceptance 场景**

Run: `./acceptance-run --feature features/game/main_turn_buttons.feature`
Expected: 至少基础 UI 场景通过；若目标选择/取消返回断言失败，根据输出调整 Step 3-4 的 choice 构造与完成状态。

- [ ] **Step 6: 提交**

```bash
git add tools/acceptance/steps/base_screen/
git commit -m "feat(acceptance): add cancel button and target-selection step handlers"
```

---

### Task 7: 跑全量回归验证

**Files:**
- 无新增文件。

- [ ] **Step 1: 跑单元测试**

Run: `make test`
Expected: PASS。

- [ ] **Step 2: 跑 acceptance**

Run: `make acceptance`
Expected: PASS，包括 `features/game/main_turn_buttons.feature`。

- [ ] **Step 3: 跑受影响模块的 mutation 测试（可选但推荐）**

Run: `lua tools/quality/mutate.lua src/ui/render/widgets/panel_controls.lua`
Run: `lua tools/quality/mutate.lua src/ui/input/route_base.lua`
Run: `lua tools/quality/mutate.lua src/turn/actions/action_dispatch.lua`
Expected: 新增/修改的 scope 全部 killed。

- [ ] **Step 4: 提交任何生成的 acceptance mutation manifest**

若 `make acceptance` 更新了 feature 文件的 mutation stamp，按项目约定由工具自动写入；不要手写修改。

```bash
git add -u
git commit -m "test: verify main-turn-buttons with make test and make acceptance"
```

---

## Self-Review

**1. Spec coverage:**
- 回合开始时只展示行动按钮 → Task 2 的 wait_action 显隐逻辑。
- 行动按钮跳过 pre-action 道具并投骰子 → 已有 `ui_button id="next"` 逻辑，不变。
- 行动按钮在目标选择阶段隐藏 → Task 2 `_is_item_target_selection` 分支。
- 投骰子后强制选择期间隐藏主按钮 → `base_visible=false` 或 choice 非 optional 时全部隐藏。
- 强制选择完成后只展示结束按钮 → Task 2 landing_optional_effect 分支。
- 结束按钮跳过 post-action 道具并结束回合 → 已有 `complete_optional_action_phase`，不变。
- 道具目标选择阶段只展示取消按钮 → Task 2 item_phase_passive 分支。
- 取消按钮返回道具槽选择且不消耗道具 → Task 4/6 派发 `choice_cancel`，由 item phase handler 处理。
- 倒计时超时自动投骰子/结束回合 → 现有 choice_auto_policy，不变。
- 输入锁定期间主按钮隐藏 → Task 2 `base_visible=false` 分支。

**2. Placeholder scan:** 无 TBD/TODO；所有步骤含代码与命令。

**3. Type consistency:**
- `route_base` 返回 `choice_cancel` intent，与 `command_definitions.COMMANDS.choice_cancel` 及 `choice_dispatch.handle_choice_action` 签名一致。
- `action_dispatch` 中 `ui_button id="cancel"` 转换为 `choice_cancel`，字段 `choice_id`/`actor_role_id`/`input_source` 与现有 choice action 一致。
