local inventory = require("src.rules.items.inventory")
local constants = require("src.config.content.constants")
local number_utils = require("src.foundation.number")

local bootstrap = {}

local function _assert_integer_like(value, label)
  local resolved = number_utils.to_integer(value)
  assert(resolved ~= nil, tostring(label) .. " must be integer-like, got: " .. tostring(value))
  if number_utils.is_numeric(value) then
    assert(resolved == value, tostring(label) .. " must be integer (no decimals), got: " .. tostring(value))
  end
  return resolved
end

local function _new_render_bootstrap()
  return {
    applied = false,
    tiles_by_id = {},
    overlays = {
      roadblock = {},
      mine = {},
    },
  }
end

local function _ensure_render_bootstrap(game)
  if type(game.test_profile_render_bootstrap) ~= "table" then
    game.test_profile_render_bootstrap = _new_render_bootstrap()
    return game.test_profile_render_bootstrap
  end
  return game.test_profile_render_bootstrap
end

local function _reset_render_bootstrap(game)
  game.test_profile_render_bootstrap = _new_render_bootstrap()
  return game.test_profile_render_bootstrap
end

local function _assert_player_profile_schema(player_cfg, index)
  assert(type(player_cfg) == "table", "invalid profile player config at index: " .. tostring(index))
  assert(player_cfg.inventory_slots == nil,
    "inventory_slots is removed; use item_counts and keep <= " .. tostring(constants.inventory_slots))
  assert(player_cfg.items == nil, "items is removed; use item_counts = { [item_id] = count }")
end

local function _apply_player_resources(game, player, player_cfg)
  if player_cfg.cash ~= nil then
    game:set_player_cash(player, player_cfg.cash)
  end
end

local function _apply_player_position_bootstrap(game, player, player_cfg)
  local tile_id = player_cfg.position_tile_id
  if tile_id == nil then
    return
  end
  local resolved_tile_id = number_utils.to_integer(tile_id)
  assert(resolved_tile_id ~= nil, "invalid position_tile_id: " .. tostring(tile_id))
  local board_index = game.board:index_of_tile_id(resolved_tile_id)
  assert(board_index ~= nil, "position_tile_id not in board path: " .. tostring(resolved_tile_id))
  game:update_player_position(player, board_index)
end

local function _apply_item_count_bootstrap(game, player, player_cfg)
  local item_counts = player_cfg.item_counts
  if item_counts == nil then
    return
  end
  assert(type(item_counts) == "table", "item_counts must be table")

  inventory.clear(player)
  local total = 0
  for raw_item_id, raw_count in pairs(item_counts) do
    local item_id = number_utils.to_integer(raw_item_id)
    assert(item_id ~= nil, "invalid item_counts item id: " .. tostring(raw_item_id))
    assert(inventory.cfg(item_id) ~= nil, "unknown item id in item_counts: " .. tostring(item_id))

    local count = number_utils.to_integer(raw_count)
    assert(number_utils.is_numeric(raw_count) and count ~= nil and count == raw_count and count > 0,
      "item_counts count must be positive integer, got: " .. tostring(raw_count))
    total = total + count
    assert(total <= constants.inventory_slots,
      "item_counts exceeds inventory limit " .. tostring(constants.inventory_slots))

    for _ = 1, count do
      local ok = inventory.give(player, item_id, { game = game })
      assert(ok == true, "failed to grant profile item: " .. tostring(item_id))
    end
  end
end

local function _apply_player_status_bootstrap(game, player, player_cfg)
  local statuses = player_cfg.statuses
  if type(statuses) ~= "table" then
    return
  end
  for status_key, status_value in pairs(statuses) do
    assert(type(status_key) == "string" and status_key ~= "", "invalid status key in profile bootstrap")
    game:set_player_status(player, status_key, status_value)
  end
end

local function _apply_player_eliminated(player, player_cfg)
  if player_cfg.eliminated == nil then
    return
  end
  assert(type(player_cfg.eliminated) == "boolean",
    "eliminated must be boolean, got: " .. tostring(player_cfg.eliminated))
  player.eliminated = player_cfg.eliminated
end

local function _apply_player_bootstrap(game, players)
  if type(players) ~= "table" then
    return
  end
  for index, player_cfg in pairs(players) do
    _assert_player_profile_schema(player_cfg, index)
    local player = game.players[index]
    assert(player ~= nil, "invalid profile player index: " .. tostring(index))

    _apply_player_resources(game, player, player_cfg)
    _apply_player_position_bootstrap(game, player, player_cfg)
    _apply_item_count_bootstrap(game, player, player_cfg)
    _apply_player_status_bootstrap(game, player, player_cfg)
    _apply_player_eliminated(player, player_cfg)
  end
end

