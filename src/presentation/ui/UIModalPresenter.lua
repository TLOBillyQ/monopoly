local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local choice_openers = require("src.presentation.ui.choice_screen_service.openers")
local choice_common = require("src.presentation.ui.choice_screen_service.common")
local popup_presenter = require("src.presentation.canvas.popup.presenter")
local market_presenter = require("src.presentation.canvas.market.presenter")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local canvas_store = require("src.presentation.canvas_runtime.CanvasStore")
local logger = require("src.core.Logger")

local modal_presenter = {}

function modal_presenter.select_choice_option(state, option_id)
  if not option_id then
    return
  end
  modal_state.select_choice_option(state, option_id)
  local ui = state and state.ui
  if not ui then
    return
  end
  if ui.active_choice_screen_key ~= "secondary_confirm" then
    return
  end
  local screen = ui.choice_screens and ui.choice_screens.secondary_confirm or nil
  local choice = state.ui_model and state.ui_model.choice or nil
  if screen and screen.title then
    ui:set_label(screen.title, choice_common.resolve_choice_title(choice, "secondary_confirm", option_id))
  end
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

  local screen_key = choice_common.resolve_screen_key(choice)
  if screen_key == "market" then
    canvas_store.mark_dirty(state, "market")
    market_presenter.open(state, choice, choice_id, market)
    return
  end

  if state.ui.market_active then
    market_presenter.close(state)
    state.ui.market_active = false
    canvas_store.mark_dirty(state, "market")
  end

  if screen_key == "base_inline" then
    if choice and choice.kind == "item_phase_choice" and not state._item_phase_confirmed then
      state._item_phase_ask_active = true
      local title = choice.title or "使用道具？"
      choice_openers.open_pre_confirm_screen(state, choice, "__item_phase_ask__", title, "是否使用道具？")
      return
    end
    state._item_phase_confirmed = nil
    if state.ui.choice_active then
      modal_presenter.close_choice_modal(state)
    else
      modal_state.close_choice(state)
      canvas.switch(state.ui, canvas.CANVAS_BASE)
      canvas_store.mark_dirty(state, "choice")
    end
    return
  end

  choice_openers.open_choice_modal(state, choice, market)
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
    canvas_store.mark_dirty(state, "choice")
  end
  if ui.market_active then
    market_presenter.close(state)
    ui.market_active = false
    canvas_store.mark_dirty(state, "market")
  end
  modal_state.close_choice(state)
  if ui.popup_active then
    popup_presenter.switch_canvas(state, ui.popup_kind or "card", canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
  else
    canvas.switch(ui, canvas.CANVAS_BASE)
  end
  state.ui_dirty = true
end

function modal_presenter.push_popup(state, payload)
  assert(payload ~= nil, "missing popup payload")
  local ui = state.ui
  ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
  popup_presenter.show(state, payload)
  modal_state.open_popup(state, payload)
  canvas_store.mark_dirty(state, "popup")
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
  popup_presenter.hide(state)
  modal_state.close_popup(state)
  ui.popup_kind = nil
  canvas_store.mark_dirty(state, "popup")
  local target = ui.popup_return_canvas
  ui.popup_return_canvas = nil
  local next_canvas = canvas.resolve_canvas_after_popup(ui, target)
  popup_presenter.switch_canvas(state, kind, next_canvas, canvas.CANVAS_BASE)
  state.ui_dirty = true
end

return modal_presenter
