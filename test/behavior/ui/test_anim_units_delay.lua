local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local luax = require("test.support.luax")
local vec3 = require("test.fixtures.vec3")
local units = require("src.ui.render.anim.units")
local timing = require("src.config.gameplay.timing")
local support = require("test.support.ui_action_anim_support")
local _with_patches = support.with_patches
local board_feedback = require("src.ui.render.board_feedback.service")
local unit_overlay = require("src.ui.render.anim.unit_overlay")

local function _reload_with(module_name, overrides, fn)
  local original_module = package.loaded[module_name]
  local originals = {}
  for key, value in pairs(overrides or {}) do
    originals[key] = package.loaded[key]
    package.loaded[key] = value
  end
  package.loaded[module_name] = nil

  local ok, result = pcall(function()
    return fn(require(module_name))
  end)

  package.loaded[module_name] = original_module
  for key, value in pairs(originals) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end

TestAnimUnitsDelay = {}

function TestAnimUnitsDelay:test_clears_overlay_immediately_without_scheduler()
  local cleared = false
  local state = {}
  local anim = { tile_index = 5 }
  local opts = {
    clear_overlay = function(s, kind, idx)
      cleared = true
      _assert_eq(s, state, "should pass state")
      _assert_eq(kind, "roadblock", "should pass roadblock kind")
      _assert_eq(idx, 5, "should pass tile_index")
    end,
  }
  units.play_roadblock_trigger(state, anim, 1.0, opts)
  _assert_eq(cleared, true, "should clear overlay immediately")
end

function TestAnimUnitsDelay:test_schedules_overlay_clear_when_scheduler_provided()
  local scheduled_delay = nil
  local scheduled_fn = nil
  local state = {}
  local anim = { tile_index = 3 }
  local opts = {
    clear_overlay = function() end,
    schedule = function(delay, fn)
      scheduled_delay = delay
      scheduled_fn = fn
    end,
  }
  local hold = timing.roadblock_destroy_hold_seconds
  if hold > 0 then
    units.play_roadblock_trigger(state, anim, 1.0, opts)
    _assert_eq(scheduled_delay, hold, "should schedule with hold_delay")
    _assert_eq(type(scheduled_fn), "function", "should schedule a function")
  else
    units.play_roadblock_trigger(state, anim, 1.0, opts)
    _assert_eq(scheduled_delay, nil, "should not schedule when hold_delay is zero")
  end
end

function TestAnimUnitsDelay:test_returns_minimum_delay_with_scheduler()
  local state = {}
  local anim = { tile_index = 1 }
  local opts = {
    clear_overlay = function() end,
    schedule = function() end,
  }
  local result = units.play_roadblock_trigger(state, anim, 0.5, opts)
  local hold = timing.roadblock_destroy_hold_seconds
  local expected = hold > 0.5 and hold or 0.5
  _assert_eq(result, expected, "should return max of hold_delay and duration")
end

function TestAnimUnitsDelay:test_clamps_negative_duration_to_zero()
  local state = {}
  local anim = { tile_index = 1 }
  local opts = { clear_overlay = function() end }
  local result = units.play_roadblock_trigger(state, anim, -1.0, opts)
  _assert_eq(result, 0, "should clamp negative duration to zero")
end

function TestAnimUnitsDelay:test_clamps_nil_duration_to_zero()
  local state = {}
  local anim = { tile_index = 1 }
  local opts = { clear_overlay = function() end }
  local result = units.play_roadblock_trigger(state, anim, nil, opts)
  _assert_eq(result, 0, "should treat nil duration as zero")
end

