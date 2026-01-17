-- Quick regression checks (run with: lua tests/regression.lua)
package.path = "src/?.lua;src/?/init.lua;src/gameplay/?.lua;src/gameplay/?/init.lua;?.lua;" .. package.path

local App = require("src.game")
local MovementService = require("src.gameplay.movement_service")
local Inventory = require("src.gameplay.item_inventory")
local Executor = require("src.gameplay.item_executor")
local Strategy = require("src.gameplay.item_strategy")
local Pricing = require("src.gameplay.land_pricing")
local LandEffect = require("src.gameplay.land")
local landing_effects = require("src.gameplay.landing")
local EffectPipeline = require("src.gameplay.effect_pipeline")
local ChoiceService = require("src.gameplay.choice_service")

local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function next_choice_id(store)
  local seq = store:get({ "turn", "choice_seq" }) or 0
  seq = seq + 1
  store:set({ "turn", "choice_seq" }, seq)
  return seq
end

local function open_choice(game, payload)
  assert(game and game.store, "Choice.open requires game.store")
  payload = payload or {}
  local id = next_choice_id(game.store)
  local entry = {
    id = id,
    kind = payload.kind,
    title = payload.title or "请选择",
    body_lines = payload.body_lines or {},
    options = payload.options or {},
    allow_cancel = payload.allow_cancel ~= false,
    cancel_label = payload.cancel_label or "取消",
    meta = payload.meta,
  }
  game.store:set({ "turn", "pending_choice" }, entry)
  return entry
end

local function get_choice(game)
  if not (game and game.store) then
    return nil
  end
  return game.store:get({ "turn", "pending_choice" })
end

local MAX_LANDING_DEPTH = 10

local function build_landing_ctx(game, player, tile, move_result)
  local phase = game and game.store and game.store:get({ "turn", "phase" }) or "landing"
  return {
    game = game,
    store = game and game.store,
    rng = game and game.rng,
    services = game and game.services,
    phase = phase,
    player = player,
    tile = tile,
    move_result = move_result,
    on_landing = true,
  }
end

local function resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local ctx = build_landing_ctx(game, player, tile, move_result)

  local function handle_need_landing(out)
    if depth >= MAX_LANDING_DEPTH then
      return out
    end
    local target_player = (out.player_id and game and game.players and game.players[out.player_id]) or player
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      next_tile = idx and game and game.board and game.board:get_tile(idx) or nil
    end
    if next_tile then
      return resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return EffectPipeline.run(landing_effects.defs, ctx, {
    resume_state = "post_action",
    resume_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
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

local function first_adjacent_land_pair(board)
  for idx = 1, #board.path - 1 do
    local a = board.path[idx]
    local b = board.path[idx + 1]
    if a.type == "land" and b.type == "land" then
      return idx, a, idx + 1, b
    end
  end
  error("no adjacent land tiles")
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
  local res = resolve_landing(g, p, g.board:get_tile(idx), {})
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
      open_choice(g, res.intent.choice_spec)
    end
    local pending = get_choice(g)
    assert(pending and pending.kind == "demolish_target", "missile should open choice")
    local first = pending.options[1]
    ChoiceService.resolve(g, pending, { option_id = first.id })
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
  local res = resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "landing resolver should wait when UI is available")
  local pending = get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice for landing optional")
end

local function test_landing_optional_waits_without_ui_and_can_resolve()
  local g = new_game()
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  local before_cash = p.cash
  local res = resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "landing resolver should wait even without UI")
  local pending = get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected without UI")
  local first = pending.options and pending.options[1]
  assert(first, "expected at least one optional effect")
  ChoiceService.resolve(g, pending, { option_id = first.id })
  assert(tile_state(g, tile).owner_id == p.id, "land should be purchased after resolving choice")
  assert(p.cash < before_cash, "cash deducted for purchase")
end

