local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local camera_follow = require("src.config.gameplay.camera_follow")
local unit_position = require("src.ui.render.unit_position")
local choice_route_policy = require("src.ui.input.choice_route")
local choice_contract = require("src.config.choice.contract")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local role_id_utils = require("src.foundation.identity")
local runtime_ui = require("src.ui.render.runtime_ui")
local canvas_store = require("src.ui.state.canvas_store")
local turn_ui_sync_shared = require("src.state.ui_sync_shared")
local landing_visual_hold = require("src.ui.visual_hold")
local modal = require("src.ui.coord.modal")
local main_view = require("src.ui.coord.ui_runtime")
local view_model = require("src.ui.view")

local camera_sync = {}

local CAMERA_PROP_DIST = 7
local CAMERA_PROP_OBSERVER_HEIGHT = 11
local CAMERA_PROP_PITCH = 15
local CAMERA_PROP_YAW = 16

local _camera_props = {
  { CAMERA_PROP_DIST, nil },
  { CAMERA_PROP_OBSERVER_HEIGHT, nil },
  { CAMERA_PROP_PITCH, nil },
  { CAMERA_PROP_YAW, nil },
}

local function _restore_camera_props(state, local_role)
  _camera_props[1][2] = camera_follow.dist
  _camera_props[2][2] = camera_follow.observer_height
  _camera_props[3][2] = camera_follow.pitch
  _camera_props[4][2] = camera_follow.yaw
  local props = _camera_props
  if type(local_role.set_camera_property) ~= "function" then
    runtime_state.log_once(state, "warn", "camera_sync:set_camera_property_unavailable", "camera_sync", "set_camera_property not available on role")
    return
  end
  for _, entry in ipairs(props) do
    local prop, value = entry[1], entry[2]
    local ok, err = pcall(local_role.set_camera_property, prop, value)
    if not ok then
      runtime_state.log_once(state, "warn", "camera_sync:set_camera_property_" .. tostring(prop), "camera_sync", "set_camera_property(" .. tostring(prop) .. ") failed:", tostring(err))
    end
  end
end

local function _safe_call_method(state, obj, key, log_key, log_prefix)
  if type(obj[key]) ~= "function" then return nil end
  local ok, result = pcall(obj[key])
  if not ok then
    runtime_state.log_once(state, "warn", log_key, "camera_sync", log_prefix, tostring(result))
    return nil
  end
  return result
end

local function _resolve_unit_position(state, role)
  if role == nil then return nil end
  local unit = _safe_call_method(state, role, "get_ctrl_unit", "camera_sync:get_ctrl_unit_failed", "resolve unit failed:")
  if unit == nil then return nil end
  return _safe_call_method(state, unit, "get_position", "camera_sync:get_position_failed", "resolve unit position failed:")
end

local function _resolve_followed_unit_live_position(state, player_id)
  local board_scene = state and state.board_scene or nil
  if board_scene == nil then
    return nil
  end
  local units_by_player_id = board_scene.units_by_player_id
  if type(units_by_player_id) ~= "table" then
    return nil
  end
  return unit_position.read_unit_position(units_by_player_id[player_id])
end

local function _resolve_follow_target_position(state, player_id)
  local live_pos = _resolve_followed_unit_live_position(state, player_id)
  if live_pos ~= nil then
    return live_pos
  end
  local followed_pos = runtime_state.get_follow_target_position(state, player_id)
  if followed_pos ~= nil then
    return followed_pos
  end
  local target_role = runtime_ports.resolve_role(player_id)
  if target_role == nil then
    return nil
  end
  return _resolve_unit_position(state, target_role)
end

local function _resolve_current_player_id(state)
  local game = state and state.game or nil
  local turn = game and game.turn or nil
  local players = game and game.players or nil
  local current_index = turn and turn.current_player_index or nil
  local current_player = current_index and players and players[current_index] or nil
  return current_player and current_player.id or nil
end

local function _resolve_camera_local_role_id(state)
  return (state and runtime_state.get_local_actor_role_id(state) or nil)
    or _resolve_current_player_id(state)
end

local function _lock_camera_to_target_position(state, local_role, target_pos)
  if target_pos == nil then
    return false
  end
  if type(local_role.set_camera_lock_position) ~= "function" then
    return false
  end
  local ok, err = pcall(local_role.set_camera_lock_position, target_pos)
  if not ok then
    runtime_state.log_once(state, "warn", "camera_sync:set_camera_lock_position_failed", "camera_sync", "set_camera_lock_position failed:", tostring(err))
  else
    _restore_camera_props(state, local_role)
  end
  return ok == true
