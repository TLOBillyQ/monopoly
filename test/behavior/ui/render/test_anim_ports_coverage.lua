-- anim 装配与动画场景的守卫/回调路径:这些函数在常规流程里由宿主动画
-- 事件驱动(anim_ports.build 的回调、move_anim 场景快照),测试只能从
-- 模块入口直接打,并把动画执行面 patch 掉。
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local anim_ports = require("src.ui.ports.anim")
local render_anim = require("src.ui.render.anim")
local move_anim = require("src.ui.render.move_anim")
local units = require("src.ui.render.anim.units")
local overlay = require("src.ui.render.anim.unit_overlay")
local stop = require("src.ui.render.move_anim.stop")
local debug_mod = require("src.ui.render.move_anim.debug")

TestAnimPortsCoverage = {}

function TestAnimPortsCoverage:test_play_move_anim_attaches_ctx_and_runs_sequence()
  _with_patches({
    { target = move_anim, key = "play_sequence", value = function() return "seq_done" end },
  }, function()
    local ports = anim_ports.build()
    _assert_eq(ports.play_move_anim({ board_scene = {} }, {}), "seq_done",
      "play_move_anim should attach ctx and run the sequence")
    _assert_eq(ports.play_move_anim({ board_scene = {} }, nil), "seq_done",
      "nil anim_ctx should still run the sequence")
  end)
end

function TestAnimPortsCoverage:test_play_action_anim_runs_player_play()
  _with_patches({
    { target = render_anim, key = "play", value = function() return 0.75 end },
  }, function()
    local ports = anim_ports.build()
    _assert_eq(ports.play_action_anim({}, {}), 0.75,
      "play_action_anim should return the player delay")
  end)
end

function TestAnimPortsCoverage:test_play_clear_obstacles_pans_then_runs_overlay()
  local overlay_calls = {}
  _with_patches({
    { target = overlay, key = "play_clear_obstacles", value = function(state, anim, duration, opts)
      overlay_calls[#overlay_calls + 1] = { state, anim, duration, opts }
      return true
    end },
  }, function()
    units.play_clear_obstacles({}, { tile_index = 5 }, 1, {})
    units.play_clear_obstacles({}, {}, 1, {})
  end)
  _assert_eq(#overlay_calls, 2,
    "overlay should run once per clear-obstacle play, after the pan")
  _assert_eq(overlay_calls[1][2].tile_index, 5,
    "first play should forward the anim with a tile_index")
  _assert_eq(overlay_calls[2][2].tile_index, nil,
    "bare anim without tile_index should skip the pan but still reach overlay")
end

function TestAnimPortsCoverage:test_reset_and_sync_status_3d()
  local status3d = require("src.ui.render.status3d")
  local resets = {}
  local syncs = {}
  _with_patches({
    { target = status3d, key = "reset", value = function(state, presentation_runtime)
      resets[#resets + 1] = { state, presentation_runtime }
      return true
    end },
    { target = status3d, key = "sync", value = function(game, state, dirty, presentation_runtime)
      syncs[#syncs + 1] = { game, state, dirty, presentation_runtime }
      return true
    end },
  }, function()
    local ports = anim_ports.build()
    ports.reset_status_3d({})
    ports.sync_status_3d({}, {}, {})
  end)
  _assert_eq(#resets, 1, "reset_status_3d should forward one reset call")
  _assert_eq(#syncs, 1, "sync_status_3d should forward one sync call")
  _assert_eq(resets[1][2], nil,
    "reset should pass presentation_runtime through (absent on a bare state)")
  _assert_eq(syncs[1][4], nil,
    "sync should pass presentation_runtime through (absent on a bare state)")
end

function TestAnimPortsCoverage:test_snap_player_to_index_covers_snap_helpers()
  _with_patches({
    { target = debug_mod, key = "enabled", value = function() return true end },
    { target = debug_mod, key = "debug_log", value = function() end },
  }, function()
    local board_scene = {
      tiles = { [2] = { get_position = function() return { x = 1 } end } },
      units_by_player_id = { p1 = { set_position = function() end } },
    }
    _assert_eq(stop.snap_player_to_index(board_scene, "p1", 2, nil, "my_reason"), 0,
      "snap should return 0 with an explicit reason")
    _assert_eq(stop.snap_player_to_index(board_scene, "p1", 2, nil, nil), 0,
      "snap should fall back to the default reason")
  end)
end

return TestAnimPortsCoverage
