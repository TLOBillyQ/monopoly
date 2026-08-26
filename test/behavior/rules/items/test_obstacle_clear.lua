-- obstacle_clear 直测(#259 变异清扫 survivor 闭合):
-- 模块级 `timing.action_anim_default_seconds or 1.0` 的 or -> and
-- (变异体把回退时长钉成 1.0 而非配置值);
-- _new_state 的 "missing context" 守卫与 `branch_parity or distance` 的
-- or -> and(变异体把显式 parity 换成 distance)。
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local timing = require("src.config.gameplay.timing")
local obstacle_clear = require("src.rules.items.obstacle_clear")
local obstacle_clear_walk = require("src.rules.items.obstacle_clear_walk")
local action_anim_port = require("src.foundation.ports.action_anim")

local _assert_eq = support.assert_eq

local function _drive(context, distance)
  local captured = {}
  support.with_patches({
    { target = obstacle_clear_walk, key = "walk_and_clear", value = function(_, _, _, state)
      captured.parity = state.parity
    end },
    { target = action_anim_port, key = "queue", value =function(_, opts)
      captured.duration = opts.duration
      captured.kind = opts.kind
      return false
    end },
  }, function()
    obstacle_clear.handle({ board = {} }, { id = 1, name = "P1" }, { distance = distance }, context)
  end)
  return captured
end

TestObstacleClear = {}

function TestObstacleClear:test_queues_the_clear_obstacles_animation_kind()
  local captured = _drive({}, 1)
  _assert_eq(captured.kind, "clear_obstacles", "the queued animation must use the clear_obstacles kind")
end

function TestObstacleClear:test_falls_back_to_the_configured_default_duration_not_a_hardcoded_1_0()
  -- the config value happens to be 1.0 today, so pin via a sentinel: reload
  -- the module (its duration local binds at require time) with the timing
  -- config set to 2.5; the `or` -> `and` mutant would yield 1.0 instead.
  local prev = timing.action_anim_default_seconds
  timing.action_anim_default_seconds = 2.5
  package.loaded["src.rules.items.obstacle_clear"] = nil
  local fresh = require("src.rules.items.obstacle_clear")
  timing.action_anim_default_seconds = prev
  local captured = {}
  support.with_patches({
    { target = obstacle_clear_walk, key = "walk_and_clear", value = function() end },
    { target = action_anim_port, key = "queue", value = function(_, opts)
      captured.duration = opts.duration
      return false
    end },
  }, function()
    fresh.handle({ board = {} }, { id = 1, name = "P1" }, { distance = 12 }, {})
  end)
  package.loaded["src.rules.items.obstacle_clear"] = nil
  require("src.rules.items.obstacle_clear")
  _assert_eq(captured.duration, 2.5, "fallback duration must come from the timing config")
end

function TestObstacleClear:test_prefers_an_explicit_context_branch_parity_over_distance()
  local captured = _drive({ branch_parity = 3 }, 1)
  _assert_eq(captured.parity, 3, "explicit branch_parity must win over distance")
end

function TestObstacleClear:test_handle_rejects_a_nil_context_with_the_guard_message()
  luax.has_error(function()
    obstacle_clear.handle({ board = {} }, { id = 1, name = "P1" }, { distance = 1 }, nil)
  end, "missing context")
end

function TestObstacleClear:test_visit_tile_remembers_a_clean_tile_across_visits()
  -- kills the snapshot's `(had_rb or had_mine) and "yes" or "no"` "no" -> nil:
  -- a nil snapshot re-probes on revisit, so a later-placed obstacle would
  -- flip the answer (and double-count the clear).
  local tiles = require("src.rules.items.obstacle_clear_tiles")
  local roadblock = false
  local probes = 0
  local board = {
    has_roadblock = function() probes = probes + 1; return roadblock end,
    has_mine = function() return false end,
  }
  local game = {
    clear_roadblock = function() end,
    clear_mine = function() end,
  }
  local state = { cleared = 0, roadblock_cleared = 0, mine_cleared = 0, obstacle_snapshot = {} }
  _assert_eq(tiles.visit_tile(game, board, state, "t1", 5), false, "clean tile reports no obstacle")
  roadblock = true
  _assert_eq(tiles.visit_tile(game, board, state, "t1", 5), false, "the snapshot sticks across visits")
  _assert_eq(probes, 1, "the tile is only probed once")
end


return TestObstacleClear
