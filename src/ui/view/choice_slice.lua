local choice_view = require("src.ui.view.choice_builder")
local runtime_state = require("src.ui.state.runtime")

local choice_slice = {}

local function _normalize_market_tab(active_tab)
  if active_tab == "item" then
    return active_tab
  end
  return "item"
end

function choice_slice.build_choice_and_market(game, env, ui_state)
  local choice = nil
  local pending = game.turn and game.turn.pending_choice
  if pending then
    choice = choice_view.build_choice_view(pending, { game = env.game })
  end
  local market = nil
  local ui_runtime = ui_state and runtime_state.ensure_ui_runtime(ui_state) or nil
  if choice and choice.route_key == "market" then
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = ui_runtime and ui_runtime.pending_choice_selected_option_id or nil,
      active_tab = _normalize_market_tab(choice.active_tab),
      page_index = choice.page_index,
      page_count = choice.page_count,
    }
  end
  return choice, market
end

return choice_slice
