-- Quick regression checks (run with: lua scripts/regression.lua)
package.path = "src/?.lua;src/?/init.lua;src/gameplay/?.lua;src/gameplay/?/init.lua;?.lua;" .. package.path

local App = require("src.app")
local MovementService = require("src.gameplay.app.services.movement_service")
local ItemService = require("src.gameplay.app.services.item_service")
local LandingResolver = require("src.gameplay.app.landing_resolver")
local Choice = require("src.gameplay.app.choice")
local ChoiceResolver = require("src.gameplay.app.choice_resolver")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")

local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function new_game()
  return App.new({ players = { "P1", "P2" }, ai = { [2] = true }, auto_all = false, seed = 42 })
end

local function first_land_tile(board)
  for idx, tile in ipairs(board.path) do
    if tile.type == "land" then
      return idx, tile
    end
  end
  error("no land tile found")
end

local function first_tile_by_type(board, t)
  for idx, tile in ipairs(board.path) do
    if tile.type == t then
      return idx, tile
    end
  end
  error("no tile found for type=" .. tostring(t))
end

local function tile_state(game, tile)
  local s = game.store and game.store:get({ "board", "tiles", tile.id }) or nil
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end

local function test_pass_start()
  local g = new_game()
  local p = g:current_player()
  -- Passing start means stepping onto tile id 35.
  g:update_player_position(p, g.board:index_of_tile_id(24))
  local res = MovementService.move(g, p, 1, { branch_parity = 1 })
  assert_eq(res.passed_start, 1, "pass_start bonus")
end

local function test_land_on_start_reward()
  local g = new_game()
  g.ui_enabled = false
  local p = g:current_player()
  local idx = first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = p.cash
  local res = LandingResolver.resolve(g, p, g.board:get_tile(idx), {})
  assert(not res, "landing resolver should not wait")
  assert(p.cash > before, "landing on start should grant reward")
end

local function test_roadblock_stop()
  local g = new_game()
  local p = g:current_player()
  g.services.overlay.place_roadblock(g, 2)
  local res = MovementService.move(g, p, 3, { branch_parity = 3 })
  assert_eq(res.stopped_on_roadblock, true, "stopped on roadblock")
  assert_eq(p.position, 2, "position should stop at roadblock")
end

local function test_monster_card()
  local g = new_game()
  local p = g:current_player()
  local idx = 3
  local tile = g.board:get_tile(idx)
  g:set_tile_owner(tile, 2)
  g:set_tile_level(tile, 2)
  p.inventory:add({ id = 2008 })
  local res = ItemService.use_item(g, p, 2008)
  local ok = (type(res) == "table" and res.ok ~= nil) and res.ok or res
  assert_eq(ok, true, "monster use ok")
  assert_eq(tile_state(g, tile).level, 0, "building destroyed")
end

local function test_missile_card()
  local g = new_game()
  local p = g:current_player()
  local idx = 4
  local tile = g.board:get_tile(idx)
  g:set_tile_owner(tile, 2)
  g:set_tile_level(tile, 1)
  g:update_player_position(g.players[2], idx)
  g.services.overlay.place_roadblock(g, idx)
  g.services.overlay.place_mine(g, idx)
  p.inventory:add({ id = 2013 })
  local res = ItemService.use_item(g, p, 2013)
  if type(res) == "table" and res.intent then
    IntentDispatcher.dispatch_from_result(g, res)
    local pending = Choice.get(g)
    assert(pending and pending.kind == "missile_target", "missile should open choice")
    local first = pending.options[1]
    ChoiceResolver.resolve(g, pending, { option_id = first.id })
    res = true
  end
  local ok = (type(res) == "table" and res.ok ~= nil) and res.ok or res
  assert_eq(ok, true, "missile use ok")
  assert_eq(tile_state(g, tile).level, 0, "building destroyed by missile")
  assert_eq(g.services.overlay.has_roadblock(g, idx), false, "roadblock cleared")
  assert_eq(g.services.overlay.has_mine(g, idx), false, "mine cleared")
  assert(g.players[2].status.stay_turns > 0, "target sent to hospital")
