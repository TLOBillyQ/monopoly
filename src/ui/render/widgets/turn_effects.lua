local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local with_client_role = require("src.ui.utils.with_client_role")
local runtime_ui = require("src.ui.render.runtime_ui")

local turn_effects = {}

local function _resolve_current_player_index(ui_model)
  local board = ui_model and ui_model.board or nil
  local players = board and board.players or nil
  local current_id = role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
  if not (players and current_id) then
    return nil
  end
  for index, player in ipairs(players) do
    if player and role_id_utils.equals(player.id, current_id) then
      return index
    end
  end
  return nil
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

local function _sync_local_turn_prompt(runtime, _, ui_model)
  local board = ui_model and ui_model.board or nil
  local phase = board and board.phase or nil
  _ltp_runtime = runtime
  _ltp_current_player_id = role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
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

local function _resolve_other_action_prompt_text(ui_model)
  local current_player_name = ui_model and ui_model.current_player_name or nil
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

function turn_effects.sync(state, ui_model, deps)
  local runtime = deps and deps.runtime or state and state.presentation_runtime and state.presentation_runtime.runtime
    or runtime_ui
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
version=2
projectHash=752960638c4a5a0e
scope.0.id=chunk:src/ui/render/widgets/turn_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=174
scope.0.semanticHash=459066dfb793fb4e
scope.1.id=function:_set_node_visible:23
scope.1.kind=function
scope.1.startLine=23
scope.1.endLine=28
scope.1.semanticHash=a9a9a7088d0ef139
scope.2.id=function:_highlight_callback:40
scope.2.kind=function
scope.2.startLine=40
scope.2.endLine=43
scope.2.semanticHash=a7b3498ff1a04d4f
scope.3.id=function:_sync_current_turn_highlight:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=49
scope.3.semanticHash=181bcf8b198d6231
scope.4.id=function:_get_role_id:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=53
scope.4.semanticHash=57b702b29214c61b
scope.5.id=function:_get_prompt_nodes:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=61
scope.5.semanticHash=e95692b9a580d998
scope.6.id=function:_set_prompt_visible:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=72
scope.6.semanticHash=8963e698481d4f85
scope.7.id=function:_is_turn_prompt_phase:74
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=76
scope.7.semanticHash=9fbf3882912bd951
scope.8.id=function:_local_turn_prompt_inner:83
scope.8.kind=function
scope.8.startLine=83
scope.8.endLine=88
scope.8.semanticHash=6f4f31c7116f80e7
scope.9.id=function:_local_turn_prompt_outer:90
scope.9.kind=function
scope.9.startLine=90
scope.9.endLine=93
scope.9.semanticHash=5f719cfd231a1f66
scope.10.id=function:_sync_local_turn_prompt:95
scope.10.kind=function
scope.10.startLine=95
scope.10.endLine=102
scope.10.semanticHash=714741dec9e1ee3f
scope.11.id=function:_other_action_prompt_callback:108
scope.11.kind=function
scope.11.startLine=108
scope.11.endLine=114
scope.11.semanticHash=061e2cf988678f85
scope.12.id=function:_set_other_action_prompt:116
scope.12.kind=function
scope.12.startLine=116
scope.12.endLine=121
scope.12.semanticHash=a31d77d2349e6f82
scope.13.id=function:_resolve_other_action_prompt_text:126
scope.13.kind=function
scope.13.startLine=126
scope.13.endLine=136
scope.13.semanticHash=3a26a69318eb0c66
scope.14.id=function:_other_player_action_callback:142
scope.14.kind=function
scope.14.startLine=142
scope.14.endLine=152
scope.14.semanticHash=052dc89f6a893b70
scope.15.id=function:_sync_other_player_action_prompt:154
scope.15.kind=function
scope.15.startLine=154
scope.15.endLine=159
scope.15.semanticHash=a756df3b386e68c6
scope.16.id=function:turn_effects.sync:161
scope.16.kind=function
scope.16.startLine=161
scope.16.endLine=171
scope.16.semanticHash=12ce5997d45e6596
]]
