local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local default_ports = require("src.turn.output.default_ports")
local compose_game = require("src.app.compose_game")
local game_factory = require("src.app.game_factory")
local movement = require("src.rules.movement")
local mine_effect = require("src.rules.effects.mine")
local roll_module = require("src.turn.phases.roll")
local dice_mult = require("src.turn.phases.dice_multiplier")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local inventory = require("src.rules.items.inventory")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

local driver = {}

local OUTER_RING_SIZE = 32

-- The black market's paid-currency purchase is a host-side gateway (real production
-- wires src.host.paid_purchase_gateway). Turn-flow scenarios never assert a market
-- purchase, but a played turn with an uncontrolled roll can incidentally route through
-- the off-ring market, and src/turn's market setup asserts a configured gateway — so
-- without one such a turn crashes. Install a no-op gateway in new_game so any incidental
-- market routing is a safe no-op, keeping play_turn robust to any roll. The paid_currency
-- / skin_shop suites reset_for_tests + configure their own gateway, so this never leaks
-- into their assertions.
local _NOOP_PAID_GATEWAY = {
  setup_for_game = function() end,
  can_start = function() return false, "acceptance_noop" end,
  start = function() return false, "acceptance_noop" end,
}

local function _build_queue_rng(queue)
  local index = 0
  return game_factory.build_rng(function(min, max)
    index = index + 1
    if index > #queue then
      return math.random(min, max)
    end
    return queue[index]
  end)
end

