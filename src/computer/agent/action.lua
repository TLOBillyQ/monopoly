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

local function _pick_steal_target(game, player, allowed)
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id]) then
      if p.inventory and p.inventory:count() > 0 then return p end
    end
  end
  return nil
end

local function _pick_missile_target(game, player, allowed)
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id]) then return p end
  end
  return nil
end

local function _pick_send_poor_target(game, player, allowed)
  if not game:player_has_deity(player, "poor") then return nil end
  return _richest_other(game, player, allowed)
end

local _target_pickers = {
  [item_ids.share_wealth] = _pick_share_wealth_target,
  [item_ids.exile] = _richest_other,
  [item_ids.tax] = _richest_other,
  [item_ids.poor] = _richest_other,
  [item_ids.steal] = _pick_steal_target,
  [item_ids.missile] = _pick_missile_target,
  [item_ids.invite_deity] = _pick_deity_target,
  [item_ids.send_poor] = _pick_send_poor_target,
}

function action_selector.pick_target_player(game, player, item_id, options)
  local allowed = _allow_from_options(options)
  local picker = _target_pickers[item_id]
  if picker then return picker(game, player, allowed) end
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

action_selector.pick_demolish_target = demolish.find_target

return action_selector

--[[ mutate4lua-manifest
version=2
projectHash=c25224d334880b41
scope.0.id=chunk:src/computer/agent/action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=120
scope.0.semanticHash=a56225c54b481fce
scope.1.id=function:_pick_share_wealth_target:44
scope.1.kind=function
scope.1.startLine=44
scope.1.endLine=49
scope.1.semanticHash=9317a020dda7c3fe
scope.2.id=function:_pick_send_poor_target:82
scope.2.kind=function
scope.2.startLine=82
scope.2.endLine=85
scope.2.semanticHash=a69078ba038c4901
scope.3.id=function:action_selector.pick_target_player:98
scope.3.kind=function
scope.3.startLine=98
scope.3.endLine=103
scope.3.semanticHash=9474a2ec0c7a71ac
scope.4.id=function:action_selector.pick_roadblock_target:105
scope.4.kind=function
scope.4.startLine=105
scope.4.endLine=115
scope.4.semanticHash=7a98a34e6abe20b2
]]
