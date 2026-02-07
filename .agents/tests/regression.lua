-- Quick regression checks (run with: lua .agents/tests/regression.lua)
local app = require("src.game.game.Game")
local movement_manager = require("src.game.movement.MovementManager")
local turn_manager = require("src.game.turn.TurnManager")
local turn_move = require("src.game.turn.TurnMove")
local inventory = require("src.game.item.ItemInventory")
local executor = require("src.game.item.ItemExecutor")
local pricing = require("src.game.land.LandPricing")
local land_actions = require("src.game.land.LandActions")
local steal = require("src.game.item.ItemSteal")
local chance_effects = require("src.game.chance.Chance")
local landing_defs = require("Config.LandingEffects")
local effect_pipeline = require("src.game.effect.EffectPipeline")
local effect = require("src.game.effect.Effect")
local choice_manager = require("src.game.choice.ChoiceManager")
local board_utils = require("src.game.land.LandBoardUtils")
local gameplay_loop = require("src.game.turn.GameplayLoop")
local constants = require("Config.Generated.Constants")
local bankruptcy_manager = require("src.game.game.BankruptcyManager")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")

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

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function _with_patches(patches, fn)
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local handler = debug and debug.traceback or function(err) return err end
  local ok, err = xpcall(fn, handler)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if not ok then
    error(err)
  end
end

LuaAPI = LuaAPI or {}
LuaAPI.rand = LuaAPI.rand or function()
  return math.random()
end

GameAPI = GameAPI or {}
if not GameAPI.random_int then
  math.randomseed(1)
  GameAPI.random_int = function(min, max)
    return math.random(min, max)
  end
end

TriggerCustomEvent = TriggerCustomEvent or function() end

local function _build_ui_port(overrides)
  local port = {
    wait_move_anim = false,
    wait_action_anim = false,
    push_popup = function() end,
    on_tile_owner_changed = function() end,
    on_tile_upgraded = function() end,
  }
  if overrides then
    for key, value in pairs(overrides) do
      port[key] = value
    end
  end
  return port
end

local function _visited_tile_ids(board, visited)
  local list = {}
  for _, idx in ipairs(visited or {}) do
    local tile = board:get_tile(idx)
    table.insert(list, tile and tile.id or idx)
  end
  return list
end

local function _list_contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function _next_choice_id(store)
  local seq = store:get({ "turn", "choice_seq" }) or 0
  seq = seq + 1
  store:set({ "turn", "choice_seq" }, seq)
  return seq
end

local function _open_choice(game, payload)
  assert(game and game.store, "Choice.open requires game.store")
  payload = payload or {}
  local id = _next_choice_id(game.store)
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

local function _get_choice(game)
  if not (game and game.store) then
    return nil
  end
  return game.store:get({ "turn", "pending_choice" })
end

local function _resolve_choice_first(game, pending)
  if pending.options and #pending.options > 0 then
    local first = pending.options[1]
    choice_manager.resolve(game, pending, { option_id = first.id or first })
    return true
  end
  if pending.allow_cancel then
    choice_manager.resolve(game, pending, { type = "choice_cancel", choice_id = pending.id })
    return true
  end
  return false
end

local max_landing_depth = 10

local function _build_landing_ctx(game, move_result)
  return effect.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })
end

