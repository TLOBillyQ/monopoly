local modal_state = require("src.ui.state.modal")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local choice_openers = require("src.ui.coord.choice_openers")
local secondary_confirm_screen = require("src.ui.screens.secondary_confirm")
local choice_common = require("src.ui.coord.choice_helpers")
local popup = require("src.ui.coord.popup")
local market_presenter = require("src.ui.coord.market")
local canvas = require("src.ui.coord.canvas_coordinator")
local dice_nodes = require("src.ui.schema.dice")
local logger = require("src.foundation.log")
local runtime_state = require("src.ui.state.runtime")
local ui_controls = require("src.ui.render.support.ui_controls")

local modal_presenter = {}

local function _refresh_secondary_confirm_copy(state, option_id)
  secondary_confirm_screen.refresh_copy(state, option_id)
end

local function _close_market_if_needed(state)
  if not state.ui.market_active then
    return  -- silent early-return: hot path called on every open_choice_modal
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
  secondary_confirm_screen.open_item_phase_pre_confirm(state, choice)
end

local function _close_or_reset_inline_choice(state)
  pending_confirmation.reset_item_phase_confirmed(state)
  if state.ui.choice_active then
    modal_presenter.close_choice_modal(state)
    return
  end
  modal_state.close_choice(state)
  choice_common.switch_modal_canvas(state, canvas.CANVAS_BASE)
end

local function _open_base_inline_choice(state, choice)
  if choice_common.requires_item_slot_pre_confirm(choice) and not pending_confirmation.is_item_phase_confirmed(state) then
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
    pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    state._suppress_item_slot_highlight_until_pick = false
    return
  end

  if screen_key == "base_inline" then
    _open_base_inline_choice(state, choice)
    return
  end

  state._suppress_item_slot_highlight_until_pick = nil
  choice_openers.open_choice_modal(state, choice, market_state)
end

function modal_presenter.close_choice_modal(state)
  local ui = state.ui
  local was_choice_active = ui.choice_active
  local was_market_active = ui.market_active
  if was_choice_active then
    _reset_active_choice_screen(ui)
  end
  if was_market_active then
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

--[[ mutate4lua-manifest
version=2
projectHash=ecd9640e1bb78b5d
scope.0.id=chunk:src/ui/coord/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=227
scope.0.semanticHash=ebfffd311ad4c681
scope.1.id=function:_resolve_secondary_confirm_parts:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=24
scope.1.semanticHash=5e8a8b60d27c9065
scope.2.id=function:_refresh_secondary_confirm_copy:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=44
scope.2.semanticHash=39cbd291233284ca
scope.3.id=function:_close_market_if_needed:46
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=52
scope.3.semanticHash=cdaf824c32c4929d
scope.4.id=function:_reset_active_choice_screen:54
scope.4.kind=function
scope.4.startLine=54
scope.4.endLine=62
scope.4.semanticHash=8078cd654803f881
scope.5.id=function:_switch_canvas_after_choice_close:64
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=70
scope.5.semanticHash=7722bb50de022f4f
scope.6.id=function:_should_skip_reopen:72
scope.6.kind=function
scope.6.startLine=72
scope.6.endLine=78
scope.6.semanticHash=b698f2e475b857a4
scope.7.id=function:_open_item_phase_pre_confirm:80
scope.7.kind=function
scope.7.startLine=80
scope.7.endLine=86
scope.7.semanticHash=51d11abfd2f6f352
scope.8.id=function:_close_or_reset_inline_choice:88
scope.8.kind=function
scope.8.startLine=88
scope.8.endLine=96
scope.8.semanticHash=8dcff6c8e6c86133
scope.9.id=function:_open_base_inline_choice:98
scope.9.kind=function
scope.9.startLine=98
scope.9.endLine=108
scope.9.semanticHash=13a619071f9a92e6
scope.10.id=function:modal_presenter.select_choice_option:110
scope.10.kind=function
scope.10.startLine=110
scope.10.endLine=116
scope.10.semanticHash=e9c1eda6ffef0ef3
scope.11.id=function:modal_presenter.open_choice_modal:118
scope.11.kind=function
scope.11.startLine=118
scope.11.endLine=155
scope.11.semanticHash=6595f236cc48c215
scope.12.id=function:modal_presenter.close_choice_modal:157
scope.12.kind=function
scope.12.startLine=157
scope.12.endLine=168
scope.12.semanticHash=ffcd75bb27c5beee
scope.13.id=function:modal_presenter.push_popup:170
scope.13.kind=function
scope.13.startLine=170
scope.13.endLine=187
scope.13.semanticHash=729e7fafcfb07e65
scope.14.id=function:_is_roll_action_anim_active:189
scope.14.kind=function
scope.14.startLine=189
scope.14.endLine=193
scope.14.semanticHash=dda61a46d152637f
scope.15.id=function:_resolve_canvas_after_popup:195
scope.15.kind=function
scope.15.startLine=195
scope.15.endLine=200
scope.15.semanticHash=8ff1173b7313c417
scope.16.id=function:modal_presenter.close_popup:202
scope.16.kind=function
scope.16.startLine=202
scope.16.endLine=224
scope.16.semanticHash=1c3a1aba785bccbf
]]
