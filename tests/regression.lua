-- Quick regression checks (run with: lua tests/regression.lua)
package.path = "src/?.lua;src/?/init.lua;src/gameplay/?.lua;src/gameplay/?/init.lua;?.lua;" .. package.path

local App = require("src.game")
local MovementService = require("src.gameplay.app.services.movement_service")
local Inventory = require("src.gameplay.domain.item_inventory")
local Executor = require("src.gameplay.domain.item_executor")
local Strategy = require("src.gameplay.domain.item_strategy")
local LandingResolver = require("src.gameplay.app.landing_resolver")
local Choice = require("src.gameplay.app.choice")
local ChoiceResolver = require("src.gameplay.app.choice_resolver")

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

local Tile = require("src.core.tile")

local function tile_state(game, tile)
  local state = Tile.get_state(game, tile)
  return state or { owner_id = nil, level = 0 }
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
  g.board:place_roadblock(2)
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
  local res = Executor.use_item(g, p, 2008, { services = g.services, by_ai = true }, { inventory = Inventory, strategy = Strategy })
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
  g.board:place_roadblock(idx)
  g.board:place_mine(idx)
  p.inventory:add({ id = 2013 })
  local res = Executor.use_item(g, p, 2013, { services = g.services }, { inventory = Inventory, strategy = Strategy })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      Choice.open(g, res.intent.choice_spec)
    end
    local pending = Choice.get(g)
    assert(pending and pending.kind == "demolish_target", "missile should open choice")
    local first = pending.options[1]
    ChoiceResolver.resolve(g, pending, { option_id = first.id })
    res = true
  end
  local ok = (type(res) == "table" and res.ok ~= nil) and res.ok or res
  assert_eq(ok, true, "missile use ok")
  assert_eq(tile_state(g, tile).level, 0, "building destroyed by missile")
  assert_eq(g.board:has_roadblock(idx), false, "roadblock cleared")
  assert_eq(g.board:has_mine(idx), false, "mine cleared")
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

  -- We verify execution by checking if RNG is used to pick a card
  local called = { rng = 0 }
  g.rng = {
    next_float = function()
      called.rng = called.rng + 1
      return 0.1 -- Pick first card usually
    end,
    -- chance.resolve might use rng for effects too
    random = function() return 1 end, 
    choice = function(self, arr) return arr[1] end
  }
  
  -- Ensure we don't crash on effect execution
  -- We assume standard chance cards are safe or we mock chance_effects?
  -- Mocking requires package reload. Let's trust integration.

  LandingResolver.resolve(g, p, tile, {})
  
  assert(called.rng > 0, "chance logic was executed (RNG used)")
end

local function test_movement_examples_from_issue()
  local g = new_game()
  local p = g:current_player()

  -- 例子1: 起点=海口路(3)，步数=4，终点=天津路(32)
  g:update_player_position(p, g.board:index_of_tile_id(3))
  local r1 = MovementService.move(g, p, 4, { branch_parity = 4, skip_market_check = true })
  assert_eq(g.board:get_tile(p.position).id, 32, "example1 end tile")
  assert(#r1.visited == 4, "example1 visited steps")

  -- 例子2: 起点=天津路(32)，当前方向向下(下一格31)，步数=6，终点=澳门路(6)
  g:update_player_position(p, g.board:index_of_tile_id(32))
  local r2 = MovementService.move(g, p, 6, { branch_parity = 6, direction = "down", skip_market_check = true })
  assert_eq(g.board:get_tile(p.position).id, 6, "example2 end tile")
  assert(#r2.visited == 6, "example2 visited steps")

  -- 例子3: 起点=南昌路(25)，当前方向向右，步数=12，终点=南宁路(7)
  g:update_player_position(p, g.board:index_of_tile_id(25))
  local r3 = MovementService.move(g, p, 12, { branch_parity = 12, direction = "right", skip_market_check = true })
  assert_eq(g.board:get_tile(p.position).id, 7, "example3 end tile")
  assert(#r3.visited == 12, "example3 visited steps")
end

local function test_ai_cancels_land_purchases()
  local Agent = require("src.gameplay.ai.agent")
  local g = new_game()
  local ai_player = g.players[2]
  assert(Agent.is_auto_player(ai_player), "player 2 should be AI")
  
  -- Set AI player as current player (index 2)
  if g.store then
    g.store:set({"turn", "current_player_index"}, 2)
  end
  
  assert(g:current_player() == ai_player, "AI should be current player")
  
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(ai_player, idx)
  
  local res = LandingResolver.resolve(g, ai_player, tile, {})
  assert(res and res.waiting, "should wait for choice")
  
  local pending = Choice.get(g)
  assert(pending and pending.kind == "landing_optional_effect", "should have landing choice")
  
  local action = Agent.auto_action_for_choice(g, pending)
  assert(action, "AI should return an action")
  assert(action.type == "choice_cancel", "AI should cancel land purchase")
  
  local before_cash = ai_player.cash
  ChoiceResolver.resolve(g, pending, action)
  assert(ai_player.cash == before_cash, "AI cash should not change after canceling")
  assert(tile_state(g, tile).owner_id == nil, "land should not be purchased")
end

local function test_mandatory_payment_causes_bankruptcy()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  
  -- Set up: p1 owns a land tile with high value, p2 has little cash
  local idx, tile = first_land_tile(g.board)
  g:set_tile_owner(tile, p1.id)
  g:set_tile_level(tile, 3) -- Max level for high rent
  g:set_player_property(p1, tile.id, true)
  
  -- Give p2 very little cash (not enough to pay rent)
  p2:set_cash(10)
  
  -- Move p2 to the land tile
  g:update_player_position(p2, idx)
  
  local before_eliminated = p2.eliminated
  LandingResolver.resolve(g, p2, tile, {})
  
  -- p2 should be eliminated due to insufficient funds for mandatory rent
  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function test_ai_skips_auto_buy_at_market()
  local MarketService = require("src.gameplay.app.services.market_service")
  local g = new_game()
  local ai_player = g.players[2]
  assert(ai_player.is_ai, "player 2 should be AI")
  
  -- Give AI player enough cash to buy something
  ai_player:set_cash(1000)
  
  local before_cash = ai_player.cash
  MarketService.auto_buy(ai_player)
  
  -- AI should not buy anything
  assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
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
  test_ai_cancels_land_purchases,
  test_mandatory_payment_causes_bankruptcy,
  test_ai_skips_auto_buy_at_market,
}

for _, fn in ipairs(tests) do
  fn()
  io.stdout:write(".")
end

print("\nAll regression checks passed (" .. #tests .. ")")
