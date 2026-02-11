local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
local player_positioning = require("src.ui.PlayerPositioning")
local step_builder = require("src.ui.PlayerMoveBehaviorStepBuilder")
local bootstrap = require("src.ui.PlayerMoveBehaviorBootstrap")
local player_move_behavior = {}
local _sessions = {}
local _collision_pair_refs = {}
local _session_seq = 0
local behavior = bootstrap.load_behavior()
local function _safe_call(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  return pcall(fn, ...)
end
local function _get_session(player_id, session_id)
  local session = _sessions[player_id]
  if not session then
    return nil
  end
  if session_id and session.id ~= session_id then
    return nil
  end
  return session
end
local function _cleanup_session(player_id, session_id)
  local session = _get_session(player_id, session_id)
  if not session then
    return
  end
  if session.tree and session.tree.destroy then
    _safe_call(session.tree.destroy, session.tree)
  end
  _sessions[player_id] = nil
end
local function _build_collision_pair_key(player_a, player_b)
  local left = tonumber(player_a)
  local right = tonumber(player_b)
  if left ~= nil and right ~= nil then
    if left > right then
      left, right = right, left
    end
    return tostring(left) .. ":" .. tostring(right)
  end
  left = tostring(player_a)
  right = tostring(player_b)
  if left > right then
    left, right = right, left
  end
  return left .. ":" .. right
end
local function _stop_unit(session)
  if session.is_vehicle and vehicle_helper and vehicle_helper.forward_eca_event_stop then
    _safe_call(vehicle_helper.forward_eca_event_stop, session.player_id)
    return
  end
  local unit = session.unit
  if unit == nil then
    return
  end
  if _safe_call(unit.force_stop_move) then
    return
  end
  local stop_duration = 0
  if math and math.tofixed then
    stop_duration = math.tofixed(0)
  end
  _safe_call(unit.ai_command_stop_move, stop_duration)
end
local function _snap_position(session, target_pos)
  if target_pos == nil then
    return
  end
  local safe_target_pos = player_positioning.clamp_to_safe_player_pos(session.board_scene, target_pos)
  if session.is_vehicle and vehicle_helper and vehicle_helper.forward_eca_event_set_position then
    _safe_call(vehicle_helper.forward_eca_event_set_position, session.player_id, safe_target_pos)
    return
  end
  local unit = session.unit
  if unit and unit.set_position then
    _safe_call(unit.set_position, safe_target_pos)
  end
end
local function _stop_and_snap(session, target_pos)
  _stop_unit(session)
  _snap_position(session, target_pos)
end
local function _disable_player_collision(session)
  if runtime_constants.player_move_disable_player_collision ~= true then
    return
  end
  if not (GameAPI and GameAPI.enable_collision_between_units) then
    return
  end
  local mover = session.unit
  if mover == nil then
    return
  end
  for pid, other in pairs(session.board_scene.units_by_player_id or {}) do
    if pid ~= session.player_id and other ~= nil then
      local pair_key = _build_collision_pair_key(session.player_id, pid)
      if not session.collision_pair_keys[pair_key] then
        session.collision_pair_keys[pair_key] = true
        local pair_ref = _collision_pair_refs[pair_key]
        if not pair_ref then
          pair_ref = { count = 0, unit_a = mover, unit_b = other }
          _collision_pair_refs[pair_key] = pair_ref
        end
        if pair_ref.count <= 0 then
          _safe_call(GameAPI.enable_collision_between_units, mover, other, false)
          pair_ref.unit_a = mover
          pair_ref.unit_b = other
        end
        pair_ref.count = pair_ref.count + 1
      end
    end
  end
end
local function _restore_player_collision(session)
  for pair_key, _ in pairs(session.collision_pair_keys) do
    local pair_ref = _collision_pair_refs[pair_key]
    if pair_ref then
      pair_ref.count = pair_ref.count - 1
      if pair_ref.count <= 0 then
        if GameAPI and GameAPI.enable_collision_between_units and pair_ref.unit_a and pair_ref.unit_b then
          _safe_call(GameAPI.enable_collision_between_units, pair_ref.unit_a, pair_ref.unit_b, true)
        end
        _collision_pair_refs[pair_key] = nil
      end
    end
  end
  session.collision_pair_keys = {}
end
local function _request_tick(player_id, session_id)
  local session = _get_session(player_id, session_id)
  if not session then
    return
  end
  if session.ticking then
    session.pending_tick = true
    return
  end
  session.ticking = true
  while true do
    session.pending_tick = false
    local ok, status = pcall(function()
      return session.tree:tick()
    end)
    if not ok or status ~= BT.Status.RUNNING then
      if not session.finalized then
        _restore_player_collision(session)
        _stop_and_snap(session, session.final_target_pos)
        session.finalized = true
      end
      break
    end
    if not session.pending_tick then
      break
    end
  end
  session.ticking = false
  if session.finalized then
    _cleanup_session(player_id, session_id)
  end
end
local function _schedule_timeout(session, delay, cb)
  if delay and delay > 0 and type(SetTimeOut) == "function" then
    SetTimeOut(delay, cb)
    return
  end
  cb()
end
local function _dispatch_step_move(session, step)
  if session.vehicle_jump_mode then
    _safe_call(vehicle_helper.forward_eca_event_set_position, session.player_id, step.target_pos)
    return
  end
  if session.vehicle_move_mode then
    _safe_call(vehicle_helper.forward_eca_event_move, session.player_id, step.dir, step.duration)
    return
  end
  local unit = assert(session.unit, "missing player unit: " .. tostring(session.player_id))
  assert(unit.start_move_by_direction ~= nil, "missing unit.start_move_by_direction: " .. tostring(session.player_id))
  unit.start_move_by_direction(step.dir, step.duration)
end
local function _finish_step(session, step)
  if runtime_constants.player_move_hard_stop_each_step ~= false then
    _stop_and_snap(session, step.target_pos)
  end
end
local function _run_prepare(session)
  _disable_player_collision(session)
  _stop_and_snap(session, session.start_pos)
  return BT.Status.SUCCESS
end
local function _run_steps(session)
  if session.enter_waiting then
    if not session.enter_timer_set then
      session.enter_timer_set = true
      _schedule_timeout(session, session.enter_delay, function()
        local active = _get_session(session.player_id, session.id)
        if not active then
          return
        end
        active.enter_waiting = false
        active.enter_timer_set = false
        _request_tick(active.player_id, active.id)
      end)
    end
    return BT.Status.RUNNING
  end
  if session.step_cursor > #session.steps then
    return BT.Status.SUCCESS
  end
  if session.step_in_progress then
    return BT.Status.RUNNING
  end
  local step = session.steps[session.step_cursor]
  _dispatch_step_move(session, step)
  if step.duration <= 0 then
    _finish_step(session, step)
    session.step_cursor = session.step_cursor + 1
    _request_tick(session.player_id, session.id)
    return BT.Status.RUNNING
  end
  session.step_in_progress = true
  _schedule_timeout(session, step.duration, function()
    local active = _get_session(session.player_id, session.id)
    if not active then
      return
    end
    active.step_in_progress = false
    _finish_step(active, step)
    active.step_cursor = active.step_cursor + 1
    _request_tick(active.player_id, active.id)
  end)
  return BT.Status.RUNNING
end
local function _run_finalize(session)
  _restore_player_collision(session)
  _stop_and_snap(session, session.final_target_pos)
  session.finalized = true
  return BT.Status.SUCCESS
end
local function _build_tree(session)
  local tree = behavior.build_tree({
    type = BT.NodeType.SEQUENCE,
    name = "player_move_root",
    children = {
      {
        type = BT.NodeType.ACTION,
        name = "prepare_move",
        func = function(blackboard)
          return _run_prepare(blackboard:get("session"))
        end,
      },
      {
        type = BT.NodeType.ACTION,
        name = "run_steps",
        func = function(blackboard)
          return _run_steps(blackboard:get("session"))
        end,
      },
      {
        type = BT.NodeType.ACTION,
        name = "finalize_move",
        func = function(blackboard)
          return _run_finalize(blackboard:get("session"))
        end,
      },
    },
  })
  tree:get_blackboard():set("session", session)
  return tree
end
function player_move_behavior.cancel(player_id)
  local session = _get_session(player_id)
  if not session then
    return
  end
  _restore_player_collision(session)
  _stop_unit(session)
  _cleanup_session(player_id, session.id)
end
function player_move_behavior.play(board_scene, anim_ctx, _opts)
  assert(board_scene ~= nil, "missing board_scene")
  assert(anim_ctx ~= nil, "missing anim_ctx")
  local player_id = assert(anim_ctx.player_id, "missing player_id")
  local from_index = assert(anim_ctx.from_index, "missing from_index")
  local to_index = assert(anim_ctx.to_index, "missing to_index")
  player_move_behavior.cancel(player_id)
  local steps, total = step_builder.build_steps(board_scene, from_index, to_index, anim_ctx.visited, anim_ctx)
  local enter_delay = #steps > 0 and step_builder.consume_enter_delay(player_id, anim_ctx) or 0
  local total_duration = total + enter_delay
  if from_index ~= to_index and total_duration <= 0 then
    local visited_count = 0
    if type(anim_ctx.visited) == "table" then
      visited_count = #anim_ctx.visited
    end
    logger.warn(
      "[Eggy] invalid bt move duration",
      "player_id=", tostring(player_id),
      "from=", tostring(from_index),
      "to=", tostring(to_index),
      "steps=", tostring(#steps),
      "visited=", tostring(visited_count),
      "walk_speed=", tostring(runtime_constants.walk_speed),
      "duration=", tostring(total_duration)
    )
  end
  _session_seq = _session_seq + 1
  local session = {
    id = _session_seq,
    player_id = player_id,
    board_scene = board_scene,
    unit = (board_scene.units_by_player_id or {})[player_id],
    anim_ctx = anim_ctx,
    steps = steps,
    step_cursor = 1,
    step_in_progress = false,
    enter_delay = enter_delay,
    enter_waiting = enter_delay > 0,
    enter_timer_set = false,
    start_pos = step_builder.resolve_tile_pos(board_scene, from_index),
    final_target_pos = step_builder.resolve_tile_pos(board_scene, to_index),
    collision_pair_keys = {},
    is_vehicle = step_builder.is_vehicle_anim(anim_ctx),
    vehicle_move_mode = step_builder.is_vehicle_move_mode(anim_ctx),
    vehicle_jump_mode = step_builder.is_vehicle_jump_mode(anim_ctx),
    finalized = false,
    ticking = false,
    pending_tick = false,
  }
  session.tree = _build_tree(session)
  _sessions[player_id] = session
  _request_tick(player_id, session.id)
  return total_duration
end
return player_move_behavior