local function _apply_tile_owner(game, tile, owner_index)
  local resolved = _assert_integer_like(owner_index, "owner_player_index")
  local owner = game.players[resolved]
  assert(owner ~= nil, "invalid owner_player_index: " .. tostring(resolved))
  game:set_tile_owner(tile, owner.id)
  game:set_player_property(owner, tile.id, true)
end

local function _apply_single_tile_cfg(game, raw_tile_id, tile_cfg, render_bootstrap)
  assert(type(tile_cfg) == "table", "invalid profile tile config: " .. tostring(raw_tile_id))
  local tile_id = _assert_integer_like(raw_tile_id, "tile id")
  local tile = game.board:get_tile_by_id(tile_id)
  assert(tile ~= nil, "invalid profile tile id: " .. tostring(tile_id))
  if tile_cfg.owner_player_index ~= nil then
    _apply_tile_owner(game, tile, tile_cfg.owner_player_index)
  end
  if tile_cfg.level ~= nil then
    game:set_tile_level(tile, _assert_integer_like(tile_cfg.level, "tile level"))
  end
  if tile_cfg.render_called == true then
    render_bootstrap.tiles_by_id[tile.id] = true
  end
end

local function _apply_tile_bootstrap(game, tiles)
  if type(tiles) ~= "table" then return end
  local render_bootstrap = _ensure_render_bootstrap(game)
  for raw_tile_id, tile_cfg in pairs(tiles) do
    _apply_single_tile_cfg(game, raw_tile_id, tile_cfg, render_bootstrap)
  end
end

local function _resolve_overlay_entry(raw_entry)
  if raw_entry == nil then
    return nil, false
  end
  if type(raw_entry) == "table" then
    return raw_entry.tile_id, raw_entry.render_called == true
  end
  return raw_entry, false
end

local function _resolve_overlay_index(game, raw_tile_id, overlay_kind)
  local tile_id = number_utils.to_integer(raw_tile_id)
  assert(tile_id ~= nil, "invalid " .. tostring(overlay_kind) .. " tile id: " .. tostring(raw_tile_id))
  local board_index = game.board:index_of_tile_id(tile_id)
  assert(board_index ~= nil, tostring(overlay_kind) .. " tile id not in board path: " .. tostring(tile_id))
  return board_index
end

local function _apply_overlay_list(game, entries, kind, place_fn, render_table)
  for _, entry in ipairs(entries) do
    local raw_tile_id, render_called = _resolve_overlay_entry(entry)
    local board_index = _resolve_overlay_index(game, raw_tile_id, kind)
    place_fn(game, board_index)
    if render_called then
      render_table[board_index] = true
    end
  end
end

local function _apply_overlay_bootstrap(game, overlays)
  if type(overlays) ~= "table" then return end
  local rb = _ensure_render_bootstrap(game)
  if type(overlays.roadblocks) == "table" then
    _apply_overlay_list(game, overlays.roadblocks, "roadblock",
      function(g, idx) g:place_roadblock(idx) end, rb.overlays.roadblock)
  end
  if type(overlays.mines) == "table" then
    _apply_overlay_list(game, overlays.mines, "mine",
      function(g, idx) g:place_mine(idx) end, rb.overlays.mine)
  end
end

local function _apply_turn_bootstrap(game, cfg)
  if cfg.current_turn_player_index == nil then
    return
  end
  local resolved = number_utils.to_integer(cfg.current_turn_player_index)
  assert(resolved ~= nil,
    "invalid current_turn_player_index: " .. tostring(cfg.current_turn_player_index))
  assert(game.players[resolved] ~= nil,
    "current_turn_player_index points to missing player: " .. tostring(resolved))
  assert(game.turn ~= nil,
    "game.turn must exist before setting current_turn_player_index")
  game.turn.current_player_index = resolved
end

local function _apply_market_limits_bootstrap(game, cfg)
  local limits = cfg.market_limits
  if type(limits) ~= "table" then
    return
  end
  for raw_product_id, raw_remaining in pairs(limits) do
    local product_id = number_utils.to_integer(raw_product_id)
    assert(product_id ~= nil, "invalid market_limits product_id: " .. tostring(raw_product_id))
    assert(game.market_limits[product_id] ~= nil,
      "market_limits product_id not in catalog: " .. tostring(product_id))
    local remaining = number_utils.to_integer(raw_remaining)
    assert(remaining ~= nil and remaining >= 0,
      "market_limits remaining must be non-negative integer, got: " .. tostring(raw_remaining))
    game.market_limits[product_id] = remaining
  end
end

function bootstrap.apply_bootstrap(game, cfg)
  assert(game ~= nil, "missing game")
  _reset_render_bootstrap(game)
  if type(cfg) ~= "table" then
    return
  end
  _apply_player_bootstrap(game, cfg.players)
  _apply_tile_bootstrap(game, cfg.tiles)
  _apply_overlay_bootstrap(game, cfg.overlays)
  _apply_turn_bootstrap(game, cfg)
  _apply_market_limits_bootstrap(game, cfg)
end

return bootstrap
