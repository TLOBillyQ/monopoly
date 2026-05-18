local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local default_ports = require("src.turn.output.default_ports")
local compose_game = require("src.app.compose_game")
local game_factory = require("src.app.game_factory")
local movement = require("src.rules.movement")

local driver = {}

local OUTER_RING_SIZE = 32

local function _build_queue_rng(queue)
  local index = 0
  return game_factory.build_rng(function()
    index = index + 1
    if index > #queue then
      error("RNG queue exhausted at call " .. tostring(index))
    end
    return queue[index]
  end)
end

function driver.new_game(opts)
  opts = opts or {}
  local rng_queue = {}
  local game = compose_game.new_game(default_ports.resolve_game_opts({
    players = opts.players or {"P1", "P2", "P3", "P4"},
    ai = opts.ai or {[2] = true, [3] = true, [4] = true},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
    rng = _build_queue_rng(rng_queue),
  }))
  return {
    game = game,
    outer_ring_size = OUTER_RING_SIZE,
    _rng_queue = rng_queue,
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

return driver