function TestAnimUnitsDelay:test_scheduled_mine_trigger_snap_uses_the_anim_duration()
  -- #550:mine_trigger_snap_delay_seconds 退役删除;调度分支不再读 timing 配置,
  -- 销毁雷+瞬移人钉在 anim duration 的回调内。reload 的 timing 覆盖故意缺位该键。
  _reload_with("src.ui.render.anim.units", {
    ["src.config.gameplay.timing"] = {
      demolish_effect_followup_delay_seconds = 0.35,
      teleport_effect_camera_hold_seconds = 1.0,
      roadblock_destroy_hold_seconds = 0,
    },
  }, function(reloaded_units)
    local scheduled_delay = nil
    local cleared = 0
    local snapped = 0
    local state = support.build_min_state()

    _with_patches({
      { target = board_feedback, key = "play_tile_cue", value = function() end },
      { target = board_feedback, key = "play_player_cue", value = function() end },
      { target = require("src.ui.render.move_anim"), key = "prepare_player_for_snap", value = function() end },
      { target = require("src.ui.render.move_anim"), key = "snap_player_to_index", value = function()
        snapped = snapped + 1
        return 0
      end },
    }, function()
      local duration = reloaded_units.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 1,
        to_index = 1,
      }, 0.2, {
        clear_overlay = function()
          cleared = cleared + 1
        end,
        schedule = function(delay, fn)
          scheduled_delay = delay
          fn()
        end,
      })

      _assert_eq(duration, 0.2, "mine trigger should return the anim duration")
    end)

    _assert_eq(scheduled_delay, 0.2, "mine trigger should schedule the snap at the anim duration")
    _assert_eq(snapped, 1, "scheduled callback should snap the player")
    _assert_eq(cleared, 1, "scheduled callback should clear the mine overlay")
  end)
end

function TestAnimUnitsDelay:test_roadblock_destroy_hold_uses_the_configured_nonzero_delay()
  _reload_with("src.ui.render.anim.units", {
    ["src.config.gameplay.timing"] = {
      demolish_effect_followup_delay_seconds = 0.35,
      teleport_effect_camera_hold_seconds = 1.0,
      roadblock_destroy_hold_seconds = 0.4,
    },
  }, function(reloaded_units)
    local scheduled_delay = nil
    local cleared = 0
    local state = support.build_min_state()

    local duration = reloaded_units.play_roadblock_trigger(state, {
      tile_index = 1,
    }, 0.1, {
      clear_overlay = function()
        cleared = cleared + 1
      end,
      schedule = function(delay, fn)
        scheduled_delay = delay
        fn()
      end,
    })

    _assert_eq(duration, 0.4, "roadblock hold should extend shorter duration")
    _assert_eq(scheduled_delay, 0.4, "roadblock hold should preserve configured delay")
    _assert_eq(cleared, 1, "scheduled roadblock clear should run")
  end)
end

function TestAnimUnitsDelay:test_pan_camera_releases_immediately_without_a_scheduler()
  local state = support.build_min_state()
  local pan_calls = 0
  local release_calls = 0
  local overlay_calls = 0

  _with_patches({
    { target = unit_overlay, key = "play_overlay", value = function()
      overlay_calls = overlay_calls + 1
    end },
  }, function()
    units.play_overlay(state, { kind = "roadblock", tile_index = 1 }, 0.4, {
      pan_camera_to_position = function(_, pos)
        pan_calls = pan_calls + 1
        _assert_eq(pos.x, 0.0, "pan should receive resolved tile position")
        return true
      end,
      release_target_pan = function(release_state)
        release_calls = release_calls + 1
        _assert_eq(release_state, state, "release should receive state")
      end,
    })
  end)

  _assert_eq(pan_calls, 1, "roadblock should pan to tile")
  _assert_eq(release_calls, 1, "missing scheduler should release immediately")
  _assert_eq(overlay_calls, 1, "overlay handler should still run")
end

function TestAnimUnitsDelay:test_pan_release_normalizes_an_invalid_scheduled_duration()
  local state = support.build_min_state()
  local scheduled_delay = nil
  local scheduled_fn = nil
  local release_calls = 0

  _with_patches({
    { target = unit_overlay, key = "play_overlay", value = function() end },
  }, function()
    units.play_overlay(state, { kind = "roadblock", tile_index = 1 }, -1, {
      pan_camera_to_position = function()
        return true
      end,
      release_target_pan = function()
        release_calls = release_calls + 1
      end,
      schedule = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
    })
  end)

  _assert_eq(scheduled_delay, 0, "negative release duration should clamp to zero")
  _assert_eq(release_calls, 0, "release should wait for scheduler callback")
  scheduled_fn()
  _assert_eq(release_calls, 1, "scheduled release callback should release pan")
end

