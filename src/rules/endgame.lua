local logger = require("src.foundation.log")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local event_kinds = require("src.config.gameplay.event_kinds")
local bankruptcy_feedback_port = require("src.rules.ports.bankruptcy_feedback")
local event_feed = require("src.rules.ports.event_feed")
local inventory = require("src.rules.items.inventory")
local monopoly_event = require("src.foundation.events")
local tile_mod = require("src.rules.board.tile")
local pricing = require("src.rules.land.pricing")
local timing = require("src.config.gameplay.timing")

local M = {}

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
      logger.info("bankruptcy skip missing tile:", tostring(tile_id))
    end
  end

  return owned_tile_ids, owned_tiles, names
end

function M.eliminate(game, player, opts)
  if player.eliminated then
    return
  end
  event_feed.publish(game, {
    kind = event_kinds.bankruptcy,
    text = player.name .. " 破产出局",
  })

  local owned_tile_ids, owned_tiles, names = _collect_owned_tiles(game, player)
  if #owned_tile_ids > 0 then
    event_feed.publish(game, {
      kind = event_kinds.bankruptcy_liquidation,
      text = player.name .. " 破产，清空地块: " .. table.concat(names, "、"),
    })

    for _, tile in ipairs(owned_tiles) do
      game:reset_tile(tile)
      game:set_player_property(player, tile.id, false)
    end
  end

  inventory.clear(player)
  game:clear_player_deity(player)

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
    bankruptcy_feedback_port.on_tiles_cleared(game, player, owned_tile_ids)
  end

  for _, list in pairs(game.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
end

M._call_life_die = _call_life_die
M._try_call_life_die = _try_call_life_die
M._resolve_life_component = _resolve_life_component
M._call_role_die = _call_role_die

local tile_state = tile_mod.get_state

local function _total_assets(game, player)
  local total = game:player_balance(player, "金币")
  assert(total ~= nil, "missing player cash")
  for tile_id in pairs(player.properties) do
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil and tile.type == "land", "invalid property tile: " .. tostring(tile_id))
    local st = tile_state(game, tile)
    local level = st.level
    total = total + pricing.total_invested(tile, level)
  end
  return total
end

local function _winner_names(list)
  local names = {}
  assert(list ~= nil, "missing winner list")
  for _, player in ipairs(list) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

local function _apply_winners(game, winners, message)
  game.winners = winners
  if #winners == 1 then
    game.winner = winners[1]
  else
    game.winner = nil
  end
  local names = _winner_names(winners)
  game.winner_names = names
  assert(message ~= nil, "missing victory message")
  event_feed.publish(game, {
    kind = event_kinds.victory,
    text = message .. game.winner_names,
  })
  local winner_ids = {}
  for _, player in ipairs(winners) do
    winner_ids[player.id] = true
  end
  monopoly_event.emit(monopoly_event.game.finished, {
    winners = winners,
    winner_ids = winner_ids,
    winner_names = names,
    message = message,
  })
  game.finished = true
  return true
end

function M.check_victory(self)
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  local turn_limit = timing.turn_limit
  assert(turn_limit ~= nil, "missing turn_limit")
  if turn_limit > 0 then
    local turn_count = self.turn.turn_count
    if turn_count >= turn_limit then
      if #alive == 0 then
        return _apply_winners(self, {}, "游戏结束，无人生还")
      end
      local winners = {}
      local best = -math.huge
      for _, player in ipairs(alive) do
        local assets = _total_assets(self, player)
        if assets > best then
          best = assets
          winners = { player }
        elseif assets == best then
          table.insert(winners, player)
        end
      end
      return _apply_winners(self, winners, "游戏结束，时间到，胜者:")
    end
  end
  if #alive <= 1 then
    if #alive == 1 then
      return _apply_winners(self, { alive[1] }, "游戏结束，胜者:")
    end
    return _apply_winners(self, {}, "游戏结束，无人生还")
  end
  return false
end

return M
