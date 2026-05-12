local modal_state = require("src.ui.state.modal")
local choice_openers = require("src.ui.coord.choice_screens.openers")
local choice_common = require("src.ui.coord.choice_screens.helpers")
local popup = require("src.ui.coord.popup")
local market_presenter = require("src.ui.coord.market")
local canvas = require("src.ui.coord.canvas_coordinator")
local dice_nodes = require("src.ui.schema.dice")
local logger = require("src.foundation.log.logger")
local runtime_state = require("src.ui.state.runtime")
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
  market_presenter.close(state)
  state.ui.market_active = false
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
    popup.switch_popup_canvas(state, ui.popup_kind or "card", canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
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
end

local function _open_base_inline_choice(state, choice)
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

function modal_presenter.select_choice_option(state, option_id)
  if not option_id then
    return
  end
  modal_state.select_choice_option(state, option_id)
  _refresh_secondary_confirm_copy(state, option_id)
end

function modal_presenter.open_choice_modal(state, choice, market_state)
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
    market_presenter.open(state, choice, choice_id, market_state)
    return
  end

  _close_market_if_needed(state)

  if screen_key == "item_phase_passive" then
    choice_common.switch_modal_canvas(state, canvas.CANVAS_BASE)
    state._item_phase_ask_active = false
    state._suppress_item_slot_highlight_until_pick = false
    return
  end

  if screen_key == "base_inline" then
    if _open_base_inline_choice(state, choice) then
      return
    end
    return
  end

  state._suppress_item_slot_highlight_until_pick = nil
  choice_openers.open_choice_modal(state, choice, market_state)
end

function modal_presenter.close_choice_modal(state)
  local ui = state.ui
  if ui.choice_active then
    _reset_active_choice_screen(ui)
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
    return true
  end
  ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
  popup.show(state, payload)
  modal_state.open_popup(state, payload)
  return true
end

local function _is_roll_action_anim_active(state)
  local turn = state and state.game and state.game.turn or nil
  local anim = turn and turn.action_anim or nil
  return turn and turn.phase == "wait_action_anim" and anim and anim.kind == "roll"
end

local function _resolve_canvas_after_popup(state, ui, target)
  if _is_roll_action_anim_active(state) then
    return dice_nodes.canvas
  end
  return canvas.resolve_canvas_after_popup(ui, target)
end

function modal_presenter.close_popup(state)
  local ui = state.ui
  if not (ui and ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  local kind = ui.popup_kind or "card"
  popup.hide(state)
  modal_state.close_popup(state)
  ui.popup_kind = nil
  local queue = ui.popup_queue
  if type(queue) == "table" and #queue > 0 then
    local next_payload = table.remove(queue, 1)
    ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
    popup.show(state, next_payload)
    modal_state.open_popup(state, next_payload)
    return
  end
  local target = ui.popup_return_canvas
  ui.popup_return_canvas = nil
  local next_canvas = _resolve_canvas_after_popup(state, ui, target)
  popup.switch_popup_canvas(state, kind, next_canvas, canvas.CANVAS_BASE)
end

return modal_presenter
