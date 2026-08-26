-- Mutation-closure pins for src/turn/waits/choice_ui_sync.lua.
-- Drives sync_pending_choice_ui and resolve_missing_ui_warning directly with
-- stub ports so the id-change sync guard and the active/should-warn logic are
-- observable without the surrounding tick.
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local choice_ui_sync = require("src.turn.waits.choice_ui_sync")
local runtime_state = require("src.state.runtime")

TestWaitsChoiceUiSync = {}

function TestWaitsChoiceUiSync:test_does_not_re_sync_when_the_active_choice_already_matches_the_pending_id()
  -- kills L7 get_pending_choice->nil and L8 ~=/==: a matching active choice
  -- must skip sync_pending_choice / on_pending_choice.
  local synced = {}
  local on_pending = {}
  local output_ports = {
    get_pending_choice = function() return { id = 1 } end,
    sync_pending_choice = function(_, choice) synced[#synced + 1] = choice end,
    clear_pending_choice = function() end,
  }
  local game = { turn = { pending_choice = { id = 1 } } }
  local opts = { on_pending_choice = function() on_pending[#on_pending + 1] = true end }
  choice_ui_sync.sync_pending_choice_ui(game, {}, opts, output_ports)
  _assert_eq(#synced, 0, "a matching active choice is not re-synced")
  _assert_eq(#on_pending, 0, "a matching active choice does not re-fire on_pending_choice")
end

function TestWaitsChoiceUiSync:test_reports_active_with_a_pending_choice_but_no_active_choice()
  -- kills L18 first ~=/== and or->and: a non-nil pending makes it active.
  -- also kills one L23 and->or arm: should_warn stays falsy without an
  -- active_choice.
  local active, should_warn = choice_ui_sync.resolve_missing_ui_warning(
    {}, {}, {}, { id = 1 }, nil, false)
  lu.assertEvalToTrue(active == true, "a pending choice alone marks the frame active")
  lu.assertEvalToTrue(not should_warn, "with no active_choice the missing-ui warning stays off")
end

function TestWaitsChoiceUiSync:test_reports_active_with_an_active_choice_but_no_pending()
  -- kills L18 second ~=/==: a non-nil active_choice makes it active.
  local active = choice_ui_sync.resolve_missing_ui_warning({}, {}, {}, nil, { id = 1 }, false)
  lu.assertEvalToTrue(active == true, "an active choice alone marks the frame active")
end

function TestWaitsChoiceUiSync:test_suppresses_the_warning_when_the_ui_already_reports_the_choice_active()
  -- kills the second L23 and->or arm: with ui_choice_active true the warning
  -- must be off.
  local _, should_warn = choice_ui_sync.resolve_missing_ui_warning(
    {}, {}, {}, { id = 1 }, { id = 1 }, true)
  lu.assertEvalToTrue(not should_warn, "an already-active ui suppresses the missing-ui warning")
end

function TestWaitsChoiceUiSync:test_warns_when_a_pending_choice_is_active_but_the_ui_is_not()
  -- kills L23 not->removed: the warning must fire when ui_choice_active is false.
  local _, should_warn = choice_ui_sync.resolve_missing_ui_warning(
    {}, {}, {}, { id = 1 }, { id = 1 }, false)
  lu.assertEvalToTrue(should_warn == true, "an active choice without ui coverage warns")
end

function TestWaitsChoiceUiSync:test_resolve_returns_the_resolved_gate_as_the_third_value()
  -- the probe logs the gate fields, so resolve must hand the gate back.
  local gate = { should_warn = false, open = true }
  local _, _, resolved = choice_ui_sync.resolve_missing_ui_warning(
    {}, {}, { resolve_choice_ui_state = function() return gate end },
    { id = 1 }, { id = 1 }, true)
  _assert_eq(resolved, gate, "the resolved gate is returned for the probe to log")
end

function TestWaitsChoiceUiSync:test_probe_skips_gate_sampling_when_no_choice_is_active()
  -- kills probe's `active_choice == nil` early-return -> removed: with no
  -- active choice the gate ports must not even be sampled.
  local active_checks = 0
  local logged
  _with_patches({
    { target = runtime_state, key = "log_once", value = function(_, ...) logged = { ... } end },
  }, function()
    choice_ui_sync.probe_missing_ui({ turn = {} }, {}, {
      is_choice_active = function() active_checks = active_checks + 1; return false end,
    }, { get_pending_choice = function() return nil end })
  end)
  _assert_eq(active_checks, 0, "no active choice skips the gate sampling entirely")
  _assert_eq(logged, nil, "no active choice never warns")
end

function TestWaitsChoiceUiSync:test_probe_warns_with_the_full_gate_fields_when_the_ui_is_missing()
  -- kills the warn literal/field mutants: the warn carries the #523 forensics
  -- field set (gate 判定全字段), one log line localizes the missing link.
  local captured
  local gate = {
    should_warn = true,
    route_key = "secondary_confirm",
    served_owner = true,
    owner_computer_controlled = false,
    expects_ui = true,
    open = false,
  }
  local game = { turn = { phase = "wait_choice" } }
  local choice = { id = 6, kind = "landing_optional_effect", owner_role_id = 1 }
  _with_patches({
    { target = runtime_state, key = "log_once", value = function(_, ...) captured = { ... } end },
  }, function()
    choice_ui_sync.probe_missing_ui(game, {}, {
      is_choice_active = function() return false end,
      resolve_choice_ui_state = function() return gate end,
    }, { get_pending_choice = function() return choice end })
  end)
  lu.assertEvalToTrue(captured ~= nil, "a missing ui warns")
  _assert_eq(captured[1], "warn", "the log level is warn")
  _assert_eq(captured[2], "choice_runtime_without_ui_6", "the log_once key carries the choice id")
  _assert_eq(captured[3], "[Eggy]", "the log prefix is [Eggy]")
  _assert_eq(captured[4], "runtime pending choice active without ui.choice_active",
    "the log message describes the missing ui")
  _assert_eq(captured[5], "choice_id=6")
  _assert_eq(captured[6], "kind=landing_optional_effect")
  _assert_eq(captured[7], "owner_role_id=1")
  _assert_eq(captured[8], "route_key=secondary_confirm", "the gate route key wins")
  _assert_eq(captured[9], "phase=wait_choice")
  _assert_eq(captured[10], "served_owner=true")
  _assert_eq(captured[11], "owner_computer_controlled=false")
  _assert_eq(captured[12], "expects_ui=true")
  _assert_eq(captured[13], "open=false")
end

function TestWaitsChoiceUiSync:test_probe_stays_silent_when_the_gate_reports_the_screen_open()
  -- #523 同帧误报回归 pin：dirty 刷新后采样看到 open=true（同帧首开
  -- 已完成）时不得再告警。
  local logged
  local game = { turn = { phase = "wait_choice" } }
  _with_patches({
    { target = runtime_state, key = "log_once", value = function(_, ...) logged = { ... } end },
  }, function()
    choice_ui_sync.probe_missing_ui(game, {}, {
      is_choice_active = function() return true end,
      resolve_choice_ui_state = function()
        return { should_warn = false, route_key = "secondary_confirm", open = true }
      end,
    }, { get_pending_choice = function() return { id = 6 } end })
  end)
  _assert_eq(logged, nil, "an opened screen never warns")
end

function TestWaitsChoiceUiSync:test_warn_falls_back_to_the_choice_route_key_without_a_gate()
  -- kills the `gate.route_key or active_choice.route_key` or->and mutant:
  -- a missing gate falls back to the choice's own route key.
  local captured
  _with_patches({
    { target = runtime_state, key = "log_once", value = function(_, ...) captured = { ... } end },
  }, function()
    choice_ui_sync.maybe_warn_missing_ui(
      {}, { turn = {} },
      { id = 2, kind = "k", owner_role_id = 3, route_key = "choice_route" },
      true, nil)
  end)
  lu.assertEvalToTrue(captured ~= nil, "a warning is logged")
  _assert_eq(captured[8], "route_key=choice_route", "no gate -> the choice route key is logged")
  _assert_eq(captured[10], "served_owner=nil", "no gate -> gate fields log as nil")
end


return TestWaitsChoiceUiSync
