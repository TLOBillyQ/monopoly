local test_profile_resolver = require("src.app.testing.TestProfileResolver")
local inventory = require("src.game.systems.items.ItemInventory")
local constants = require("Config.Generated.Constants")
local number_utils = require("src.core.utils.NumberUtils")

local bootstrap = {}

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

  local balances = player_cfg.balances
  if type(balances) == "table" then
    for currency, amount in pairs(balances) do
      game:set_player_balance(player, currency, amount)
    end
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
  for tile_id, tile_cfg in pairs(tiles) do
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil, "invalid profile tile id: " .. tostring(tile_id))

    local owner_index = tile_cfg.owner_player_index
    if owner_index ~= nil then
      local owner = game.players[owner_index]
      assert(owner ~= nil, "invalid owner_player_index: " .. tostring(owner_index))
      game:set_tile_owner(tile, owner.id)
      game:set_player_property(owner, tile.id, true)
    end

    if tile_cfg.level ~= nil then
      game:set_tile_level(tile, tile_cfg.level)
    end
  end
end

function bootstrap.apply(game, profile_name)
  assert(game ~= nil, "missing game")

  local cfg = test_profile_resolver.resolve_bootstrap(profile_name)
  if type(cfg) ~= "table" then
    return
  end

  _apply_player_bootstrap(game, cfg.players)
  _apply_tile_bootstrap(game, cfg.tiles)
end

return bootstrap
