local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local modal_state = require("src.ui.stores.modal_state")
local host_runtime_ports = require("src.ui.runtime.host_bridge")
local ui_nodes = require("src.ui.render.node_ops")
local choice_contract = require("src.core.choice.contract")
local target_choice_effects = {}
local _move_arrow
local function _is_target_choice(choice)
  return choice ~= nil and choice.route_key == "target" and choice_contract.uses_target_picker(choice)
end
local function _resolve_option_id(option)
  local raw = option
  if type(option) == "table" then
    raw = option.id or option.option_id or option.tile_index
  end
  return number_utils.to_integer(raw)
end
local function _resolve_choice_owner_role_id(game, choice)
  local from_choice = choice and number_utils.to_integer(choice.target_picker_owner_role_id) or nil
  if from_choice ~= nil then
    return from_choice
  end
  local owner_role_id = choice and number_utils.to_integer(choice.owner_role_id) or nil
  if owner_role_id ~= nil then
    return owner_role_id
  end
  local current = game and game.current_player and game:current_player() or nil
  return current and number_utils.to_integer(current.id) or nil
end
local function _vec_component(vec, key, index)
  if type(vec) ~= "table" then
    return nil
  end
  local value = vec[key]
  if value ~= nil then
    return value
  end
  return vec[index]
end
local function _vec_new(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x, y, z)
  end
  return { x = x, y = y, z = z }
end
local function _offset_pos(base, y_offset)
  local ok, pos = pcall(function()
    return base + _vec_new(0.0, y_offset, 0.0)
  end)
  if ok and pos ~= nil then
    return pos
  end
  return _vec_new(
    _vec_component(base, "x", 1) or 0,
    (_vec_component(base, "y", 2) or 0) + y_offset,
    _vec_component(base, "z", 3) or 0
  )
end
local function _warn_once(state, key, ...)
  if type(state._target_pick_warn_once) ~= "table" then
    state._target_pick_warn_once = {}
  end
  if state._target_pick_warn_once[key] then
    return
  end
  state._target_pick_warn_once[key] = true
  logger.warn("[TargetPick]", ...)
end
local function _sync_buttons(state, locked)
  ui_nodes.sync_target_choice_buttons(state, locked == true)
end
local function _sync_highlight_state(state, option_id, locked)
  _sync_buttons(state, locked)
  _move_arrow(state and state.board_scene or nil, option_id)
end
local function _resolve_tile_position(scene, option_id)
  local tile = scene and scene.tiles and scene.tiles[option_id] or nil
  if not tile or type(tile.get_position) ~= "function" then
    return nil
  end
  local ok, pos = pcall(tile.get_position)
  if not ok then
    ok, pos = pcall(tile.get_position, tile)
  end
  if ok then
    return pos
  end
  return nil
end
function _move_arrow(scene, option_id)
  local arrow = scene and scene.target_pick and scene.target_pick.arrow_unit or nil
  if not arrow then
    return
  end
  if option_id == nil then
    if type(arrow.set_model_visible) == "function" then
      arrow.set_model_visible(false)
    end
    return
  end
  local pos = _resolve_tile_position(scene, option_id)
  if not pos then
    return
  end
  local cfg = gameplay_rules.target_pick or {}
  local y_offset = cfg.arrow_height_offset or cfg.marker_height_offset or 1.6
  if type(arrow.set_position) == "function" then
    arrow.set_position(_offset_pos(pos, y_offset))
  end
  if type(arrow.set_model_visible) == "function" then
    arrow.set_model_visible(true)
  end
end
local function _runtime(state)
  return type(state) == "table" and state.target_choice_runtime or nil
end
local function _reset_runtime_state(state, runtime)
  _sync_highlight_state(state, nil, false)
  if runtime and runtime.scene_pick_listener_token ~= nil then
    host_runtime_ports.unregister_target_pick_listener(runtime.scene_pick_listener_token)
  end
  state.target_choice_runtime = nil