function TestAnimUnitsDelay:test_teleport_pans_to_destination_for_at_least_the_hold_duration()
  local state = support.build_min_state({
    mutate = function(target)
      target.board_scene.tiles[2] = {
        get_position = function()
          return math.Vector3(20.0, 0.0, 0.0)
        end,
      }
    end,
  })
  local scheduled_delay = nil
  local played = 0

  _with_patches({
    { target = require("src.ui.render.move_anim"), key = "play_teleport", value = function()
      played = played + 1
      return 0.25
    end },
  }, function()
    local duration = units.play_teleport_effect(state, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
    }, 0.1, {
      pan_camera_to_position = function(_, pos)
        _assert_eq(pos.x, 20.0, "teleport pan should target destination tile")
        return true
      end,
      release_target_pan = function() end,
      schedule = function(delay)
        scheduled_delay = delay
      end,
    })

    _assert_eq(duration, 0.25, "teleport should return move animation duration")
  end)

  _assert_eq(played, 1, "teleport move animation should play")
  _assert_eq(scheduled_delay, 1.0, "teleport pan should hold for configured minimum")
end

function TestAnimUnitsDelay:test_teleport_without_destination_skips_the_camera_pan()
  local state = support.build_min_state()
  local pan_calls = 0

  _with_patches({
    { target = require("src.ui.render.move_anim"), key = "play_teleport", value = function()
      return 0.25
    end },
  }, function()
    units.play_teleport_effect(state, nil, 0.1, {
      pan_camera_to_position = function()
        pan_calls = pan_calls + 1
        return true
      end,
      release_target_pan = function() end,
      schedule = function() end,
    })
    units.play_teleport_effect(state, { player_id = 1, from_index = 1 }, 0.1, {
      pan_camera_to_position = function()
        pan_calls = pan_calls + 1
        return true
      end,
      release_target_pan = function() end,
      schedule = function() end,
    })
  end)

  _assert_eq(pan_calls, 0, "teleport without a destination should not pan")
end

function TestAnimUnitsDelay:test_play_move_effect_returns_sequence_duration()
  -- L112 play_sequence 调用换 nil:返回值必须透传序列时长。
  local state = {
    board_scene = {
      tiles = {
        [1] = { get_position = function() return vec3.with_sub_length(1, 2, 3) end },
        [2] = { get_position = function() return vec3.with_sub_length(1, 2, 3) end },
      },
      units_by_player_id = {
        [1] = {
          start_move_by_direction = function() end,
        },
      },
    },
  }
  local result = units.play_move_effect(state, {
    player_id = 1,
    from_index = 1,
    to_index = 2,
    direction = { x = 0, y = 0, z = 1 },
  })
  _assert_eq(type(result), "number", "play_move_effect should return the sequence duration")
  _assert_eq(result, 0, "zero distance should return zero duration")
end

function TestAnimUnitsDelay:test_pan_skips_when_state_is_missing()
  -- L32 两连(state==nil 守卫的 false->true / or->and):state 缺失时必须整体跳过 pan。
  local scheduled = 0
  local overlay_calls = 0

  _with_patches({
    { target = unit_overlay, key = "play_overlay", value = function()
      overlay_calls = overlay_calls + 1
    end },
  }, function()
    units.play_overlay(nil, { kind = "roadblock", tile_index = 1 }, 0, {
      pan_camera_to_position = function()
        return true
      end,
      release_target_pan = function() end,
      schedule = function()
        scheduled = scheduled + 1
      end,
    })
  end)

  _assert_eq(scheduled, 0, "missing state should skip the pan entirely")
  _assert_eq(overlay_calls, 1, "overlay handler should still run")
end

function TestAnimUnitsDelay:test_pan_skips_when_pan_function_is_missing()
  -- L34 pan_fn 类型守卫的 false->true:缺 pan 函数时必须回退,不能触发 release。
  local state = support.build_min_state()
  local released = 0
  local overlay_calls = 0

  _with_patches({
    { target = unit_overlay, key = "play_overlay", value = function()
      overlay_calls = overlay_calls + 1
    end },
  }, function()
    units.play_overlay(state, { kind = "roadblock", tile_index = 1 }, 0, {
      release_target_pan = function()
        released = released + 1
      end,
    })
  end)

  _assert_eq(released, 0, "missing pan function should not release")
  _assert_eq(overlay_calls, 1, "overlay handler should still run")
end

