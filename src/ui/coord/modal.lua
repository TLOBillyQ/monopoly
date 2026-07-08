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
projectHash=d0df40d0a6562ded
scope.0.id=chunk:src/ui/coord/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=199
scope.0.semanticHash=3f4ad0513cac3ac6
scope.1.id=function:_refresh_secondary_confirm_copy:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=b21f3b659d93add3
scope.2.id=function:_close_market_if_needed:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=26
scope.2.semanticHash=cdaf824c32c4929d
scope.3.id=function:_reset_active_choice_screen:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=36
scope.3.semanticHash=8078cd654803f881
scope.4.id=function:_switch_canvas_after_choice_close:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=44
scope.4.semanticHash=7722bb50de022f4f
scope.5.id=function:_should_skip_reopen:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=52
scope.5.semanticHash=b698f2e475b857a4
scope.6.id=function:_open_item_phase_pre_confirm:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=56
scope.6.semanticHash=e722c28ecd4c9481
scope.7.id=function:_close_or_reset_inline_choice:58
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=66
scope.7.semanticHash=81bb7802a036856c
scope.8.id=function:_open_base_inline_choice:68
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=78
scope.8.semanticHash=addd23ce9b52dbf6
scope.9.id=function:modal_presenter.select_choice_option:80
scope.9.kind=function
scope.9.startLine=80
scope.9.endLine=86
scope.9.semanticHash=e9c1eda6ffef0ef3
scope.10.id=function:modal_presenter.open_choice_modal:88
scope.10.kind=function
scope.10.startLine=88
scope.10.endLine=125
scope.10.semanticHash=a689de8987a59959
scope.11.id=function:modal_presenter.close_choice_modal:127
scope.11.kind=function
scope.11.startLine=127
scope.11.endLine=140
scope.11.semanticHash=d180e02e0026b1d0
scope.12.id=function:modal_presenter.push_popup:142
scope.12.kind=function
scope.12.startLine=142
scope.12.endLine=159
scope.12.semanticHash=729e7fafcfb07e65
scope.13.id=function:_is_roll_action_anim_active:161
scope.13.kind=function
scope.13.startLine=161
scope.13.endLine=165
scope.13.semanticHash=dda61a46d152637f
scope.14.id=function:_resolve_canvas_after_popup:167
scope.14.kind=function
scope.14.startLine=167
scope.14.endLine=172
scope.14.semanticHash=8ff1173b7313c417
scope.15.id=function:modal_presenter.close_popup:174
scope.15.kind=function
scope.15.startLine=174
scope.15.endLine=196
scope.15.semanticHash=1c3a1aba785bccbf
]]
