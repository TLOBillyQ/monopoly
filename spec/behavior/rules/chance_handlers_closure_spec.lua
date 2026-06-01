-- Mutation-closure pins for src/rules/chance/handlers.lua.
-- Targets the boundary/branch survivors not already covered by chance_spec,
-- chance_asset_handlers_spec, and chance_cash_others_contract_spec:
--   * adjust_chance_delta deity cross-cases (rich only doubles gains, poor
--     only doubles payments) and the gain/payment sign split,
--   * handle_bankruptcy_if_non_positive's `> 0` boundary,
--   * _apply_to_all_players eliminated-skip and _dispatch_payment angel-skip,
--   * pay_others mountain-skip and payer-bankruptcy break,
--   * collect_from_others liquid cap, mountain-skip, and the
--     total_collected > 0 anim guard.
-- Routed by architect (agent_context/rules-mutation-bootstrap-debt.md).
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local chance_handlers = require("src.rules.chance.handlers")
local asset_handlers = require("src.rules.chance.handlers")._asset
local movement = require("src.rules.movement")
local event_feed = require("src.rules.ports.event_feed")
local monopoly_event = require("src.foundation.events")
local config_reset = require("spec.support.config_reset")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _game(players)
  return support.new_game({ map = default_map, players = players or { "P1", "P2" } })
end

local function _balance(game, player)
  return game:player_balance(player, "金币")
end

