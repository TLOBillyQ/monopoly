local modal_state = require("src.ui.stores.modal_state")
local choice_openers = require("src.ui.ctl.choice_screens.openers")
local choice_common = require("src.ui.ctl.choice_screens.helpers")
local popup_controller = require("src.ui.ctl.popup_controller")
local market_controller = require("src.ui.ctl.market_controller")
local canvas = require("src.ui.ctl.canvas_coordinator")
local canvas_store = require("src.ui.stores.canvas_store")
local logger = require("src.core.utils.logger")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
local runtime_state = require("src.ui.ctl.ports.runtime_state_seam")
local ui_controls = require("src.ui.render.support.ui_controls")

local modal_presenter = {}

local function _resolve_secondary_confirm_parts(state, option_id)
  local ui = state and state.ui
  local screen = ui and ui.choice_screens and ui.choice_screens.secondary_confirm or nil
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not screen or not choice then
    return screen, choice, nil, nil
  end
  local option_label = choice_common.resolve_option_label_by_id(choice, option_id)
  return screen, choice, option_label, current_model
end

local function _refresh_secondary_confirm_copy(state, option_id)
  local ui = state and state.ui
  if not ui or ui.active_choice_screen_key ~= "secondary_confirm" then
    return
  end
  local screen, choice, option_label = _resolve_secondary_confirm_parts(state, option_id)
  if screen and screen.title then
    ui:set_label(screen.title, choice_common.resolve_secondary_confirm_title(choice, state.game, "secondary_confirm", option_id))
  end
  if screen and screen.body then
    ui:set_label(screen.body, choice_common.resolve_secondary_confirm_body(
      choice,
      state.game,
      "secondary_confirm",
      option_id,
      option_label
    ))
  end
end

local function _close_market_if_needed(state)
  if not state.ui.market_active then
    return
  end
  market_controller.close(state)
  state.ui.market_active = false
  canvas_store.mark_dirty(state, "market")
end

local function _reset_active_choice_screen(ui)
  local key = ui.active_choice_screen_key
  local screen = key and ui.choice_screens and ui.choice_screens[key] or nil
  if screen then
    ui_controls.reset_choice_screen(ui, screen)
  end
  ui.choice_active = false
  ui.active_choice_screen_key = nil
end

local function _switch_canvas_after_choice_close(state, ui)
  if ui.popup_active then
    popup_controller.switch_canvas(state, ui.popup_kind or "card", canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
    return
  end
  choice_common.switch_modal_canvas(state, canvas.CANVAS_BASE)
end

local function _should_skip_reopen(state, screen_key, choice_id)
  if screen_key == "market" then
    return false
  end
  return runtime_state.get_pending_choice_id(state) == choice_id
    and (state.ui.choice_active or state.ui.market_active)
end

local function _open_market_choice(state, choice, choice_id, market)
  target_choice_effects.leave(state, "open_market")
  canvas_store.mark_dirty(state, "market")
  market_controller.open(state, choice, choice_id, market)
end

local function _open_item_phase_pre_confirm(state, choice)
  state._item_phase_ask_active = true
  state._suppress_item_slot_highlight_until_pick = true
  local title = choice_common.resolve_secondary_confirm_title(choice, state.game, "base_inline", nil)
  local body = choice_common.resolve_secondary_confirm_body(choice, state.game, "base_inline", nil, nil)
  choice_openers.open_pre_confirm_screen(state, choice, "__item_phase_ask__", title, body)
end

local function _close_or_reset_inline_choice(state)
  state._item_phase_confirmed = nil
  if state.ui.choice_active then
    modal_presenter.close_choice_modal(state)
    return
  end
  modal_state.close_choice(state)
  choice_common.switch_modal_canvas(state, canvas.CANVAS_BASE)
  canvas_store.mark_dirty(state, "choice")
end

local function _open_base_inline_choice(state, choice)
  target_choice_effects.leave(state, "open_base_inline")
  if choice_common.requires_item_slot_pre_confirm(choice) and not state._item_phase_confirmed then
    _open_item_phase_pre_confirm(state, choice)
    return true
  end
  if not choice_common.uses_item_slots(choice) then
    state._suppress_item_slot_highlight_until_pick = nil
  end
  _close_or_reset_inline_choice(state)
  return true
end

local function _open_regular_choice(state, choice, market, screen_key)
  state._suppress_item_slot_highlight_until_pick = nil
  choice_openers.open_choice_modal(state, choice, market)
  if screen_key == "target" then
    target_choice_effects.enter(state, choice)
    return
  end
  target_choice_effects.leave(state, "open_non_target")
end

function modal_presenter.select_choice_option(state, option_id)
  if not option_id then
    return
  end
  modal_state.select_choice_option(state, option_id)
  _refresh_secondary_confirm_copy(state, option_id)
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
  local screen_key = choice_common.resolve_screen_key(choice)
  local choice_id = choice.id
  if _should_skip_reopen(state, screen_key, choice_id) then
    return
  end
  runtime_state.set_ui_dirty(state, true)

  if screen_key == "market" then
    _open_market_choice(state, choice, choice_id, market)
    return
  end

  _close_market_if_needed(state)

  if screen_key == "base_inline" then
    if _open_base_inline_choice(state, choice) then
      return
    end
    return
  end

  _open_regular_choice(state, choice, market, screen_key)
end

function modal_presenter.close_choice_modal(state)
  target_choice_effects.leave(state, "close_choice_modal")
  local ui = state.ui
  if ui.choice_active then
    _reset_active_choice_screen(ui)
    canvas_store.mark_dirty(state, "choice")
  end
  if ui.market_active then
    _close_market_if_needed(state)
  end
  modal_state.close_choice(state)
  _switch_canvas_after_choice_close(state, ui)
  runtime_state.set_ui_dirty(state, true)
end

function modal_presenter.push_popup(state, payload, opts)
  assert(payload ~= nil, "missing popup payload")
  opts = opts or {}
  local ui = state.ui
  if opts.policy == "defer" and ui.popup_active then
    local queue = ui.popup_queue
    if type(queue) ~= "table" then
      queue = {}
      ui.popup_queue = queue
    end
    queue[#queue + 1] = payload
    canvas_store.mark_dirty(state, "popup")
    runtime_state.set_ui_dirty(state, true)
    return true
  end
  ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
  popup_controller.show(state, payload)
  modal_state.open_popup(state, payload)
  canvas_store.mark_dirty(state, "popup")
  runtime_state.set_ui_dirty(state, true)
  return true
end

function modal_presenter.close_popup(state)
  local ui = state.ui
  if not (ui and ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  local kind = ui.popup_kind or "card"
  popup_controller.hide(state)
  modal_state.close_popup(state)
  ui.popup_kind = nil
  canvas_store.mark_dirty(state, "popup")
  local queue = ui.popup_queue
  if type(queue) == "table" and #queue > 0 then
    local next_payload = table.remove(queue, 1)
    ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
    popup_controller.show(state, next_payload)
    modal_state.open_popup(state, next_payload)
    canvas_store.mark_dirty(state, "popup")
    runtime_state.set_ui_dirty(state, true)
    return
  end
  local target = ui.popup_return_canvas
  ui.popup_return_canvas = nil
  local next_canvas = canvas.resolve_canvas_after_popup(ui, target)
  popup_controller.switch_canvas(state, kind, next_canvas, canvas.CANVAS_BASE)
  runtime_state.set_ui_dirty(state, true)
end

return modal_presenter