local function _build_event_capture_port(events)
  return {
    publish = function(_, _, event)
      events[#events + 1] = event
      return true
    end,
  }
end

function driver.new_game(opts)
  opts = opts or {}
  paid_purchase_port.configure(_NOOP_PAID_GATEWAY)
  local rng_queue = {}
  local captured_events = {}
  local game = compose_game.new_game(default_ports.resolve_game_opts({
    players = opts.players or {"P1", "P2", "P3", "P4"},
    ai = opts.ai or {[2] = true, [3] = true, [4] = true},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
    rng = _build_queue_rng(rng_queue),
  }))
  game.event_feed_port = _build_event_capture_port(captured_events)
  return {
    game = game,
    outer_ring_size = OUTER_RING_SIZE,
    _rng_queue = rng_queue,
    _events = captured_events,
  }
end

function driver.current_player(ctx)
  return ctx.game.players[1]
end

function driver.set_player_position(ctx, player, index)
  ctx.game:update_player_position(player, index)
end

function driver.clear_move_state(ctx, player)
  ctx.game:set_player_status(player, "move_dir", nil)
end

function driver.move(ctx, player, steps)
  return movement.move(ctx.game, player, steps)
end

function driver.set_next_rolls(ctx, values)
  ctx._rng_queue = values
  ctx.game.rng = _build_queue_rng(values)
end

function driver.player_position(_, player)
  return player.position
end

function driver.player_cash(ctx, player)
  return ctx.game:player_cash(player)
end

function driver.tile_at(ctx, index)
  return ctx.game.board:get_tile(index)
end

function driver.tile_owner(ctx, index)
  local tile = ctx.game.board:get_tile(index)
  if tile then
    return tile.owner_id
  end
  return nil
end

function driver.tile_level(ctx, index)
  local tile = ctx.game.board:get_tile(index)
  if tile then
    return tile.level
  end
  return nil
end

function driver.sync_outer_facing(ctx, player)
  local tile = ctx.game.board:get_tile(player.position)
  if not tile then return end
  local map = ctx.game.board.map
  local next_id = map.outer_next[tile.id]
  if next_id then
    ctx.game:set_player_status(player, "move_dir", map.direction(tile.id, next_id))
  end
end

function driver.place_roadblock(ctx, tile_id)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  ctx.game:place_roadblock(idx)
end

function driver.has_roadblock(ctx, tile_id)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  return ctx.game.board:has_roadblock(idx)
end

function driver.place_mine(ctx, tile_id, data)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  ctx.game:place_mine(idx, data)
end

function driver.has_mine(ctx, tile_id)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  return ctx.game.board:has_mine(idx)
end

function driver.set_tile_type(ctx, tile_id, tile_type)
  local idx = ctx.game.board:index_of_tile_id(tile_id)
  ctx.game.board:get_tile(idx).type = tile_type
end

function driver.set_player_deity(ctx, player, name, duration)
  ctx.game:set_player_deity(player, name, duration or 5)
end

function driver.tile_n_before_start(ctx, n)
  local map = ctx.game.board.map
  local id = map.start_id
  for _ = 1, n do
    id = map.outer_prev[id]
  end
  return ctx.game.board:index_of_tile_id(id)
end

function driver.set_player_facing(ctx, player, facing)
  ctx.game:set_player_status(player, "move_dir", facing)
end

function driver.move_with_opts(ctx, player, steps, opts)
  return movement.move(ctx.game, player, steps, opts)
end

function driver.try_trigger_mine(ctx, player)
  local pos = player.position
  if not mine_effect.can_trigger(ctx.game, player, pos) then
    return nil
  end
  local result = mine_effect.apply(ctx.game, player, pos)
  if result and result.hospitalized then
    ctx.game:player_apply_hospital_effects(player)
  end
  return result
end

function driver.events(ctx)
  return ctx._events
end

-- ── landing-settlement setup (cluster 3 support) ──────────────────────────────

-- Give a player a real inventory item by id (e.g. item_ids.free_rent / .strong),
-- so landing settlement sees a genuine card holding rather than a fixture flag.
function driver.give_item(_, player, item_id)
  inventory.add(player, { id = item_id })
end

function driver.has_item(_, player, item_id)
  return inventory.find_index(player, item_id) ~= nil
end

function driver.set_tile_owner(ctx, tile_id, owner_id)
  local tile = ctx.game.board:get_tile_by_id(tile_id)
  ctx.game:set_tile_owner(tile, owner_id)
end

-- Find the first ownable land tile on the outer ring; returns its ring index and tile
-- id. Lets a landing-settlement test seat a player there (by index) and set ownership
-- (by id) over the real map without hardcoding a tile. The map always has land tiles.
function driver.first_land_tile(ctx)
  for i = 1, OUTER_RING_SIZE do
    local tile = ctx.game.board:get_tile(i)
    if tile and tile.type == "land" then
      return i, tile.id
    end
  end
  error("no land tile on the outer ring")
end

-- Place `player` on `tile_id` and orient them forward along the outer ring (facing the
-- next ring tile) — the seating every ring-based setup verb shares. The outer ring is a
-- complete 32-tile cycle, so outer_next is always defined for a ring tile. Returns tile_id.
local function _seat_facing_forward(ctx, player, tile_id)
  local map = ctx.game.board.map
  ctx.game:update_player_position(player, ctx.game.board:index_of_tile_id(tile_id))
  ctx.game:set_player_status(player, "move_dir", map.direction(tile_id, map.outer_next[tile_id]))
  return tile_id
end

-- Seat a player one ring-step before the target tile (and face the ring forward) so
-- a roll of 1 lands them exactly on it — the real move+land path, no teleporting
-- onto the tile mid-settlement.
function driver.seat_before_tile(ctx, player, tile_id)
  _seat_facing_forward(ctx, player, ctx.game.board.map.outer_prev[tile_id])
end

-- Mark every black-market good sold out by zeroing its global purchase limit, the
-- same state production reaches once stock is exhausted.
function driver.set_market_sold_out(ctx)
  local limits = ctx.game.market_limits or {}
  for product_id in pairs(limits) do
    limits[product_id] = 0
  end
end

-- The black market sits off the 32-tile outer ring on an inner cross-path: a player
-- only reaches it by entering the inner path at an outer-ring entry_point, which the
-- real direction resolver gates on an EVEN branch parity — and the turn machine sets
-- branch_parity to the dice roll. So a market visit is driven by seating the player a
-- fixed number of outer steps before an entry_point and queuing an even roll. These
-- helpers derive that seat + roll from the live map (entry_points + fresh_forward_next),
-- so they track map edits instead of hardcoding tile ids, and queue the roll on the
-- rng so a plain played turn routes through the real movement path — no teleporting.

-- Steps from an entry_point's outer tile to the market, following the inner path the
-- direction resolver takes once inner entry triggers. Returns market_id, the chosen
-- entry's outer tile id, and that step distance (entry tile -> ... -> market).
local function _market_route(ctx)
  local map = ctx.game.board.map
  local market_id = map.market_id
  for entry_id, entry in pairs(map.entry_points) do
    local hops, cur = 1, entry.inner_id
    while cur ~= market_id and hops < 64 do
      local next_id = map.fresh_forward_next[cur]
      if not next_id then
        break
      end
      hops = hops + 1
      cur = next_id
    end
    if cur == market_id then
      return market_id, entry_id, hops
    end
  end
  error("no entry_point routes to the market")
end

-- Seat `player` `back` outer steps before `entry_id` and face them forward along the
-- ring, so a forward move runs through the entry_point.
local function _seat_before_entry(ctx, player, entry_id, back)
  local map = ctx.game.board.map
  local id = entry_id
  for _ = 1, back do
    id = map.outer_prev[id]
  end
  _seat_facing_forward(ctx, player, id)
end

-- Seat + roll so a played turn LANDS the player exactly on the black market (final
-- step), driving the real landing settlement (market effect). The roll must be even
-- for inner entry, so the seat distance is chosen to make total steps even. Returns
-- the market tile id.
function driver.seat_to_land_on_market(ctx, player)
  local market_id, entry_id, hops = _market_route(ctx)
  -- total steps = back + hops; choose the smallest back >= 1 making it even.
  local back = (hops % 2 == 0) and 2 or 1
  _seat_before_entry(ctx, player, entry_id, back)
  driver.set_next_rolls(ctx, { back + hops })
  return market_id
end

-- Seat + roll so a played turn PASSES THROUGH the market mid-move (the real
-- market_interrupt fires) rather than landing on it, with at least one step
-- remaining. Returns the market tile id.
function driver.seat_to_pass_through_market(ctx, player)
  local market_id, entry_id, hops = _market_route(ctx)
  local market_step = 1 + hops -- seated 1 before the entry: market reached at this step
  local roll = market_step + 1
  if roll % 2 ~= 0 then
    roll = roll + 1
  end
  _seat_before_entry(ctx, player, entry_id, 1)
  driver.set_next_rolls(ctx, { roll })
  return market_id
end

-- ── AI item-phase setup (cluster 5 support) ───────────────────────────────────

-- Seat `player` on the outer ring facing forward. Used to give the AI item-phase a
-- concrete board position from which its trigger predicates (e.g. obstacles ahead)
-- evaluate over real movement geometry.
function driver.seat_on_ring(ctx, player)
  return _seat_facing_forward(ctx, player, ctx.game.board.map.start_id)
end

-- Seat `player` on the ring and place a roadblock a couple of tiles ahead on the path,
-- so the AI's clear-obstacles trigger (strategy.has_obstacles_ahead) fires through the
-- real board scan rather than a flag. Returns the obstacle tile id.
function driver.seat_with_obstacle_ahead(ctx, player)
  local seat_id = driver.seat_on_ring(ctx, player)
  local map = ctx.game.board.map
  local ahead = map.outer_next[map.outer_next[seat_id]]
  driver.place_roadblock(ctx, ahead)
  return ahead
end

function driver.roll_dice(ctx, player, dice_count)
  local override = player.status and player.status.pending_remote_dice
    and player.status.pending_remote_dice.values
  local results, raw_total = roll_module._roll_dice(dice_count, override, ctx.game.rng)
  local total = dice_mult.apply_roll_total(ctx.game, raw_total, player)
  event_feed.publish(ctx.game, {
    kind = event_kinds.dice_roll,
    text = player.name .. " 投骰: [" .. table.concat(results, ",") .. "] => " .. tostring(total),
    tip = true,
  })
  ctx.game.last_turn = ctx.game.last_turn or {}
  ctx.game.last_turn.rolls = results
  ctx.game.last_turn.total = total
  ctx.game.last_turn.raw_total = raw_total
  if override then
    ctx.game:set_player_status(player, "pending_remote_dice", nil)
  end
  local mult = player.status and player.status.pending_dice_multiplier or 1
  if mult > 1 then
    ctx.game:set_player_status(player, "pending_dice_multiplier", 1)
  end
  return results, raw_total, total
end

function driver.apply_remote_dice(ctx, player, dice_count, value)
  local values = {}
  for i = 1, dice_count do values[i] = value end
  ctx.game:set_player_status(player, "pending_remote_dice", { values = values })
end

function driver.set_dice_multiplier(ctx, player, mult)
  ctx.game:set_player_status(player, "pending_dice_multiplier", mult)
end

function driver.last_rolls(ctx)
  return ctx.game.last_turn and ctx.game.last_turn.rolls
end

function driver.last_total(ctx)
  return ctx.game.last_turn and ctx.game.last_turn.total
end

function driver.last_raw_total(ctx)
  return ctx.game.last_turn and ctx.game.last_turn.raw_total
end

return driver