local function test_landing_optional_stale_choice_is_blocked()
  local g = new_game()
  g.ui_port = {}
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "should open choice")
  local pending = get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected")

  -- Invalidate the option after choice is shown (simulate state change).
  p:set_cash(0)

  ChoiceService.resolve(g, pending, { option_id = "buy_land" })
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

  resolve_landing(g, p, tile, {})
  
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
  local Agent = require("src.gameplay.agent")
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
  
  local res = resolve_landing(g, ai_player, tile, {})
  assert(res and res.waiting, "should wait for choice")
  
  local pending = get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "should have landing choice")
  
  local action = Agent.auto_action_for_choice(g, pending)
  assert(action, "AI should return an action")
  assert(action.type == "choice_cancel", "AI should cancel land purchase")
  
  local before_cash = ai_player.cash
  ChoiceService.resolve(g, pending, action)
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
  resolve_landing(g, p2, tile, {})
  
  -- p2 should be eliminated due to insufficient funds for mandatory rent
  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function test_ai_skips_auto_buy_at_market()
  local MarketService = require("src.gameplay.market_service")
  local g = new_game()
  local ai_player = g.players[2]
  assert(ai_player.is_ai, "player 2 should be AI")
  
  -- Give AI player enough cash to buy something
  ai_player:set_cash(1000)
  
  local before_cash = ai_player.cash
  MarketService.auto_buy(g, ai_player)
  
  -- AI should not buy anything
  assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
end

local function test_land_rent_contiguous_sum()
  local g = new_game()
  local owner = g.players[1]
  local tenant = g.players[2]

  local idx1, tile1, idx2, tile2 = first_adjacent_land_pair(g.board)
  g:set_tile_owner(tile1, owner.id)
  g:set_tile_owner(tile2, owner.id)
  g:set_tile_level(tile1, 1)
  g:set_tile_level(tile2, 2)
  g:set_player_property(owner, tile1.id, true)
  g:set_player_property(owner, tile2.id, true)

  g:update_player_position(tenant, idx1)
  local before = tenant.cash
  LandEffect.execute_pay_rent(g, tenant.id, tile1.id)
  local expected = Pricing.rent_for_level(tile1, 1) + Pricing.rent_for_level(tile2, 2)
  assert_eq(before - tenant.cash, expected, "contiguous rent sum")
end

local function test_item_equalize_cash()
  local g = new_game()
  local user = g.players[1]
  local target = g.players[2]
  user:set_cash(1000)
  target:set_cash(9000)
  user.inventory:add({ id = 2011 })
  local res = Executor.use_item(g, user, 2011, { by_ai = true }, { inventory = Inventory, strategy = Strategy })
  local ok = (type(res) == "table" and res.ok ~= nil) and res.ok or res
  assert_eq(ok, true, "equalize use ok")
  assert_eq(user.cash, 5000, "equalize user cash")
  assert_eq(target.cash, 5000, "equalize target cash")
end

local function test_market_full_inventory_blocks_items()
  local MarketService = require("src.gameplay.market_service")
  local g = new_game()
  local p = g:current_player()
  p:set_cash(999999)
  for _ = 1, p.inventory.max_slots do
    p.inventory:add({ id = 2001 })
  end

  local list = MarketService.list_buyable(p)
  for _, entry in ipairs(list) do
    assert(entry.kind ~= "item", "item should be excluded when inventory full")
  end
end

local function test_zero_cash_no_buy_choice()
  local g = new_game()
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  p:set_cash(0)
  local res = resolve_landing(g, p, tile, {})
  assert(not res, "no choice when cannot buy")
  assert(get_choice(g) == nil, "no pending choice")
end

local function test_movement_backward_wrap()
  local g = new_game()
  local p = g:current_player()
  g:update_player_position(p, 1)
  local res = MovementService.move(g, p, -1, { branch_parity = 1 })
  assert(p.position >= 1 and p.position <= g.board:length(), "backward index in range")
  assert(#res.visited == 1, "visited steps")
end

local function test_invalid_choice_option_rejected()
  local g = new_game()
  local choice = open_choice(g, {
    kind = "market_buy",
    options = { { id = 1, label = "X" } },
    meta = { player_id = g:current_player().id },
  })
  ChoiceService.resolve(g, choice, { option_id = 999 })
  assert(get_choice(g) == nil, "invalid option should clear choice")
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
  test_land_rent_contiguous_sum,
  test_item_equalize_cash,
  test_market_full_inventory_blocks_items,
  test_zero_cash_no_buy_choice,
  test_movement_backward_wrap,
  test_invalid_choice_option_rejected,
}

for _, fn in ipairs(tests) do
  fn()
  io.stdout:write(".")
end

print("\nAll regression checks passed (" .. #tests .. ")")
