local inventory = require("src.rules.items.inventory")
local constants = require("src.config.content.constants")
local number_utils = require("src.foundation.lang.number")

local bootstrap = {}
local _is_render_called_flag_enabled

local function _assert_integer_like(value, label)
  local resolved = number_utils.to_integer(value)
  assert(resolved ~= nil, tostring(label) .. " must be integer-like, got: " .. tostring(value))
  if type(value) == "number" then
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

function bootstrap.reset_render_bootstrap(game)
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
  end
end

local function _apply_tile_bootstrap(game, tiles)
  if type(tiles) ~= "table" then
    return
  end
  local render_bootstrap = _ensure_render_bootstrap(game)
  for raw_tile_id, tile_cfg in pairs(tiles) do
    assert(type(tile_cfg) == "table", "invalid profile tile config: " .. tostring(raw_tile_id))
    local tile_id = _assert_integer_like(raw_tile_id, "tile id")
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil, "invalid profile tile id: " .. tostring(tile_id))

    local owner_index = tile_cfg.owner_player_index
    if owner_index ~= nil then
      local resolved_owner_index = _assert_integer_like(owner_index, "owner_player_index")
      local owner = game.players[resolved_owner_index]
      assert(owner ~= nil, "invalid owner_player_index: " .. tostring(resolved_owner_index))
      game:set_tile_owner(tile, owner.id)
      game:set_player_property(owner, tile.id, true)
    end

    if tile_cfg.level ~= nil then
      local level = _assert_integer_like(tile_cfg.level, "tile level")
      game:set_tile_level(tile, level)
    end

    if _is_render_called_flag_enabled(tile_cfg.render_called) then
      render_bootstrap.tiles_by_id[tile.id] = true
    end
  end
end

function _is_render_called_flag_enabled(value)
  return value == true
end

local function _resolve_overlay_entry(raw_entry)
  if raw_entry == nil then
    return nil, false
  end
  if type(raw_entry) == "table" then
    return raw_entry.tile_id, _is_render_called_flag_enabled(raw_entry.render_called)
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

local function _apply_overlay_bootstrap(game, overlays)
  if type(overlays) ~= "table" then
    return
  end

  local render_bootstrap = _ensure_render_bootstrap(game)

  local roadblocks = overlays.roadblocks
  if type(roadblocks) == "table" then
    for _, entry in ipairs(roadblocks) do
      local raw_tile_id, render_called = _resolve_overlay_entry(entry)
      local board_index = _resolve_overlay_index(game, raw_tile_id, "roadblock")
      game:place_roadblock(board_index)
      if render_called then
        render_bootstrap.overlays.roadblock[board_index] = true
      end
    end
  end

  local mines = overlays.mines
  if type(mines) == "table" then
    for _, entry in ipairs(mines) do
      local raw_tile_id, render_called = _resolve_overlay_entry(entry)
      local board_index = _resolve_overlay_index(game, raw_tile_id, "mine")
      game:place_mine(board_index)
      if render_called then
        render_bootstrap.overlays.mine[board_index] = true
      end
    end
  end
end

function bootstrap.apply_bootstrap(game, cfg)
  assert(game ~= nil, "missing game")
  bootstrap.reset_render_bootstrap(game)
  if type(cfg) ~= "table" then
    return
  end
  _apply_player_bootstrap(game, cfg.players)
  _apply_tile_bootstrap(game, cfg.tiles)
  _apply_overlay_bootstrap(game, cfg.overlays)
end

return bootstrap