describe("chance handlers closure", function()
  before_each(function() config_reset.reset_all() end)

  -- adjust_chance_delta deity cross-cases ----------------------------------

  it("add_cash: rich doubles a gain", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_deity(p, "rich", 3)
    local before = _balance(g, p)
    h.add_cash(g, p, { effect = "add_cash", amount = 1000, target = "self" })
    _assert_eq(_balance(g, p) - before, 2000, "rich deity doubles a positive delta")
  end)

  it("add_cash: rich doubles even a single-coin gain", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_deity(p, "rich", 3)
    local before = _balance(g, p)
    h.add_cash(g, p, { effect = "add_cash", amount = 1, target = "self" })
    _assert_eq(_balance(g, p) - before, 2, "a gain of one coin is still > 0 and must double")
  end)

  it("add_cash: poor does not double a gain", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_deity(p, "poor", 3)
    local before = _balance(g, p)
    h.add_cash(g, p, { effect = "add_cash", amount = 1000, target = "self" })
    _assert_eq(_balance(g, p) - before, 1000, "poor deity must not touch gains")
  end)

  it("add_cash target=all skips eliminated players", function()
    local g = _game({ "P1", "P2", "P3" })
    local h = chance_handlers.build()
    g.players[2].eliminated = true
    local before2 = _balance(g, g.players[2])
    local before3 = _balance(g, g.players[3])
    h.add_cash(g, g.players[1], { effect = "add_cash", amount = 1000, target = "all" })
    _assert_eq(_balance(g, g.players[2]) - before2, 0, "eliminated player is not credited")
    _assert_eq(_balance(g, g.players[3]) - before3, 1000, "live player is credited")
  end)

  it("pay_cash: poor doubles a payment", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_cash(p, 99999)
    g:set_player_deity(p, "poor", 3)
    local before = _balance(g, p)
    h.pay_cash(g, p, { effect = "pay_cash", amount = 1000, target = "self" })
    _assert_eq(_balance(g, p) - before, -2000, "poor deity doubles a negative delta")
  end)

  it("pay_cash: rich does not double a payment", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_cash(p, 99999)
    g:set_player_deity(p, "rich", 3)
    local before = _balance(g, p)
    h.pay_cash(g, p, { effect = "pay_cash", amount = 1000, target = "self" })
    _assert_eq(_balance(g, p) - before, -1000, "rich deity must not touch payments")
  end)

  -- _dispatch_payment angel-skip (target=all) ------------------------------

  it("pay_cash target=all skips an angel player only for a negative card", function()
    local g = _game({ "P1", "P2", "P3" })
    local h = chance_handlers.build()
    for _, p in ipairs(g.players) do g:set_player_cash(p, 99999) end
    g:set_player_deity(g.players[2], "angel", 3)
    local before2 = _balance(g, g.players[2])
    local before3 = _balance(g, g.players[3])
    h.pay_cash(g, g.players[1], { effect = "pay_cash", amount = 1000, target = "all", negative = true })
    _assert_eq(_balance(g, g.players[2]) - before2, 0, "angel blocks a negative chance charge")
    _assert_eq(_balance(g, g.players[3]) - before3, -1000, "non-angel player still pays")
  end)

  it("pay_cash target=all still charges an angel player for a non-negative card", function()
    local g = _game()
    local h = chance_handlers.build()
    for _, p in ipairs(g.players) do g:set_player_cash(p, 99999) end
    g:set_player_deity(g.players[2], "angel", 3)
    local before2 = _balance(g, g.players[2])
    h.pay_cash(g, g.players[1], { effect = "pay_cash", amount = 1000, target = "all", negative = false })
    _assert_eq(_balance(g, g.players[2]) - before2, -1000, "angel only protects against negative cards")
  end)

  -- handle_bankruptcy_if_non_positive boundary -----------------------------

  it("a payment that lands on exactly zero eliminates the player", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_cash(p, 1000)
    h.pay_cash(g, p, { effect = "pay_cash", amount = 1000, target = "self" })
    _assert_eq(_balance(g, p), 0, "balance reaches zero")
    _assert_eq(p.eliminated, true, "zero balance is non-positive -> eliminated")
  end)

  it("a payment that leaves a positive balance does not eliminate", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:set_player_cash(p, 1001)
    h.pay_cash(g, p, { effect = "pay_cash", amount = 1000, target = "self" })
    _assert_eq(_balance(g, p), 1, "one coin remains")
    _assert_eq(p.eliminated or false, false, "positive balance survives")
  end)

  -- pay_others branches ----------------------------------------------------

  it("pay_others does not pay a recipient who is in the mountain", function()
    local g = _game()
    local h = chance_handlers.build()
    local payer, other = g.players[1], g.players[2]
    g:set_player_cash(payer, 99999)
    local mountain = g.board:find_first_by_type("mountain")
    g:player_relocate(other, { destination_index = mountain, move_dir_mode = "clear" })
    local before = _balance(g, other)
    h.pay_others(g, payer, { effect = "pay_others", amount = 3000, target = "self" })
    _assert_eq(_balance(g, other) - before, 0, "a recipient in the mountain receives nothing")
  end)

  it("pay_others stops distributing once the payer goes bankrupt", function()
    local g = _game({ "P1", "P2", "P3", "P4" })
    local h = chance_handlers.build()
    local payer = g.players[1]
    g:set_player_cash(payer, 3000) -- only enough for one recipient
    local before = {}
    for i = 2, 4 do before[i] = _balance(g, g.players[i]) end
    h.pay_others(g, payer, { effect = "pay_others", amount = 3000, target = "self" })
    _assert_eq(payer.eliminated, true, "payer goes bankrupt after the first payment")
    _assert_eq(_balance(g, g.players[2]) - before[2], 3000, "first recipient is paid")
    _assert_eq(_balance(g, g.players[3]) - before[3], 0, "distribution breaks before the second recipient")
    _assert_eq(_balance(g, g.players[4]) - before[4], 0, "distribution breaks before the third recipient")
  end)

  -- collect_from_others branches -------------------------------------------

  it("collect_from_others caps the actor's gain at the target's liquidity", function()
    local g = _game()
    local h = chance_handlers.build()
    local actor, other = g.players[1], g.players[2]
    g:set_player_cash(other, 500)
    local actor_before = _balance(g, actor)
    h.collect_from_others(g, actor, { effect = "collect_from_others", amount = 3000, target = "self" })
    _assert_eq(_balance(g, actor) - actor_before, 500, "actor only receives what the target can liquidate")
    _assert_eq(other.eliminated, true, "the target is still charged the full fee and goes bankrupt")
  end)

  it("collect_from_others collects nothing while the collector is in the mountain", function()
    local g = _game()
    local h = chance_handlers.build()
    local actor, other = g.players[1], g.players[2]
    g:set_player_cash(other, 99999)
    local mountain = g.board:find_first_by_type("mountain")
    g:player_relocate(actor, { destination_index = mountain, move_dir_mode = "clear" })
    local before = _balance(g, other)
    h.collect_from_others(g, actor, { effect = "collect_from_others", amount = 3000, target = "self" })
    _assert_eq(_balance(g, other) - before, 0, "a collector in the mountain collects nothing")
  end)

  it("collect_from_others queues no summary anim when nothing is collected", function()
    local g = _game()
    local h = chance_handlers.build()
    local actor, other = g.players[1], g.players[2]
    g:set_player_cash(other, 99999)
    local mountain = g.board:find_first_by_type("mountain")
    g:player_relocate(actor, { destination_index = mountain, move_dir_mode = "clear" })
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    h.collect_from_others(g, actor, { effect = "collect_from_others", amount = 3000, target = "self" })
    _assert_eq(g.turn.action_anim, nil, "total_collected == 0 must not queue a cash_receive anim")
  end)

  -- collect_from_others total_collected > 0 boundary -----------------------

  it("collect_from_others queues the summary anim when exactly one coin is collected", function()
    local g = _game()
    local h = chance_handlers.build()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local actor, other = g.players[1], g.players[2]
    g:set_player_cash(other, 1) -- liquidity caps the collection at exactly 1
    h.collect_from_others(g, actor, { effect = "collect_from_others", amount = 3000, target = "self" })
    assert(g.turn.action_anim ~= nil, "total_collected == 1 is > 0 and must queue a cash_receive anim")
    _assert_eq(g.turn.action_anim.kind, "cash_receive", "summary anim is a cash_receive")
    _assert_eq(g.turn.action_anim.amount, 1, "summary anim carries the collected total")
  end)

  -- move_steps chance_move anim source -------------------------------------

  it("move_forward tags the move_anim payload with the chance_move source", function()
    local g = _game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = true }
    local h = chance_handlers.build()
    local p = g.players[1]
    h.move_forward(g, p, { effect = "move_forward", steps = 3 })
    assert(g.turn.move_anim ~= nil, "open move_anim gate routes the move onto the move_anim channel")
    _assert_eq(g.turn.move_anim.source, "chance_move", "chance moves identify their anim source")
  end)

  -- move_backward move_opts + allow_optional -------------------------------

  it("move_backward drives movement with the relative_backward facing and market skip", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    local captured
    _with_patches({
      { target = movement, key = "move", value = function(_, _, steps, opts)
          captured = { steps = steps, opts = opts }
          return { visited = {}, steps = steps }
        end },
    }, function()
      h.move_backward(g, p, { effect = "move_backward", steps = 2 }, { arrival_direction = "down" })
    end)
    _assert_eq(captured.opts.facing_mode, "relative_backward", "backward moves use relative_backward facing")
    _assert_eq(captured.opts.skip_market_check, true, "backward moves skip the market check")
    _assert_eq(captured.opts.direction, "down", "an arrival_direction context seeds the move direction")
  end)

  it("move_backward tolerates a nil context without indexing it", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    local ok = pcall(function()
      _with_patches({
        { target = movement, key = "move", value = function(_, _, steps)
            return { visited = {}, steps = steps }
          end },
      }, function()
        h.move_backward(g, p, { effect = "move_backward", steps = 1 }, nil)
      end)
    end)
    assert(ok, "the context guard must short-circuit before indexing a nil context")
  end)

  it("move_backward marks its move_result as optional", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    g:update_player_position(p, g.board:index_of_tile_id(32))
    g:set_player_status(p, "move_dir", "down")
    local out = h.move_backward(g, p, { effect = "move_backward", steps = 2 }, {})
    assert(out and out.move_result, "move_backward returns a move result")
    _assert_eq(out.move_result.allow_optional, true, "backward landings are optional")
  end)

  -- forced_move teleport classification ------------------------------------

  it("forced_move into the mountain queues a forced relocation anim", function()
    local g = _game()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local h = chance_handlers.build()
    local p = g.players[1]
    local mountain = g.board:get_tile(g.board:find_first_by_type("mountain"))
    h.forced_move(g, p, { effect = "forced_move", destination_tile_id = mountain.id }, {})
    assert(g.turn.action_anim ~= nil, "forced_move queues an anim")
    _assert_eq(g.turn.action_anim.kind, "forced_relocation",
      "a mountain destination is a teleport tile and uses forced_relocation")
  end)

  -- emit_event event_feed publication guard --------------------------------

  it("emit_event publishes a chance_card feed entry when the payload carries text", function()
    local g = _game()
    local h = chance_handlers.build()
    local p = g.players[1]
    local published = {}
    _with_patches({
      { target = event_feed, key = "publish", value = function(_, entry)
          published[#published + 1] = entry
        end },
    }, function()
      h.add_cash(g, p, { effect = "add_cash", amount = 100, target = "self" })
    end)
    _assert_eq(#published, 1, "a string-text payload publishes exactly one feed entry")
    _assert_eq(published[1].kind, "chance_card", "the feed entry is tagged as a chance card")
    assert(type(published[1].text) == "string" and #published[1].text > 0,
      "the published entry carries the payload text")
  end)
end)

-- Asset-handler boundary pins, exercised through the injected common port so
-- the destroy/discard arithmetic can be observed without a full game.
describe("chance asset handler closure", function()
  before_each(function() config_reset.reset_all() end)

  local function _events_common(deps_extra)
    local events = {}
    local common = {
      emit_event = function(_, _, payload) events[#events + 1] = payload end,
      dependencies = function()
        local deps = { monopoly_event = monopoly_event }
        for k, v in pairs(deps_extra or {}) do deps[k] = v end
        return deps
      end,
    }
    local handlers = {}
    asset_handlers.register(handlers, common)
    return handlers, events
  end

  -- destroy_buildings_on_path: (t.level or 0) > 0 boundary ------------------

  it("destroy_buildings_on_path destroys level-1 land and spares level-nil land", function()
    local handlers, events = _events_common()
    local destroyed = {}
    local game = {
      board = {
        get_tile = function(_, idx)
          if idx == 1 then return { type = "land", level = 1, name = "Lvl1" } end
          if idx == 2 then return { type = "land", name = "NoLevel" } end -- level is nil
          return { type = "chance", name = "Chance" }
        end,
      },
      set_tile_level = function(_, tile, level) destroyed[tile.name] = level end,
    }
    handlers.destroy_buildings_on_path(game, {}, {}, { visited = { 1, 2, 3 } })
    _assert_eq(#events, 1, "only the level-1 tile crosses the > 0 threshold")
    _assert_eq(events[1].tile.name, "Lvl1", "the destroyed tile is the one with a building")
    _assert_eq(destroyed["Lvl1"], 0, "the level-1 tile is razed to 0")
    _assert_eq(destroyed["NoLevel"], nil, "a nil-level tile defaults to 0 and is left untouched")
  end)

  -- discard_items: count==0 drops the whole inventory ----------------------

  local function _inventory_deps(item_ids)
    return {
      inventory = {
        count = function() return #item_ids end,
        remove_by_index = function(_, idx) return { id = table.remove(item_ids, idx) } end,
        item_name = function(id) return "Item" .. tostring(id) end,
      },
    }
  end

  local function _rng_game()
    return { rng = { next_int = function(_, lo) return lo end } }
  end

  it("discard_items with count 0 drops every item the player holds", function()
    local item_ids = { 10, 20 }
    local handlers, events = _events_common(_inventory_deps(item_ids))
    handlers.discard_items(_rng_game(), { name = "P" }, { effect = "discard_items", count = 0 })
    _assert_eq(#item_ids, 0, "count==0 resolves to the full inventory size and drains it")
    _assert_eq(#events, 1, "one summary event is emitted")
    assert(events[1].text:find("2 张", 1, true), "the summary reports two discarded items")
  end)

  it("discard_items lists the dropped names only when at least one item is dropped", function()
    local item_ids = { 10 }
    local handlers, events = _events_common(_inventory_deps(item_ids))
    handlers.discard_items(_rng_game(), { name = "P" }, { effect = "discard_items", count = 1 })
    assert(events[1].text:find(": ", 1, true), "dropping one item appends the name list")
  end)

  it("discard_items omits the name list when nothing is dropped", function()
    local item_ids = {}
    local handlers, events = _events_common(_inventory_deps(item_ids))
    handlers.discard_items(_rng_game(), { name = "P" }, { effect = "discard_items", count = 2 })
    _assert_eq(events[1].text:find(": ", 1, true), nil, "an empty drop must not append a name list separator")
  end)
end)