function TestAnimUnitsDelay:test_only_roadblock_anims_pan_the_camera()
  -- L63 两个 and->or:非 roadblock anim 不得进入 pan 分支。
  local state = support.build_min_state()
  local scheduled = 0
  local overlay_calls = 0

  _with_patches({
    { target = unit_overlay, key = "play_overlay", value = function()
      overlay_calls = overlay_calls + 1
    end },
  }, function()
    units.play_overlay(state, { kind = "mine", tile_index = 1 }, 0, {
      pan_camera_to_position = function()
        return true
      end,
      release_target_pan = function() end,
      schedule = function()
        scheduled = scheduled + 1
      end,
    })
  end)

  _assert_eq(scheduled, 0, "non-roadblock anims should not pan")
  _assert_eq(overlay_calls, 1, "overlay handler should still run")
end

function TestAnimUnitsDelay:test_clear_obstacles_pans_when_tile_index_is_present()
  -- L105 `~=`->`==`:带 tile_index 的清障 anim 必须 pan 到该地块。
  local state = support.build_min_state()
  local scheduled = 0
  local overlay_calls = 0

  _with_patches({
    { target = unit_overlay, key = "play_clear_obstacles", value = function()
      overlay_calls = overlay_calls + 1
    end },
  }, function()
    units.play_clear_obstacles(state, { tile_index = 1 }, 0, {
      pan_camera_to_position = function()
        return true
      end,
      release_target_pan = function() end,
      schedule = function()
        scheduled = scheduled + 1
      end,
    })
  end)

  _assert_eq(scheduled, 1, "clear obstacles should pan to the tile")
  _assert_eq(overlay_calls, 1, "overlay handler should still run")
end

function TestAnimUnitsDelay:test_pan_release_keeps_a_short_positive_duration()
  -- L47 clamp 阈值 0->1:0.5 秒的合法时长必须原样保留。
  local state = support.build_min_state()
  local scheduled_delay = nil

  _with_patches({
    { target = unit_overlay, key = "play_overlay", value = function() end },
  }, function()
    units.play_overlay(state, { kind = "roadblock", tile_index = 1 }, 0.5, {
      pan_camera_to_position = function()
        return true
      end,
      release_target_pan = function() end,
      schedule = function(delay)
        scheduled_delay = delay
      end,
    })
  end)

  _assert_eq(scheduled_delay, 0.5, "a short positive release duration should be preserved")
end

function TestAnimUnitsDelay:test_teleport_pan_keeps_an_extended_numeric_hold()
  -- L120 两连(not 删除 / is_numeric->nil):数值时长超过 hold 下限时必须保留原值。
  local state = support.build_min_state({
    mutate = function(target)
      target.board_scene.tiles[2] = {
        get_position = function()
          return math.Vector3(20.0, 0.0, 0.0)
        end,
      }
    end,
  })
  local scheduled_delay = nil

  _with_patches({
    { target = require("src.ui.render.move_anim"), key = "play_teleport", value = function()
      return 0.25
    end },
  }, function()
    units.play_teleport_effect(state, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
    }, 2.0, {
      pan_camera_to_position = function()
        return true
      end,
      release_target_pan = function() end,
      schedule = function(delay)
        scheduled_delay = delay
      end,
    })
  end)

  _assert_eq(scheduled_delay, 2.0, "an extended numeric hold should be preserved")
end

function TestAnimUnitsDelay:test_mine_trigger_hit_position_prefers_the_player_unit_position()
  -- L150 两连(and->or / or->and):命中位置必须优先取自玩家单位,而非地块兜底。
  local state = support.build_min_state({
    mutate = function(target)
      target.board_scene.units_by_player_id[1] = {
        get_position = function()
          return math.Vector3(7.0, 0.0, 0.0)
        end,
      }
    end,
  })
  local cue_pos = nil

  _with_patches({
    { target = board_feedback, key = "play_player_cue", value = function(_, _, _, payload)
      cue_pos = payload.pos
    end },
    { target = board_feedback, key = "play_tile_cue", value = function() end },
    { target = require("src.ui.render.move_anim"), key = "prepare_player_for_snap", value = function() end },
    { target = require("src.ui.render.move_anim"), key = "snap_player_to_index", value = function()
      return 0
    end },
  }, function()
    units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 1,
      to_index = 1,
    }, 0.2, {
      clear_overlay = function() end,
      schedule = function() end,
    })
  end)

  _assert_eq(cue_pos.x, 7.0, "hit position should come from the player unit")
end

