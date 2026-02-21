local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local choice_renderer = require("src.presentation.ui.ChoiceScreenService")
local popup_renderer = require("src.presentation.ui.PopupRenderer")
local market_renderer = require("src.presentation.ui.MarketModalRenderer")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local logger = require("src.core.Logger")

local modal_presenter = {}

function modal_presenter.select_choice_option(state, option_id)
  choice_renderer.select_choice_option(state, option_id)
end

function modal_presenter.open_choice_modal(state, choice, market)
  if not choice then
    logger.warn("open_choice_modal missing choice")
    return
  end
  if not choice.id then
    logger.warn("open_choice_modal missing choice id")
    return
  end
  local choice_id = choice.id
  if state.pending_choice_id == choice_id
      and (state.ui.choice_active or state.ui.market_active) then
    return
  end
  state.ui_dirty = true

  local screen_key = choice_renderer.resolve_screen_key(choice)
  if screen_key == "market" then
    market_renderer.open_market_panel(state, choice, choice_id, market)
    return
  end

  if state.ui.market_active then
    market_renderer.close_market_panel(state)
    state.ui.market_active = false
  end

  choice_renderer.open_choice_modal(state, choice, market)
end

function modal_presenter.close_choice_modal(state)
  local ui = state.ui
  if ui.choice_active then
    local key = ui.active_choice_screen_key
    local screen = key and ui.choice_screens and ui.choice_screens[key] or nil
    if screen and screen.root then
      ui:set_visible(screen.root, false)
    end
    ui.choice_active = false
    ui.active_choice_screen_key = nil
  end
  if ui.market_active then
    market_renderer.close_market_panel(state)
    ui.market_active = false
  end
  modal_state.close_choice(state)
  if ui.popup_active then
    popup_renderer.switch_popup_canvas(state, ui.popup_kind or "card", canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
  else
    canvas.switch(ui, canvas.CANVAS_BASE)
  end
  state.ui_dirty = true
end

function modal_presenter.push_popup(state, payload)
  assert(payload ~= nil, "missing popup payload")
  local ui = state.ui
  ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
  popup_renderer.show_popup(state, payload)
  modal_state.open_popup(state, payload)
  state.ui_dirty = true
  return true
end

function modal_presenter.close_popup(state)
  local ui = state.ui
  if not (ui and ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  local kind = ui.popup_kind or "card"
  popup_renderer.hide_popup(state)
  modal_state.close_popup(state)
  ui.popup_kind = nil
  local target = ui.popup_return_canvas
  ui.popup_return_canvas = nil
  local next_canvas = canvas.resolve_canvas_after_popup(ui, target)
  popup_renderer.switch_popup_canvas(state, kind, next_canvas, canvas.CANVAS_BASE)
  state.ui_dirty = true
end

return modal_presenter
