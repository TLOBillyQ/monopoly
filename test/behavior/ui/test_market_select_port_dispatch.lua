-- Regression for the market_select view-command port path.
--
-- Field symptom (deploy log, 2026-07-11): every black-market item tap logged
--   [warn] view_command port missing, intent dropped: market_select
-- and the selection never registered. Mechanism: the assembled
-- state.gameplay_loop_ports.view_command resolved nil at dispatch time, so
-- view_command_dispatcher dropped the intent.
--
-- The existing two_tap_flatten_e2e Scenario D leans on the bind_ui_runtime
-- helper, which always injects a full presentation_ports.build() table — so it
-- cannot catch view_command being dropped from the assembled ports, nor does it
-- assert the "port missing" warn stays silent. These specs pin both directly.
local lu = require("luaunit")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local _bind_ui_runtime = P.bind_ui_runtime

local presentation_ports = require("src.ui.ports")
local view_command_dispatcher = require("src.ui.input.view_command")
local intent_dispatcher = require("src.ui.input.intent_dispatcher")
local market_renderer = require("src.ui.screens.market")
local logger = require("src.foundation.log")

local function _capture_warns()
  local warns = {}
  return warns, { target = logger, key = "warn", value = function(...)
    local parts = {}
    for _, v in ipairs({ ... }) do
      parts[#parts + 1] = tostring(v)
    end
    warns[#warns + 1] = table.concat(parts, " ")
  end }
end

local function _has_port_missing_warn(warns)
  for _, line in ipairs(warns) do
    if string.find(line, "view_command port missing", 1, true) then
      return true
    end
  end
  return false
end

TestMarketSelectPortDispatch = {}

function TestMarketSelectPortDispatch:test_assembled_presentation_ports_keep_a_market_select_view_command_handler()
  local ports = presentation_ports.build()
  lu.assertEvalToTrue(ports.view_command ~= nil, "presentation_ports.build() must expose view_command")
  _assert_eq(type(ports.view_command.dispatch), "function",
    "assembled view_command port must expose a dispatch function")

  local selected = nil
  _with_patches({
    { target = market_renderer, key = "select_market_option",
      value = function(_, option_id) selected = option_id end },
  }, function()
    local handled = ports.view_command.dispatch({}, { type = "market_select", option_id = 2001 })
    _assert_eq(handled, true, "view_command port must report market_select as handled")
  end)

  _assert_eq(selected, 2001,
    "market_select must route through the assembled port to select_market_option")
end

function TestMarketSelectPortDispatch:test_market_select_through_intent_dispatcher_reaches_the_port_without_a_missing_port_warn()
  local selected = nil
  local warns, warn_patch = _capture_warns()

  local state = {
    ui_model = {
      choice = {
        id = 88,
        kind = "market_buy",
        route_key = "market",
        owner_role_id = 7,
        options = { { id = 2001, label = "路障卡" } },
      },
      market = {
        choice_id = 88,
        options = { { id = 2001, label = "路障卡" } },
      },
    },
    ui = { input_blocked = false },
    game = {},
  }
  -- bind_ui_runtime injects a real gameplay_loop_ports = presentation_ports.build().
  _bind_ui_runtime(state)

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
    warn_patch,
    { target = market_renderer, key = "select_market_option",
      value = function(_, option_id) selected = option_id end },
  }, function()
    intent_dispatcher.dispatch(state, state.game, {
      type = "market_select",
      option_id = 2001,
      actor_role_id = 7,
    }, {})
  end)

  _assert_eq(selected, 2001,
    "market_select dispatched through intent_dispatcher must reach the port handler")
  _assert_eq(_has_port_missing_warn(warns), false,
    "a properly wired gameplay_loop_ports must not drop market_select as 'port missing'")
end

function TestMarketSelectPortDispatch:test_view_command_survives_the_turn_loop_ports_resolve_that_overwrites_state_gameplay_loop_ports()
  -- Field symptom round 2 (deploy log, 2026-07-12): the assembled ports DO
  -- carry view_command, but the first tick funnels them through
  -- gameplay_loop_ports.resolve (src/turn/loop/init.lua) and writes the
  -- resolved table back onto state.gameplay_loop_ports. resolve() rebuilt
  -- only the declared turn-loop groups, silently dropping the UI-side
  -- view_command / actor_context groups — so every later market_select tap
  -- hit the 'port missing' warn. Paging kept working because it routes via
  -- game_handler, not the view_command port.
  local loop_ports = require("src.turn.loop.ports")
  local warns, warn_patch = _capture_warns()
  local selected = nil

  local resolved = loop_ports.resolve(presentation_ports.build())
  lu.assertEvalToTrue(resolved.view_command ~= nil,
    "loop ports resolve must pass the view_command group through")
  lu.assertEvalToTrue(resolved.actor_context ~= nil,
    "loop ports resolve must pass the actor_context group through")

  local state = { gameplay_loop_ports = resolved }
  _with_patches({
    warn_patch,
    { target = market_renderer, key = "select_market_option",
      value = function(_, option_id) selected = option_id end },
  }, function()
    local handled = view_command_dispatcher.dispatch(state,
      { type = "market_select", option_id = 2001 })
    _assert_eq(handled, true,
      "market_select must stay handled after the tick-time ports resolve")
  end)

  _assert_eq(selected, 2001,
    "resolved gameplay_loop_ports must keep routing market_select to select_market_option")
  _assert_eq(_has_port_missing_warn(warns), false,
    "the tick-time resolve must not strip view_command from state.gameplay_loop_ports")
end

function TestMarketSelectPortDispatch:test_view_command_dispatcher_warns_and_drops_market_select_when_the_port_is_unwired()
  -- Pins the diagnostic contract that surfaced the field bug: an absent
  -- view_command port yields the exact 'port missing' warn and a false return.
  local warns, warn_patch = _capture_warns()
  local dropped

  _with_patches({ warn_patch }, function()
    dropped = view_command_dispatcher.dispatch(
      { gameplay_loop_ports = {} },
      { type = "market_select", option_id = 2001 }
    )
  end)

  _assert_eq(dropped, false, "missing view_command port must make dispatch return false")
  _assert_eq(_has_port_missing_warn(warns), true,
    "missing view_command port must emit the 'view_command port missing' diagnostic")
end

function TestMarketSelectPortDispatch:test_game_action_intent_without_game_warns_and_drops()
  local warns, warn_patch = _capture_warns()
  local state = { ui = { input_blocked = false } }
  _bind_ui_runtime(state)

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
    warn_patch,
  }, function()
    intent_dispatcher.dispatch(state, nil, {
      type = "choice_select",
      option_id = 1,
      actor_role_id = 7,
    }, {})
  end)

  lu.assertEvalToTrue(#warns == 1
      and string.find(warns[1], "ui intent without game", 1, true) ~= nil,
    "a game-action intent without a game should warn and drop: " .. tostring(warns[1]))
end


return TestMarketSelectPortDispatch