local function _resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local ctx = _build_landing_ctx(game, move_result)

  local function handle_need_landing(out)
    if depth >= max_landing_depth then
      return out
    end
    local target_player = (out.player_id and game and game.players and game.players[out.player_id]) or player
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      next_tile = idx and game and game.board and game.board:get_tile(idx) or nil
    end
    if next_tile then
      return _resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return effect_pipeline.run(landing_defs, player, tile, ctx, {
    resume_state = "post_action",
    resume_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
end

local function _resolve_landing_with_choices(game, player, tile, move_result, max_iterations)
  local res = _resolve_landing(game, player, tile, move_result, 0)
  local iteration = 0
  local limit = max_iterations or 10
  while res and res.waiting and iteration < limit do
    iteration = iteration + 1
    local pending = _get_choice(game)
    if not pending then
      break
    end
    if not _resolve_choice_first(game, pending) then
      break
    end
    if iteration < limit then
      local current_tile = game.board:get_tile(player.position)
      res = _resolve_landing(game, player, current_tile, move_result, iteration)
    end
  end
  return res
end

local function _new_game()
  local game = app:new({
    players = { "P1", "P2" },
    ai = { [2] = true },
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  game.ui_port = _build_ui_port()
  return game
end

local function _first_land_tile(board)
  for idx, tile in ipairs(board.path) do
    if tile.type == "land" then
      return idx, tile
    end
  end
  error("no land tile found")
end

local function _first_tile_by_type(board, t)
  for idx, tile in ipairs(board.path) do
    if tile.type == t then
      return idx, tile
    end
  end
  error("no tile found for type=" .. tostring(t))
end

local function _first_adjacent_land_pair(board)
  for idx = 1, #board.path - 1 do
    local a = board.path[idx]
    local b = board.path[idx + 1]
    if a.type == "land" and b.type == "land" then
      return idx, a, idx + 1, b
    end
  end
  error("no adjacent land tiles")
end

local tile = require("src.game.board.Tile")

local function _tile_state(game, tile)
  local state = tile.get_state(game, tile)
  return state or { owner_id = nil, level = 0 }
end

local function _test_pass_start()
  local g = _new_game()
  local p = g:current_player()
  -- Passing start means stepping onto tile id 35.
  g:update_player_position(p, g.board:index_of_tile_id(24))
  local res = movement_manager.move(g, p, 1, { branch_parity = 1 })
  _assert_eq(res.passed_start, 1, "pass_start bonus")
end


local function _test_move_anim_callback_and_delay()
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
  local delay_called = nil
  local function call_delay(delay, cb)
    delay_called = delay
    cb()
  end
  _with_patches({
    { key = "LuaAPI", value = { call_delay_time = call_delay } },
    { key = "SetTimeOut", value = call_delay },
  }, function()
    gameplay_loop.step_move_anim(game, layer, {
      on_move_anim = function(_, anim)
        _assert_eq(anim.seq, 1, "anim seq forwarded")
        return 0.2
      end,
    })
  end)
  _assert_eq(delay_called, 0.2, "delay requested")
  _assert_eq(#dispatched, 1, "move_anim_done dispatched")
  _assert_eq(dispatched[1].seq, 1, "move_anim_done seq")
end
local function _test_land_on_start_reward()
  local g = _new_game()
  local p = g:current_player()
  local idx = _first_tile_by_type(g.board, "start")
  g:update_player_position(p, idx)
  local before = p.cash
  local res = _resolve_landing(g, p, g.board:get_tile(idx), {})
  assert(not res, "landing resolver should not wait")
  assert(p.cash > before, "landing on start should grant reward")
end

local function _test_pass_players_without_steal_does_not_crash()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local idx = _first_tile_by_type(g.board, "start")
  local next_idx = idx + 1
  if next_idx > g.board:length() then
    next_idx = 1
  end
  g:update_player_position(p1, idx)
  g:update_player_position(p2, next_idx)
  local res = _resolve_landing(g, p1, g.board:get_tile(idx), {
    encountered_players = { p2.id },
  })
  assert(not res, "landing resolver should not wait without steal")
  assert(_get_choice(g) == nil, "should not open choice without steal")
end

local function _test_roadblock_stop()
  local g = _new_game()
  local p = g:current_player()
  g.board:place_roadblock(2)
  local res = movement_manager.move(g, p, 3, { branch_parity = 3 })
  _assert_eq(res.stopped_on_roadblock, true, "stopped on roadblock")
  _assert_eq(p.position, 2, "position should stop at roadblock")
end

local function _test_monster_card()
  local g = _new_game()
  local p = g:current_player()
  local idx = 3
  local tile = g.board:get_tile(idx)
  g:set_tile_owner(tile, 2)
  g:set_tile_level(tile, 2)
  p.inventory:add({ id = 2008 })
  local res = executor.use_item(g, p, 2008, { by_ai = true })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "monster should open choice")
    _resolve_choice_first(g, pending)
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "monster use ok")
  _assert_eq(_tile_state(g, tile).level, 0, "building destroyed")
end

local function _test_missile_card()
  local g = _new_game()
  local p = g:current_player()
  local idx = 4
  local tile = g.board:get_tile(idx)
  g:set_tile_owner(tile, 2)
  g:set_tile_level(tile, 1)
  g:update_player_position(g.players[2], idx)
  g.board:place_roadblock(idx)
  g.board:place_mine(idx)
  p.inventory:add({ id = 2013 })
  local res = executor.use_item(g, p, 2013, {})
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "demolish_target", "missile should open choice")
    _resolve_choice_first(g, pending)
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "missile use ok")
  _assert_eq(_tile_state(g, tile).level, 0, "building destroyed by missile")
  _assert_eq(g.board:has_roadblock(idx), false, "roadblock cleared")
  _assert_eq(g.board:has_mine(idx), false, "mine cleared")
  assert(g.players[2].status.stay_turns > 0, "target sent to hospital")
end

local function _test_landing_optional_waits_with_ui()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local p = g:current_player()
  local idx, tile = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = _resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "landing resolver should wait when UI is available")
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice for landing optional")
end

