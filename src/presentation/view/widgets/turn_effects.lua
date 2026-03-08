local runtime = require("src.presentation.runtime.ui_runtime")
local base_nodes = require("src.presentation.view.canvas.base.nodes")
local role_id_utils = require("src.core.utils.role_id")

local turn_effects = {}

local function _with_client_role(role, fn)
  if type(runtime.with_client_role) == "function" then
    return runtime.with_client_role(role, fn)
  end
  runtime.set_client_role(role)
  local ok, err = pcall(fn)
  runtime.set_client_role(nil)
  if not ok then
    error(err)
  end
end

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

local function _set_highlight_visible(index)
  for i, name in ipairs(base_nodes.player_action_effects) do
    local node = runtime.query_node(name)
    _set_node_visible(node, index ~= nil and i == index)
  end
end

local function _sync_current_turn_highlight(_, ui_model)
  _with_client_role(nil, function()
    local current_index = _resolve_current_player_index(ui_model)
    _set_highlight_visible(current_index)
  end)
end

local function _get_role_id(role)
  return role_id_utils.normalize(runtime.resolve_role_id(role))
end

local function _get_prompt_nodes()
  return {
    star = runtime.query_node(base_nodes.action_hint_effect),
    label = runtime.query_node(base_nodes.action_hint),
  }
end

local function _set_prompt_visible(nodes, visible)
  _set_node_visible(nodes.star, visible)
  _set_node_visible(nodes.label, visible)
end

local function _is_pre_action_phase(phase)
  return phase == "start" or phase == "end_turn"
end

local function _sync_local_turn_prompt(_, ui_model)
  local board = ui_model and ui_model.board or nil
  local phase = board and board.phase or nil
  local current_player_id = role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
  local can_show = _is_pre_action_phase(phase)
  runtime.for_each_role_or_global(function(role)
    local role_id = _get_role_id(role)
    _with_client_role(role, function()
      local nodes = _get_prompt_nodes()
      local show = role_id ~= nil and current_player_id ~= nil and role_id_utils.equals(role_id, current_player_id) and can_show
      _set_prompt_visible(nodes, show)
    end)
  end)
end

local function _get_other_action_prompt_label_node()
  return runtime.query_node(base_nodes.other_player_hint)
end

local function _set_other_action_prompt(role, text, visible)
  _with_client_role(role, function()
    local node = _get_other_action_prompt_label_node()
    if node then
      node.text = text or ""
      node.visible = visible == true
    end
  end)
end

local function _resolve_other_action_prompt_text(ui_model)
  local current_player_name = ui_model and ui_model.current_player_name or nil
  if type(current_player_name) == "string" and current_player_name ~= "" then
    return current_player_name .. "正在行动"
  end
  return "其他玩家正在行动"
end

local function _sync_other_player_action_prompt(_, ui_model)
  local current_player_id = role_id_utils.normalize(ui_model and ui_model.current_player_id or nil)
  local prompt_text = _resolve_other_action_prompt_text(ui_model)
  runtime.for_each_role_or_global(function(role)
    local role_id = _get_role_id(role)
    local show = role_id ~= nil
      and current_player_id ~= nil
      and not role_id_utils.equals(role_id, current_player_id)
    if show then
      _set_other_action_prompt(role, prompt_text, true)
    else
      _set_other_action_prompt(role, "", false)
    end
  end)
end

function turn_effects.sync(state, ui_model)
  _sync_current_turn_highlight(state, ui_model)
  _sync_local_turn_prompt(state, ui_model)
  _sync_other_player_action_prompt(state, ui_model)
  runtime.set_client_role(nil)
end

return turn_effects