end

local function _reset_camera_to_self(state, local_role)
  if type(local_role.reset_camera) ~= "function" then
    return false
  end
  local ok, err = pcall(local_role.reset_camera, true, true, true, true)
  if not ok then
    runtime_state.log_once(state, "warn", "camera_sync:reset_camera_failed", "camera_sync", "reset_camera failed:", tostring(err))
  end
  return ok == true
end

function camera_sync.follow_camera(state, player_id)
  if player_id == nil then
    return false
  end
  local camera = runtime_ports.resolve_camera_helper()
  if camera then
    camera.target_role_id = player_id
  end
  if camera and type(camera.follow) == "function" then
    camera.follow(player_id)
  end

  local local_role_id = _resolve_camera_local_role_id(state)
  if local_role_id == nil then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end

  if player_id == local_role_id then
    return _reset_camera_to_self(state, local_role)
  end

  _reset_camera_to_self(state, local_role)

  local target_pos = _resolve_follow_target_position(state, player_id)
  if target_pos == nil then
    return false
  end

  return _lock_camera_to_target_position(state, local_role, target_pos)
end


function camera_sync.sync_camera_position(state)
  local camera = runtime_ports.resolve_camera_helper()
  local target_id = camera and camera.target_role_id or nil
  if target_id == nil then
    return false
  end
  local local_role_id = _resolve_camera_local_role_id(state)
  if local_role_id == nil or target_id == local_role_id then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end
  local target_pos = _resolve_follow_target_position(state, target_id)
  return _lock_camera_to_target_position(state, local_role, target_pos)
end

function camera_sync.pan_camera_to_position(state, target_pos)
  if target_pos == nil then
    return false
  end
  local local_role_id = _resolve_camera_local_role_id(state)
  if local_role_id == nil then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end
  local camera = runtime_ports.resolve_camera_helper()
  if camera then
    camera.target_role_id = nil
  end
  _reset_camera_to_self(state, local_role)
  return _lock_camera_to_target_position(state, local_role, target_pos)
end

function camera_sync.release_target_pan(state)
  if state == nil then
    return false
  end
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  if turn_runtime == nil then
    return false
  end
  turn_runtime.last_follow_player_id = nil
  return true
end

local choice_ui_state = {}

local _input_blocked_phases = {
  wait_action_anim = true,
  wait_move_anim = true,
  wait_landing_visual = true,
  detained_wait = true,
  inter_turn_wait = true,
}

local function _is_phase_input_blocked(phase)
  return _input_blocked_phases[phase] == true
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_or_meta_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  local current_index = game and game.turn and game.turn.current_player_index or nil
  local player = current_index and game and game.players and game.players[current_index] or nil
  return role_id_utils.normalize(player and player.id or nil)
end

local function _find_player(game, role_id)
  if game == nil or role_id == nil then
    return nil
  end
  if type(game.find_player_by_id) == "function" then
    return game:find_player_by_id(role_id)
  end
  for _, player in ipairs(game.players or {}) do
    if role_id_utils.equals(player and player.id or nil, role_id) then
      return player
    end
  end
  return nil
end

local function _is_game_input_blocked_phase(game)
  local phase = game and game.turn and game.turn.phase or nil
  return _is_phase_input_blocked(phase)
end

local function _is_local_role(state, owner_role_id)
  if owner_role_id == nil then
    return false
  end

  local local_role_id = role_id_utils.normalize(local_actor_resolver.resolve_local(state))
  if local_role_id ~= nil then
    return role_id_utils.equals(local_role_id, owner_role_id)
  end

  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles == 1 then
    local role_id = role_id_utils.normalize(runtime_ui.resolve_role_id(roles[1]))
    if role_id ~= nil then
      return role_id_utils.equals(role_id, owner_role_id)
    end
  end

  return false
end

choice_ui_state.resolve_route_key = choice_route_policy.resolve

local _cached_gate_state = {}

