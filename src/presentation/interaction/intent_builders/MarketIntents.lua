local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local market_ui = require("src.presentation.shared.MarketLayout")

local market_intents = {}

function market_intents.build_items(state)
  local specs = {}
  for index, name in ipairs(market_ui.item_buttons) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        if not market_ui.is_ready() then
          logger.warn("market ui not ready")
          return nil
        end
        local market = state.ui_model and state.ui_model.market or nil
        if not market then
          logger.warn("market_select without market")
          return nil
        end
        local option_id = ui_event_intents.resolve_option_id(market, { index = index }, state)
        if not option_id then
          logger.warn("market_select missing option:", tostring(index))
          return nil
        end
        return { type = "market_select", option_id = option_id }
      end,
    }
  end
  return specs
end

return market_intents
