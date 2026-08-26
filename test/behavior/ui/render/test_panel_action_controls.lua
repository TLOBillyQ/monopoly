-- Behavior specs for src/ui/render/widgets/panel_action_controls.lua.
-- The base screen owns three buttons (行动 / 结束 / 取消) and which of them the
-- player sees depends on the optional-action choice currently open. This pins the
-- whole decision table, plus the countdown and action-hint controls.

local lu = require("luaunit")

local base_nodes = require("src.ui.schema.base")
local panel_action_controls = require("src.ui.render.widgets.panel_action_controls")

local function _assert_eq(a, b, msg)
  lu.assertIs(a, b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _stub_ui()
  local ui = { visible = {}, touch = {}, labels = {} }
  ui.set_visible = function(self, name, value) self.visible[name] = value end
  ui.set_touch_enabled = function(self, name, value) self.touch[name] = value end
  ui.set_label = function(self, name, text) self.labels[name] = text end
  return ui
end

-- Renders the base controls for a choice and reports which buttons are live, as
-- an "action/end/cancel" signature. Visibility and touch must always agree.
-- cancel_allowed 是取消按钮的窄门(panel_controls.is_base_cancel_allowed 的产物):
-- followup 的选择屏会置 choice_active 放倒 base_visible,取消按钮只听这道窄门。
local function _buttons(choice, base_visible, cancel_allowed)
  local ui = _stub_ui()
  panel_action_controls.apply_base_action_controls(ui, { choice = choice }, base_visible, cancel_allowed)

  local names = {
    action = base_nodes.action_button,
    ["end"] = base_nodes.end_button,
    cancel = base_nodes.cancel_button,
  }
  local shown = {}
  for _, key in ipairs({ "action", "end", "cancel" }) do
    local name = names[key]
    lu.assertEvalToTrue(ui.visible[name] == ui.touch[name],
      key .. " button visibility and touch must agree: " .. tostring(ui.visible[name])
        .. " vs " .. tostring(ui.touch[name]))
    shown[#shown + 1] = ui.visible[name] and key or "-"
  end
  return table.concat(shown, "/")
end

TestPanelActionControls = {}

do
  -- panel_action_controls.apply_base_action_controls 共享夹具。
  -- followup 夹具按各 kind 的真实出生地配字段（handlers.lua:153/197/241、
  -- demolish_choice.lua:69）：偷窃 2007 / 遥控骰子 2002(仅 pre_action) /
  -- 路障 2004 / 怪兽 2008。
  local FOLLOWUP_FIXTURES = {
    { kind = "item_target_player", item_id = 2007, phase = "pre_action" },
    { kind = "remote_dice_value", item_id = 2002, phase = "pre_action" },
    { kind = "roadblock_target", item_id = 2004, phase = "post_action" },
    { kind = "demolish_target", item_id = 2008, phase = "pre_action" },
  }

  local function _followup(fixture, overrides)
    local choice = {
      kind = fixture.kind,
      allow_cancel = true,
      meta = { passive_origin = true, item_id = fixture.item_id, player_id = 1, phase = fixture.phase },
    }
    for key, value in pairs(overrides or {}) do
      choice[key] = value
    end
    return choice
  end

  function TestPanelActionControls:test_hides_all_three_buttons_when_the_base_screen_is_not_visible()
    _assert_eq(_buttons(nil, false), "-/-/-", "an invisible base screen shows no buttons")
    _assert_eq(_buttons(nil, nil), "-/-/-", "a missing base_visible shows no buttons")
    _assert_eq(_buttons({ kind = "item_phase_passive" }, "yes"), "-/-/-",
      "only a literal true opens the base screen")
  end

  function TestPanelActionControls:test_shows_the_action_button_when_no_optional_action_choice_is_open()
    _assert_eq(_buttons(nil, true), "action/-/-", "no choice means the plain action button")
    _assert_eq(_buttons({ kind = "market_buy" }, true), "action/-/-",
      "an unrelated choice means the plain action button")
  end

  function TestPanelActionControls:test_hides_all_three_buttons_for_a_non_cancelable_optional_action_choice()
    _assert_eq(_buttons({ kind = "landing_optional_effect", allow_cancel = false }, true), "-/-/-",
      "a forced optional action offers no way out")
  end

  function TestPanelActionControls:test_shows_only_the_cancel_button_during_an_item_usage_follow_up()
    -- followup 的真源标记是 rules 装饰的 meta.passive_origin，kind 因卡而异；
    -- 基础屏取消按钮是该阶段唯一退出口（选择屏自己的取消键刻意 inert）。
    for _, fixture in ipairs(FOLLOWUP_FIXTURES) do
      _assert_eq(_buttons(_followup(fixture), true, true), "-/-/cancel",
        fixture.kind .. " follow-up keeps the base cancel button as the exit")
    end
  end

  function TestPanelActionControls:test_keeps_the_cancel_button_up_when_the_followups_own_screen_drops_base_visible()
    -- 真机时序：followup 选择屏开屏置 choice_active → base_visible=false。
    -- 取消按钮走自己的窄门(cancel_allowed)，不得跟着整屏一起灭——这正是
    -- 「验收全绿、真机不亮」曾经测不到的门。
    _assert_eq(_buttons(_followup(FOLLOWUP_FIXTURES[1]), false, true), "-/-/cancel",
      "choice_active dropping base_visible must not take the cancel exit down")
  end

  function TestPanelActionControls:test_hides_the_cancel_button_when_the_narrow_gate_denies()
    -- 窄门拒绝 = 弹窗/黑市/移动/输入锁在场，或非操作席(对手/旁观屏)。
    _assert_eq(_buttons(_followup(FOLLOWUP_FIXTURES[1]), false, false), "-/-/-",
      "a denied narrow gate hides the cancel exit on this seat")
    _assert_eq(_buttons(_followup(FOLLOWUP_FIXTURES[1]), true, nil), "-/-/-",
      "a missing narrow gate verdict never lights the cancel button")
  end

  function TestPanelActionControls:test_hides_all_three_buttons_for_a_followup_whose_cancel_exit_rules_closed()
    -- escrow/预消耗 followup 由 rules 成对写 allow_cancel=false 与
    -- meta.item_preconsumed(settlement.lua escrow / item_preconsume_policy)：
    -- 无路可退，玩家只能在选择屏里完成选择。
    local escrow = _followup(FOLLOWUP_FIXTURES[1], { allow_cancel = false })
    escrow.meta.item_preconsumed = true
    _assert_eq(_buttons(escrow, true, true), "-/-/-",
      "an escrowed followup offers no base-screen exit")
  end

  function TestPanelActionControls:test_routes_a_pre_action_item_phase_skip_onto_the_action_button()
    _assert_eq(_buttons({
      kind = "item_phase_passive",
      meta = { phase = "pre_action" },
    }, true), "action/-/-", "skipping a pre-action card belongs to 行动")
  end

  function TestPanelActionControls:test_routes_any_other_cancelable_optional_action_onto_the_end_button()
    _assert_eq(_buttons({ kind = "landing_optional_effect" }, true), "-/end/-",
      "a landing optional effect resolves through 结束")
    _assert_eq(_buttons({
      kind = "item_phase_passive",
      meta = { phase = "post_action" },
    }, true), "-/end/-", "a post-action item phase resolves through 结束")
  end
end

do
  -- panel_action_controls.apply_countdown
  function TestPanelActionControls:test_shows_the_countdown_and_its_line_with_the_turn_label()
    local ui = _stub_ui()
    panel_action_controls.apply_countdown(ui, { turn_label = "剩余 12 秒" })
    _assert_eq(ui.visible[base_nodes.countdown], true, "countdown visible by default")
    _assert_eq(ui.visible[base_nodes.countdown_line], true, "countdown line visible by default")
    _assert_eq(ui.labels[base_nodes.countdown], "剩余 12 秒", "the turn label is rendered")
  end

  function TestPanelActionControls:test_hides_the_countdown_when_the_panel_asks_for_it()
    local ui = _stub_ui()
    panel_action_controls.apply_countdown(ui, { countdown_visible = false, turn_label = "x" })
    _assert_eq(ui.visible[base_nodes.countdown], false, "countdown hidden")
    _assert_eq(ui.visible[base_nodes.countdown_line], false, "countdown line hidden with it")
  end

  function TestPanelActionControls:test_treats_a_non_boolean_countdown_visible_as_hidden()
    local ui = _stub_ui()
    panel_action_controls.apply_countdown(ui, { countdown_visible = "yes" })
    _assert_eq(ui.visible[base_nodes.countdown], false, "only a literal true keeps the countdown up")
  end

  function TestPanelActionControls:test_blanks_the_countdown_label_when_the_panel_has_no_turn_label()
    local ui = _stub_ui()
    panel_action_controls.apply_countdown(ui, {})
    _assert_eq(ui.labels[base_nodes.countdown], "", "a missing turn label renders as empty")
  end
end

do
  -- panel_action_controls.apply_action_hint
  function TestPanelActionControls:test_shows_the_action_hint_when_the_panel_reports_no_available_action()
    local ui = _stub_ui()
    panel_action_controls.apply_action_hint(ui, { no_action_visible = true })
    _assert_eq(ui.visible[base_nodes.action_hint], true, "the hint is shown")
  end

  function TestPanelActionControls:test_leaves_the_action_hint_alone_otherwise()
    local ui = _stub_ui()
    panel_action_controls.apply_action_hint(ui, { no_action_visible = false })
    panel_action_controls.apply_action_hint(ui, {})
    _assert_eq(ui.visible[base_nodes.action_hint], nil,
      "the hint's visibility is not touched when there is an action available")
  end
end


return TestPanelActionControls