function TestAnimUnitsDelay:test_mine_trigger_scheduled_snap_carries_mine_trigger_reason()
  -- L188 prepare 的 "mine_trigger" 标签换 nil:计划快照必须携带 mine_trigger 原因。
  local state = support.build_min_state()
  local prepare_reason = nil
  local scheduled_fn = nil

  _with_patches({
    { target = board_feedback, key = "play_player_cue", value = function() end },
    { target = board_feedback, key = "play_tile_cue", value = function() end },
    { target = require("src.ui.render.move_anim"), key = "prepare_player_for_snap", value = function(_, _, _, reason)
      prepare_reason = reason
    end },
    { target = require("src.ui.render.move_anim"), key = "snap_player_to_index", value = function()
      return 0
    end },
  }, function()
    units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 1,
      to_index = 1,
    }, 0.2, {
      clear_overlay = function() end,
      schedule = function(_, fn)
        scheduled_fn = fn
      end,
    })
    scheduled_fn()
  end)

  _assert_eq(prepare_reason, "mine_trigger", "scheduled snap prepare should carry the mine_trigger reason")
end

function TestAnimUnitsDelay:test_mine_trigger_fallback_snap_carries_mine_trigger_reasons()
  -- L209 prepare 与 L212 snap 的标签换 nil:无调度器兜底路径必须携带原因参数。
  local state = support.build_min_state()
  local prepare_reason = nil
  local snap_reason = nil

  _with_patches({
    { target = board_feedback, key = "play_player_cue", value = function() end },
    { target = board_feedback, key = "play_tile_cue", value = function() end },
    { target = require("src.ui.render.move_anim"), key = "prepare_player_for_snap", value = function(_, _, _, reason)
      prepare_reason = reason
    end },
    { target = require("src.ui.render.move_anim"), key = "snap_player_to_index", value = function(_, _, _, _, reason)
      snap_reason = reason
      return 0
    end },
  }, function()
    local duration = units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 1,
      to_index = 1,
    }, 0.2, {
      clear_overlay = function() end,
    })
    _assert_eq(duration, 0.2, "fallback should return the supplied duration")
  end)

  _assert_eq(prepare_reason, "mine_trigger", "fallback prepare should carry the mine_trigger reason")
  _assert_eq(snap_reason, "play_sequence_mine_trigger", "fallback snap should carry the play_sequence_mine_trigger reason")
end

