local logger = require("src.core.Logger")
local inventory = require("src.game.item.ItemInventory")

local bankruptcy = {}

local function _resolve_bankruptcy_text(player, opts)
  if opts and opts.reason and opts.reason ~= "" then
    return opts.reason
  end
  return player.name .. " 破产出局"
end

local function _push_bankruptcy_popup(game, player, opts)
  local ui_port = game and game.ui_port or nil
  if not (ui_port and ui_port.push_popup) then
    return
  end
  ui_port:push_popup({
    kind = "bankruptcy",
    player_id = player and player.id or nil,
    player_name = player and player.name or nil,
    text = _resolve_bankruptcy_text(player, opts),
  })
end

local function _collect_owned_tiles(game, player)
  local owned_tile_ids = {}
  local props = player.properties or {}
  for tile_id, owned in pairs(props) do
    if owned == true then
      table.insert(owned_tile_ids, tile_id)
    end
  end

  local owned_tiles = {}
  local names = {}
  for _, tile_id in ipairs(owned_tile_ids) do
    local tile = game.board:get_tile_by_id(tile_id)
    if tile then
      table.insert(owned_tiles, tile)
      table.insert(names, tile.name)
    else
      logger.warn("bankruptcy skip missing tile:", tostring(tile_id))
    end
  end

  return owned_tile_ids, owned_tiles, names
end

local function _notify_tiles_cleared(game, player, owned_tile_ids)
  local ports = game and game.gameplay_loop_ports or nil
  if ports and type(ports.on_bankruptcy_tiles_cleared) == "function" then
    ports.on_bankruptcy_tiles_cleared(game, player, owned_tile_ids)
  end
end

function bankruptcy.eliminate(game, player, opts)
  if player.eliminated then
    return
  end
  logger.event(player.name .. " 破产出局")

  local owned_tile_ids, owned_tiles, names = _collect_owned_tiles(game, player)
  if #owned_tile_ids > 0 then
    logger.event(player.name .. " 破产，清空地块: " .. table.concat(names, "、"))

    for _, tile in ipairs(owned_tiles) do
      game:reset_tile(tile)
      game:set_player_property(player, tile.id, false)
    end
  end

  inventory.clear(player)

  game:set_player_eliminated(player, true)
  _push_bankruptcy_popup(game, player, opts)

  local ui_port = game.ui_port
  if GameAPI and GameAPI.get_role then
    local role = GameAPI.get_role(player.id)
    if role and role.lose then
      role.lose()
    end
  end

  if #owned_tile_ids > 0 then
    _notify_tiles_cleared(game, player, owned_tile_ids)
  end

  for tile_idx, list in pairs(game.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
end

return bankruptcy
