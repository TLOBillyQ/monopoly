local app = require("game")
local movement = require("game.move")
local board_utils = require("game.land.utils")
local map_cfg = require("cfg.Map")
local tiles_cfg = require("cfg.Generated.Tiles")
local assertions = require("support.assertions")

local function new_game()
  app.setup({
    players = { "P1", "P2" },
    ai = { [2] = true },
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  return app
end

local function _test_pass_start()
  local g = new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(24))
  local res = movement.move(g, p, 1, { branch_parity = 1 })
  assertions.assert_equal(res.passed_start, 1, "pass_start bonus")
end

local function _test_roadblock_stop()
  local g = new_game()
  local p = g:current_player()
  g.board:place_roadblock(2)
  local res = movement.move(g, p, 3, { branch_parity = 3 })
  assertions.assert_equal(res.stopped_on_roadblock, true, "stopped on roadblock")
  assertions.assert_equal(p.position, 2, "position should stop at roadblock")
end

local function _test_movement_examples_from_issue()
  local g = new_game()
  local p = g:current_player()

  g:update_player_position(p, g.board:index_of_tile_id(3))
  local r1 = movement.move(g, p, 4, { branch_parity = 4, skip_market_check = true })
  assertions.assert_equal(g.board:get_tile(p.position).id, 32, "example1 end tile")
  assert(#r1.visited == 4, "example1 visited steps")

  g:update_player_position(p, g.board:index_of_tile_id(32))
  local r2 = movement.move(g, p, 6, { branch_parity = 6, direction = "down", skip_market_check = true })
  assertions.assert_equal(g.board:get_tile(p.position).id, 6, "example2 end tile")
  assert(#r2.visited == 6, "example2 visited steps")

  g:update_player_position(p, g.board:index_of_tile_id(25))
  local r3 = movement.move(g, p, 12, { branch_parity = 12, direction = "right", skip_market_check = true })
  assertions.assert_equal(g.board:get_tile(p.position).id, 7, "example3 end tile")
  assert(#r3.visited == 12, "example3 visited steps")
end

local function _test_board_indices_in_range_uses_graph_distance()
  local g = new_game()
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  assert(idx_a and idx_b, "expected tile ids 27/28")
  local list = board_utils.indices_in_range(g.board, idx_a, 1)
  for _, idx in ipairs(list) do
    assert(idx ~= idx_b, "graph distance should not include path neighbor")
  end
end

local function _test_movement_backward_wrap()
  local g = new_game()
  local p = g:current_player()
  g:update_player_position(p, 1)
  local res = movement.move(g, p, -1, { branch_parity = 1 })
  assert(p.position >= 1 and p.position <= g.board:length(), "backward index in range")
  assert(#res.visited == 1, "visited steps")
end

local _tests = {
  _test_pass_start,
  _test_roadblock_stop,
  _test_movement_examples_from_issue,
  _test_board_indices_in_range_uses_graph_distance,
  _test_movement_backward_wrap,
}

local _cases = {}
for index, run in ipairs(_tests) do
  _cases[#_cases + 1] = {
    id = "movement.case_" .. tostring(index),
    desc = "movement migrated case " .. tostring(index),
    run = run,
  }
end

return {
  layer = "regression",
  domain = "movement",
  cases = _cases,
}
