local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local with_client_role = require("src.ui.render.support.with_client_role")
local runtime_ui = require("src.ui.render.support.runtime_ui")

local turn_effects = {}

local function _find_player_index(players, current_id)
  for index, player in ipairs(players) do
    if player and role_id_utils.equals(player.id, current_id) then
      return index
    end
  end
  return nil
end

local function _model_board(ui_model)
  return ui_model and ui_model.board or nil
end

local function _board_players(board)
  return board and board.players or nil
end

local function _current_player_id(ui_model)
  return role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
end

local function _resolve_current_player_index(ui_model)
  local players = _board_players(_model_board(ui_model))
  local current_id = _current_player_id(ui_model)
  if not (players and current_id) then
    return nil
  end
  return _find_player_index(players, current_id)
end

local function _set_node_visible(node, visible)
  if not node then
    return
  end
  node.visible = visible == true
end

local function _set_highlight_visible(runtime, index)
  for i, name in ipairs(base_nodes.player_action_effects) do
    local node = runtime.query_node(name)
    _set_node_visible(node, index ~= nil and i == index)
  end
end

local _hl_runtime
local _hl_ui_model

local function _highlight_callback()
  local current_index = _resolve_current_player_index(_hl_ui_model)
  _set_highlight_visible(_hl_runtime, current_index)
end

local function _sync_current_turn_highlight(runtime, _, ui_model)
  _hl_runtime = runtime
  _hl_ui_model = ui_model
  with_client_role(runtime, nil, _highlight_callback)
end

local function _get_role_id(runtime, role)
  return role_id_utils.normalize(runtime.resolve_role_id(role))
end

local _prompt_nodes = {}

local function _get_prompt_nodes(runtime)
  _prompt_nodes.star = runtime.query_node(base_nodes.action_hint_effect)
  _prompt_nodes.label = runtime.query_node(base_nodes.action_hint)
  return _prompt_nodes
end

local function _set_prompt_visible(nodes, visible)
  _set_node_visible(nodes.star, visible)
  _set_node_visible(nodes.label, visible)
  if nodes.star then
    nodes.star.disabled = true
  end
  if nodes.label then
    nodes.label.disabled = true
  end
end

local function _is_turn_prompt_phase(phase)
  return phase == "wait_action"
end

local _ltp_runtime
local _ltp_current_player_id
local _ltp_can_show
local _ltp_role_id

local function _local_turn_prompt_inner()
  local nodes = _get_prompt_nodes(_ltp_runtime)
  local show = _ltp_role_id ~= nil and _ltp_current_player_id ~= nil
    and role_id_utils.equals(_ltp_role_id, _ltp_current_player_id) and _ltp_can_show
  _set_prompt_visible(nodes, show)
end

local function _local_turn_prompt_outer(role)
  _ltp_role_id = _get_role_id(_ltp_runtime, role)
  with_client_role(_ltp_runtime, role, _local_turn_prompt_inner)
end

local function _board_phase(board)
  return board and board.phase or nil
end

local function _sync_local_turn_prompt(runtime, _, ui_model)
  local phase = _board_phase(_model_board(ui_model))
  _ltp_runtime = runtime
  _ltp_current_player_id = _current_player_id(ui_model)
  _ltp_can_show = _is_turn_prompt_phase(phase)
  runtime.for_each_role_or_global(_local_turn_prompt_outer)
end

local _oap_runtime
local _oap_text
local _oap_visible

local function _other_action_prompt_callback()
  local node = _oap_runtime.query_node(base_nodes.other_player_hint)
  if node then
    node.text = _oap_text or ""
    node.visible = _oap_visible == true
  end
end

local function _set_other_action_prompt(runtime, role, text, visible)
  _oap_runtime = runtime
  _oap_text = text
  _oap_visible = visible
  with_client_role(runtime, role, _other_action_prompt_callback)
end

local _cached_prompt_name
local _cached_prompt_text

local function _current_player_name(ui_model)
  return ui_model and ui_model.current_player_name or nil
end

local function _resolve_other_action_prompt_text(ui_model)
  local current_player_name = _current_player_name(ui_model)
  if type(current_player_name) == "string" and current_player_name ~= "" then
    if current_player_name ~= _cached_prompt_name then
      _cached_prompt_name = current_player_name
      _cached_prompt_text = current_player_name .. "正在行动"
    end
    return _cached_prompt_text
  end
  return "其他玩家正在行动"
end

local _soap_runtime
local _soap_current_player_id
local _soap_prompt_text

local function _other_player_action_callback(role)
  local role_id = _get_role_id(_soap_runtime, role)
  local show = role_id ~= nil
    and _soap_current_player_id ~= nil
    and not role_id_utils.equals(role_id, _soap_current_player_id)
  if show then
    _set_other_action_prompt(_soap_runtime, role, _soap_prompt_text, true)
  else
    _set_other_action_prompt(_soap_runtime, role, "", false)
  end
end

local function _sync_other_player_action_prompt(runtime, _, ui_model)
  _soap_current_player_id = role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
  _soap_prompt_text = _resolve_other_action_prompt_text(ui_model)
  _soap_runtime = runtime
  runtime.for_each_role_or_global(_other_player_action_callback)
