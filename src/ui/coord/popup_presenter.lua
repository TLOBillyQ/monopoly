local modal_state = require("src.ui.state.modal")
local popup = require("src.ui.coord.popup")
local canvas = require("src.ui.coord.canvas_coordinator")
local dice_nodes = require("src.ui.schema.dice")
local role_id_utils = require("src.foundation.identity")
local logger = require("src.foundation.log")

local popup_presenter = {}

-- 先落状态再渲染:popup_broadcast 只在 modal_state.open_popup 一处置位,
-- popup.show 的 canvas 分发读的就是这份状态。
function popup_presenter.push_popup(state, payload, opts)
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
  modal_state.open_popup(state, payload)
  popup.show(state, payload)
  return true
end

local function _current_turn(state)
  return state and state.game and state.game.turn or nil
end

local function _action_anim_of(turn)
  return turn and turn.action_anim or nil
end

local function _is_roll_action_anim(turn)
  local anim = _action_anim_of(turn)
  return turn ~= nil and turn.phase == "wait_action_anim" and anim ~= nil and anim.kind == "roll"
end

local function _is_roll_action_anim_active(state)
  return _is_roll_action_anim(_current_turn(state))
end

local function _resolve_canvas_after_popup(state, ui)
  if _is_roll_action_anim_active(state) then
    return dice_nodes.canvas
  end
  return canvas.resolve_canvas_after_popup(ui)
end

local function _next_queued_popup(queue)
  if type(queue) == "table" and #queue > 0 then
    return table.remove(queue, 1)
  end
  return nil
end

function popup_presenter.close_popup(state)
  local ui = state.ui
  if not (ui and ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  local kind = ui.popup_kind or "card"
  popup.hide(state)
  modal_state.close_popup(state)
  ui.popup_kind = nil
  local next_payload = _next_queued_popup(ui.popup_queue)
  if next_payload ~= nil then
    modal_state.open_popup(state, next_payload)
    popup.show(state, next_payload)
    return
  end
  local next_canvas = _resolve_canvas_after_popup(state, ui)
  popup.switch_popup_canvas(state, kind, next_canvas, canvas.CANVAS_BASE)
  ui.popup_broadcast = false
  ui.popup_exclude_role_id = nil
end

-- 点击关闭的唯一入口:广播展示的关闭权只归行动者,非广播弹窗维持谁点谁关。
-- 买家免展示口径(2026-08-25):被载荷排除的角色(黑市买家)看不到展示也无
-- 关闭权——其收屏只走超时自动关闭,程序化 popup_confirm 不得提前收掉旁观者
-- 的展示。
-- 广播弹窗的关闭权判定(CRAP 门禁):排除者与非行动者两条拒绝路径收敛到
-- 本谓词,dismiss_popup 只留「是否广播」的分派与收屏。
local function _may_dismiss_broadcast(state, ui, actor_role_id)
  local actor = role_id_utils.normalize(actor_role_id)
  if ui.popup_exclude_role_id ~= nil and role_id_utils.equals(actor, ui.popup_exclude_role_id) then
    return false
  end
  return role_id_utils.equals(actor, modal_state.operator_role_id(state))
end

function popup_presenter.dismiss_popup(state, actor_role_id)
  local ui = state and state.ui
  if ui and ui.popup_broadcast and not _may_dismiss_broadcast(state, ui, actor_role_id) then
    return false
  end
  popup_presenter.close_popup(state)
  return true
end

return popup_presenter

--[[ mutate4lua-manifest
version=4
projectHash=5b53a154cb0b0eb4
scope.0.id=chunk:src/ui/coord/popup_presenter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=107
scope.0.semanticHash=445f63df6fd683be
scope.1.id=function:popup_presenter.push_popup
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=28
scope.1.semanticHash=b17a91cd57c8990a
scope.2.id=function:_current_turn
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=32
scope.2.semanticHash=c250138038aa193a
scope.3.id=function:_action_anim_of
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=36
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_is_roll_action_anim
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=41
scope.4.semanticHash=ae5b8f80121800e6
scope.5.id=function:_is_roll_action_anim_active
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=45
scope.5.semanticHash=535dada822144f33
scope.6.id=function:_resolve_canvas_after_popup
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=52
scope.6.semanticHash=2ef414419fb3d775
scope.7.id=function:_next_queued_popup
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=59
scope.7.semanticHash=0f0f86b4b83bf8f0
scope.8.id=function:popup_presenter.close_popup
scope.8.kind=function
scope.8.startLine=61
scope.8.endLine=81
scope.8.semanticHash=dcb1be0b3603b8c5
scope.9.id=function:_may_dismiss_broadcast
scope.9.kind=function
scope.9.startLine=89
scope.9.endLine=95
scope.9.semanticHash=015c8e2f8830ec4a
scope.10.id=function:popup_presenter.dismiss_popup
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=104
scope.10.semanticHash=f39d9cd795d600da
]]