function choice_ui_state.resolve_gate_state(game, state, choice)
  local route_key = choice_ui_state.resolve_route_key(choice)
  local ui = state and state.ui or nil
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  local owner_player = _find_player(game, owner_role_id)
  local local_owner = _is_local_role(state, owner_role_id)
  local owner_auto = owner_player and (owner_player.is_ai == true or owner_player.auto == true) or false
  local expects_ui = route_key ~= "base_inline" and not _is_game_input_blocked_phase(game) and local_owner and not owner_auto
  local open

  if route_key == "base_inline" or route_key == "item_phase_passive" then
    open = true
  elseif route_key == "market" then
    open = ui and ui.market_active == true or false
  else
    open = ui and ui.choice_active == true and ui.active_choice_screen_key == route_key or false
  end

  _cached_gate_state.route_key = route_key
  _cached_gate_state.owner_role_id = owner_role_id
  _cached_gate_state.local_owner = local_owner
  _cached_gate_state.owner_auto = owner_auto
  _cached_gate_state.expects_ui = expects_ui
  _cached_gate_state.open = open
  _cached_gate_state.should_warn = expects_ui and not open
  return _cached_gate_state
end

function choice_ui_state.should_reconcile(game, state, choice)
  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  return gate.expects_ui and not gate.open
end

local ui_gate_sync = {}
local _cached_gate = {}

local function _read_flag(ui, key)
  return ui and ui[key] == true or false
end

local function _read_value(ui, key)
  return ui and ui[key] or nil
end

local function _resolve_popup_auto_close_seconds(ui)
  local popup = ui and ui.popup_payload or nil
  return popup and popup.auto_close_seconds or nil
end

function ui_gate_sync.get_ui_state(state, common)
  return common.get_ui_state(state)
end

function ui_gate_sync.resolve_ui_gate(state, common)
  local ui = common.get_ui_state(state)
  _cached_gate.input_blocked = _read_flag(ui, "input_blocked")
  _cached_gate.choice_active = _read_flag(ui, "choice_active")
  _cached_gate.market_active = _read_flag(ui, "market_active")
  _cached_gate.popup_active = _read_flag(ui, "popup_active")
  _cached_gate.popup_seq = _read_value(ui, "popup_seq")
  _cached_gate.popup_auto_close_seconds = _resolve_popup_auto_close_seconds(ui)
  _cached_gate.popup_owner_index = _read_value(ui, "popup_owner_index")
  return _cached_gate
end

function ui_gate_sync.is_input_blocked(state, common)
  return _read_flag(common.get_ui_state(state), "input_blocked")
end

function ui_gate_sync.is_popup_active(state, common)
  return _read_flag(common.get_ui_state(state), "popup_active")
end

function ui_gate_sync.is_choice_active(state, common)
  return _read_flag(common.get_ui_state(state), "choice_active")
end

function ui_gate_sync.is_market_active(state, common)
  return _read_flag(common.get_ui_state(state), "market_active")
end

function ui_gate_sync.get_popup_owner_index(state, common)
  return _read_value(common.get_ui_state(state), "popup_owner_index")
end

function ui_gate_sync.set_input_blocked(state, blocked, common)
  local ui = common.get_ui_state(state)
  if not ui then
    return false
  end
  if ui.input_blocked == blocked then
    return false
  end
  canvas_store.patch_slice(state, "base", function()
    ui.input_blocked = blocked
  end)
  return true
end

local ui_model_sync = {}

local function _mark_ui_dirty_from_runtime(state, dirty)
  if runtime_state.is_ui_dirty(state) then
    dirty.ui = true
  end
end

local function _defer_refresh_for_landing_hold(state, dirty)
  if not landing_visual_hold.should_defer(state) then
    return false
  end
  landing_visual_hold.freeze_active_ui(state)
  if dirty.any or dirty.ui then
    landing_visual_hold.defer_dirty(state, dirty)
  end
  return true
end

local function _update_runtime_ui_model(state, game, dirty)
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  local next_model = view_model.update(runtime_state.get_ui_model(state), game, env, dirty)
  runtime_state.set_ui_model(state, next_model)
  return next_model
end

local function _refresh_turn_label(state, next_model)
  local panel = next_model and next_model.panel or nil
  main_view.refresh_turn_label(
    state,
    panel and panel.turn_label or "",
    panel and panel.countdown_visible
  )
end

local function _should_open_choice_modal(game, state, next_model, dirty)
  local phase = game and game.turn and game.turn.phase or nil
  if not (next_model and next_model.choice) then
    return false
  end
  if _is_phase_input_blocked(phase) then
    return false
  end
  local route_key = choice_ui_state.resolve_route_key(next_model.choice)
  if route_key == "base_inline" or route_key == "item_phase_passive" then
    return true
  end
  if route_key == "market" and next_model.market ~= nil then
    if dirty and dirty.market == true then
      return true
    end
    return choice_ui_state.should_reconcile(game, state, next_model.choice)
  end
  return choice_ui_state.should_reconcile(game, state, next_model.choice)
