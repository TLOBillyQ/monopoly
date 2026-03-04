local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local gameplay_rules = require("src.core.config.GameplayRules")
local runtime_constants = require("src.core.config.RuntimeConstants")
local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local host_runtime = require("src.presentation.api.HostRuntimePort")
local ui_core = require("src.presentation.api.ui_view_service.core")

local target_choice_effects = {}

local function _is_target_choice(choice)
  local kind = choice and choice.kind or nil
  return kind == "roadblock_target" or kind == "demolish_target"
end

local function _resolve_option_id(option)
  local raw = option
  if type(option) == "table" then
    raw = option.id or option.option_id or option.tile_index
  end
  return number_utils.to_integer(raw)
end

local function _resolve_choice_owner_role_id(game, choice)
  local meta = choice and choice.meta or nil
  local from_meta = meta and number_utils.to_integer(meta.player_id) or nil
  if from_meta ~= nil then
    return from_meta
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

local function _distance(a, b)
  local ok, len = pcall(function()
    return (a - b):length()
  end)
  if ok and number_utils.is_numeric(len) then
    return len
  end
  local dx = (_vec_component(a, "x", 1) or 0) - (_vec_component(b, "x", 1) or 0)
  local dy = (_vec_component(a, "y", 2) or 0) - (_vec_component(b, "y", 2) or 0)
  local dz = (_vec_component(a, "z", 3) or 0) - (_vec_component(b, "z", 3) or 0)
  return math.sqrt(dx * dx + dy * dy + dz * dz)
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
  ui_core.sync_target_choice_buttons(state, locked == true)
end

local function _resolve_tile_position(scene, option_id)
  local tile = scene and scene.tiles and scene.tiles[option_id] or nil
  if not tile or type(tile.get_position) ~= "function" then
    return nil
  end
  local ok, pos = pcall(tile.get_position, tile)
  if ok then
    return pos
  end
  return nil
end

local function _move_arrow(scene, option_id)
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

local function _resolve_pending_target_choice(game)
  local choice = game and game.turn and game.turn.pending_choice or nil
  if not _is_target_choice(choice) then
    return nil
  end
  return choice
end

local function _resolve_runtime(state)
  local runtime = state and state.target_choice_runtime or nil
  if type(runtime) ~= "table" then
    return nil
  end
  return runtime
end

local function _resolve_hit_option_id(state, runtime, hit)
  local scene = state and state.board_scene or nil
  if not scene then
    return nil
  end

  local unit = hit and hit.unit or nil
  local unit_id = host_runtime.get_unit_id(unit)
  if unit_id ~= nil then
    local mapped = runtime.marker_option_by_unit_id and runtime.marker_option_by_unit_id[unit_id] or nil
    if mapped ~= nil then
      return mapped
    end
    local from_tile = scene.target_pick and scene.target_pick.tile_index_by_unit_id
        and scene.target_pick.tile_index_by_unit_id[unit_id] or nil
    if from_tile ~= nil then
      return from_tile
    end
  end

  local hit_pos = host_runtime.resolve_hit_position(hit and hit.hit or hit)
  if not hit_pos then
    return nil
  end

  local cfg = gameplay_rules.target_pick or {}
  local max_dist = cfg.nearest_tile_max_distance or 1.8
  local best_option = nil
  local best_dist = nil
  for _, option_id in ipairs(runtime.option_ids or {}) do
    local tile_pos = _resolve_tile_position(scene, option_id)
    if tile_pos then
      local dist = _distance(tile_pos, hit_pos)
      if best_dist == nil or dist < best_dist then
        best_dist = dist
        best_option = option_id
      end
    end
  end
  if best_dist ~= nil and best_dist <= max_dist then
    return best_option
  end
  return nil
end

