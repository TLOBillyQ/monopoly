local logger = require("src.core.utils.logger")
local runtime_ports = require("src.core.ports.runtime_ports")
local bankruptcy_feedback_port = require("src.rules.ports.bankruptcy_feedback")
local inventory = require("src.rules.items.inventory")
local monopoly_event = require("src.core.events")

local bankruptcy = {}

local function _try_pcall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local ok = pcall(fn, ...)
  return ok == true
end

local function _call_role_die(role)
  if type(role) ~= "table" then
    return false
  end
  return _try_pcall(role.die, role, nil) or _try_pcall(role.die, nil)
end

local function _resolve_life_component(role)
  if type(role) ~= "table" or type(role.get_component) ~= "function" then
    return nil
  end
  local ok, life_comp = pcall(role.get_component, role, "LifeComp")
  if ok then
    return life_comp
  end
  return nil
end

local function _call_life_die(life_comp, role)
  if type(life_comp) ~= "table" then
    return false
  end
  return _try_pcall(life_comp.die, life_comp, role)
    or _try_pcall(life_comp.die, role)
    or _try_pcall(life_comp.die, nil)
end

local function _try_call_life_die(role)
  if not role then
    return false
  end
  if _call_role_die(role) then
    return true
  end
  return _call_life_die(_resolve_life_component(role), role)
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
  bankruptcy_feedback_port.on_tiles_cleared(game, player, owned_tile_ids)
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

-- Export helpers for testability
bankruptcy._call_life_die = _call_life_die
bankruptcy._try_call_life_die = _try_call_life_die
bankruptcy._resolve_life_component = _resolve_life_component
bankruptcy._call_role_die = _call_role_die

return bankruptcy
