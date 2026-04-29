local move_anim = require("src.ui.render.move_anim")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local board_feedback = require("src.ui.render.board_feedback.service")
local support = require("support.move_anim_support")
local vec3 = require("fixtures.vec3")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _scene_linear(count)
  local scene = { tiles = {}, units_by_player_id = {} }
  for i = 1, count do
    local pos = vec3.with_sub_length((i - 1) * 10, 0, 0)
    scene.tiles[i] = { get_position = function() return pos end }
  end
  return scene
end

local function _scene_with_turn(before, after)
  -- before 格沿 x 轴，after 格沿 y 轴（从最后一格 x 方向延伸）
  local scene = { tiles = {}, units_by_player_id = {} }
  for i = 1, before do
    local pos = vec3.with_sub_length((i - 1) * 10, 0, 0)
    scene.tiles[i] = { get_position = function() return pos end }
  end
  local corner_x = (before - 1) * 10
  for j = 1, after do
    local pos = vec3.with_sub_length(corner_x, j * 10, 0)
    scene.tiles[before + j] = { get_position = function() return pos end }
  end
  return scene
end

-- 3 格共线：应合并成 1 次 start_move_by_direction 调用，3 个音效仍逐格触发
local function _test_collinear_steps_merged_into_single_segment()
  local scene = _scene_linear(4)
  local move_calls = {}
  local sound_calls = {}
  scene.units_by_player_id[1] = {
    start_move_by_direction = function(d, t) move_calls[#move_calls + 1] = { dir = d, time = t } end,
    stop_move = function() end,
    stop_anim = function() end,
  }

  local scheduled = {}
  _with_patches({
    { target = board_feedback, key = "play_step_tile_sound", value = function(_, _, tile_index)
      sound_calls[#sound_calls + 1] = tile_index
    end },
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      state = {},
      player_id = 1, seq = 1,
      from_index = 1, to_index = 4,
      visited = { 2, 3, 4 },
      direction = { x = 1, y = 0, z = 0 },
    })
    -- sort+call 必须在 patch 块内，否则 board_feedback patch 失效
    table.sort(scheduled, function(a, b) return a.delay < b.delay end)
    for _, entry in ipairs(scheduled) do entry.fn() end
  end)

  _assert_eq(#move_calls, 1, "three collinear steps should produce exactly one start_move_by_direction call")
  _assert_eq(#sound_calls, 3, "three anchors should fire step sound for every visited tile")
  _assert_eq(sound_calls[1], 2, "first sound should target tile 2")
  _assert_eq(sound_calls[2], 3, "second sound should target tile 3")
  _assert_eq(sound_calls[3], 4, "third sound should target tile 4")
end

-- 合并 segment 的总 duration 应等于各格时长之和（无拐点倍率）
local function _test_collinear_segment_time_equals_sum_of_step_times()
  local scene = _scene_linear(4)
  local move_calls = {}
  scene.units_by_player_id[1] = {
    start_move_by_direction = function(d, t) move_calls[#move_calls + 1] = { dir = d, time = t } end,
    stop_move = function() end, stop_anim = function() end,
  }

  local scheduled = {}
  _with_patches({
    { target = board_feedback, key = "play_step_tile_sound", value = function() end },
    { target = runtime_ports, key = "schedule", value = function(d, fn)
      scheduled[#scheduled + 1] = { delay = d, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1, seq = 2,
      from_index = 1, to_index = 4,
      visited = { 2, 3, 4 },
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  local expected_per_step = 10 / runtime_constants.walk_speed
  local expected_total = expected_per_step * 3
  local actual_time = move_calls[1] and move_calls[1].time or 0
  assert(math.abs(actual_time - expected_total) < 0.001,
    "merged segment time should equal 3x per-step time, got " .. tostring(actual_time))
end

-- 拐点 segment 的 duration 应被 turn_slow_factor 拉长
local function _test_turn_segment_duration_multiplied_by_turn_slow_factor()
  local scene = _scene_with_turn(2, 1)
  local move_calls = {}
  scene.units_by_player_id[1] = {
    start_move_by_direction = function(d, t) move_calls[#move_calls + 1] = { dir = d, time = t } end,
    stop_move = function() end, stop_anim = function() end,
  }

  local scheduled = {}
  _with_patches({
    { target = board_feedback, key = "play_step_tile_sound", value = function() end },
    { target = runtime_ports, key = "schedule", value = function(d, fn)
      scheduled[#scheduled + 1] = { delay = d, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1, seq = 3,
      from_index = 1, to_index = 3,
      visited = { 2, 3 },
      direction = { x = 1, y = 0, z = 0 },
    })
    table.sort(scheduled, function(a, b) return a.delay < b.delay end)
    for _, entry in ipairs(scheduled) do entry.fn() end
  end)

  -- 2 个 segment：直道段(1→2) + 入弯段(2→3)
  _assert_eq(#move_calls, 2, "straight + turn path should produce two segments")

  local step_time = 10 / runtime_constants.walk_speed
  local factor = runtime_constants.turn_slow_factor or 1.3
  local straight_time = move_calls[1].time
  local turn_time = move_calls[2].time
  assert(math.abs(straight_time - step_time) < 0.001,
    "straight segment should have base step time, got " .. tostring(straight_time))
  assert(math.abs(turn_time - step_time * factor) < 0.001,
    "turn segment should be multiplied by turn_slow_factor, got " .. tostring(turn_time))
end

-- 直 → 拐（后续同向合并进拐点段）：拐点步被拉长，同向续步正常累加
local function _test_mixed_path_turn_then_straight_merges()
  -- tiles: 1,2,3 沿 x 轴；4,5 从 tile3 沿 y 轴
  -- step(1→2), step(2→3): 同向 x → 合并成 segment1
  -- step(3→4): 转 y 轴 → is_turn, time *= 1.3 → segment2
  -- step(4→5): 与 segment2 同向 y → 合并进 segment2
  local scene = { tiles = {}, units_by_player_id = {} }
  for i = 1, 3 do
    local pos = vec3.with_sub_length((i - 1) * 10, 0, 0)
    scene.tiles[i] = { get_position = function() return pos end }
  end
  for j = 1, 2 do
    local pos = vec3.with_sub_length(20, j * 10, 0)
    scene.tiles[3 + j] = { get_position = function() return pos end }
  end
  local move_calls = {}
  scene.units_by_player_id[1] = {
    start_move_by_direction = function(d, t) move_calls[#move_calls + 1] = { dir = d, time = t } end,
    stop_move = function() end, stop_anim = function() end,
  }

  local scheduled = {}
  _with_patches({
    { target = board_feedback, key = "play_step_tile_sound", value = function() end },
    { target = runtime_ports, key = "schedule", value = function(d, fn)
      scheduled[#scheduled + 1] = { delay = d, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1, seq = 4,
      from_index = 1, to_index = 5,
      visited = { 2, 3, 4, 5 },
      direction = { x = 1, y = 0, z = 0 },
    })
    table.sort(scheduled, function(a, b) return a.delay < b.delay end)
    for _, entry in ipairs(scheduled) do entry.fn() end
  end)

  -- segment1: x 直道 (tiles 1→2→3), segment2: y 方向 (入弯 3→4 + 续 4→5)
  _assert_eq(#move_calls, 2, "straight then turn-and-continue should produce 2 segments")

  local step_time = 10 / runtime_constants.walk_speed
  local factor = runtime_constants.turn_slow_factor or 1.3
  assert(math.abs(move_calls[1].time - step_time * 2) < 0.001, "straight segment should span 2 x-axis steps")
  -- segment2 的 time = 入弯步(1.3x) + 续步(1x)
  local expected_seg2 = step_time * factor + step_time
  assert(math.abs(move_calls[2].time - expected_seg2) < 0.001,
    "turn segment should start with slowed step then accumulate normal steps")
end

-- 单格路径：不合并，不拉长（没有前一 segment 比较）
local function _test_single_step_path_unchanged()
  local scene = _scene_linear(2)
  local move_calls = {}
  scene.units_by_player_id[1] = {
    start_move_by_direction = function(d, t) move_calls[#move_calls + 1] = { dir = d, time = t } end,
    stop_move = function() end, stop_anim = function() end,
  }

  _with_patches({
    { target = board_feedback, key = "play_step_tile_sound", value = function() end },
    { target = runtime_ports, key = "schedule", value = function() end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1, seq = 5,
      from_index = 1, to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  _assert_eq(#move_calls, 1, "single step should produce one segment")
  local step_time = 10 / runtime_constants.walk_speed
  assert(math.abs(move_calls[1].time - step_time) < 0.001,
    "single segment should not be slowed (no prior segment to compare)")
end

return {
  name = "presentation.move_anim_segment_merge",
  tests = {
    { name = "collinear_steps_merged_into_single_segment",           run = _test_collinear_steps_merged_into_single_segment },
    { name = "collinear_segment_time_equals_sum_of_step_times",      run = _test_collinear_segment_time_equals_sum_of_step_times },
    { name = "turn_segment_duration_multiplied_by_turn_slow_factor", run = _test_turn_segment_duration_multiplied_by_turn_slow_factor },
    { name = "mixed_path_turn_then_straight_merges",                  run = _test_mixed_path_turn_then_straight_merges },
    { name = "single_step_path_unchanged",                           run = _test_single_step_path_unchanged },
  },
}
