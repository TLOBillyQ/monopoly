-- #293 批3 pin:src/ui/render/move_anim/playback.lua 的幸存者分四簇:
-- ① one_step 单步链(start_move_by_direction / publish_follow_target /
--    on_step_lock 的调用与返回值);
-- ② play_sequence 编排链(build_steps 实参、速度加成、token/sequence 登记、
--    panel 开场、即时步与延时步调度、停表调度);
-- ③ _execute_step 的 stale-token 跳过(改动 token 后延时步必须不落地);
-- ④ _stop_active_sequence 的收尾链(stop 直调、锁释放、token 清除、
--    panel 收场)与 stale-token 整体跳过。
-- rt 用真实模块(plain table 上可直跑),桩 seq_builder / stop / debug /
-- board_feedback / runtime_ports,panel_interrupt 经 package.loaded 换桩
-- 以捕获 begin_move/end_move。debug 恒关,日志类变异按等价处置。

local lu = require("luaunit")

local playback = require("src.ui.render.move_anim.playback")
local rt = require("src.ui.render.move_anim.runtime")
local seq_builder = require("src.ui.render.move_anim.sequence_builder")
local stop = require("src.ui.render.move_anim.stop")
local debug_mod = require("src.ui.render.move_anim.debug")
local board_feedback = require("src.ui.render.board_feedback.service")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local timing = require("src.config.gameplay.timing")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local _saved_step_duration = playback.step_duration
local _saved_calc_step_vector = seq_builder.calc_step_vector
local _saved_resolve_direction = seq_builder.resolve_direction
local _saved_build_steps = seq_builder.build_steps
local _saved_publish_follow_target = seq_builder.publish_follow_target
local _saved_stop_presentation = stop.stop_player_presentation
local _saved_clear_token = stop.clear_player_token
local _saved_enabled = debug_mod.enabled
local _saved_play_step_sound = board_feedback.play_step_tile_sound
local _saved_schedule = runtime_ports.schedule
local panel_interrupt = require("src.ui.state.panel_interrupt")
local _saved_begin_move = panel_interrupt.begin_move
local _saved_end_move = panel_interrupt.end_move