end

local function _should_close_choice_modal(state, next_model)
  local ui = state and state.ui or nil
  if not ui then
    return false
  end
  if not ui.choice_active then
    return false
  end
  return not (next_model and next_model.choice)
end

local function _render_ui_model(game, state, next_model, dirty, common)
  main_view.render(state, next_model, common.log_once, common.build_log_prefix)
  if _should_close_choice_modal(state, next_model) then
    modal.close_choice_modal(state)
    return
  end
  if _should_open_choice_modal(game, state, next_model, dirty) then
    modal.open_choice_modal(state, next_model.choice, next_model.market)
  end
end

function ui_model_sync.apply_input_lock(state)
  main_view.apply_input_lock(state)
end

function ui_model_sync.build_model(state, game)
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  return view_model.build(game, env)
end

function ui_model_sync.refresh_from_dirty(game, state, dirty, common)
  landing_visual_hold.sync_state_from_game(state, game)
  _mark_ui_dirty_from_runtime(state, dirty)
  if _defer_refresh_for_landing_hold(state, dirty) then
    return false
  end
  if not (dirty.any or dirty.ui) then
    return false
  end
  local only_countdown = turn_ui_sync_shared.is_only_turn_countdown(dirty)
  local next_model = _update_runtime_ui_model(state, game, dirty)
  if only_countdown then
    _refresh_turn_label(state, next_model)
  else
    _render_ui_model(game, state, next_model, dirty, common)
  end
  runtime_state.set_ui_dirty(state, false)
  return not only_countdown
end

local function _resolve_reconciled_choice_model(game, state, pending)
  local model = runtime_state.get_ui_model(state)
  if model and model.choice and model.choice.id == pending.id then
    return model
  end

  model = ui_model_sync.build_model(state, game)
  runtime_state.set_ui_model(state, model)
  return model
end

local function _reopen_choice_modal_if_needed(game, state, pending)
  if not choice_ui_state.should_reconcile(game, state, pending) then
    return false
  end
  local model = _resolve_reconciled_choice_model(game, state, pending)
  if not (model and model.choice) then
    return false
  end
  modal.open_choice_modal(state, model.choice, model.market)
  return true
end

local ui_sync_ports = {}

function ui_sync_ports.build(common)
  return {
    apply_input_lock = ui_model_sync.apply_input_lock,
    on_pending_choice = function(game, state, pending)
      runtime_state.set_ui_dirty(state, true)
      _reopen_choice_modal_if_needed(game, state, pending)
    end,
    resolve_choice_ui_state = function(game, state, choice)
      return choice_ui_state.resolve_gate_state(game, state, choice)
    end,
    build_model = ui_model_sync.build_model,
    refresh_from_dirty = function(game, state, dirty)
      return ui_model_sync.refresh_from_dirty(game, state, dirty, common)
    end,
    follow_camera = camera_sync.follow_camera,
    sync_camera_position = camera_sync.sync_camera_position,
    pan_camera_to_position = camera_sync.pan_camera_to_position,
    release_target_pan = camera_sync.release_target_pan,
    get_ui_state = function(state)
      return ui_gate_sync.get_ui_state(state, common)
    end,
    resolve_ui_gate = function(state)
      return ui_gate_sync.resolve_ui_gate(state, common)
    end,
    is_input_blocked = function(state)
      return ui_gate_sync.is_input_blocked(state, common)
    end,
    is_popup_active = function(state)
      return ui_gate_sync.is_popup_active(state, common)
    end,
    is_choice_active = function(state)
      return ui_gate_sync.is_choice_active(state, common)
    end,
    is_market_active = function(state)
      return ui_gate_sync.is_market_active(state, common)
    end,
    get_popup_owner_index = function(state)
      return ui_gate_sync.get_popup_owner_index(state, common)
    end,
    set_input_blocked = function(state, blocked)
      return ui_gate_sync.set_input_blocked(state, blocked, common)
    end,
  }
end

ui_sync_ports._model = ui_model_sync
ui_sync_ports._camera = camera_sync
ui_sync_ports._choice_state = choice_ui_state
ui_sync_ports._gate = ui_gate_sync

return ui_sync_ports
