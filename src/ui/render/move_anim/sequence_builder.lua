local runtime_constants = require("src.config.gameplay.runtime_constants")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")

local sequence_builder = {}

local _ZERO_VEC = (math and math.Vector3) and math.Vector3(0.0, 0.0, 0.0) or { x = 0.0, y = 0.0, z = 0.0 }

local function _zero_vector()
  return _ZERO_VEC
end

local function _calc_step_vector(scene, from_index, to_index)
  local start_tile = scene.tiles[from_index]
  local end_tile = scene.tiles[to_index]
  local pos_s = start_tile.get_position()
  local pos_e = end_tile.get_position()
  local dist = pos_e - pos_s
  local len = dist:length()
  if len <= 0 then
    return _zero_vector(), 0
  end
  local dir = math.Vector3(dist.x / len, dist.y / len, dist.z / len)
  return dir, len
end

local function _calc_walk_step_time(len)
  if len <= 0 then
    return 0
  end
  local walk_speed = runtime_constants.walk_speed or 0
  if walk_speed <= 0 then
    return 0
  end
  return len / walk_speed
end

sequence_builder.calc_step_vector = _calc_step_vector

function sequence_builder.calc_step_time(scene, from_index, to_index, _anim_ctx)
  local _, len = _calc_step_vector(scene, from_index, to_index)
  return _calc_walk_step_time(len)
end

function sequence_builder.resolve_role(player_id)
  if player_id == nil then
    return nil
  end
  local ok, role = pcall(runtime_ports.resolve_role, player_id)
  if not ok then
    return nil
  end
  return role
end

function sequence_builder.is_synthetic_actor(player_id)
  local role = sequence_builder.resolve_role(player_id)
  return role and role.is_synthetic_actor == true or false
end

function sequence_builder.resolve_direction(anim_ctx)
  if anim_ctx.direction then
    return anim_ctx.direction
  end
  if anim_ctx.steps and anim_ctx.steps < 0 then
    return runtime_constants.v3_right
  end
  if anim_ctx.steps and anim_ctx.steps > 0 then
    return runtime_constants.v3_left
  end
  return nil
end

function sequence_builder.build_steps(board_scene, from_index, to_index, visited, anim_ctx, step_duration_fn)
  local steps = {}
  local total_time = 0
  local function _push_step(step_from, step_to)
    if step_from == step_to then
      return
    end
    local step_time = step_duration_fn(board_scene, step_from, step_to, anim_ctx)
    if step_time <= 0 then
      return
    end
    local delay = total_time
    total_time = total_time + step_time
    steps[#steps + 1] = { from = step_from, to = step_to, delay = delay }
  end

  if not visited or #visited <= 1 then
    if from_index ~= to_index then
      _push_step(from_index, to_index)
    end
  else
    local step_from = from_index
    for i = 1, #visited do
      local step_to = visited[i]
      _push_step(step_from, step_to)
      step_from = step_to
    end
  end

  return steps, total_time
end

function sequence_builder.format_visited(visited)
  if type(visited) ~= "table" or #visited == 0 then
    return "nil"
  end
  local out = {}
  for i, value in ipairs(visited) do
    out[i] = tostring(value)
  end
  return table.concat(out, ",")
end

local _follow_opts = {}

function sequence_builder.publish_follow_target(anim_ctx, player_id, position, source)
  local state = anim_ctx and anim_ctx.state or nil
  if state == nil or player_id == nil or position == nil then
    return false
  end
  _follow_opts.source = source
  _follow_opts.seq = anim_ctx and anim_ctx.seq or nil
  return runtime_state.set_follow_target_position(state, player_id, position, _follow_opts)
end

return sequence_builder

--[[ mutate4lua-manifest
version=2
projectHash=c3d85c0e87b58b02
scope.0.id=chunk:src/ui/render/move_anim/sequence_builder.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=130
scope.0.semanticHash=1de79b66d16cb372
scope.1.id=function:_zero_vector:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=dcf1e694edceb014
scope.2.id=function:_calc_step_vector:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=25
scope.2.semanticHash=283f071b2f691857
scope.3.id=function:_calc_walk_step_time:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=36
scope.3.semanticHash=3e0be5e893443b0d
scope.4.id=function:sequence_builder.calc_step_time:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=43
scope.4.semanticHash=13ad70f8d7893fb5
scope.5.id=function:sequence_builder.resolve_role:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=54
scope.5.semanticHash=79fa256ece831b95
scope.6.id=function:sequence_builder.is_synthetic_actor:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=59
scope.6.semanticHash=125acfad2e8b21b8
scope.7.id=function:sequence_builder.resolve_direction:61
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=72
scope.7.semanticHash=4445260366420014
scope.8.id=function:_push_step:77
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=88
scope.8.semanticHash=8b47e15df33c2440
scope.9.id=function:sequence_builder.publish_follow_target:119
scope.9.kind=function
scope.9.startLine=119
scope.9.endLine=127
scope.9.semanticHash=44c8a4c926ee7dfc
]]
