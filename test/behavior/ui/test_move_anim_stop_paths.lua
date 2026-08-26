local move_anim = require("src.ui.render.move_anim")
local stop = require("src.ui.render.move_anim.stop")
local rt = require("src.ui.render.move_anim.runtime")
local debug_alias = require("src.ui.render.move_anim.debug")
local seq_builder = require("src.ui.render.move_anim.sequence_builder")
local support = require("test.support.move_anim_support")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

-- A unit that exposes only the host methods named in `methods`, so each stop
-- path can be driven in isolation.
local function _unit_with(methods)
  local calls = {}
  local unit = {}
  for _, name in ipairs(methods) do
    unit[name] = function(...)
      calls[#calls + 1] = { name = name, args = { ... } }
    end
  end
  return unit, calls
end

local function _presentation(unit, opts)
  return stop.stop_player_presentation(1, unit, opts)
end

-- with_patches swallows the callback's return value, so the result travels out
-- through an upvalue.
local function _presentation_as(synthetic, unit, opts)
  local result
  _with_patches({
    { target = seq_builder, key = "is_synthetic_actor", value = function() return synthetic end },
  }, function()
    result = _presentation(unit, opts)
  end)
  return result
end

local function _scene_with_active_sequence(entry)
  local scene = support.new_scene_with_linear_tiles(2)
  rt.set_active_token(scene, 1, "token_1")
  rt.set_active_sequence(scene, 1, entry)
  return scene
end

TestMoveAnimStopPaths = {}

function TestMoveAnimStopPaths:test_motion_stop_prefers_stop_move_over_later_fallbacks()
  local unit, calls = _unit_with({ "stop_move", "force_stop_move", "stop_forced_move", "ai_command_stop_move" })
  local result = _presentation(unit)
  _assert_eq(result.motion_stop_path, "stop_move", "stop_move should win when the unit exposes it")
  _assert_eq(#calls, 1, "only the first matching motion stop should run")
  _assert_eq(calls[1].name, "stop_move", "stop_move should be the method invoked")
end

function TestMoveAnimStopPaths:test_motion_stop_falls_back_to_force_stop_move()
  local unit, calls = _unit_with({ "force_stop_move", "stop_forced_move", "ai_command_stop_move" })
  local result = _presentation(unit)
  _assert_eq(result.motion_stop_path, "force_stop_move", "force_stop_move should be used without stop_move")
  _assert_eq(calls[1].name, "force_stop_move", "force_stop_move should be the method invoked")
  _assert_eq(#calls, 1, "fallback should stop after the first match")
end

function TestMoveAnimStopPaths:test_motion_stop_falls_back_to_stop_forced_move()
  local unit, calls = _unit_with({ "stop_forced_move", "ai_command_stop_move" })
  local result = _presentation(unit)
  _assert_eq(result.motion_stop_path, "stop_forced_move", "stop_forced_move should be used as the third choice")
  _assert_eq(calls[1].name, "stop_forced_move", "stop_forced_move should be the method invoked")
end

function TestMoveAnimStopPaths:test_motion_stop_falls_back_to_ai_command_stop_move_with_zero_time()
  local unit, calls = _unit_with({ "ai_command_stop_move" })
  local result = _presentation(unit)
  _assert_eq(result.motion_stop_path, "ai_command_stop_move", "ai stop should be the last motion fallback")
  _assert_eq(calls[1].name, "ai_command_stop_move", "ai_command_stop_move should be the method invoked")
  _assert_eq(calls[1].args[1], 0, "ai stop should be told to stop over zero time")
end

function TestMoveAnimStopPaths:test_motion_stop_path_is_nil_when_unit_exposes_no_stop_method()
  local unit = _unit_with({})
  local result = _presentation(unit)
  _assert_eq(result.motion_stop_path, nil, "a unit with no stop method should report no motion stop path")
  _assert_eq(result.anim_stop_path, nil, "a unit with no anim method should report no anim stop path")
end

function TestMoveAnimStopPaths:test_stop_presentation_tolerates_a_missing_unit()
  local result = _presentation(nil)
  _assert_eq(result.motion_stop_path, nil, "missing unit should report no motion stop path")
  _assert_eq(result.anim_stop_path, nil, "missing unit should report no anim stop path")
  _assert_eq(result.ai_stop_path, nil, "missing unit should report no ai stop path")
end

function TestMoveAnimStopPaths:test_anim_stop_runs_every_exposed_method_and_joins_the_path()
  local unit, calls = _unit_with({
    "interrupt_multi_animation",
    "stop_anim",
    "stop_play_body_anim",
    "stop_play_upper_anim",
    "model_stop_animation",
  })
  local result = _presentation(unit)
  _assert_eq(result.anim_stop_path,
    "interrupt_multi_animation+stop_anim+stop_play_body_anim+stop_play_upper_anim+model_stop_animation",
    "anim stop should run every exposed method and record them in order")
  _assert_eq(#calls, 5, "every exposed anim stop method should be invoked")
end

function TestMoveAnimStopPaths:test_anim_stop_path_names_only_the_methods_the_unit_exposes()
  local unit, calls = _unit_with({ "stop_anim", "model_stop_animation" })
  local result = _presentation(unit)
  _assert_eq(result.anim_stop_path, "stop_anim+model_stop_animation",
    "anim stop path should skip methods the unit does not expose")
  _assert_eq(#calls, 2, "only exposed anim stop methods should be invoked")
end

function TestMoveAnimStopPaths:test_anim_stop_path_is_the_bare_method_name_for_a_single_match()
  local unit = _unit_with({ "stop_play_body_anim" })
  local result = _presentation(unit)
  _assert_eq(result.anim_stop_path, "stop_play_body_anim",
    "a single anim stop should not be prefixed with a separator")
end

function TestMoveAnimStopPaths:test_synthetic_ai_stop_runs_only_for_a_synthetic_actor()
  local unit = _unit_with({ "stop_move", "ai_command_stop_move" })
  local result = _presentation_as(true, unit, { stop_synthetic_ai = true })
  _assert_eq(result.synthetic_actor, true, "synthetic actor should be reported")
  _assert_eq(result.ai_stop_path, "ai_command_stop_move", "synthetic actor should also get the ai stop")
  _assert_eq(result.motion_stop_path, "stop_move", "motion stop should still take the preferred path")
end

function TestMoveAnimStopPaths:test_synthetic_ai_stop_is_skipped_for_a_human_actor()
  local unit = _unit_with({ "stop_move", "ai_command_stop_move" })
  local result = _presentation_as(false, unit, { stop_synthetic_ai = true })
  _assert_eq(result.synthetic_actor, false, "human actor should not be reported as synthetic")
  _assert_eq(result.ai_stop_path, nil, "human actor should not get the synthetic ai stop")
end

function TestMoveAnimStopPaths:test_synthetic_ai_stop_is_skipped_when_the_caller_does_not_ask_for_it()
  local unit = _unit_with({ "ai_command_stop_move" })
  local result = _presentation_as(true, unit, {})
  _assert_eq(result.ai_stop_path, nil, "opting out should skip the synthetic ai stop")
  _assert_eq(result.motion_stop_path, "ai_command_stop_move",
    "the plain motion fallback should still reach ai_command_stop_move")
end

function TestMoveAnimStopPaths:test_synthetic_ai_stop_is_nil_when_the_unit_has_no_ai_command()
  local unit = _unit_with({ "stop_move" })
  local result = _presentation_as(true, unit, { stop_synthetic_ai = true })
  _assert_eq(result.ai_stop_path, nil, "a unit without ai_command_stop_move should report no ai stop path")
end

function TestMoveAnimStopPaths:test_clearing_releases_the_sequence_lock_with_the_given_reason()
  local released = {}
  local scene = _scene_with_active_sequence({
    token = "token_1",
    player_id = 1,
    seq = 7,
    total_time = 1.0,
    lock_released = false,
    anim_ctx = {
      on_sequence_lock = function(enabled, _, meta)
        released[#released + 1] = tostring(enabled) .. ":" .. tostring(meta and meta.reason)
      end,
    },
  })

  stop.clear_player_token(scene, 1, "teleport")

  _assert_eq(released[1], "true:teleport", "clearing should relock the sequence with the caller's reason")
  _assert_eq(rt.get_active_sequence(scene, 1), nil, "clearing should drop the active sequence")
  _assert_eq(stop.has_active_stop_context(scene, 1), false, "clearing should leave no stop context")
end

function TestMoveAnimStopPaths:test_clearing_defaults_the_release_reason()
  local released = {}
  local scene = _scene_with_active_sequence({
    token = "token_1",
    player_id = 1,
    lock_released = false,
    anim_ctx = {
      on_sequence_lock = function(_, _, meta)
        released[#released + 1] = tostring(meta and meta.reason)
      end,
    },
  })

  stop.clear_player_token(scene, 1)

  _assert_eq(released[1], "clear_player_token", "a missing reason should fall back to clear_player_token")
end

function TestMoveAnimStopPaths:test_clearing_an_idle_player_is_a_no_op()
  local scene = support.new_scene_with_linear_tiles(2)
  stop.clear_player_token(scene, 1, "teleport")
  _assert_eq(stop.has_active_stop_context(scene, 1), false, "an idle player should stay idle")
end

function TestMoveAnimStopPaths:test_clearing_without_a_scene_or_player_is_a_no_op()
  stop.clear_player_token(nil, 1, "teleport")
  stop.clear_player_token(support.new_scene_with_linear_tiles(2), nil, "teleport")
  _assert_eq(stop.has_active_stop_context(nil, 1), false, "a missing scene should report no stop context")
  _assert_eq(stop.has_active_stop_context(support.new_scene_with_linear_tiles(2), nil), false,
    "a missing player should report no stop context")
end

function TestMoveAnimStopPaths:test_clearing_logs_the_dropped_token_when_debug_is_enabled()
  local logged = {}
  local scene = _scene_with_active_sequence(nil)
  _with_patches({
    { target = debug_alias, key = "enabled", value = function() return true end },
    { target = debug_alias, key = "debug_log", value = function(tag, ...)
      logged[#logged + 1] = { tag = tag, fields = { ... } }
    end },
  }, function()
    stop.clear_player_token(scene, 1, "teleport")
  end)

  _assert_eq(#logged, 1, "debug mode should log exactly one clear_token line")
  _assert_eq(logged[1].tag, "clear_token", "the log line should be tagged clear_token")
  _assert_eq(logged[1].fields[2], "reason=teleport", "the log line should carry the clear reason")
  _assert_eq(logged[1].fields[3], "token=token_1", "the log line should carry the dropped token")
end

function TestMoveAnimStopPaths:test_clearing_logs_placeholder_fields_when_reason_is_missing()
  local logged = {}
  local scene = support.new_scene_with_linear_tiles(2)
  rt.set_active_sequence(scene, 1, { player_id = 1, lock_released = true })
  _with_patches({
    { target = debug_alias, key = "enabled", value = function() return true end },
    { target = debug_alias, key = "debug_log", value = function(tag, ...)
      logged[#logged + 1] = { tag = tag, fields = { ... } }
    end },
  }, function()
    stop.clear_player_token(scene, 1)
  end)

  _assert_eq(logged[1].fields[2], "reason=none",
    "a missing reason should be logged as none, unlike the lock-release default")
  _assert_eq(logged[1].fields[3], "token=nil", "a missing token should be logged as nil")
end

function TestMoveAnimStopPaths:test_preparing_for_a_snap_clears_the_token_and_stops_the_unit()
  local unit, calls = _unit_with({ "stop_move", "stop_anim" })
  local scene = support.new_scene_with_linear_tiles(2, { units_by_player_id = { [1] = unit } })
  rt.set_active_token(scene, 1, "token_1")

  local result = move_anim.prepare_player_for_snap(scene, 1, nil, "teleport")

  _assert_eq(result.motion_stop_path, "stop_move", "snap prep should stop the unit's motion")
  _assert_eq(result.anim_stop_path, "stop_anim", "snap prep should stop the unit's anim")
  _assert_eq(calls[1].name, "stop_move", "snap prep should invoke the host stop method")
  _assert_eq(stop.has_active_stop_context(scene, 1), false, "snap prep should clear the active token")
end

function TestMoveAnimStopPaths:test_preparing_for_a_snap_defaults_the_clear_reason_to_teleport()
  local released = {}
  local scene = support.new_scene_with_linear_tiles(2)
  rt.set_active_sequence(scene, 1, {
    player_id = 1,
    lock_released = false,
    anim_ctx = {
      on_sequence_lock = function(_, _, meta)
        released[#released + 1] = tostring(meta and meta.reason)
      end,
    },
  })

  move_anim.prepare_player_for_snap(scene, 1, nil, nil)

  _assert_eq(released[1], "teleport", "snap prep without a reason should release the lock as teleport")
end

function TestMoveAnimStopPaths:test_preparing_for_a_snap_without_a_unit_reports_no_stop_paths()
  local scene = support.new_scene_with_linear_tiles(2)
  local result = move_anim.prepare_player_for_snap(scene, 1, nil, "teleport")
  _assert_eq(result.motion_stop_path, nil, "a player without a unit should report no motion stop path")
end

function TestMoveAnimStopPaths:test_re_setting_the_same_sequence_keeps_the_lock()
  -- kills set_active_sequence 的 `previous ~= nil and previous ~= entry`
  -- and->or:同一 entry 重复设置不得释放既有锁(or 变异体在 previous 非 nil
  -- 时无条件走 release 分支)。
  local released = 0
  local scene = support.new_scene_with_linear_tiles(2)
  local entry = {
    player_id = 1,
    anim_ctx = {
      on_sequence_lock = function()
        released = released + 1
      end,
    },
  }
  rt.set_active_sequence(scene, 1, entry)
  rt.set_active_sequence(scene, 1, entry)
  _assert_eq(released, 0, "re-setting the same entry must not release the held lock")
end


return TestMoveAnimStopPaths
