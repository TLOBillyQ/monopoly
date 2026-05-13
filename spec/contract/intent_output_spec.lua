local support = require("spec.support.runtime_support")

local intent_output_port = require("src.rules.ports.intent_output")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local gameplay_loop = require("src.turn.loop")
local paid_currency_bridge = require("src.rules.commerce.paid_currency_bridge")
local market_purchase = require("src.rules.market.purchase.core")
local presenter = require("src.rules.land.presenter")

local function build_state()
  return {
    auto_runner = {
      set_enabled = function() end,
      reset_timer = function() end,
    },
  }
end

describe("intent_output_contract", function()
  it("gameplay_loop_set_game_installs_intent_output_port", function()
    local game = support.new_game({ install_ui_port = false })
    local state = build_state()
    local installed_port = { open_choice = function() end, push_popup = function() return true end }

    support.with_patches({
      { target = intent_dispatcher, key = "build_port", value = function() return installed_port end },
      { target = paid_currency_bridge, key = "setup_for_game", value = function() return true end },
      { target = market_purchase, key = "setup_for_game", value = function() return true end },
    }, function()
      gameplay_loop.set_game(state, game)
    end)

    assert.equals(installed_port, game.intent_output_port,
      "set_game should install intent_output_port from adapter")
  end)

  it("land_presenter_push_popup_prefers_intent_output_port", function()
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

    local ok = presenter.push_popup(game, "机会卡", "描述", {
      kind = "chance",
      image_ref = 101,
      auto_close_seconds = 2.0,
      popup_opts = { policy = "replace" },
    })

    assert.equals(true, ok, "landing presenter should report success when intent_output_port handles popup")
    assert.equals(false, popup_called, "landing presenter should not bypass intent_output_port directly")
    assert.equals("机会卡", payload.title, "landing presenter should pass popup title through intent_output_port")
    assert.equals("描述", payload.body, "landing presenter should pass popup body through intent_output_port")
    assert.equals("chance", payload.kind, "landing presenter should pass popup kind through intent_output_port")
    assert.equals(101, payload.image_ref, "landing presenter should pass image_ref through intent_output_port")
    assert.equals(2.0, payload.auto_close_seconds,
      "landing presenter should pass auto_close_seconds through intent_output_port")
    assert.equals("replace", payload.popup_opts.policy,
      "landing presenter should pass popup opts through intent_output_port")
  end)

  it("intent_output_port_returns_default_when_game_port_missing", function()
    local game = {}
    local popup_ok = intent_output_port.push_popup(game, { title = "A" }, { policy = "defer" })
    local choice_entry = intent_output_port.open_choice(game, { title = "B" }, { source = "test" })

    assert.equals(false, popup_ok, "intent_output_port should stay inert when no adapter is installed")
    assert.equals(nil, choice_entry, "intent_output_port should not resolve choice output without installed adapter")
  end)
end)
