local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local intent_output_port = require("src.game.ports.intent_output_port")
local intent_output_adapter = require("src.game.flow.output_adapters.intent_output_adapter")
local gameplay_loop = require("src.game.flow.turn.loop")
local paid_currency_bridge = require("src.game.systems.commerce.paid_currency_bridge")
local market_purchase = require("src.game.systems.market.application.purchase")
local landing_presenter = require("src.game.systems.land.landing_presenter")

local function _build_state()
  return {
    auto_runner = {
      set_enabled = function() end,
      reset_timer = function() end,
    },
  }
end

local function _test_gameplay_loop_set_game_installs_intent_output_port()
  local game = support.new_game({ install_ui_port = false })
  local state = _build_state()
  local installed_port = { open_choice = function() end, push_popup = function() return true end }

  _with_patches({
    { target = intent_output_adapter, key = "build", value = function() return installed_port end },
    { target = paid_currency_bridge, key = "setup_for_game", value = function() return true end },
    { target = market_purchase, key = "setup_for_game", value = function() return true end },
  }, function()
    gameplay_loop.set_game(state, game)
  end)

  _assert_eq(game.intent_output_port, installed_port, "set_game should install intent_output_port from adapter")
end

local function _test_landing_presenter_push_popup_prefers_intent_output_port()
  local payload = nil
  local popup_called = false
  local game = {
    intent_output_port = {
      push_popup = function(_, popup_payload, popup_opts)
        payload = {
          title = popup_payload.title,
          body = popup_payload.body,
          kind = popup_payload.kind,
          image_ref = popup_payload.image_ref,
          auto_close_seconds = popup_payload.auto_close_seconds,
          popup_opts = popup_opts,
        }
        return true
      end,
    },
    popup_port = {
      push_popup = function()
        popup_called = true
        return true
      end,
    },
  }

  local ok = landing_presenter.push_popup(game, "机会卡", "描述", {
    kind = "chance",
    image_ref = 101,
    auto_close_seconds = 2.0,
    popup_opts = { policy = "replace" },
  })

  _assert_eq(ok, true, "landing presenter should report success when intent_output_port handles popup")
  _assert_eq(popup_called, false, "landing presenter should not bypass intent_output_port directly")
  _assert_eq(payload.title, "机会卡", "landing presenter should pass popup title through intent_output_port")
  _assert_eq(payload.body, "描述", "landing presenter should pass popup body through intent_output_port")
  _assert_eq(payload.kind, "chance", "landing presenter should pass popup kind through intent_output_port")
  _assert_eq(payload.image_ref, 101, "landing presenter should pass image_ref through intent_output_port")
  _assert_eq(payload.auto_close_seconds, 2.0, "landing presenter should pass auto_close_seconds through intent_output_port")
  _assert_eq(payload.popup_opts.policy, "replace", "landing presenter should pass popup opts through intent_output_port")
end

local function _test_intent_output_port_falls_back_to_adapter_when_game_port_missing()
  local calls = {}

  _with_patches({
    {
      target = intent_output_adapter,
      key = "build",
      value = function()
        return {
          open_choice = function(_, choice_spec, opts)
            calls[#calls + 1] = { kind = "open_choice", title = choice_spec.title, opts = opts }
            return { id = 9 }
          end,
          push_popup = function(_, popup_payload, opts)
            calls[#calls + 1] = { kind = "push_popup", title = popup_payload.title, opts = opts }
            return true
          end,
        }
      end,
    },
  }, function()
    local game = {}
    local popup_ok = intent_output_port.push_popup(game, { title = "A" }, { policy = "defer" })
    local choice_entry = intent_output_port.open_choice(game, { title = "B" }, { source = "test" })
    _assert_eq(popup_ok, true, "intent_output_port should fall back to adapter for popup")
    _assert_eq(choice_entry.id, 9, "intent_output_port should fall back to adapter for choice")
  end)

  _assert_eq(calls[1].kind, "push_popup", "fallback adapter should receive popup first")
  _assert_eq(calls[1].title, "A", "fallback adapter should receive popup payload")
  _assert_eq(calls[1].opts.policy, "defer", "fallback adapter should receive popup opts")
  _assert_eq(calls[2].kind, "open_choice", "fallback adapter should receive open_choice")
  _assert_eq(calls[2].title, "B", "fallback adapter should receive choice spec")
  _assert_eq(calls[2].opts.source, "test", "fallback adapter should receive choice opts")
end

return {
  name = "intent_output_contract",
  tests = {
    {
      name = "gameplay_loop_set_game_installs_intent_output_port",
      run = _test_gameplay_loop_set_game_installs_intent_output_port,
    },
    {
      name = "landing_presenter_push_popup_prefers_intent_output_port",
      run = _test_landing_presenter_push_popup_prefers_intent_output_port,
    },
    {
      name = "intent_output_port_falls_back_to_adapter_when_game_port_missing",
      run = _test_intent_output_port_falls_back_to_adapter_when_game_port_missing,
    },
  },
}