local function _spawn_markers(state, runtime)
  local scene = state.board_scene
  local target_pick = scene and scene.target_pick or nil
  if not target_pick then
    _warn_once(state, "missing_target_pick_scene", "target_pick scene data missing")
    return
  end

  local cfg = gameplay_rules.target_pick or {}
  local y_offset = cfg.marker_height_offset or 1.6
  local marker_unit_id = target_pick.marker_unit_id
  if marker_unit_id == nil then
    _warn_once(state, "missing_marker_unit", "marker template id unavailable")
    return
  end

  for _, option_id in ipairs(runtime.option_ids or {}) do
    local tile_pos = _resolve_tile_position(scene, option_id)
    if tile_pos then
      local marker_pos = _offset_pos(tile_pos, y_offset)
      local marker = host_runtime.create_unit_with_scale(
        marker_unit_id,
        marker_pos,
        runtime_constants.q_zero,
        runtime_constants.v3_one
      )
      if marker ~= nil then
        runtime.marker_handles[#runtime.marker_handles + 1] = marker
        local marker_id = host_runtime.get_unit_id(marker)
        if marker_id ~= nil then
          runtime.marker_option_by_unit_id[marker_id] = option_id
        end
      else
        _warn_once(state, "create_marker_failed", "create_unit_with_scale unavailable, skip marker spawn")
        return
      end
    end
  end
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

  local option_ids = {}
  local option_set = {}
  for _, option in ipairs(choice.options or {}) do
    local option_id = _resolve_option_id(option)
    if option_id ~= nil and option_set[option_id] ~= true then
      option_set[option_id] = true
      option_ids[#option_ids + 1] = option_id
    end
  end
  if #option_ids == 0 then
    return false
  end

  local runtime = {
    choice_id = choice.id,
    owner_role_id = _resolve_choice_owner_role_id(state.game, choice),
    option_ids = option_ids,
    option_set = option_set,
    hover_option_id = option_ids[1],
    locked_option_id = nil,
    marker_handles = {},
    marker_option_by_unit_id = {},
    scene_pick_listener_token = nil,
  }
  state.target_choice_runtime = runtime

  _spawn_markers(state, runtime)
  _move_arrow(scene, runtime.hover_option_id)
  _sync_buttons(state, false)

  runtime.scene_pick_listener_token = host_runtime.register_target_pick_listener(function(payload)
    local option_id = payload and (payload.option_id or payload.tile_index) or nil
    local actor_role_id = payload and payload.actor_role_id or nil
    target_choice_effects.on_scene_pick(state, option_id, actor_role_id, payload)
  end)

  logger.info("[TargetPick] enter", tostring(choice.id), "options", tostring(#option_ids))
  return true
end

function target_choice_effects.step(game, state, _dt)
  local runtime = _resolve_runtime(state)
  if not runtime then
    return false
  end

  local choice = _resolve_pending_target_choice(game)
  if not choice or choice.id ~= runtime.choice_id then
    target_choice_effects.leave(state, "choice_changed")
    return false
  end

  _sync_buttons(state, runtime.locked_option_id ~= nil)
  if runtime.locked_option_id ~= nil then
    _move_arrow(state.board_scene, runtime.locked_option_id)
    return true
  end

  local cfg = gameplay_rules.target_pick or {}
  local role_id = runtime.owner_role_id or _resolve_choice_owner_role_id(game, choice)
  runtime.owner_role_id = role_id
  local role = role_id and host_runtime.resolve_role(role_id) or nil
  if not role then
    return false
  end

  local hit_option_id = nil
  if type(state.target_pick_raycast_override) == "function" then
    hit_option_id = number_utils.to_integer(state.target_pick_raycast_override(game, state, runtime, role))
  else
    local ray, ray_err = host_runtime.build_camera_ray(role, cfg)
    if ray == nil then
      _warn_once(state, "ray_build_unavailable", "ray build unavailable:", tostring(ray_err))
      return false
    end
    local hit, hit_err = host_runtime.pick_first_hit_unit(ray.start_pos, ray.end_pos, cfg)
    if hit == nil then
      if hit_err ~= nil then
        _warn_once(state, "ray_api_unavailable", "raycast unavailable:", tostring(hit_err))
      end
      return false
    end
    hit_option_id = _resolve_hit_option_id(state, runtime, hit)
  end

  if hit_option_id == nil or runtime.option_set[hit_option_id] ~= true then
    return false
  end
  if runtime.hover_option_id == hit_option_id then
    return true
  end

  logger.info("[TargetPick] hover_changed", tostring(runtime.hover_option_id), "->", tostring(hit_option_id))
  runtime.hover_option_id = hit_option_id
  _move_arrow(state.board_scene, hit_option_id)
  return true
end

function target_choice_effects.on_scene_pick(state, option_id, actor_role_id, payload)
  local runtime = _resolve_runtime(state)
  if not runtime then
    return false
  end

  local parsed_role_id = number_utils.to_integer(actor_role_id)
  if parsed_role_id ~= nil and runtime.owner_role_id ~= nil and parsed_role_id ~= runtime.owner_role_id then
    return false
  end

  local resolved_option_id = number_utils.to_integer(option_id)
  if resolved_option_id == nil and payload and payload.unit ~= nil then
    local picked_unit_id = host_runtime.get_unit_id(payload.unit)
    if picked_unit_id ~= nil then
      resolved_option_id = runtime.marker_option_by_unit_id[picked_unit_id]
          or (state.board_scene and state.board_scene.target_pick and state.board_scene.target_pick.tile_index_by_unit_id
            and state.board_scene.target_pick.tile_index_by_unit_id[picked_unit_id])
    end
  end

  if resolved_option_id == nil or runtime.option_set[resolved_option_id] ~= true then
    logger.info("[TargetPick] pick_not_candidate", tostring(resolved_option_id))
    return false
  end

  runtime.locked_option_id = resolved_option_id
  runtime.hover_option_id = resolved_option_id
  modal_state.select_choice_option(state, resolved_option_id)
  _sync_buttons(state, true)
  _move_arrow(state.board_scene, resolved_option_id)
  logger.info("[TargetPick] lock_target", tostring(resolved_option_id), "role", tostring(parsed_role_id))
  return true
end

function target_choice_effects.on_unlock(state)
  local runtime = _resolve_runtime(state)
  if not runtime then
    return false
  end
  if runtime.locked_option_id == nil then
    _sync_buttons(state, false)
    return false
  end

  runtime.locked_option_id = nil
  _sync_buttons(state, false)
  _move_arrow(state.board_scene, runtime.hover_option_id)
  logger.info("[TargetPick] unlock")
  return true
end

function target_choice_effects.leave(state, reason)
  local runtime = _resolve_runtime(state)
  if not runtime then
    return false
  end

  if runtime.scene_pick_listener_token ~= nil then
    host_runtime.unregister_target_pick_listener(runtime.scene_pick_listener_token)
  end

  for _, marker in ipairs(runtime.marker_handles or {}) do
    host_runtime.destroy_unit(marker)
  end

  _move_arrow(state.board_scene, nil)
  _sync_buttons(state, false)
  state.target_choice_runtime = nil
  logger.info("[TargetPick] leave", tostring(reason or ""))
  return true
end

return target_choice_effects
