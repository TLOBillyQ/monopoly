local runtime = require("src.presentation.api.UIRuntimePort")

local turn_effects = {}

local highlight_nodes = {
  "基础_玩家1高亮光效",
  "基础_玩家2高亮光效",
  "基础_玩家3高亮光效",
  "基础_玩家4高亮光效",
}

local function _resolve_current_player_index(ui_model)
  local board = ui_model and ui_model.board or nil
  local players = board and board.players or nil
  local current_id = ui_model and ui_model.current_player_id or nil
  if not (players and current_id) then
    return nil
  end
  for index, player in ipairs(players) do
    if player and player.id == current_id then
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
  for i, name in ipairs(highlight_nodes) do
    local node = runtime.query_node(name)
    _set_node_visible(node, index ~= nil and i == index)
  end
end

local function _sync_current_turn_highlight(_, ui_model)
  runtime.set_client_role(nil)
  local current_index = _resolve_current_player_index(ui_model)
  _set_highlight_visible(current_index)
  runtime.set_client_role(nil)
end

local function _get_role_id(role)
  if not role or not role.get_roleid then
    return nil
  end
  local ok, role_id = pcall(role.get_roleid)
  if ok then
    return role_id
  end
  return nil
end

local function _get_prompt_nodes()
  return {
    star = runtime.query_node("基础_星星中心爆开"),
    label = runtime.query_node("基础_行动提示"),
  }
end

local function _set_prompt_visible(nodes, visible)
  _set_node_visible(nodes.star, visible)
  _set_node_visible(nodes.label, visible)
end

local function _reset_prompt_animation(role, nodes)
  if not (role and role.reset_animation) then
    return
  end
  if nodes.star then
    pcall(role.reset_animation, role, nodes.star)
  end
end

local function _sync_local_turn_prompt(state, ui_model)
  if not state then
    return
  end
  if type(state.ui_turn_prompt_seq_by_role) ~= "table" then
    state.ui_turn_prompt_seq_by_role = {}
  end
  local current_id = ui_model and ui_model.current_player_id or nil
  runtime.for_each_role_or_global(function(role)
    local role_id = _get_role_id(role)
    runtime.set_client_role(role)
    local nodes = _get_prompt_nodes()
    if role_id and current_id and role_id == current_id then
      local seq = (state.ui_turn_prompt_seq_by_role[role_id] or 0) + 1
      state.ui_turn_prompt_seq_by_role[role_id] = seq
      _reset_prompt_animation(role, nodes)
      _set_prompt_visible(nodes, true)
      SetTimeOut(1.0, function()
        if state.ui_turn_prompt_seq_by_role[role_id] == seq then
          runtime.set_client_role(role)
          local timeout_nodes = _get_prompt_nodes()
          _set_prompt_visible(timeout_nodes, false)
          runtime.set_client_role(nil)
        end
      end)
    else
      _set_prompt_visible(nodes, false)
    end
    runtime.set_client_role(nil)
  end)
end

function turn_effects.sync(state, ui_model)
  _sync_current_turn_highlight(state, ui_model)
  _sync_local_turn_prompt(state, ui_model)
end

return turn_effects
