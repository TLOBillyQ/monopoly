local gameplay_rules = require("Config.GameplayRules")
local test_profiles = require("Config.TestProfiles")
local inventory = require("src.game.systems.items.ItemInventory")

local bootstrap = {}

local function _resolve_profile_name(opts)
  local candidate = opts and opts.profile_name or gameplay_rules.test_profile
  if type(candidate) ~= "string" or candidate == "" then
    return "default"
  end
  return candidate
end

local function _apply_player_bootstrap(game, players)
  if type(players) ~= "table" then
    return
  end
  for index, player_cfg in pairs(players) do
    local player = game.players[index]
    assert(player ~= nil, "invalid profile player index: " .. tostring(index))

    if player_cfg.cash ~= nil then
      game:set_player_cash(player, player_cfg.cash)
    end

    local balances = player_cfg.balances
    if type(balances) == "table" then
      for currency, amount in pairs(balances) do
        game:set_player_balance(player, currency, amount)
      end
    end

    local items = player_cfg.items
    if type(items) == "table" then
      if player_cfg.inventory_slots then
        player.inventory.max_slots = player_cfg.inventory_slots
      end
      inventory.clear(player)
      for _, item_id in ipairs(items) do
        local ok = inventory.give(player, item_id, { game = game })
        assert(ok == true, "failed to grant profile item: " .. tostring(item_id))
      end
    end
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

function bootstrap.apply(game, opts)
  assert(game ~= nil, "missing game")

  local profile_name = _resolve_profile_name(opts)
  if profile_name == "default" then
    return
  end

  local profile = test_profiles.resolve(profile_name)
  local cfg = profile.bootstrap
  if type(cfg) ~= "table" then
    return
  end

  _apply_player_bootstrap(game, cfg.players)
  _apply_tile_bootstrap(game, cfg.tiles)
end

return bootstrap
