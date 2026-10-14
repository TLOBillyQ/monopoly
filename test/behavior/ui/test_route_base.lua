-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

local route_base = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")
local logger = require("src.foundation.log")

local _saved_warn = logger.warn

describe("TestRouteBase", function()

local _warn_captured = nil

local function _with_warn_capture(fn)
  logger.warn = function(...)
    _warn_captured = { ... }
  end
  local ok, err = pcall(fn)
  logger.warn = _saved_warn
  if not ok then
    error(err, 0)
  end
end


do
  local function _state_with_choice(choice)
    return {
      ui_runtime = {
        ui_model = { choice = choice },
      },
    }
  end

  local function _cancel_intent_for(choice)
    local specs = route_base.build(_state_with_choice(choice))
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.cancel_button then
        return spec.build_intent(), true
      end
    end
    return nil, false
  end

  it("test_builds cancel intent for a production item usage follow-up", function()
    -- 生产 followup 形态：kind 因卡而异（item_target_player / remote_dice_value /
    -- roadblock_target / demolish_target），真源标记是 rules 装饰的 meta.passive_origin
    -- （src/rules/choice_handlers/item_phase_handlers.lua）。
    local intent, found = _cancel_intent_for({
      id = "target_choice_1",
      kind = "item_target_player",
      route_key = "player",
      allow_cancel = true,
      meta = { passive_origin = true, item_id = 2007, player_id = 1, phase = "pre_action" },
    })

    luassert.truthy(found, "cancel spec must exist")
    luassert.truthy(intent ~= nil, "a cancelable followup must yield a cancel intent")
    _assert_eq(intent.type, "choice_cancel", "cancel intent type")
    _assert_eq(intent.choice_id, "target_choice_1", "cancel intent targets current choice")
  end)

  it("test_builds cancel intent for every followup kind, not just one", function()
    -- 各 kind 按真实出生地配卡：遥控骰子 2002(仅 pre_action)/路障 2004/怪兽 2008。
    local fixtures = {
      { kind = "remote_dice_value", item_id = 2002, phase = "pre_action" },
      { kind = "roadblock_target", item_id = 2004, phase = "post_action" },
      { kind = "demolish_target", item_id = 2008, phase = "pre_action" },
    }
    for _, fixture in ipairs(fixtures) do
      local intent = _cancel_intent_for({
        id = "followup_" .. fixture.kind,
        kind = fixture.kind,
        allow_cancel = true,
        meta = { passive_origin = true, item_id = fixture.item_id, player_id = 1, phase = fixture.phase },
      })
      luassert.truthy(intent ~= nil, "cancel intent must exist for followup kind " .. fixture.kind)
      _assert_eq(intent.type, "choice_cancel", "cancel intent type for " .. fixture.kind)
    end
  end)

  it("test_omits cancel intent for the item phase slot window", function()
    -- 槽位窗（kind=item_phase_passive, meta.phase 恒有值）的退出口是行动/结束按钮
    -- （complete_optional_action_phase），基础屏取消按钮不接管它。
    local intent = _cancel_intent_for({
      id = "slot_window_1",
      kind = "item_phase_passive",
      allow_cancel = true,
      meta = { player_id = 1, phase = "pre_action", resume_next_state = "roll" },
    })
    luassert.truthy(intent == nil, "the slot window must not yield a base cancel intent")
  end)

  it("test_omits cancel intent when rules closed the followup exit", function()
    -- escrow/预消耗由 rules 成对写 allow_cancel=false 与 meta.item_preconsumed。
    local intent = _cancel_intent_for({
      id = "escrow_1",
      kind = "item_target_player",
      allow_cancel = false,
      meta = { passive_origin = true, item_id = 2007, player_id = 1, phase = "pre_action", item_preconsumed = true },
    })
    luassert.truthy(intent == nil, "an allow_cancel=false followup must not yield a cancel intent")
  end)

  it("test_omits cancel intent when no item target selection", function()
    local intent = _cancel_intent_for({
      id = "optional_1",
      kind = "landing_optional_effect",
      allow_cancel = true,
    })
    luassert.truthy(intent == nil, "cancel intent should be nil for landing optional effect")
  end)

  it("test_keeps action intent for wait-action phase", function()
    local state = _state_with_choice(nil)

    local specs = route_base.build(state)
    local action_spec = nil
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.action_button then
        action_spec = spec
        break
      end
    end

    luassert.truthy(action_spec ~= nil, "action spec must exist")
    local intent = action_spec.build_intent()
    _assert_eq(intent.type, "ui_button", "action intent type")
    _assert_eq(intent.id, "next", "action intent id")
  end)

  local function _action_intent_for(choice)
    local specs = route_base.build(_state_with_choice(choice))
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.action_button then
        return spec.build_intent()
      end
    end
    return nil
  end

  it("test_routes action button through skip during pre-action item phase", function()
    local intent = _action_intent_for({
      id = "pre_action_1",
      kind = "item_phase_passive",
      allow_cancel = true,
      meta = { phase = "pre_action" },
    })

    luassert.truthy(intent ~= nil, "action button should build an intent during pre-action item phase")
    _assert_eq(intent.type, "complete_optional_action_phase",
      "action button should skip the pre-action item phase and advance to the roll")
  end)

  it("test_omits action intent during post-action optional phase", function()
    local intent = _action_intent_for({
      id = "post_action_1",
      kind = "item_phase_passive",
      allow_cancel = true,
      meta = { phase = "post_action" },
    })

    luassert.truthy(intent == nil,
      "post-action optional phase should route the skip through the end button, not the action button")
  end)

  it("test_ignored_cancel_click_logs_kind_when_choice_present", function()
    -- L61 `choice and ("choice_kind=" .. ...) or "choice=nil"` 的 and->or
    -- (choice 表整表进 warn)与 or->and(恒 "choice=nil"):口径外点击必须
    -- 带 choice_kind 前缀日志。
    _with_warn_capture(function()
      local intent = _cancel_intent_for({
        id = "optional_1",
        kind = "landing_optional_effect",
        allow_cancel = true,
      })
      luassert.truthy(intent == nil, "non-cancelable kind must yield no intent")
    end)
    luassert.truthy(_warn_captured ~= nil, "ignored cancel click must warn")
    _assert_eq(_warn_captured[2], "choice_kind=landing_optional_effect",
      "warn must carry the choice kind prefix")
  end)

  it("test_ignored_cancel_click_logs_choice_nil_marker", function()
    -- L61 `"choice=nil"` 换 nil:无 choice 时必须带 choice=nil 标记。
    _with_warn_capture(function()
      local intent = _cancel_intent_for(nil)
      luassert.truthy(intent == nil, "no choice must yield no cancel intent")
    end)
    luassert.truthy(_warn_captured ~= nil, "ignored cancel click without choice must warn")
    _assert_eq(_warn_captured[2], "choice=nil", "warn must carry the choice=nil marker")
  end)
end


end)
