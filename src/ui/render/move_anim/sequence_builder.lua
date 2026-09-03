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

-- 合成 AI 身份唯一真源是 runtime_ports.is_synthetic_player(#611 端口,注册表实现、
-- 退役不擦除);不再从 resolve_role 的适配器标志推断——退役后适配器解析不到,
-- 两条真源会给出相反结论。退役后本模块拿不到单位,各消费方按 nil 单位自然短路。
function sequence_builder.is_synthetic_actor(player_id)
  if player_id == nil then
    return false
  end
  return runtime_ports.is_synthetic_player(player_id) == true
end

local function _direction_from_steps(steps)
  if steps and steps < 0 then
    return runtime_constants.v3_right
  end
  if steps and steps > 0 then
    return runtime_constants.v3_left
  end
  return nil
end

function sequence_builder.resolve_direction(anim_ctx)
  if anim_ctx.direction then
    return anim_ctx.direction
  end
  return _direction_from_steps(anim_ctx.steps)
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

local function _follow_ctx(anim_ctx)
  return anim_ctx and anim_ctx.state or nil
end

local function _has_follow_args(state, player_id, position)
  return state ~= nil and player_id ~= nil and position ~= nil
end

local function _follow_seq(anim_ctx)
  return anim_ctx and anim_ctx.seq or nil
end

function sequence_builder.publish_follow_target(anim_ctx, player_id, position, source)
  local state = _follow_ctx(anim_ctx)
  if not _has_follow_args(state, player_id, position) then
    return false
  end
  _follow_opts.source = source
  _follow_opts.seq = _follow_seq(anim_ctx)
  return runtime_state.set_follow_target_position(state, player_id, position, _follow_opts)
end

return sequence_builder

--[[ mutate4lua-manifest
version=4
projectHash=857ee4c0bc1a3903
scope.0.id=chunk:src/ui/render/move_anim/sequence_builder.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=86a304011968137b
scope.1.id=function:_zero_vector
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=1136505bd37c301e
scope.2.id=function:_calc_step_vector
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=25
scope.2.semanticHash=114fe0d26d8d6896
scope.3.id=function:_calc_walk_step_time
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=36
scope.3.semanticHash=0c1408e31b124529
scope.4.id=function:sequence_builder.calc_step_time
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=43
scope.4.semanticHash=3d7f94ff02e37efd
scope.5.id=function:sequence_builder.resolve_role
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=54
scope.5.semanticHash=ddaf37692a837981
scope.6.id=function:sequence_builder.is_synthetic_actor
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=64
scope.6.semanticHash=258a1ea85937adfc
scope.7.id=function:_direction_from_steps
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=74
scope.7.semanticHash=60628117eddd7be9
scope.8.id=function:sequence_builder.resolve_direction
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=81
scope.8.semanticHash=c71b1a7ba67ce816
scope.9.id=function:sequence_builder.build_steps
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=113
scope.9.semanticHash=e07b72ed21ab8ee7
scope.10.id=function:_push_step
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=97
scope.10.semanticHash=a7b15fc7117290ba
scope.11.id=function:sequence_builder.format_visited
scope.11.kind=function
scope.11.startLine=115
scope.11.endLine=124
scope.11.semanticHash=2e95ef79fedd92ce
scope.12.id=function:_follow_ctx
scope.12.kind=function
scope.12.startLine=128
scope.12.endLine=130
scope.12.semanticHash=616a2ca60599c94f
scope.13.id=function:_has_follow_args
scope.13.kind=function
scope.13.startLine=132
scope.13.endLine=134
scope.13.semanticHash=342b68d7fd51b713
scope.14.id=function:_follow_seq
scope.14.kind=function
scope.14.startLine=136
scope.14.endLine=138
scope.14.semanticHash=616a2ca60599c94f
scope.15.id=function:sequence_builder.publish_follow_target
scope.15.kind=function
scope.15.startLine=140
scope.15.endLine=148
scope.15.semanticHash=c6cf543e4322bef7
]]
