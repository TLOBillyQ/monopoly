local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local base_nodes = require("src.presentation.canvas.base.nodes")
local always_show_nodes = require("src.presentation.canvas.always_show.nodes")
local market_nodes = require("src.presentation.canvas.market.nodes")
local building_nodes = require("src.presentation.canvas.building_choice.nodes")
local remote_nodes = require("src.presentation.canvas.remote_choice.nodes")
local market_layout = require("src.presentation.shared.MarketLayout")

local intents = {}

function intents.build(state)
  return {
    {
      name = base_nodes.action_button,
      build_intent = function()
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = always_show_nodes.auto_button,
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = market_layout.confirm_button,
      build_intent = function()
        local market = state.ui_model and state.ui_model.market or nil
        if not market then
          logger.warn("market_confirm without market")
          return nil
        end
        local option_id = state.pending_choice_selected_option_id
        if not option_id then
          logger.warn("market_confirm missing selected option")
          return nil
        end
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = market_layout.cancel_button,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_cancel")
      end,
    },
    {
      name = market_nodes.close,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_close")
      end,
    },
    {
      name = building_nodes.confirm,
      build_intent = function()
        return ui_event_intents.choice_confirm_intent(state, "building_confirm")
      end,
    },
    {
      name = building_nodes.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "building_cancel")
      end,
    },
    {
      name = remote_nodes.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "remote_cancel")
      end,
    },
  }
end

return intents