end

local function test_landing_optional_waits_with_ui()
  local g = new_game()
  -- UI is considered available when an adapter port exists.
  g.ui_port = {}
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = LandingResolver.resolve(g, p, tile, {})
  assert(res and res.waiting, "landing resolver should wait when UI is available")
  local pending = Choice.get(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice for landing optional")
end

local function test_landing_optional_waits_without_ui_and_can_resolve()
  local g = new_game()
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  local before_cash = p.cash
  local res = LandingResolver.resolve(g, p, tile, {})
  assert(res and res.waiting, "landing resolver should wait even without UI")
  local pending = Choice.get(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected without UI")
  local first = pending.options and pending.options[1]
  assert(first, "expected at least one optional effect")
  ChoiceResolver.resolve(g, pending, { option_id = first.id })
  assert(tile_state(g, tile).owner_id == p.id, "land should be purchased after resolving choice")
  assert(p.cash < before_cash, "cash deducted for purchase")
end

local function test_landing_optional_stale_choice_is_blocked()
  local g = new_game()
  g.ui_port = {}
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = LandingResolver.resolve(g, p, tile, {})
  assert(res and res.waiting, "should open choice")
  local pending = Choice.get(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected")

  -- Invalidate the option after choice is shown (simulate state change).
  p:set_cash(0)

  ChoiceResolver.resolve(g, pending, { option_id = "buy_land" })
  assert(tile_state(g, tile).owner_id == nil, "stale buy_land should be blocked")
end

local function test_chance_is_mandatory_effect_entrypoint()
  local g = new_game()
  local p = g:current_player()
  local idx, tile = first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)

  local called = { draw = 0, resolve = 0 }
  g.services.chance = {
    draw_card = function()
      called.draw = called.draw + 1
      return { description = "stub", effect = "add_cash", amount = 0 }
    end,
    resolve = function()
      called.resolve = called.resolve + 1
    end,
  }

  local res = LandingResolver.resolve(g, p, tile, {})
  assert(not res, "chance landing should not wait")
  assert_eq(called.draw, 1, "chance draw called")
  assert_eq(called.resolve, 1, "chance resolve called")
end

local function test_movement_examples_from_issue()
  local g = new_game()
  local p = g:current_player()

  -- 例子1: 起点=海口路(3)，步数=4，终点=天津路(32)
  g:update_player_position(p, g.board:index_of_tile_id(3))
  local r1 = MovementService.move(g, p, 4, { branch_parity = 4 })
  assert_eq(g.board:get_tile(p.position).id, 32, "example1 end tile")
  assert(#r1.visited == 4, "example1 visited steps")

  -- 例子2: 起点=天津路(32)，当前方向向下(下一格31)，步数=6，终点=澳门路(6)
  g:update_player_position(p, g.board:index_of_tile_id(32))
  local r2 = MovementService.move(g, p, 6, { branch_parity = 6, direction = "down" })
  assert_eq(g.board:get_tile(p.position).id, 6, "example2 end tile")
  assert(#r2.visited == 6, "example2 visited steps")

  -- 例子3: 起点=南昌路(25)，当前方向向右，步数=12，终点=南宁路(7)
  g:update_player_position(p, g.board:index_of_tile_id(25))
  local r3 = MovementService.move(g, p, 12, { branch_parity = 12, direction = "right" })
  assert_eq(g.board:get_tile(p.position).id, 7, "example3 end tile")
  assert(#r3.visited == 12, "example3 visited steps")
end

local tests = {
  test_pass_start,
  test_land_on_start_reward,
  test_roadblock_stop,
  test_monster_card,
  test_missile_card,
  test_landing_optional_waits_with_ui,
  test_landing_optional_waits_without_ui_and_can_resolve,
  test_landing_optional_stale_choice_is_blocked,
  test_chance_is_mandatory_effect_entrypoint,
  test_movement_examples_from_issue,
}

for _, fn in ipairs(tests) do
  fn()
  io.stdout:write(".")
end

print("\nAll regression checks passed (" .. #tests .. ")")
