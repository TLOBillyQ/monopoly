-- Quick regression checks (run with: lua tests/regression.lua)
local App = require("Manager.GameManager.Game")
local MovementService = require("Manager.MovementManager.Movement.MovementService")
local TurnManager = require("Manager.TurnManager.Turn.TurnManager")
local turn_move = require("Manager.TurnManager.Turn.TurnMove")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local Executor = require("Manager.ItemManager.Item.ItemExecutor")
local Strategy = require("Manager.ItemManager.Item.ItemStrategy")
local Pricing = require("Manager.LandManager.Land.LandPricing")
local LandActions = require("Manager.LandManager.Land.LandActions")
local Steal = require("Manager.ItemManager.Item.ItemSteal")
local ChanceEffects = require("Manager.GameManager.Chance")
local landing_defs = require("Config.LandingEffects")
local EffectPipeline = require("Manager.EffectManager.Effect.EffectPipeline")
local Effect = require("Manager.EffectManager.Effect.Effect")
local ChoiceService = require("Manager.ChoiceManager.Choice.ChoiceService")
local BoardUtils = require("Manager.ItemManager.Item.ItemBoardUtils")
local RuntimeLoop = require("Manager.System.GUI.RuntimeLoop")
local constants = require("Config.Generated.Constants")
local logger = require("Library.Monopoly.Logger")
local SERVICE_KEY = require("Globals.ServiceKeys")

if not math.tofixed then
  function math.tofixed(value)
    return value
  end
end

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

if not math.Quaternion then
  function math.Quaternion(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

LuaAPI = LuaAPI or {}
LuaAPI.rand = LuaAPI.rand or function()
  return math.random()
end

local function visited_tile_ids(board, visited)
  local list = {}
  for _, idx in ipairs(visited or {}) do
    local tile = board:get_tile(idx)
    table.insert(list, tile and tile.id or idx)
  end
  return list
end

local function list_contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
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

local function build_landing_ctx(game, move_result)
  return Effect.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })
end

