local modal_state = require("src.ui.state.modal")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local choice_openers = require("src.ui.coord.choice_openers")
local screens_registry = require("src.ui.screens_registry")
local screen_openers = require("src.ui.seams.screen_openers")
local choice_common = require("src.ui.coord.choice_helpers")
local popup = require("src.ui.coord.popup")
local canvas = require("src.ui.coord.canvas_coordinator")
local logger = require("src.foundation.log")
local runtime_state = require("src.ui.state.runtime")
local ui_controls = require("src.ui.render.support.ui_controls")

local modal_presenter = {}

-- #332:开屏/收屏经 screen_openers 契约接缝(不反向 require screens 模块)。
local function _refresh_secondary_confirm_copy(state, option_id)
  screen_openers.refresh_secondary_confirm_copy(state, option_id)
end

local function _close_market_if_needed(state)
  if not state.ui.market_active then
    return  -- silent early-return: hot path called on every open_choice_modal
  end
  screen_openers.close_market(state)
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

-- 只有「这个 route 自己的屏已经开着」才算重复开屏。判定必须和 choice_state 的
-- 开屏门控同口径（choice_active AND active_choice_screen_key == route_key）：
-- 早先这里只看 choice_active，于是任何残留的旧屏都会把后续所有开屏一并跳过 ——
-- 旧屏关不掉、新屏出不来，choice_active 与 key 一起卡死。
local function _should_skip_reopen(state, screen_key, choice_id)
  if screen_key == "market" then
    return false
  end
  if runtime_state.get_pending_choice_id(state) ~= choice_id then
    return false
  end
  return state.ui.choice_active == true and state.ui.active_choice_screen_key == screen_key
end

local function _open_item_phase_pre_confirm(state, choice)
  screen_openers.open_item_phase_pre_confirm(state, choice)
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

-- 返回值会被 _open_special_screen 丢弃,不要在这里 return 状态位:
-- 死返回值在变异测试下不可证伪(true→false 突变必然幸存)。
local function _open_base_inline_choice(state, choice)
  if choice_common.requires_item_slot_pre_confirm(choice) and not pending_confirmation.is_item_phase_confirmed(state) then
    _open_item_phase_pre_confirm(state, choice)
    return
  end
  _close_or_reset_inline_choice(state)
end

-- 道具阶段窗口住在基础屏，没有自己的选择屏；接管时必须先关掉上一个选择屏
-- （目标 / 点数 / 角色），否则它会连同 ui.choice_active 一起残留。
local function _open_item_phase_passive_choice(state)
  if state.ui.choice_active then
    modal_presenter.close_choice_modal(state)
  end
  choice_common.switch_modal_canvas(state, canvas.CANVAS_BASE)
  pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
end

-- 走自有开屏路径的 screen_key；其余 key 交给 choice_openers 的通用开屏。
local SPECIAL_SCREEN_OPENERS = {
  item_phase_passive = _open_item_phase_passive_choice,
  base_inline = _open_base_inline_choice,
}

local function _open_special_screen(state, screen_key, choice)
  local opener = SPECIAL_SCREEN_OPENERS[screen_key]
  if opener == nil then
    return false
  end
  opener(state, choice)
  return true
end

local function _validate_choice(choice)
  if not choice then
    logger.warn("open_choice_modal missing choice")
    return false
  end
  if not choice.id then
    logger.warn("open_choice_modal missing choice id")
    return false
  end
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
  if not _validate_choice(choice) then
    return
  end
  local screen_key = choice_common.resolve_screen_key(choice)
  local choice_id = choice.id
  if _should_skip_reopen(state, screen_key, choice_id) then
    return
  end
  runtime_state.set_ui_dirty(state, true)

  if screen_key == "market" then
    screen_openers.open_market(state, choice, choice_id, market_state)
    return
  end

  _close_market_if_needed(state)

  if _open_special_screen(state, screen_key, choice) then
    return
  end

  choice_openers.open_choice_modal(state, choice, market_state, screens_registry.opener_for)
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

return modal_presenter

--[[ mutate4lua-manifest
version=4
projectHash=14f18e0d05ebe989
scope.0.id=chunk:src/ui/coord/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=170
scope.0.semanticHash=492fdaa875c6c1da
scope.1.id=function:_refresh_secondary_confirm_copy
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=4ad1b5cb81e9ede6
scope.2.id=function:_close_market_if_needed
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=26
scope.2.semanticHash=738438847f99c242
scope.3.id=function:_reset_active_choice_screen
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=36
scope.3.semanticHash=dad3f2d3460f2969
scope.4.id=function:_switch_canvas_after_choice_close
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=44
scope.4.semanticHash=b200708d323dcc16
scope.5.id=function:_should_skip_reopen
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=58
scope.5.semanticHash=28ff692db30aef42
scope.6.id=function:_open_item_phase_pre_confirm
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=62
scope.6.semanticHash=4ad1b5cb81e9ede6
scope.7.id=function:_close_or_reset_inline_choice
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=72
scope.7.semanticHash=b865dbd1bb730b08
scope.8.id=function:_open_base_inline_choice
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=82
scope.8.semanticHash=979e4be53e59564f
scope.9.id=function:_open_item_phase_passive_choice
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=92
scope.9.semanticHash=a93f9ed01389e69c
scope.10.id=function:_open_special_screen
scope.10.kind=function
scope.10.startLine=100
scope.10.endLine=107
scope.10.semanticHash=54b76197bf464b96
scope.11.id=function:_validate_choice
scope.11.kind=function
scope.11.startLine=109
scope.11.endLine=119
scope.11.semanticHash=6b998cc0e8b28f1e
scope.12.id=function:modal_presenter.select_choice_option
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=127
scope.12.semanticHash=f0aa90a6274fcd6b
scope.13.id=function:modal_presenter.open_choice_modal
scope.13.kind=function
scope.13.startLine=129
scope.13.endLine=152
scope.13.semanticHash=6b6f64fe9c0c7c5f
scope.14.id=function:modal_presenter.close_choice_modal
scope.14.kind=function
scope.14.startLine=154
scope.14.endLine=167
scope.14.semanticHash=5f78a460770f8a6b
]]