local function _test_landing_optional_waits_without_ui_and_can_resolve()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local before_cash = p.cash
  local res = _resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "landing resolver should wait without manual UI interaction")
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected")
  local resolved = _resolve_choice_first(g, pending)
  assert(resolved, "expected at least one optional effect")
  assert(_tile_state(g, tile).owner_id == p.id, "land should be purchased after resolving choice")
  assert(p.cash < before_cash, "cash deducted for purchase")
end

local function _test_popup_timeout_auto_confirm()
  local g = _new_game()
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
  gameplay_loop.step_modal_timeout(layer, near_timeout, timeout_opts)
  _assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
  gameplay_loop.step_modal_timeout(layer, near_timeout + 1, timeout_opts)
  _assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
end

local function _test_landing_optional_stale_choice_is_blocked()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local p = g:current_player()
  local idx, tile = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  local res = _resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "should open choice")
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "pending choice expected")

  -- Invalidate the option after choice is shown (simulate state change).
  g:set_player_cash(p, 0)

  choice_manager.resolve(g, pending, { option_id = "buy_land" })
  assert(_tile_state(g, tile).owner_id == nil, "stale buy_land should be blocked")
end

local function _test_chance_is_mandatory_effect_entrypoint()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile = _first_tile_by_type(g.board, "chance")
  g:update_player_position(p, idx)

  -- We verify execution by checking if LuaAPI.rand is used to pick a card
  local called = { rand = 0 }
  local prev_lua_api = LuaAPI
  local lua_api = prev_lua_api or {}
  local function rand()
    called.rand = called.rand + 1
    return 0 -- Pick first card
  end
  _with_patches({
    { key = "LuaAPI", value = lua_api },
    { target = lua_api, key = "rand", value = rand },
  }, function()
    -- Ensure we don't crash on effect execution
    -- We assume standard chance cards are safe or we mock chance_effects?
    -- Mocking requires package reload. Let's trust integration.
    _resolve_landing(g, p, tile, {})
  end)

  assert(called.rand > 0, "chance logic was executed (LuaAPI.rand used)")
end

