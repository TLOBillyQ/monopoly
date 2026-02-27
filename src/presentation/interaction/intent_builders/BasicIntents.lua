local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local market_ui = require("src.presentation.shared.MarketLayout")
local ui_nodes = require("src.presentation.shared.UINodes")

local basic_intents = {}

function basic_intents.build(state)
  return {
    {
      name = ui_nodes.base.action_button,
      build_intent = function()
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = ui_nodes.always_show.auto_button,
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = market_ui.confirm_button,
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
      name = market_ui.cancel_button,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_cancel")
      end,
    },
    {
      name = ui_nodes.market.close,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_close")
      end,
    },
    {
      name = ui_nodes.building_choice.confirm,
      build_intent = function()
        return ui_event_intents.choice_confirm_intent(state, "building_confirm")
      end,
    },
    {
      name = ui_nodes.building_choice.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "building_cancel")
      end,
    },
    {
      name = ui_nodes.remote_choice.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "remote_cancel")
      end,
    },
  }
end

return basic_intents
