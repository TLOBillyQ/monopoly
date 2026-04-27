local roadblock = require("src.rules.items.roadblock")
local demolish = require("src.rules.items.demolish")
local item_ids = require("src.config.gameplay.item_ids")

local action_selector = {}

local function _richest_other(game, player, allow_ids)
  local best, best_cash = nil, nil
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id then
      if not allow_ids or allow_ids[p.id] then
        local cash = game:player_balance(p, "金币")
        if not best_cash or cash > best_cash then
          best = p
          best_cash = cash
        end
      end
    end
  end
  return best
end

local function _is_richest(game, player)
  local player_cash = game:player_balance(player, "金币")
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id and game:player_balance(p, "金币") > player_cash then
      return false
    end
  end
  return true
end

local function _allow_from_options(options)
  if not options then
    return nil
  end
  local allowed = {}
  for _, opt in ipairs(options) do
    allowed[opt.id] = true
  end
  return allowed
end

local function _pick_share_wealth_target(game, player, allowed)
  if _is_richest(game, player) then
    return nil
  end
  return _richest_other(game, player, allowed)
end

local function _pick_deity_target(game, player, allowed)
  local best = nil
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id]) then
      if game:player_has_deity(p, "angel") then
        return p
      end
      if game:player_has_deity(p, "rich") and not best then
        best = p
      end
    end
  end
  return best
end

function action_selector.pick_target_player(game, player, item_id, options)
  local allowed = _allow_from_options(options)
  if item_id == item_ids.share_wealth then
    return _pick_share_wealth_target(game, player, allowed)
  end
  if item_id == item_ids.exile or item_id == item_ids.tax or item_id == item_ids.poor then
    return _richest_other(game, player, allowed)
  end
  if item_id == item_ids.invite_deity then
    return _pick_deity_target(game, player, allowed)
  end
  if item_id == item_ids.send_poor then
    if not game:player_has_deity(player, "poor") then
      return nil
    end
    return _richest_other(game, player, allowed)
  end

  return nil
end

function action_selector.pick_roadblock_target(game, player)
  local candidates = roadblock.auto_candidates(game, player, 3)
  if not candidates or #candidates == 0 then
    return nil
  end
  local best = roadblock.pick_best(candidates)
  if not best then
    return nil
  end
  return best.idx
end

function action_selector.pick_demolish_target(game, player, distance)
  return demolish.find_target(game, player, distance)
end

return action_selector