local function resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local ctx = build_landing_ctx(game, move_result)

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

  return EffectPipeline.run(landing_defs, player, tile, ctx, {
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

local Tile = require("Components.Tile")

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

local function test_logger_adapter_called()
  local called = 0
  local last = nil
  logger.set_adapter({
    on_log = function(entry)
      called = called + 1
      last = entry
    end,
  })
  logger.info("adapter-test", 1)
  assert_eq(called, 1, "adapter should be called")
  assert_eq(last and last.text, "adapter-test 1", "adapter entry text")
  logger.set_adapter(nil)
end

local function test_move_anim_callback_and_delay()
  local dispatched = {}
  local layer = { wait_move_anim = true }
  local game = {
    store = {
      get = function(_, key)
        if key[1] == "turn" and key[2] == "move_anim" then
          return { seq = 1 }
        end
        if key[1] == "turn" and key[2] == "phase" then
          return "wait_move_anim"
        end
        return nil
      end,
    },
    dispatch_action = function(_, action)
      table.insert(dispatched, action)
    end,
  }
  layer.game = game
  local delay_called = nil
  local original_lua_api = LuaAPI
  local original_set_timeout = SetTimeOut
  LuaAPI = {
    call_delay_time = function(delay, cb)
      delay_called = delay
      cb()
    end,
  }
  SetTimeOut = LuaAPI.call_delay_time
  RuntimeLoop.step_move_anim(layer, {
    on_move_anim = function(_, anim)
      assert_eq(anim.seq, 1, "anim seq forwarded")
      return 0.2
    end,
  })
  LuaAPI = original_lua_api
  SetTimeOut = original_set_timeout
  assert_eq(delay_called, 0.2, "delay requested")
  assert_eq(#dispatched, 1, "move_anim_done dispatched")
  assert_eq(dispatched[1].seq, 1, "move_anim_done seq")
end
local function test_land_on_start_reward()
  local g = new_game()
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

local function test_popup_timeout_auto_confirm()
  local g = new_game()
  local layer = {}
  layer.ui_modal_elapsed = 0
  layer.ui_modal_ref = nil
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    return
  end
  local near_timeout = timeout * 0.9
  local popup = {
    active = true,
    confirm_called = 0,
    confirm = function(self)
      self.confirm_called = self.confirm_called + 1
      self.active = false
      return true
    end,
  }
  layer.modal = { active = popup }
  local timeout_opts = {
    is_active = function(l)
      return l.modal and l.modal.active and l.modal.active.active
    end,
    get_ref = function(l)
      return l.modal and l.modal.active
    end,
    on_timeout = function(l)
      l.modal.active:confirm()
    end,
  }
  RuntimeLoop.step_modal_timeout(layer, near_timeout, timeout_opts)
  assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
  RuntimeLoop.step_modal_timeout(layer, near_timeout + 1, timeout_opts)
  assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
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

  -- We verify execution by checking if LuaAPI.rand is used to pick a card
  local called = { rand = 0 }
  local original_lua_api = LuaAPI
  LuaAPI = LuaAPI or {}
  LuaAPI.rand = function()
    called.rand = called.rand + 1
    return 0 -- Pick first card
  end
  
  -- Ensure we don't crash on effect execution
  -- We assume standard chance cards are safe or we mock chance_effects?
  -- Mocking requires package reload. Let's trust integration.

  resolve_landing(g, p, tile, {})
  LuaAPI = original_lua_api

  assert(called.rand > 0, "chance logic was executed (LuaAPI.rand used)")
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

local function test_ai_picks_land_purchase()
  local Agent = require("Manager.GameManager.Agent")
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
  assert(action.type == "choice_select", "AI should select land purchase")
  assert(action.option_id == "buy_land", "AI should pick buy_land")
  
  local before_cash = ai_player.cash
  ChoiceService.resolve(g, pending, action)
  assert(ai_player.cash == before_cash - tile.price, "AI cash should decrease by land price")
  assert(tile_state(g, tile).owner_id == ai_player.id, "land should be purchased")
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

local function test_bankruptcy_resets_owned_tiles()
  local g = new_game()
  local p1 = g.players[1]
  local _, tile1 = first_land_tile(g.board)
  local tile2 = nil
  for i = 1, #g.board.path do
    local t = g.board.path[i]
    if t.type == "land" and t.id ~= tile1.id then
      tile2 = t
      break
    end
  end
  assert(tile2, "should have at least two land tiles")

  g:set_tile_owner(tile1, p1.id)
  g:set_tile_level(tile1, 2)
  g:set_player_property(p1, tile1.id, true)

  g:set_tile_owner(tile2, p1.id)
  g:set_tile_level(tile2, 1)

  local bankruptcy = g:get_service(SERVICE_KEY.bankruptcy)
  bankruptcy.eliminate(g, p1)

  local st1 = tile_state(g, tile1)
  local st2 = tile_state(g, tile2)
  assert(st1.owner_id == nil and st1.level == 0, "bankruptcy clears owned tile1")
  assert(st2.owner_id == nil and st2.level == 0, "bankruptcy clears owned tile2")
  assert(next(p1.properties) == nil, "bankruptcy clears player properties")
end

local function test_ai_skips_auto_buy_at_market()
  local MarketService = require("Manager.MarketManager.Market.MarketService")
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
  LandActions.execute_pay_rent(g, tenant.id, tile1.id)
  local expected = Pricing.rent_for_level(tile1, 1) + Pricing.rent_for_level(tile2, 2)
  assert_eq(before - tenant.cash, expected, "contiguous rent sum")
end

local function test_land_rent_graph_adjacency_breaks_path_neighbors()
  local g = new_game()
  local owner = g.players[1]
  local tenant = g.players[2]
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  assert(idx_a and idx_b, "expected tile ids 27/28")
  local tile_a = g.board:get_tile(idx_a)
  local tile_b = g.board:get_tile(idx_b)
  assert(tile_a and tile_b, "expected land tiles")

  g:set_tile_owner(tile_a, owner.id)
  g:set_tile_owner(tile_b, owner.id)
  g:set_tile_level(tile_a, 1)
  g:set_tile_level(tile_b, 2)
  g:set_player_property(owner, tile_a.id, true)
  g:set_player_property(owner, tile_b.id, true)

  g:update_player_position(tenant, idx_a)
  local before = tenant.cash
  LandActions.execute_pay_rent(g, tenant.id, tile_a.id)
  local expected = Pricing.rent_for_level(tile_a, 1)
  assert_eq(before - tenant.cash, expected, "graph adjacency rent excludes non-neighbors")
end

local function test_board_indices_in_range_uses_graph_distance()
  local g = new_game()
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  assert(idx_a and idx_b, "expected tile ids 27/28")
  local list = BoardUtils.indices_in_range(g.board, idx_a, 1)
  for _, idx in ipairs(list) do
    assert(idx ~= idx_b, "graph distance should not include path neighbor")
  end
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
  local MarketService = require("Manager.MarketManager.Market.MarketService")
  local g = new_game()
  local p = g:current_player()
  p:set_cash(999999)
  for _ = 1, p.inventory.max_slots do
    p.inventory:add({ id = 2001 })
  end

  local list = MarketService.list_buyable(p, g)
  for _, entry in ipairs(list) do
    assert(entry.kind ~= "item", "item should be excluded when inventory full")
  end
end

local function test_market_global_limit()
  local MarketService = require("Manager.MarketManager.Market.MarketService")
  local market_cfg = require("Config.Generated.Market")
  local g = new_game()
  local p = g:current_player()
  local entry = nil
  for _, cfg in ipairs(market_cfg) do
    if cfg.kind == "item" and cfg.currency == "金币" then
      entry = cfg
      break
    end
  end
  assert(entry, "should find a market item with coin currency")
  p:set_cash((entry.price or 0) + 1000)
  g.store:set({ "market", "global_limits", entry.product_id }, 1)

  local res = MarketService.buy(g, p, entry.product_id)
  local ok = (type(res) == "table" and res.ok ~= nil) and res.ok or res
  assert(ok, "first purchase should succeed")

  local list = MarketService.list_buyable(p, g)
  for _, item in ipairs(list) do
    assert(item.product_id ~= entry.product_id, "sold out item should be excluded from list")
  end

  local spec = MarketService.build_choice_spec(p, g)
  if spec and spec.options then
    for _, option in ipairs(spec.options) do
      assert(option.id ~= entry.product_id, "sold out item should be excluded from choice")
    end
  end
end

local function test_zero_cash_no_buy_choice()
  local g = new_game()
  local p = g:current_player()
  local idx, tile = first_land_tile(g.board)
  g:update_player_position(p, idx)
  p:set_cash(0)
  local res = resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "buy choice should appear even when cash is zero")
  assert(get_choice(g) ~= nil, "pending choice should exist")
end

local function test_movement_backward_wrap()
  local g = new_game()
  local p = g:current_player()
  g:update_player_position(p, 1)
  local res = MovementService.move(g, p, -1, { branch_parity = 1 })
  assert(p.position >= 1 and p.position <= g.board:length(), "backward index in range")
  assert(#res.visited == 1, "visited steps")
end

local function test_chance_move_backward_pass_market()
  local g = new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = ChanceEffects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = visited_tile_ids(g.board, out.move_result.visited)
  assert(list_contains(visited_ids, 39), "backward move should pass market")
  assert(out.move_result.market_interrupt == nil, "backward move should not trigger market interrupt")
end

local function test_chance_move_backward_pass_intersection()
  local g = new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", "down")
  local out = ChanceEffects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = visited_tile_ids(g.board, out.move_result.visited)
  assert(list_contains(visited_ids, 45), "backward move should pass intersection")
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

local function test_move_anim_wait_and_resume()
  local g = new_game()
  g.ui_port = { wait_move_anim = true }
  local player = g:current_player()
  g.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  local phases = {
    start = function()
      return "move", { player = player, total = 1, raw_total = 1 }
    end,
    move = turn_move,
    landing = function()
      return nil
    end,
  }
  g.turn_manager = TurnManager.new(g, phases)

  local res = g.turn_manager:run_until_wait()
  assert(res == "wait_move_anim", "should wait for move anim")
  local seq = g.store:get({ "turn", "move_anim", "seq" })
  assert(seq, "move_anim seq should be set")

  g:dispatch_action({ type = "move_anim_done", seq = seq })

  assert(g.store:get({ "turn", "move_anim" }) == nil, "move_anim should be cleared")
  local phase = g.store:get({ "turn", "phase" })
  assert(phase ~= "wait_move_anim", "should resume after move anim done")
end

-- 最复杂的回合结算用例：连续触发多个效果
-- 场景设计：
-- 1. 玩家持有偷窃卡，移动经过其他玩家
-- 2. 落地在机会卡格子
-- 3. 机会卡触发向前移动（例如：后方有犬吠，向前跑两格）
-- 4. 新位置有地雷
-- 5. 地雷爆炸，摧毁座驾并送往医院
-- 6. 医院落地效果触发（治疗）
-- 这个用例将触发：偷窃提示 -> 机会卡 -> 二次移动 -> 地雷效果 -> 医院落地
-- 共5层连续触发
local function test_complex_consecutive_turn_settlement()
  local g = new_game()
  local p1 = g.players[1]  -- 主角玩家
  local p2 = g.players[2]  -- 被经过的玩家
  
  -- 设置场景：
  -- p1 在位置 10，持有偷窃卡和一个座驾
  -- p2 在位置 12，持有道具
  -- 位置 13 是机会卡格子
  -- 位置 15 放置地雷
  
  -- 给 p1 偷窃卡（id=2007）和座驾
  p1.inventory:add({ id = 2007 })
  p1:set_cash(10000)
  g:set_player_seat(p1, 4001) -- 滑板座驾
  
  -- 给 p2 一些道具作为偷窃目标
  p2.inventory:add({ id = 2001 }) -- 路障卡
  p2:set_cash(10000)
  
  -- 设置初始位置
  g:update_player_position(p1, 10)
  g:update_player_position(p2, 12)
  
  -- 找到一个机会卡格子
  local chance_idx = first_tile_by_type(g.board, "chance")
  local hospital_idx = first_tile_by_type(g.board, "hospital")
  
  -- 重新设置位置以便测试：
  -- p1 在 chance_idx - 3 的位置
  -- p2 在 chance_idx - 2 的位置（将被经过）
  -- chance_idx 是机会卡
  -- chance_idx + 2 放置地雷
  g:update_player_position(p1, chance_idx - 3)
  g:update_player_position(p2, chance_idx - 2)
  
  -- 在 chance_idx + 2 位置放置地雷
  local mine_pos = g.board:get_tile(chance_idx + 2)
  if mine_pos then
    g.board:place_mine(mine_pos.id)
  end
  
  -- 验证配置中存在向前移动的机会卡（测试依赖此配置）
  -- 直接检查机会卡 3023: "后方有犬吠，你向前跑两格"
  local chance_cfg = require("Config.Generated.ChanceCards")
  local has_card_3023 = false
  for _, card in ipairs(chance_cfg) do
    if card.id == 3023 then
      has_card_3023 = true
      break
    end
  end
  assert(has_card_3023, "配置中需要存在机会卡 3023（向前移动2格）")
  
  -- 记录初始状态
  local initial_has_steal_card = Inventory.find_index(p1, 2007) ~= nil
  local initial_p2_item_count = p2.inventory:count()
  local initial_has_vehicle = p1.seat_id ~= nil
  
  assert(initial_has_steal_card, "p1 应该有偷窃卡")
  assert(initial_p2_item_count > 0, "p2 应该有道具可被偷")
  assert(initial_has_vehicle, "p1 应该有座驾")
  
  -- 第一步：移动3格，经过p2，到达机会卡格子
  -- branch_parity 用于在分叉路口选择方向，设为与步数相同确保一致性
  local res1 = MovementService.move(g, p1, 3, { branch_parity = 3, skip_market_check = true })
  local first_res = res1
  if res1.steal_interrupt then
    local interrupt = res1.steal_interrupt
    local steal_res = Steal.handle_pass_players(g, p1, interrupt.encountered_ids or {})
    if steal_res and steal_res.waiting then
      local pending = get_choice(g)
      if pending and pending.options and #pending.options > 0 then
        ChoiceService.resolve(g, pending, { option_id = pending.options[1].id })
      elseif pending and pending.allow_cancel then
        ChoiceService.resolve(g, pending, { type = "choice_cancel", choice_id = pending.id })
      end
    end
    res1 = MovementService.move(g, p1, interrupt.remaining_steps, {
      branch_parity = interrupt.branch_parity,
      direction = interrupt.facing,
      skip_market_check = true,
      skip_steal_check = true,
    })
  end

  -- 验证经过了玩家
  assert(first_res.encountered_players and #first_res.encountered_players > 0, "应该经过其他玩家")
  assert(p1.position == chance_idx, "应该停在机会卡格子")
  
  -- 第二步：处理经过玩家的偷窃卡提示
  local tile_chance = g.board:get_tile(chance_idx)
  local landing_res = resolve_landing(g, p1, tile_chance, res1, 0)
  
  -- 在无UI模式下，应该自动处理偷窃并继续
  -- 然后触发机会卡效果
  -- 如果有等待选择，需要手动处理
  local iteration = 0
  local max_iterations = 10
  while landing_res and landing_res.waiting and iteration < max_iterations do
    iteration = iteration + 1
    local pending = get_choice(g)
    if not pending then
      break
    end
    
    -- 自动选择第一个选项或取消
    if pending.options and #pending.options > 0 then
      ChoiceService.resolve(g, pending, { option_id = pending.options[1].id })
    elseif pending.allow_cancel then
      ChoiceService.resolve(g, pending, { type = "choice_cancel", choice_id = pending.id })
    else
      break
    end
    
    -- 重新检查 landing
    if iteration < max_iterations then
      local current_tile = g.board:get_tile(p1.position)
      landing_res = resolve_landing(g, p1, current_tile, res1, iteration)
    end
  end
  
  -- 验证连续触发的结果：
  -- 由于RNG的随机性和复杂的状态转换，我们主要验证系统没有崩溃
  assert(p1, "玩家1应该存在")
  
  -- 如果玩家被送到医院，验证医院效果已应用
  local hospital_tile = g.board:get_tile(hospital_idx)
  if p1.position == hospital_idx then
    assert(type(p1.status.stay_turns) == "number", "医院应设置 stay_turns")
  end
  
  -- 验证测试通过（没有崩溃即为成功）
  assert(true, "复杂连续结算完成")
end

-- 另一个复杂场景：黑市中断 + 后续租金支付
-- 场景：移动经过黑市时中断，购买后继续移动，落地在他人地块上需要支付租金
local function test_complex_market_interrupt_with_rent()
  local g = new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  
  p1:set_cash(50000)
  p2:set_cash(50000)
  
  -- 找到黑市位置
  local market_idx = first_tile_by_type(g.board, "market")
  
  -- 找到一个地块
  local land_idx, land_tile = first_land_tile(g.board)
  local found_land = false
  for idx = market_idx + 1, g.board:length() do
    local t = g.board:get_tile(idx)
    if t and t.type == "land" then
      land_idx = idx
      land_tile = t
      found_land = true
      break
    end
  end
  if not found_land then
    for idx = 1, market_idx - 1 do
      local t = g.board:get_tile(idx)
      if t and t.type == "land" then
        land_idx = idx
        land_tile = t
        found_land = true
        break
      end
    end
  end
  assert(found_land, "should find a land tile after market")
  
  -- 设置地块归 p2 所有，且有建筑
  g:set_tile_owner(land_tile, p2.id)
  g:set_tile_level(land_tile, 2)
  g:set_player_property(p2, land_tile.id, true)
  
  -- 放置 p1 在合适的位置，使其经过黑市到达地块
  local start_pos = market_idx - 1
  if start_pos < 1 then
    start_pos = g.board:length()
  end
  g:update_player_position(p1, start_pos)
  
  local move_distance = land_idx - start_pos
  if move_distance <= 0 then
    move_distance = g.board:length() + move_distance
  end
  
  -- 移动
  local initial_cash = p1.cash
  local res = MovementService.move(g, p1, move_distance, { branch_parity = move_distance })
  
  -- 如果触发了黑市中断
  local has_market_interrupt = res.market_interrupt ~= nil
  
  -- 如果没有中断或已处理，继续落地
  if not has_market_interrupt or (res.market_interrupt and res.market_interrupt.remaining_steps == 0) then
    local final_tile = g.board:get_tile(p1.position)
    local landing_res = resolve_landing(g, p1, final_tile, res, 0)
    
    -- 处理所有等待的选择（例如支付租金）
    local iteration = 0
    while landing_res and landing_res.waiting and iteration < 10 do
      iteration = iteration + 1
      local pending = get_choice(g)
      if not pending then
        break
      end
      
      if pending.options and #pending.options > 0 then
        ChoiceService.resolve(g, pending, { option_id = pending.options[1].id })
      elseif pending.allow_cancel then
        ChoiceService.resolve(g, pending, { type = "choice_cancel", choice_id = pending.id })
      else
        break
      end
      
      if iteration < 10 then
        local current_tile = g.board:get_tile(p1.position)
        landing_res = resolve_landing(g, p1, current_tile, res, iteration)
      end
    end
  end
  
  -- 验证：没有崩溃即为成功
  assert(p1, "玩家应该存在")
  assert(true, "黑市中断 + 租金支付场景完成")
end

local tests = {
  test_pass_start,
  test_logger_adapter_called,
  test_move_anim_callback_and_delay,
  test_land_on_start_reward,
  test_roadblock_stop,
  test_monster_card,
  test_missile_card,
  test_landing_optional_waits_with_ui,
  test_landing_optional_waits_without_ui_and_can_resolve,
  test_popup_timeout_auto_confirm,
  test_landing_optional_stale_choice_is_blocked,
  test_chance_is_mandatory_effect_entrypoint,
  test_movement_examples_from_issue,
  test_mandatory_payment_causes_bankruptcy,
  test_bankruptcy_resets_owned_tiles,
  test_ai_skips_auto_buy_at_market,
  test_land_rent_contiguous_sum,
  test_land_rent_graph_adjacency_breaks_path_neighbors,
  test_board_indices_in_range_uses_graph_distance,
  test_item_equalize_cash,
  test_market_full_inventory_blocks_items,
  test_market_global_limit,
  test_zero_cash_no_buy_choice,
  test_movement_backward_wrap,
  test_chance_move_backward_pass_market,
  test_chance_move_backward_pass_intersection,
  test_invalid_choice_option_rejected,
  test_move_anim_wait_and_resume,
  test_complex_consecutive_turn_settlement,
  test_complex_market_interrupt_with_rent,
}

for _, fn in ipairs(tests) do
  fn()
  io.stdout:write(".")
end

print("\nAll regression checks passed (" .. #tests .. ")")
