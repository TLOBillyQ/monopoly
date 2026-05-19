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

local driver = {}

local OUTER_RING_SIZE = 32

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
  return ctx.game:player_balance(player, "金币")
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

function driver.roll_dice(ctx, player, dice_count)
  local override = player.status and player.status.pending_remote_dice
    and player.status.pending_remote_dice.values
  local results, raw_total = roll_module._roll_dice(dice_count, override, ctx.game.rng)
  local total = dice_mult.apply_roll_total(raw_total, player)
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