local _captured = nil

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _unit(has_modifier)
  local unit = {
    start_move_by_direction = function(direction, time)
      _captured.moves[#_captured.moves + 1] = { direction = direction, time = time }
    end,
  }
  if has_modifier ~= false then
    unit.add_modifier_by_key = function(key, opts)
      _captured.modifiers[#_captured.modifiers + 1] = { key = key, opts = opts }
      return _captured.modifier
    end
  end
  return unit
end

local function _scene(has_modifier)
  return {
    units_by_player_id = { [1] = _unit(has_modifier) },
    tiles = {
      [1] = { get_position = function() return "pos_1" end },
      [2] = { get_position = function() return "pos_2" end },
    },
  }
end

local function _anim_ctx()
  return {
    player_id = 1,
    from_index = 0,
    to_index = 2,
    seq = 7,
    state = { ui = {} },
  }
end

local function _steps()
  return {
    { from = 0, to = 1, delay = 0 },
    { from = 1, to = 2, delay = 1.5 },
  }
end

TestPlayback = {}

function TestPlayback:setUp()
  _captured = {
    moves = {}, modifiers = {}, durations = {},
    publish = {}, schedules = {}, sounds = {},
    stops = {}, clears = {}, panel = {},
    built = nil, total_time = 5.0,
  }
  _captured.modifier = {
    set_remain_duration = function(duration)
      _captured.durations[#_captured.durations + 1] = duration
    end,
  }
  playback.step_duration = function()
    return 1.0
  end
  seq_builder.calc_step_vector = function(_, from_index, to_index)
    return "dir_" .. from_index .. "_" .. to_index, nil
  end
  seq_builder.resolve_direction = function()
    return true
  end
  seq_builder.build_steps = function(scene, from_index, to_index, visited, anim_ctx, step_duration)
    _captured.built = {
      scene = scene, from_index = from_index, to_index = to_index,
      visited = visited, anim_ctx = anim_ctx, step_duration = step_duration,
    }
    return _steps(), _captured.total_time
  end
  seq_builder.publish_follow_target = function(anim_ctx, player_id, pos, kind)
    _captured.publish[#_captured.publish + 1] = { anim_ctx = anim_ctx, player_id = player_id, pos = pos, kind = kind }
  end
  stop.stop_player_presentation = function(player_id, unit, opts)
    _captured.stops[#_captured.stops + 1] = { player_id = player_id, unit = unit, opts = opts }
    return { motion_stop_path = "motion", anim_stop_path = "anim" }
  end
  stop.clear_player_token = function(board_scene, player_id, reason)
    _captured.clears[#_captured.clears + 1] = { board_scene = board_scene, player_id = player_id, reason = reason }
  end
  debug_mod.enabled = function()
    return false
  end
  board_feedback.play_step_tile_sound = function(state, player_id, to_index)
    _captured.sounds[#_captured.sounds + 1] = { state = state, player_id = player_id, to_index = to_index }
  end
  runtime_ports.schedule = function(delay, callback)
    _captured.schedules[#_captured.schedules + 1] = { delay = delay, callback = callback }
  end
  -- 直接补丁真实模块表上的 begin_move/end_move 并透传原行为:playback 的
  -- _panel_interrupt_module 首载即缓存,进程内早于本 spec 的调用方可能已
  -- 把真实模块缓存住——package.loaded 换桩会被绕开,同表补丁则无论缓存
  -- 与否都生效,且后续调用方仍拿到真实效果。
  panel_interrupt.begin_move = function(state)
    _captured.panel[#_captured.panel + 1] = { name = "begin", state = state }
    _saved_begin_move(state)
  end
  panel_interrupt.end_move = function(state)
    _captured.panel[#_captured.panel + 1] = { name = "end", state = state }
    _saved_end_move(state)
  end
end

function TestPlayback:tearDown()
  playback.step_duration = _saved_step_duration
  seq_builder.calc_step_vector = _saved_calc_step_vector
  seq_builder.resolve_direction = _saved_resolve_direction
  seq_builder.build_steps = _saved_build_steps
  seq_builder.publish_follow_target = _saved_publish_follow_target
  stop.stop_player_presentation = _saved_stop_presentation
  stop.clear_player_token = _saved_clear_token
  debug_mod.enabled = _saved_enabled
  board_feedback.play_step_tile_sound = _saved_play_step_sound
  runtime_ports.schedule = _saved_schedule
  panel_interrupt.begin_move = _saved_begin_move
  panel_interrupt.end_move = _saved_end_move
end

function TestPlayback:test_one_step_moves_unit_and_publishes_follow_target()
  -- 单步主契约:start_move_by_direction(方向, 步时)直调、follow target 发布、
  -- 返回值即步时。L54/L55 调用换 nil 与 L56 return time 换 nil 在此击杀。
  local scene = _scene()
  local anim_ctx = _anim_ctx()
  local result = playback.one_step(scene, 1, 0, 2, anim_ctx)
  _assert_eq(result, 1.0, "one step must return the step time")
  _assert_eq(#_captured.moves, 1, "unit must move once")
  _assert_eq(_captured.moves[1].direction, "dir_0_2", "direction must come from calc_step_vector")
  _assert_eq(_captured.moves[1].time, 1.0, "move time must be the step duration")
  _assert_eq(#_captured.publish, 1, "follow target must be published")
  _assert_eq(_captured.publish[1].player_id, 1, "follow target player")
  _assert_eq(_captured.publish[1].pos, "pos_2", "follow target position")
  _assert_eq(_captured.publish[1].kind, "move_anim_step", "follow target kind")
end

function TestPlayback:test_one_step_returns_zero_without_moving_for_zero_time()
  -- L41 `time <= 0` 的 <= -> <:步时 0 时必须直接返回 0,不落任何移动。
  local scene = _scene()
  playback.step_duration = function()
    return 0
  end
  local result = playback.one_step(scene, 1, 0, 2, _anim_ctx())
  _assert_eq(result, 0, "zero step time must yield zero")
  _assert_eq(#_captured.moves, 0, "zero step time must not move")
end

function TestPlayback:test_one_step_runs_on_step_lock_unlock_pair()
  -- L44 `type(anim_ctx.on_step_lock) == "function"` 的 == -> ~= 与 L46/L47
  -- 调用换 nil:on_step_lock 必须(false, 步时, meta)先落、经 schedule 后
  -- (true, 步时, meta)补上,meta 带 player/from/to。
  local scene = _scene()
  local locks = {}
  local anim_ctx = _anim_ctx()
  anim_ctx.on_step_lock = function(locked, time, meta)
    locks[#locks + 1] = { locked = locked, time = time, meta = meta }
  end
  local result = playback.one_step(scene, 1, 0, 2, anim_ctx)
  _assert_eq(result, 1.0, "locked step must still return the step time")
  _assert_eq(#locks, 1, "lock must be taken immediately")
  _assert_eq(locks[1].locked, false, "lock state must be false first")
  _assert_eq(locks[1].time, 1.0, "lock duration must be the step time")
  _assert_eq(locks[1].meta.player_id, 1, "lock meta player")
  _assert_eq(locks[1].meta.from, 0, "lock meta from")
  _assert_eq(locks[1].meta.to, 2, "lock meta to")
  _assert_eq(#_captured.schedules, 1, "unlock must be scheduled")
  _captured.schedules[1].callback()
  _assert_eq(#locks, 2, "unlock must fire via schedule")
  _assert_eq(locks[2].locked, true, "lock state must be true after unlock")
end

function TestPlayback:test_play_sequence_schedules_and_executes_steps()
  -- 编排主契约:build_steps 实参全量透传、速度加成(total+tail padding)、
  -- token/sequence 登记、panel 开场、delay 0 步即时执行、delay>0 步与停表
  -- 分别入调度、返回总时长。L245 step_duration 透传、L248 token 链、
  -- L251 调度链、L258 停表链的变异在此击杀。
  local scene = _scene()
  local anim_ctx = _anim_ctx()
  local result = playback.play_sequence(scene, anim_ctx, nil)
  _assert_eq(result, 5.0, "play_sequence must return the total time")
  _assert_eq(_captured.built.from_index, 0, "build_steps must receive from_index")
  _assert_eq(_captured.built.to_index, 2, "build_steps must receive to_index")
  _assert_eq(_captured.built.anim_ctx, anim_ctx, "build_steps must receive the anim context")
  _assert_eq(_captured.built.step_duration, playback.step_duration, "build_steps must receive the step duration")
  _assert_eq(#_captured.modifiers, 1, "speed boost modifier must be applied")
  _assert_eq(_captured.modifiers[1].key, runtime_constants.speed_boost_modifier_key, "boost modifier key")
  _assert_eq(_captured.durations[1], 5.0 + timing.move_anim_tail_padding_seconds,
    "boost duration must be total plus tail padding")
  _assert_eq(rt.token_matches(scene, 1, "1:7"), true, "active token must be registered")
  local entry = rt.get_active_sequence(scene, 1)
  _assert_eq(entry.seq, 7, "active sequence must carry the seq")
  _assert_eq(entry.total_time, 5.0, "active sequence must carry the total time")
  _assert_eq(#_captured.panel, 1, "panel begin must be called")
  _assert_eq(_captured.panel[1].name, "begin", "panel begin first")
  _assert_eq(#_captured.moves, 1, "zero-delay step must execute immediately")
  _assert_eq(#_captured.sounds, 1, "zero-delay step must play its sound")
  _assert_eq(#_captured.schedules, 2, "delayed step and stop must be scheduled")
  _assert_eq(_captured.schedules[1].delay, 1.5, "delayed step schedule delay")
  _assert_eq(_captured.schedules[2].delay, 5.0, "stop schedule delay must be the total time")
end

function TestPlayback:test_play_sequence_skips_boost_token_and_panel_for_zero_total()
  -- L110/L115 `total_time <= 0` 的 <= -> <:总时长 0 时不得加成才、不得登记
  -- token、不得开 panel。
  local scene = _scene()
  _captured.total_time = 0
  local result = playback.play_sequence(scene, _anim_ctx(), nil)
  _assert_eq(result, 0, "zero total must return zero")
  _assert_eq(#_captured.modifiers, 0, "zero total must not apply the boost")
  _assert_eq(rt.get_active_sequence(scene, 1), nil, "zero total must not register a sequence")
  _assert_eq(#_captured.panel, 0, "zero total must not open the panel")
end

function TestPlayback:test_play_sequence_applies_boost_when_total_time_is_one()
  -- L110 `total_time <= 0` 的 0 -> 1(变异体把总时长 1 误判为无需加成):
  -- 总时长 1 时加成必须照常应用。
  local scene = _scene()
  _captured.total_time = 1.0
  local result = playback.play_sequence(scene, _anim_ctx(), nil)
  _assert_eq(result, 1.0, "total one must pass through")
  _assert_eq(#_captured.modifiers, 1, "total one must still apply the boost")
end

function TestPlayback:test_play_sequence_without_anim_state_skips_sound_and_panel()
  -- L83/L201/L212 的 `and` -> `or`(变异体在 anim_ctx.state 缺失时放行):
  -- 无 state 的 anim 不得发声、不得开收 panel。
  local scene = _scene()
  local anim_ctx = _anim_ctx()
  anim_ctx.state = nil
  playback.play_sequence(scene, anim_ctx, nil)
  _assert_eq(#_captured.sounds, 0, "anim without state must not play a sound")
  _assert_eq(#_captured.panel, 0, "anim without state must not open the panel")
  _captured.schedules[2].callback()
  _assert_eq(#_captured.panel, 0, "anim without state must not close the panel either")
end

function TestPlayback:test_play_sequence_skips_duration_when_modifier_missing()
  -- L104 `modifier and modifier.set_remain_duration` 的 and -> or(变异体对
  -- nil modifier 撞索引):add_modifier_by_key 返回 nil 时必须跳过时长设置。
  local scene = _scene()
  _captured.modifier = nil
  local result = playback.play_sequence(scene, _anim_ctx(), nil)
  _assert_eq(result, 5.0, "sequence must still run without a modifier")
  _assert_eq(#_captured.durations, 0, "missing modifier must not set a duration")
end

function TestPlayback:test_play_sequence_skips_modifier_when_unit_lacks_method()
  -- L102 `not (unit and unit.add_modifier_by_key)` 的 and -> or:单位缺加成
  -- 方法时必须跳过,不能撞 nil 调用。
  local scene = _scene(false)
  local result = playback.play_sequence(scene, _anim_ctx(), nil)
  _assert_eq(result, 5.0, "sequence must still run without a boost method")
  _assert_eq(#_captured.modifiers, 0, "unit without method must not be boosted")
end

function TestPlayback:test_play_sequence_skips_stale_token_step()
  -- L196 `ctx.token ~= nil and not rt.token_matches(...)` 的 not 删除(变异体
  -- 对过期 token 继续执行):延时步触发前 token 已换,该步必须跳过,
  -- 不移动、不发声。
  local scene = _scene()
  local anim_ctx = _anim_ctx()
  playback.play_sequence(scene, anim_ctx, nil)
  rt.set_active_token(scene, 1, "stale_override")
  _captured.schedules[1].callback()
  _assert_eq(#_captured.moves, 1, "stale step must not move")
  _assert_eq(#_captured.sounds, 1, "stale step must not play its sound")
end

function TestPlayback:test_play_sequence_stop_closure_releases_and_clears()
  -- 收尾主契约:停表触发时 stop_player_presentation(玩家, 单位, 合成AI停止
  -- 选项)直调、sequence 锁释放、token 清除、panel 收场。
  local scene = _scene()
  local anim_ctx = _anim_ctx()
  playback.play_sequence(scene, anim_ctx, nil)
  _captured.schedules[2].callback()
  _assert_eq(#_captured.stops, 1, "stop must be called once")
  _assert_eq(_captured.stops[1].player_id, 1, "stop player")
  _assert_eq(_captured.stops[1].unit, scene.units_by_player_id[1], "stop unit")
  _assert_eq(_captured.stops[1].opts.stop_synthetic_ai, true, "stop must carry the synthetic-ai option")
  _assert_eq(rt.get_active_sequence(scene, 1).lock_released, true, "sequence lock must be released")
  _assert_eq(#_captured.clears, 1, "player token must be cleared")
  _assert_eq(_captured.clears[1].reason, "sequence_finished", "clear reason")
  _assert_eq(#_captured.panel, 2, "panel end must be called after begin")
  _assert_eq(_captured.panel[2].name, "end", "panel end last")
end

function TestPlayback:test_play_sequence_stop_closure_skips_when_token_stale()
  -- L89 `_should_skip_stop_active_sequence(...)` 调用换 nil(变异体对过期
  -- token 仍走收尾):token 已换时停表必须整体跳过,不收尾、不清 token。
  local scene = _scene()
  local anim_ctx = _anim_ctx()
  playback.play_sequence(scene, anim_ctx, nil)
  rt.set_active_token(scene, 1, "stale_override")
  _captured.schedules[2].callback()
  _assert_eq(#_captured.stops, 0, "stale token must not stop")
  _assert_eq(#_captured.clears, 0, "stale token must not clear")
  _assert_eq(rt.get_active_sequence(scene, 1).lock_released, false, "stale token must not release the lock")
end

return TestPlayback
