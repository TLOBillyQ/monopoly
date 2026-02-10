local market_view = require("src.ui.MarketView")
local market_ui = require("src.ui.MarketLayout")
local modal_state = require("src.ui.UIModalStateCoordinator")
local runtime = require("src.ui.UIRuntimePort")
local canvas = require("src.ui.UICanvasCoordinator")
local logger = require("src.core.Logger")

local modal_presenter = {}

local function _resolve_popup_image_key(state, payload)
  if not payload then
    return nil
  end
  if payload.image_key ~= nil then
    return payload.image_key
  end
  local image_ref = payload.image_ref
  if image_ref == nil then
    return nil
  end
  local refs = state and state.ui_refs or nil
  if not refs then
    return nil
  end
  return refs[tostring(image_ref)] or refs[image_ref]
end

local function _set_popup_card_image(state, payload)
  local ui = state and state.ui
  if not ui or not ui.popup or not ui.popup.card then
    return
  end
  local card_name = ui.popup.card
  local card_node = ui.query_node(card_name)
  local image_key = _resolve_popup_image_key(state, payload)
  if image_key ~= nil then
    runtime.set_node_texture_keep_size(card_node, image_key)
    ui:set_visible(card_name, true)
    return
  end
  local refs = state and state.ui_refs or nil
  local empty_key = refs and refs["空"] or nil
  if empty_key ~= nil then
    runtime.set_node_texture_keep_size(card_node, empty_key)
  end
  ui:set_visible(card_name, false)
end

local function _open_market_panel(state, choice, choice_id, market)
  canvas.switch(state.ui, canvas.CANVAS_MARKET)
  if state.ui.choice_active then
    state.ui:set_visible(state.ui.choice.root, false)
    state.ui.choice_active = false
  end
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = state.pending_choice_selected_option_id,
  }
  market_view.refresh_market(state, market_payload)
end

local function _open_generic_choice(state, choice, choice_id)
  if state.ui.market_active then
    market_view.close_market_panel(state)
  end

  canvas.switch(state.ui, canvas.CANVAS_CHOICE)
  state.ui:set_label(state.ui.choice.title, choice.title)
  state.ui:set_label(state.ui.choice.body, choice.body)
  state.ui:set_visible(state.ui.choice.root, true)

  local option_nodes = state.ui.choice.option_buttons
  for idx, name in ipairs(option_nodes) do
    local option = choice.options[idx]
    if option then
      state.ui:set_button(name, option.label)
      state.ui:set_visible(name, true)
      state.ui:set_touch_enabled(name, true)
    else
      state.ui:set_visible(name, false)
      state.ui:set_touch_enabled(name, false)
    end
  end

  if not choice.allow_cancel then
    state.ui:set_visible(state.ui.choice.cancel, false)
    state.ui:set_touch_enabled(state.ui.choice.cancel, false)
  else
    state.ui:set_button(state.ui.choice.cancel, choice.cancel_label)
    state.ui:set_visible(state.ui.choice.cancel, true)
    state.ui:set_touch_enabled(state.ui.choice.cancel, true)
  end

  state.ui.choice_active = true
  modal_state.open_choice(state, choice_id)
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

  if choice.kind == "market_buy" and market_ui.is_panel_ready() then
    _open_market_panel(state, choice, choice_id, market)
    return
  end
  _open_generic_choice(state, choice, choice_id)
end

function modal_presenter.close_choice_modal(state)
  if state.ui.choice_active then
    state.ui:set_visible(state.ui.choice.root, false)
    state.ui.choice_active = false
  end
  if state.ui.market_active then
    market_view.close_market_panel(state)
  end
  modal_state.close_choice(state)
  if state.ui.popup_active then
    canvas.switch(state.ui, canvas.CANVAS_POPUP)
  else
    canvas.switch(state.ui, canvas.CANVAS_BASE)
  end
  state.ui_dirty = true
end

function modal_presenter.push_popup(state, payload)
  assert(payload ~= nil, "missing popup payload")
  state.ui.popup_return_canvas = canvas.resolve_popup_return_canvas(state.ui)
  canvas.switch(state.ui, canvas.CANVAS_POPUP)
  state.ui:set_label(state.ui.popup.title, payload.title)
  state.ui:set_label(state.ui.popup.body, payload.body)
  state.ui:set_button(state.ui.popup.confirm, payload.button_text or "确认")
  _set_popup_card_image(state, payload)
  state.ui:set_visible(state.ui.popup.root, true)
  modal_state.open_popup(state, payload)
  state.ui_dirty = true
  return true
end

function modal_presenter.close_popup(state)
  if not (state.ui and state.ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  state.ui:set_visible(state.ui.popup.root, false)
  modal_state.close_popup(state)
  _set_popup_card_image(state, nil)
  local target = state.ui.popup_return_canvas
  state.ui.popup_return_canvas = nil
  canvas.switch(state.ui, canvas.resolve_canvas_after_popup(state.ui, target))
  state.ui_dirty = true
end

return modal_presenter