function TestAnimUnitsDelay:test_monster_feedback_plays_both_cues_immediately_without_scheduler()
  -- L176/L177 两连(烟效名换 nil / use_building_tile_position 的 == 与 true 变异):
  -- 无调度器时怪兽反馈必须立即依次播爆炸与烟效,且用建筑地块位置。
  local state = support.build_min_state()
  local calls = {}

  _with_patches({
    { target = board_feedback, key = "play_tile_cue", value = function(_, cue_name, _, payload)
      calls[#calls + 1] = { name = cue_name, opts = payload }
    end },
  }, function()
    units.play_monster(state, { tile_index = 1 }, 0, {})
  end)

  _assert_eq(#calls, 2, "monster feedback should play blast then smoke")
  _assert_eq(calls[1].name, "mine_blast", "blast cue should come first")
  _assert_eq(calls[2].name, "upgrade_land_smoke", "smoke cue should follow immediately")
  _assert_eq(calls[2].opts.use_building_tile_position, true, "monster feedback should use building tile position")
end

function TestAnimUnitsDelay:test_missile_asserts_on_missing_board_scene()
  -- L86 两连(assert 调用换 nil / 消息换 nil):缺 board_scene 必须钉死报错。
  luax.has_error(function()
    units.play_missile({}, { tile_index = 1 }, 0, {})
  end, "missing board_scene")
end

function TestAnimUnitsDelay:test_missile_asserts_on_missing_tile_index()
  -- L88 消息换 nil:导弹缺 tile_index 必须钉死报错。
  local state = support.build_min_state()
  luax.has_error(function()
    units.play_missile(state, { to_index = 1 }, 0, {})
  end, "missing missile tile_index")
end

function TestAnimUnitsDelay:test_monster_asserts_on_missing_tile_index()
  -- L99 消息换 nil:怪兽缺 tile_index 必须钉死报错。
  local state = support.build_min_state()
  luax.has_error(function()
    units.play_monster(state, {}, 0, {})
  end, "missing monster tile_index")
end

function TestAnimUnitsDelay:test_mine_trigger_asserts_on_missing_fields()
  -- L194-L197 与 L182 消息换 nil:字段缺失必须逐条钉死报错。
  local state = support.build_min_state()

  luax.has_error(function()
    units.play_mine_trigger({}, { player_id = 1, tile_index = 1, to_index = 1 }, 0.1, {
      clear_overlay = function() end,
    })
  end, "missing board_scene")

  luax.has_error(function()
    units.play_mine_trigger(state, { tile_index = 1, to_index = 1 }, 0.1, {})
  end, "missing player_id")

  luax.has_error(function()
    units.play_mine_trigger(state, { player_id = 1, to_index = 1 }, 0.1, {})
  end, "missing tile_index")

  luax.has_error(function()
    units.play_mine_trigger(state, { player_id = 1, tile_index = 1 }, 0.1, {})
  end, "missing to_index")

  _with_patches({
    { target = board_feedback, key = "play_player_cue", value = function() end },
    { target = board_feedback, key = "play_tile_cue", value = function() end },
    { target = require("src.ui.render.move_anim"), key = "prepare_player_for_snap", value = function() end },
    { target = require("src.ui.render.move_anim"), key = "snap_player_to_index", value = function() end },
  }, function()
    luax.has_error(function()
      units.play_mine_trigger(state, { player_id = 1, tile_index = 1, to_index = 1 }, 0.1, {})
    end, "missing clear_overlay")
  end)
end

function TestAnimUnitsDelay:test_roadblock_trigger_asserts_on_missing_fields()
  -- L221/L222 消息换 nil:缺 clear_overlay / tile_index 必须钉死报错。
  luax.has_error(function()
    units.play_roadblock_trigger({}, { tile_index = 1 }, 0.1, {})
  end, "missing clear_overlay")

  luax.has_error(function()
    units.play_roadblock_trigger({}, {}, 0.1, { clear_overlay = function() end })
  end, "missing tile_index")
end

function TestAnimUnitsDelay:test_zero_roadblock_hold_clears_immediately()
  -- L224 `>`->`>=`:hold 恰为 0 时不得走调度分支。
  _reload_with("src.ui.render.anim.units", {
    ["src.config.gameplay.timing"] = {
      demolish_effect_followup_delay_seconds = 0.35,
      teleport_effect_camera_hold_seconds = 1.0,
      roadblock_destroy_hold_seconds = 0,
    },
  }, function(reloaded_units)
    local scheduled = 0
    local cleared = 0
    local state = {}

    reloaded_units.play_roadblock_trigger(state, { tile_index = 1 }, 0.1, {
      clear_overlay = function()
        cleared = cleared + 1
      end,
      schedule = function()
        scheduled = scheduled + 1
      end,
    })

    _assert_eq(scheduled, 0, "zero hold should not schedule")
    _assert_eq(cleared, 1, "zero hold should clear immediately")
  end)
end

function TestAnimUnitsDelay:test_zero_demolish_followup_plays_smoke_immediately()
  -- L168 `>`->`>=`:followup 恰为 0 时不得走调度分支,烟效必须立即播。
  _reload_with("src.ui.render.anim.units", {
    ["src.config.gameplay.timing"] = {
      demolish_effect_followup_delay_seconds = 0,
      teleport_effect_camera_hold_seconds = 1.0,
      roadblock_destroy_hold_seconds = 0.5,
    },
  }, function(reloaded_units)
    local scheduled = 0
    local cue_names = {}
    local state = support.build_min_state()

    _with_patches({
      { target = board_feedback, key = "play_tile_cue", value = function(_, cue_name)
        cue_names[#cue_names + 1] = cue_name
      end },
      { target = unit_overlay, key = "play_missile", value = function() end },
    }, function()
      reloaded_units.play_missile(state, { tile_index = 1 }, 0, {
        schedule = function()
          scheduled = scheduled + 1
        end,
      })
    end)

    _assert_eq(scheduled, 0, "zero followup delay should not schedule")
    _assert_eq(#cue_names, 2, "zero followup delay should play smoke immediately")
    _assert_eq(cue_names[2], "upgrade_land_smoke", "smoke cue should follow the blast cue")
  end)
end


return TestAnimUnitsDelay
