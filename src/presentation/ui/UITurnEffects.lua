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
  if type(state.ui_turn_prompt_last_seq_by_role) ~= "table" then
    state.ui_turn_prompt_last_seq_by_role = {}
  end
  if type(state.ui_turn_prompt_visible_seq_by_role) ~= "table" then
    state.ui_turn_prompt_visible_seq_by_role = {}
  end
  local board = ui_model and ui_model.board or nil
  local prompt_seq = board and board.turn_start_prompt_seq or 0
  local prompt_player_id = board and board.turn_start_prompt_player_id or nil
  runtime.for_each_role_or_global(function(role)
    local role_id = _get_role_id(role)
    runtime.set_client_role(role)
    local nodes = _get_prompt_nodes()
    if role_id and prompt_player_id and role_id == prompt_player_id then
      local last_seq = state.ui_turn_prompt_last_seq_by_role[role_id] or 0
      if prompt_seq ~= nil and prompt_seq > 0 and prompt_seq ~= last_seq then
        state.ui_turn_prompt_last_seq_by_role[role_id] = prompt_seq
        state.ui_turn_prompt_visible_seq_by_role[role_id] = prompt_seq
        _reset_prompt_animation(role, nodes)
        _set_prompt_visible(nodes, true)
        SetTimeOut(1.0, function()
          if state.ui_turn_prompt_visible_seq_by_role[role_id] == prompt_seq then
            runtime.set_client_role(role)
            local timeout_nodes = _get_prompt_nodes()
            _set_prompt_visible(timeout_nodes, false)
            runtime.set_client_role(nil)
          end
        end)
      end
    else
      if role_id ~= nil then
        state.ui_turn_prompt_visible_seq_by_role[role_id] = nil
      end
      _set_prompt_visible(nodes, false)
    end
    runtime.set_client_role(nil)
  end)
end

local function _get_other_action_prompt_label_node()
  return runtime.query_node("基础_其他玩家行动提示")
end

local function _set_other_action_prompt(role, text, visible)
  runtime.set_client_role(role)
  local node = _get_other_action_prompt_label_node()
  if node then
    node.text = text or ""
    node.visible = visible == true
  end
  runtime.set_client_role(nil)
end

local function _sync_other_player_action_prompt(state)
  if not state then
    return
  end
  local pending = state.ui_other_action_prompt_pending
  if not pending then
    return
  end
  state.ui_other_action_prompt_pending = nil
  if type(state.ui_other_action_prompt_seq_by_role) ~= "table" then
    state.ui_other_action_prompt_seq_by_role = {}
  end

  runtime.for_each_role_or_global(function(role)
    local role_id = _get_role_id(role)
    local show = role_id ~= nil
      and pending.actor_player_id ~= nil
      and role_id ~= pending.actor_player_id
      and pending.text ~= nil
      and pending.text ~= ""
    if show then
      local seq = (state.ui_other_action_prompt_seq_by_role[role_id] or 0) + 1
      state.ui_other_action_prompt_seq_by_role[role_id] = seq
      _set_other_action_prompt(role, pending.text, true)
      SetTimeOut(1.0, function()
        if state.ui_other_action_prompt_seq_by_role[role_id] == seq then
          _set_other_action_prompt(role, "", false)
        end
      end)
    else
      if role_id ~= nil then
        state.ui_other_action_prompt_seq_by_role[role_id] = nil
      end
      _set_other_action_prompt(role, "", false)
    end
  end)
end

function turn_effects.sync(state, ui_model)
  _sync_current_turn_highlight(state, ui_model)
  _sync_local_turn_prompt(state, ui_model)
  _sync_other_player_action_prompt(state)
end

return turn_effects
