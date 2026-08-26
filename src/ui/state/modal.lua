local modal_state = {}
local runtime_state = require("src.ui.state.runtime")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local role_id_utils = require("src.foundation.identity")

local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

function modal_state.open_choice(state, choice_id, option_ids, selected_option_id)
  assert(state ~= nil, "missing state")
  runtime_state.set_pending_choice_elapsed(state, 0)
  runtime_state.set_pending_choice_id(state, choice_id)
  local ui_runtime = _ui_runtime(state)
  ui_runtime.choice_visible_option_ids = option_ids
  ui_runtime.pending_choice_selected_option_id = selected_option_id
end

modal_state.open_market = modal_state.open_choice

function modal_state.select_choice_option(state, option_id)
  assert(state ~= nil, "missing state")
  local ui_runtime = _ui_runtime(state)
  ui_runtime.pending_choice_selected_option_id = option_id
  runtime_state.set_ui_dirty(state, true)
end

modal_state.select_market_option = modal_state.select_choice_option

function modal_state.close_choice(state)
  assert(state ~= nil, "missing state")
  local ui_runtime = _ui_runtime(state)
  ui_runtime.choice_visible_option_ids = nil
  ui_runtime.pending_choice_selected_option_id = nil
end

-- 「待确认选项」的读取口：其它模块不再直接翻 ui_runtime 字段。
function modal_state.get_selected_option_id(state)
  assert(state ~= nil, "missing state")
  return _ui_runtime(state).pending_choice_selected_option_id
end

function modal_state.get_visible_option_id(state, index)
  assert(state ~= nil, "missing state")
  local option_ids = _ui_runtime(state).choice_visible_option_ids
  if type(option_ids) ~= "table" then
    return nil
  end
  return option_ids[index]
end

-- 当前激活的选择屏 key（由 coord 层开屏/关屏时写入 state.ui）。
function modal_state.get_active_choice_screen_key(state)
  local ui = state and state.ui or nil
  return ui and ui.active_choice_screen_key or nil
end

local function _model_current_role_id(state)
  local model = runtime_state.get_ui_model(state)
  return model and role_id_utils.normalize(model.current_player_id) or nil
end

-- 操作者 role 的唯一读取口:行动中的 role 优先,否则回退到模型侧当前玩家。
function modal_state.operator_role_id(state)
  local ui = state and state.ui
  if not ui then
    return nil
  end
  if ui.current_action_role_id ~= nil then
    return ui.current_action_role_id
  end
  return _model_current_role_id(state)
end

-- 载荷落旗标(CRAP 门禁):payload 派生的四个字段收敛到本函数,
-- open_popup 只留断言、dirty 标记与面板打断。
local function _apply_popup_payload(ui, payload)
  ui.popup_active = true
  ui.popup_payload = payload
  ui.popup_seq = (ui.popup_seq or 0) + 1
  ui.popup_broadcast = payload and payload.broadcast == true
  ui.popup_exclude_role_id = payload and payload.exclude_role_id or nil
end

-- popup 旗标影响 base_visible / 道具槽可点性,开关都必须标 ui_dirty 驱动重绘:
-- 弹窗自动关闭后若再无其他 dirty 源(如回合结束阶段用卡),槽位会保持弹窗期间
-- 渲染的不可点状态直到窗口超时。
function modal_state.open_popup(state, payload)
  assert(state ~= nil and state.ui ~= nil, "missing ui state")
  _apply_popup_payload(state.ui, payload)
  -- 买家免展示口径(2026-08-25):载荷排除的角色由弹窗 canvas 分发跳过,
  -- 旗标随载荷落 ui 态,供分发与黑市重建门读取。旗标必须活过 modal 关闭:
  -- close_popup 收屏后的 canvas 回切分发仍要读它(被排除角色收屏也不回切),
  -- 故只能由 popup_presenter.close_popup 在最终分发完成后清,不能随本模块清。
  runtime_state.set_ui_dirty(state, true)
  panel_interrupt.interrupt(state)
end

function modal_state.close_popup(state)
  assert(state ~= nil and state.ui ~= nil, "missing ui state")
  state.ui.popup_active = false
  state.ui.popup_payload = nil
  runtime_state.set_ui_dirty(state, true)
end

return modal_state

--[[ mutate4lua-manifest
version=4
projectHash=669813b3f0b5fd9d
scope.0.id=chunk:src/ui/state/modal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=107
scope.0.semanticHash=c90f0f92d6116d97
scope.1.id=function:_ui_runtime
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=f1ce1850b7232305
scope.2.id=function:modal_state.open_choice
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=17
scope.2.semanticHash=958565533821284c
scope.3.id=function:modal_state.select_choice_option
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=26
scope.3.semanticHash=38dfcdc24b92a191
scope.4.id=function:modal_state.close_choice
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=35
scope.4.semanticHash=4003194c24b78fb4
scope.5.id=function:modal_state.get_selected_option_id
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=41
scope.5.semanticHash=4d4eec09cc2dfe5b
scope.6.id=function:modal_state.get_visible_option_id
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=50
scope.6.semanticHash=47ed09944544ce15
scope.7.id=function:modal_state.get_active_choice_screen_key
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=56
scope.7.semanticHash=93c839897afe61e5
scope.8.id=function:_model_current_role_id
scope.8.kind=function
scope.8.startLine=58
scope.8.endLine=61
scope.8.semanticHash=c6c577296c107741
scope.9.id=function:modal_state.operator_role_id
scope.9.kind=function
scope.9.startLine=64
scope.9.endLine=73
scope.9.semanticHash=b320e192d6491bec
scope.10.id=function:_apply_popup_payload
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=83
scope.10.semanticHash=fb558ed79ec05f84
scope.11.id=function:modal_state.open_popup
scope.11.kind=function
scope.11.startLine=88
scope.11.endLine=97
scope.11.semanticHash=7543f8d68dd62b65
scope.12.id=function:modal_state.close_popup
scope.12.kind=function
scope.12.startLine=99
scope.12.endLine=104
scope.12.semanticHash=e7da942fdcafa27d
]]