end

local function _presentation_runtime(state)
  return state and state.presentation_runtime and state.presentation_runtime.runtime or nil
end

local function _resolve_runtime(state, deps)
  return deps and deps.runtime or _presentation_runtime(state) or runtime_ui
end

function turn_effects.sync(state, ui_model, deps)
  local runtime = _resolve_runtime(state, deps)
  assert(runtime, "missing deps.runtime")
  _sync_current_turn_highlight(runtime, state, ui_model)
  _sync_local_turn_prompt(runtime, state, ui_model)
  _sync_other_player_action_prompt(runtime, state, ui_model)
  if type(runtime.set_client_role) == "function" then
    runtime.set_client_role(nil)
  end
end

return turn_effects

--[[ mutate4lua-manifest
version=4
projectHash=f8a956f4eeeeee07
scope.0.id=chunk:src/ui/render/widgets/turn_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=203
scope.0.semanticHash=f0ae6f55275672b5
scope.1.id=function:_find_player_index
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=15
scope.1.semanticHash=a9a27c19c8ee3045
scope.2.id=function:_model_board
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_board_players
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_current_player_id
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=27
scope.4.semanticHash=6e8a930f39c3fdd1
scope.5.id=function:_resolve_current_player_index
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=36
scope.5.semanticHash=175886d7813d6aa5
scope.6.id=function:_set_node_visible
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=43
scope.6.semanticHash=2e94693c6941bd4f
scope.7.id=function:_set_highlight_visible
scope.7.kind=function
scope.7.startLine=45
scope.7.endLine=50
scope.7.semanticHash=3d1c2204d06de241
scope.8.id=function:_highlight_callback
scope.8.kind=function
scope.8.startLine=55
scope.8.endLine=58
scope.8.semanticHash=a22ac54484cb85ec
scope.9.id=function:_sync_current_turn_highlight
scope.9.kind=function
scope.9.startLine=60
scope.9.endLine=64
scope.9.semanticHash=3907de1e58228815
scope.10.id=function:_get_role_id
scope.10.kind=function
scope.10.startLine=66
scope.10.endLine=68
scope.10.semanticHash=ec09ede95c0022d8
scope.11.id=function:_get_prompt_nodes
scope.11.kind=function
scope.11.startLine=72
scope.11.endLine=76
scope.11.semanticHash=79cc9ed76d80d823
scope.12.id=function:_set_prompt_visible
scope.12.kind=function
scope.12.startLine=78
scope.12.endLine=87
scope.12.semanticHash=8fda1bbf29179df8
scope.13.id=function:_is_turn_prompt_phase
scope.13.kind=function
scope.13.startLine=89
scope.13.endLine=91
scope.13.semanticHash=df7a871d489ab136
scope.14.id=function:_local_turn_prompt_inner
scope.14.kind=function
scope.14.startLine=98
scope.14.endLine=103
scope.14.semanticHash=95cc80e85d68d554
scope.15.id=function:_local_turn_prompt_outer
scope.15.kind=function
scope.15.startLine=105
scope.15.endLine=108
scope.15.semanticHash=b39dc24536d6a1ee
scope.16.id=function:_board_phase
scope.16.kind=function
scope.16.startLine=110
scope.16.endLine=112
scope.16.semanticHash=616a2ca60599c94f
scope.17.id=function:_sync_local_turn_prompt
scope.17.kind=function
scope.17.startLine=114
scope.17.endLine=120
scope.17.semanticHash=c4c13e4aaceda1b1
scope.18.id=function:_other_action_prompt_callback
scope.18.kind=function
scope.18.startLine=126
scope.18.endLine=132
scope.18.semanticHash=2f3a7f108461b203
scope.19.id=function:_set_other_action_prompt
scope.19.kind=function
scope.19.startLine=134
scope.19.endLine=139
scope.19.semanticHash=dab19f5f22647d76
scope.20.id=function:_current_player_name
scope.20.kind=function
scope.20.startLine=144
scope.20.endLine=146
scope.20.semanticHash=616a2ca60599c94f
scope.21.id=function:_resolve_other_action_prompt_text
scope.21.kind=function
scope.21.startLine=148
scope.21.endLine=158
scope.21.semanticHash=6426346dd5a58556
scope.22.id=function:_other_player_action_callback
scope.22.kind=function
scope.22.startLine=164
scope.22.endLine=174
scope.22.semanticHash=2dd2f4cd37540257
scope.23.id=function:_sync_other_player_action_prompt
scope.23.kind=function
scope.23.startLine=176
scope.23.endLine=181
scope.23.semanticHash=3e027649e16f4c6f
scope.24.id=function:_presentation_runtime
scope.24.kind=function
scope.24.startLine=183
scope.24.endLine=185
scope.24.semanticHash=c250138038aa193a
scope.25.id=function:_resolve_runtime
scope.25.kind=function
scope.25.startLine=187
scope.25.endLine=189
scope.25.semanticHash=cd13fbcbfbf9ed08
scope.26.id=function:turn_effects.sync
scope.26.kind=function
scope.26.startLine=191
scope.26.endLine=200
scope.26.semanticHash=ae58f117ea66103e
]]