end
local function _collect_option_set(choice)
  local option_set = {}
  local option_count = 0
  for _, option in ipairs(choice.options or {}) do
    local option_id = _resolve_option_id(option)
    if option_id ~= nil and option_set[option_id] ~= true then
      option_set[option_id] = true
      option_count = option_count + 1
    end
  end
  return option_set, option_count
end
local function _resolve_picked_option_id(state, option_id, payload)
  local resolved_option_id = number_utils.to_integer(option_id)
  if resolved_option_id ~= nil or not (payload and payload.unit ~= nil) then
    return resolved_option_id
  end
  local picked_unit_id = host_runtime_ports.get_unit_id(payload.unit)
  if picked_unit_id == nil then
    return nil
  end
  local target_pick = state.board_scene and state.board_scene.target_pick or nil
  local tile_index_by_unit_id = target_pick and target_pick.tile_index_by_unit_id or nil
  return tile_index_by_unit_id and tile_index_by_unit_id[picked_unit_id] or nil
end
local function _lock_option(state, runtime, option_id)
  runtime.locked_option_id = option_id
  runtime.hover_option_id = option_id
  modal_state.select_choice_option(state, option_id)
  _sync_highlight_state(state, option_id, true)
  return true
end
function target_choice_effects.enter(state, choice)
  if not _is_target_choice(choice) then
    return false
  end
  local scene = state and state.board_scene or nil
  if not scene then
    _warn_once(state, "missing_board_scene", "board_scene missing, skip target effects")
    return false
  end
  target_choice_effects.leave(state, "reenter")
  local option_set, option_count = _collect_option_set(choice)
  if option_count == 0 then
    return false
  end
  local runtime = {
    choice_id = choice.id,
    owner_role_id = _resolve_choice_owner_role_id(state.game, choice),
    option_set = option_set,
    hover_option_id = nil,
    locked_option_id = nil,
    scene_pick_listener_token = nil,
  }
  state.target_choice_runtime = runtime
  _sync_highlight_state(state, nil, false)
  runtime.scene_pick_listener_token = host_runtime_ports.register_target_pick_listener(function(payload)
    local option_id = payload and (payload.option_id or payload.tile_index) or nil
    local actor_role_id = payload and payload.actor_role_id or nil
    target_choice_effects.on_scene_pick(state, option_id, actor_role_id, payload)
  end)
  return true
end
function target_choice_effects.step(game, state, _dt)
  local runtime = _runtime(state)
  if not runtime then
    return false
  end
  local choice = game and game.turn and game.turn.pending_choice or nil
  if not _is_target_choice(choice) or choice.id ~= runtime.choice_id then
    target_choice_effects.leave(state, "choice_changed")
    return false
  end
  _sync_highlight_state(state, runtime.locked_option_id, runtime.locked_option_id ~= nil)
  return runtime.locked_option_id ~= nil
end
function target_choice_effects.on_scene_pick(state, option_id, actor_role_id, payload)
  local runtime = _runtime(state)
  if not runtime then
    return false
  end
  local parsed_role_id = number_utils.to_integer(actor_role_id)
  if parsed_role_id ~= nil and runtime.owner_role_id ~= nil and parsed_role_id ~= runtime.owner_role_id then
    return false
  end
  local resolved_option_id = _resolve_picked_option_id(state, option_id, payload)
  if resolved_option_id == nil or runtime.option_set[resolved_option_id] ~= true then
    return false
  end
  return _lock_option(state, runtime, resolved_option_id)
end
function target_choice_effects.on_unlock(state)
  local runtime = _runtime(state)
  if not runtime then
    return false
  end
  if runtime.locked_option_id == nil then
    _sync_buttons(state, false)
    return false
  end
  runtime.locked_option_id = nil
  runtime.hover_option_id = nil
  _sync_highlight_state(state, nil, false)
  return true
end
function target_choice_effects.leave(state, _)
  local runtime = _runtime(state)
  if not runtime then
    return false
  end
  _reset_runtime_state(state, runtime)
  return true
end
return target_choice_effects
