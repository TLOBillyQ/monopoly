local market_renderer = require("src.presentation.widgets.MarketModalRenderer")

local presenter = {}

function presenter.open(state, choice, choice_id, market)
  return market_renderer.open_market_panel(state, choice, choice_id, market)
end

function presenter.close(state)
  return market_renderer.close_market_panel(state)
end

function presenter.select_option(state, option_id)
  return market_renderer.select_market_option(state, option_id)
end

return presenter