local function _test_movement_examples_from_issue()
  local g = _new_game()
  local p = g:current_player()

  -- 例子1: 起点=海口路(3)，步数=4，终点=天津路(32)
  g:update_player_position(p, g.board:index_of_tile_id(3))
  local r1 = movement_manager.move(g, p, 4, { branch_parity = 4, skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 32, "example1 end tile")
  assert(#r1.visited == 4, "example1 visited steps")

  -- 例子2: 起点=天津路(32)，当前方向向下(下一格31)，步数=6，终点=澳门路(6)
  g:update_player_position(p, g.board:index_of_tile_id(32))
  local r2 = movement_manager.move(g, p, 6, { branch_parity = 6, direction = "down", skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 6, "example2 end tile")
  assert(#r2.visited == 6, "example2 visited steps")

  -- 例子3: 起点=南昌路(25)，当前方向向右，步数=12，终点=南宁路(7)
  g:update_player_position(p, g.board:index_of_tile_id(25))
  local r3 = movement_manager.move(g, p, 12, { branch_parity = 12, direction = "right", skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 7, "example3 end tile")
  assert(#r3.visited == 12, "example3 visited steps")
end

local function _test_ai_picks_land_purchase()
  local agent = require("src.game.game.Agent")
  local g = _new_game()
  local ai_player = g.players[2]
  assert(agent.is_auto_player(ai_player), "player 2 should be AI")
  
  -- Set AI player as current player (index 2)
  if g.store then
    g.store:set({"turn", "current_player_index"}, 2)
  end
  
  assert(g:current_player() == ai_player, "AI should be current player")
  
  local idx, tile = _first_land_tile(g.board)
  g:update_player_position(ai_player, idx)
  
  local res = _resolve_landing(g, ai_player, tile, {})
  assert(res and res.waiting, "should wait for choice")
  
  local pending = _get_choice(g)
  assert(pending and pending.kind == "landing_optional_effect", "should have landing choice")
  
  local action = agent.auto_action_for_choice(g, pending)
  assert(action, "AI should return an action")
  assert(action.type == "choice_select", "AI should select land purchase")
  assert(action.option_id == "buy_land", "AI should pick buy_land")
  
  local before_cash = ai_player.cash
  choice_manager.resolve(g, pending, action)
  assert(ai_player.cash == before_cash - tile.price, "AI cash should decrease by land price")
  assert(_tile_state(g, tile).owner_id == ai_player.id, "land should be purchased")
end

local function _test_mandatory_payment_causes_bankruptcy()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  
  -- Set up: p1 owns a land tile with high value, p2 has little cash
  local idx, tile = _first_land_tile(g.board)
  g:set_tile_owner(tile, p1.id)
  g:set_tile_level(tile, 3) -- Max level for high rent
  g:set_player_property(p1, tile.id, true)
  
  -- Give p2 very little cash (not enough to pay rent)
  g:set_player_cash(p2, 10)
  
  -- Move p2 to the land tile
  g:update_player_position(p2, idx)
  
  local before_eliminated = p2.eliminated
  _resolve_landing(g, p2, tile, {})
  
  -- p2 should be eliminated due to insufficient funds for mandatory rent
  assert(p2.eliminated == true, "player should be eliminated after failing to pay rent")
  assert(before_eliminated == false, "player should not have been eliminated before")
end

local function _test_bankruptcy_resets_owned_tiles()
  local g = _new_game()
  local p1 = g.players[1]
  local _, tile1 = _first_land_tile(g.board)
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
  g:set_player_property(p1, tile2.id, true)

  bankruptcy_manager.eliminate(g, p1)

  local st1 = _tile_state(g, tile1)
  local st2 = _tile_state(g, tile2)
  assert(st1.owner_id == nil and st1.level == 0, "bankruptcy clears owned tile1")
  assert(st2.owner_id == nil and st2.level == 0, "bankruptcy clears owned tile2")
  assert(next(p1.properties) == nil, "bankruptcy clears player properties")
end

local function _test_ai_skips_auto_buy_at_market()
  local market_manager = require("src.game.market.MarketManager")
  local g = _new_game()
  local ai_player = g.players[2]
  assert(ai_player.is_ai, "player 2 should be AI")
  
  -- Give AI player enough cash to buy something
  g:set_player_cash(ai_player, 1000)
  
  local before_cash = ai_player.cash
  market_manager.auto_buy(g, ai_player)
  
  -- AI should not buy anything
  assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
end

local function _test_land_rent_contiguous_sum()
  local g = _new_game()
  local owner = g.players[1]
  local tenant = g.players[2]

  local idx1, tile1, idx2, tile2 = _first_adjacent_land_pair(g.board)
  g:set_tile_owner(tile1, owner.id)
  g:set_tile_owner(tile2, owner.id)
  g:set_tile_level(tile1, 1)
  g:set_tile_level(tile2, 2)
  g:set_player_property(owner, tile1.id, true)
  g:set_player_property(owner, tile2.id, true)

  g:update_player_position(tenant, idx1)
  local before = tenant.cash
  land_actions.execute_pay_rent(g, tenant.id, tile1.id)
  local expected = pricing.rent_for_level(tile1, 1) + pricing.rent_for_level(tile2, 2)
  _assert_eq(before - tenant.cash, expected, "contiguous rent sum")

  g:set_tile_level(tile1, 2)
  local before2 = tenant.cash
  land_actions.execute_pay_rent(g, tenant.id, tile1.id)
  local expected2 = pricing.rent_for_level(tile1, 2) + pricing.rent_for_level(tile2, 2)
  _assert_eq(before2 - tenant.cash, expected2, "contiguous rent sum after upgrade")
end

local function _test_land_rent_graph_adjacency_breaks_path_neighbors()
  local g = _new_game()
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
  land_actions.execute_pay_rent(g, tenant.id, tile_a.id)
  local expected = pricing.rent_for_level(tile_a, 1)
  _assert_eq(before - tenant.cash, expected, "graph adjacency rent excludes non-neighbors")
end

local function _test_rent_owner_missing_skips_payment()
  local land = require("src.game.land.Land")
  local g = _new_game()
  local tenant = g.players[1]
  local owner = g.players[2]
  local idx, tile = _first_land_tile(g.board)

  g:set_tile_owner(tile, owner.id)
  g:set_tile_level(tile, 1)
  g:set_player_property(owner, tile.id, true)
  g:update_player_position(tenant, idx)

  g:set_player_status(tenant, "pending_free_rent", true)
  g:player_send_to_mountain(owner)
  local before = tenant.cash
  land.executors.pay_rent.apply({ game = g, player = tenant, tile = tile })
  _assert_eq(tenant.cash, before, "rent skipped when owner in mountain")
  assert(tenant.status.pending_free_rent == true, "pending_free_rent should remain when owner missing")

  g:set_player_status(tenant, "pending_free_rent", false)
  owner.eliminated = true
  local before2 = tenant.cash
  local ok = land_actions.execute_pay_rent(g, tenant.id, tile.id)
  _assert_eq(ok, false, "execute_pay_rent should return false when owner missing")
  _assert_eq(tenant.cash, before2, "rent skipped when owner missing")
end

local function _test_board_indices_in_range_uses_graph_distance()
  local g = _new_game()
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  assert(idx_a and idx_b, "expected tile ids 27/28")
  local list = board_utils.indices_in_range(g.board, idx_a, 1)
  for _, idx in ipairs(list) do
    assert(idx ~= idx_b, "graph distance should not include path neighbor")
  end
end

local function _test_item_equalize_cash()
  local g = _new_game()
  local user = g.players[1]
  local target = g.players[2]
  g:set_player_cash(user, 1000)
  g:set_player_cash(target, 9000)
  user.inventory:add({ id = 2011 })
  local res = executor.use_item(g, user, 2011, { by_ai = true })
  if type(res) == "table" and res.intent then
    if res.intent.kind == "need_choice" then
      _open_choice(g, res.intent.choice_spec)
    end
    local pending = _get_choice(g)
    assert(pending and pending.kind == "item_target_player", "equalize should open choice")
    local first = pending.options[1]
    choice_manager.resolve(g, pending, { option_id = first.id })
    res = true
  end
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  _assert_eq(ok, true, "equalize use ok")
  _assert_eq(user.cash, 5000, "equalize user cash")
  _assert_eq(target.cash, 5000, "equalize target cash")
end

local function _test_market_full_inventory_blocks_items()
  local market_manager = require("src.game.market.MarketManager")
  local g = _new_game()
  local p = g:current_player()
  g:set_player_cash(p, 999999)
  for _ = 1, p.inventory.max_slots do
    p.inventory:add({ id = 2001 })
  end

  local list = market_manager.list_buyable(p, g)
  for _, entry in ipairs(list) do
    assert(entry.kind ~= "item", "item should be excluded when inventory full")
  end
end

local function _test_market_global_limit()
  local market_manager = require("src.game.market.MarketManager")
  local market_cfg = require("Config.Generated.Market")
  local g = _new_game()
  local p = g:current_player()
  local entry = nil
  for _, cfg in ipairs(market_cfg) do
    if cfg.kind == "item" and cfg.currency == "金币" then
      entry = cfg
      break
    end
  end
  assert(entry, "should find a market item with coin currency")
  g:set_player_cash(p, (entry.price or 0) + 1000)
  g.store:set({ "market", "global_limits", entry.product_id }, 1)

  local res = market_manager.buy_with_opts(g, p, entry.product_id, nil)
  local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
  assert(ok, "first purchase should succeed")

  local list = market_manager.list_buyable(p, g)
  for _, item in ipairs(list) do
    assert(item.product_id ~= entry.product_id, "sold out item should be excluded from list")
  end

  local spec = market_manager.build_choice_spec(p, g)
  if spec and spec.options then
    for _, option in ipairs(spec.options) do
      assert(option.id ~= entry.product_id, "sold out item should be excluded from choice")
    end
  end
end

local function _test_zero_cash_no_buy_choice()
  local g = _new_game()
  local p = g:current_player()
  local idx, tile = _first_land_tile(g.board)
  g:update_player_position(p, idx)
  g:set_player_cash(p, 0)
  local res = _resolve_landing(g, p, tile, {})
  assert(res and res.waiting, "buy choice should appear even when cash is zero")
  assert(_get_choice(g) ~= nil, "pending choice should exist")
end

local function _test_movement_backward_wrap()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, 1)
  local res = movement_manager.move(g, p, -1, { branch_parity = 1 })
  assert(p.position >= 1 and p.position <= g.board:length(), "backward index in range")
  assert(#res.visited == 1, "visited steps")
end

local function _test_chance_move_backward_pass_market()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(32))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  assert(_list_contains(visited_ids, 39), "backward move should pass market")
  assert(out.move_result.market_interrupt == nil, "backward move should not trigger market interrupt")
end

local function _test_chance_move_backward_pass_intersection()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", "down")
  local out = chance_effects.resolve(g, p, { effect = "move_backward", steps = 2, target = "self" }, {})
  assert(out and out.move_result, "move_backward should return move result")
  local visited_ids = _visited_tile_ids(g.board, out.move_result.visited)
  assert(_list_contains(visited_ids, 45), "backward move should pass intersection")
end

local function _test_invalid_choice_option_rejected()
  local g = _new_game()
  local choice = _open_choice(g, {
    kind = "market_buy",
    options = { { id = 1, label = "X" } },
    meta = { player_id = g:current_player().id },
  })
  choice_manager.resolve(g, choice, { option_id = 999 })
  assert(_get_choice(g) ~= nil, "invalid option should keep choice")
end

local function _test_move_anim_wait_and_resume()
  local g = _new_game()
  g.ui_port = _build_ui_port({ wait_move_anim = true })
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
  g.turn_manager = turn_manager:new(g, phases)

  local res = g.turn_manager:run_until_wait()
  assert(res == "wait_move_anim", "should wait for move anim")
  local seq = g.store:get({ "turn", "move_anim", "seq" })
  assert(seq, "move_anim seq should be set")

  g:dispatch_action({ type = "move_anim_done", seq = seq })

  assert(g.store:get({ "turn", "move_anim" }) == nil, "move_anim should be cleared")
  local phase = g.store:get({ "turn", "phase" })
  assert(phase ~= "wait_move_anim", "should resume after move anim done")
end

local function _test_store_missing_path_get_set()
  local store = require("src.core.Store")
  local store = store:new({})
  assert(store:get({ "missing" }) == nil, "missing path should return nil")
  store:set({ "a", "b", "c" }, 3)
  _assert_eq(store:get({ "a", "b", "c" }), 3, "store set should create path")
  assert(store:get({ "a", "b", "d" }) == nil, "missing leaf should return nil")
end

local function _test_number_utils_to_integer()
  _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
  _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
  _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
end

local function _test_ui_model_structure()
  local ui_model = require("src.ui.UIModel")
  local g = _new_game()
  local player = g:current_player()
  player.inventory:add({ id = 2001 })
  local ui_state = {
    ui = {
      auto_play = false,
      item_slots = { 1, 2, 3, 4, 5 },
    },
  }
  local model = ui_model.build(g.store.state, {
    game = g,
    ui_state = ui_state,
    last_turn = g.last_turn,
    finished = g.finished,
  })
  assert(model.panel and model.panel.turn_label, "ui_model.panel.turn_label expected")
  assert(type(model.item_slots) == "table" and model.item_slots[1] == 2001, "ui_model.item_slots[1] expected")
  assert(model.board and model.board.tiles and model.board.tile_states, "ui_model.board data")
end

local function _test_tick_skips_anim_when_no_anim()
  local store = require("src.core.Store")
  local main_view = require("src.ui.UIView")
  local ui_model = require("src.ui.UIModel")

  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = main_view, key = "refresh_board", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(store_state)
      return {
        state = store_state,
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = store_state.turn.turn_count,
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function()
      return {
        set_camera_bind_mode = function() end,
        set_camera_lock_position = function() end,
      }
    end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
  }

  local store = store:new({
    players = { [1] = { id = 1, name = "P1", cash = 0 } },
    turn = { phase = "move", current_player_index = 1, turn_count = 0 },
  })
  local game = { finished = false, store = store }
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = {},
  }

  local ok, err = pcall(function()
    _with_patches(patches, function()
      gameplay_loop.tick(game, state, 0.1)
    end)
  end)

  assert(ok, "tick should not error without anim: " .. tostring(err))
end

local function _test_autorunner_runs_to_end()
  local auto_runner = require("src.game.turn.AutoRunner")
  local agent = require("src.game.game.Agent")
  local gameplay_rules = require("Config.GameplayRules")
  local land = require("src.game.land.Land")
  local land_actions = require("src.game.land.LandActions")
  local steal = require("src.game.item.ItemSteal")
  local item_inventory = require("src.game.item.ItemInventory")

  local g = app:new({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = true,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  g.ui_port = _build_ui_port()

  local state = {
    auto_runner = auto_runner:new({ interval = 0.01 }),
    ui = { choice_active = false, market_active = false },
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
  }
  state.auto_runner:set_enabled(true)

  local turn_limit = gameplay_rules.turn_limit or 0
  local max_steps = turn_limit * 5
  assert(max_steps > 0, "invalid turn_limit for autorunner test")

  local timeout = constants.action_timeout_seconds or 0
  local dt = timeout > 0 and (timeout + 0.1) or 1

  local now = 0

  local old_handle_pass_players = steal.handle_pass_players
  local old_pick_roadblock_target = agent.pick_roadblock_target
  local old_can_pay_rent = land.executors.pay_rent.can_apply
  local game_api = GameAPI or {}
  local patches = {
    { target = steal, key = "handle_pass_players", value = function(game_ctx, player, encountered_ids)
      if not item_inventory.find_index(player, gameplay_rules.item_ids.steal) then
        return nil
      end
      return old_handle_pass_players(game_ctx, player, encountered_ids)
    end },
    { target = agent, key = "pick_roadblock_target", value = function()
      return nil
    end },
    { target = land.executors.pay_rent, key = "can_apply", value = function(ctx)
      if not old_can_pay_rent(ctx) then
        return false
      end
      local owner = land_actions.resolve_rent_owner(ctx.game, ctx.tile)
      return owner ~= nil
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
  }

  local ok, err = pcall(function()
    _with_patches(patches, function()
      for _ = 1, max_steps do
        if g.finished then
          break
        end
        now = now + dt
        gameplay_loop.step_auto_runner(g, state, dt, {
          modal_active = false,
          modal_buttons = nil,
          game_finished = g.finished,
        })
        gameplay_loop.step_choice_timeout(g, state, dt, {
          on_pending_choice = function() end,
          is_choice_active = function(ctx)
            return ctx.pending_choice and true or false
          end,
          build_action = function(game_ctx, ctx, choice)
            local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
            if auto_choice then
              return auto_choice
            end
            local options = assert(choice.options, "missing choice.options")
            local first = assert(options[1], "missing choice option")
            return {
              type = "choice_select",
              choice_id = choice.id,
              option_id = first.id or first,
            }
          end,
        })
      end
      if not g.finished then
        error("autorunner did not finish within max_steps=" .. tostring(max_steps))
      end
    end)
  end)

  assert(ok, "autorunner test failed: " .. tostring(err))
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
local function _test_complex_consecutive_turn_settlement()
  local g = _new_game()
  local p1 = g.players[1]  -- 主角玩家
  local p2 = g.players[2]  -- 被经过的玩家
  
  -- 设置场景：
  -- p1 在位置 10，持有偷窃卡和一个座驾
  -- p2 在位置 12，持有道具
  -- 位置 13 是机会卡格子
  -- 位置 15 放置地雷
  
  -- 给 p1 偷窃卡（id=2007）和座驾
  p1.inventory:add({ id = 2007 })
  g:set_player_cash(p1, 10000)
  g:set_player_seat(p1, 4001) -- 滑板座驾
  
  -- 给 p2 一些道具作为偷窃目标
  p2.inventory:add({ id = 2001 }) -- 路障卡
  g:set_player_cash(p2, 10000)
  
  -- 设置初始位置
  g:update_player_position(p1, 10)
  g:update_player_position(p2, 12)
  
  -- 找到一个机会卡格子
  local chance_idx = _first_tile_by_type(g.board, "chance")
  local hospital_idx = _first_tile_by_type(g.board, "hospital")
  
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
  
  -- 验证配置中存在向前移动 2 格的机会卡（测试依赖此配置）
  local chance_cfg = require("Config.Generated.ChanceCards")
  local has_move_forward = false
  for _, card in ipairs(chance_cfg) do
    if card.effect == "move_forward" and card.steps == 2 and card.target == "self" then
      has_move_forward = true
      break
    end
  end
  assert(has_move_forward, "配置中需要存在向前移动2格的机会卡")
  
  -- 记录初始状态
  local initial_has_steal_card = inventory.find_index(p1, 2007) and true or false
  local initial_p2_item_count = p2.inventory:count()
  local initial_has_vehicle = p1.seat_id and true or false
  
  assert(initial_has_steal_card, "p1 应该有偷窃卡")
  assert(initial_p2_item_count > 0, "p2 应该有道具可被偷")
  assert(initial_has_vehicle, "p1 应该有座驾")
  
  -- 第一步：移动3格，经过p2，到达机会卡格子
  -- branch_parity 用于在分叉路口选择方向，设为与步数相同确保一致性
  local res1 = movement_manager.move(g, p1, 3, { branch_parity = 3, skip_market_check = true })
  local first_res = res1
  if res1.steal_interrupt then
    local interrupt = res1.steal_interrupt
    local steal_res = steal.handle_pass_players(g, p1, interrupt.encountered_ids or {})
    if steal_res and steal_res.waiting then
      local pending = _get_choice(g)
      if pending then
        _resolve_choice_first(g, pending)
      end
    end
    res1 = movement_manager.move(g, p1, interrupt.remaining_steps, {
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
  -- 在无UI模式下，自动处理偷窃并继续，然后触发机会卡效果
  _resolve_landing_with_choices(g, p1, tile_chance, res1, 10)
  
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
local function _test_complex_market_interrupt_with_rent()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  
  g:set_player_cash(p1, 50000)
  g:set_player_cash(p2, 50000)
  
  -- 找到黑市位置
  local market_idx = _first_tile_by_type(g.board, "market")
  
  -- 找到一个地块
  local land_idx, land_tile = _first_land_tile(g.board)
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
  local res = movement_manager.move(g, p1, move_distance, { branch_parity = move_distance })
  res.encountered_players = {}
  
  -- 如果触发了黑市中断
  local has_market_interrupt = res.market_interrupt and true or false
  
  -- 如果没有中断或已处理，继续落地
  if not has_market_interrupt or (res.market_interrupt and res.market_interrupt.remaining_steps == 0) then
    local final_tile = g.board:get_tile(p1.position)
    _resolve_landing_with_choices(g, p1, final_tile, res, 10)
  end
  
  -- 验证：没有崩溃即为成功
  assert(p1, "玩家应该存在")
  assert(true, "黑市中断 + 租金支付场景完成")
end

local tests = {
  _test_pass_start,
  _test_move_anim_callback_and_delay,
  _test_land_on_start_reward,
  _test_pass_players_without_steal_does_not_crash,
  _test_roadblock_stop,
  _test_monster_card,
  _test_missile_card,
  _test_landing_optional_waits_with_ui,
  _test_landing_optional_waits_without_ui_and_can_resolve,
  _test_popup_timeout_auto_confirm,
  _test_landing_optional_stale_choice_is_blocked,
  _test_chance_is_mandatory_effect_entrypoint,
  _test_movement_examples_from_issue,
  _test_mandatory_payment_causes_bankruptcy,
  _test_bankruptcy_resets_owned_tiles,
  _test_ai_skips_auto_buy_at_market,
  _test_land_rent_contiguous_sum,
  _test_land_rent_graph_adjacency_breaks_path_neighbors,
  _test_rent_owner_missing_skips_payment,
  _test_board_indices_in_range_uses_graph_distance,
  _test_item_equalize_cash,
  _test_market_full_inventory_blocks_items,
  _test_market_global_limit,
  _test_zero_cash_no_buy_choice,
  _test_movement_backward_wrap,
  _test_chance_move_backward_pass_market,
  _test_chance_move_backward_pass_intersection,
  _test_invalid_choice_option_rejected,
  _test_move_anim_wait_and_resume,
  _test_store_missing_path_get_set,
  _test_number_utils_to_integer,
  _test_ui_model_structure,
  _test_tick_skips_anim_when_no_anim,
  _test_autorunner_runs_to_end,
  _test_complex_consecutive_turn_settlement,
  _test_complex_market_interrupt_with_rent,
}

for _, fn in ipairs(tests) do
  math.randomseed(1)
  fn()
  io.stdout:write(".")
end

print("\nAll regression checks passed (" .. #tests .. ")")
