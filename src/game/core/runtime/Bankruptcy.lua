local logger = require("src.core.utils.logger")
local runtime_ports = require("src.core.ports.runtime_ports")
local inventory = require("src.game.systems.items.item_inventory")
local monopoly_event = require("src.core.events.monopoly_events")

local bankruptcy = {}
local warned_missing_tiles_cleared_callback = false

local function _try_call_life_die(role)
  if not role then
    return false
  end
  if type(role.die) == "function" then
    local ok = pcall(role.die, role, nil)
    if ok then
      return true
    end
    ok = pcall(role.die, nil)
    if ok then
      return true
    end
  end
  if type(role.get_component) == "function" then
    local ok, life_comp = pcall(role.get_component, role, "LifeComp")
    if ok and life_comp and type(life_comp.die) == "function" then
      local die_ok = pcall(life_comp.die, life_comp, role)
      if die_ok then
        return true
      end
      die_ok = pcall(life_comp.die, role)
      if die_ok then
        return true
      end
      die_ok = pcall(life_comp.die, nil)
      if die_ok then
        return true
      end
    end
  end
  return false
end

local function _resolve_bankruptcy_text(player, opts)
  if opts and opts.reason and opts.reason ~= "" then
    return opts.reason
  end
  return player.name .. " 破产出局"
end

local function _push_bankruptcy_popup(game, player, opts)
  local popup_port = game and game.popup_port or nil
  if popup_port == nil and game and type(game.ensure_popup_port) == "function" then
    popup_port = game:ensure_popup_port()
  end
  if not (popup_port and popup_port.push_popup) then
    return
  end
  popup_port:push_popup({
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
  local callback = nil
  if ports and type(ports.state) == "table" and type(ports.state.on_bankruptcy_tiles_cleared) == "function" then
    callback = ports.state.on_bankruptcy_tiles_cleared
  elseif ports and type(ports.on_bankruptcy_tiles_cleared) == "function" then
    callback = ports.on_bankruptcy_tiles_cleared
  end
  if callback then
    callback(game, player, owned_tile_ids)
    return
  end
  if not warned_missing_tiles_cleared_callback then
    warned_missing_tiles_cleared_callback = true
    logger.warn("missing gameplay_loop_ports.state.on_bankruptcy_tiles_cleared")
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
  monopoly_event.emit(monopoly_event.feedback.bankruptcy, {
    player = player,
    player_id = player.id,
    reason = _resolve_bankruptcy_text(player, opts),
  })

  local role = runtime_ports.resolve_role(player.id)
  _try_call_life_die(role)
  runtime_ports.mark_role_lose(role)

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
