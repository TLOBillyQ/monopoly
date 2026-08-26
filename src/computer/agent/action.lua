local roadblock = require("src.rules.items.roadblock")
local demolish = require("src.rules.items.demolish")
local item_ids = require("src.config.gameplay.item_ids")

local action_selector = {}

local function _other_alive(p, player)
  return not p.eliminated and p.id ~= player.id
end

local function _allowed(allow_ids, player_id)
  return allow_ids == nil or allow_ids[player_id]
end

local function _richer(cash, best_cash)
  return best_cash == nil or cash > best_cash
end

local function _richest_other(game, player, allow_ids)
  local best, best_cash = nil, nil
  for _, p in ipairs(game.players) do
    if _other_alive(p, player) then
      if _allowed(allow_ids, p.id) then
        local cash = game:player_cash(p)
        if _richer(cash, best_cash) then
          best = p
          best_cash = cash
        end
      end
    end
  end
  return best
end

local function _is_richest(game, player)
  local player_cash = game:player_cash(player)
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id and game:player_cash(p) > player_cash then
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

local function _targetable(p, player, allowed)
  return p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id])
end

local function _rich_candidate(game, p, best)
  return game:player_has_deity(p, "rich") and best == nil
end

local function _pick_deity_target(game, player, allowed)
  local best = nil
  for _, p in ipairs(game.players) do
    if _targetable(p, player, allowed) then
      if game:player_has_deity(p, "angel") then
        return p
      end
      if _rich_candidate(game, p, best) then
        best = p
      end
    end
  end
  return best
end

local function _has_inventory(p)
  return p.inventory ~= nil and p.inventory:count() > 0
end

local function _pick_steal_target(game, player, allowed)
  for _, p in ipairs(game.players) do
    if _targetable(p, player, allowed) then
      if _has_inventory(p) then return p end
    end
  end
  return nil
end

local function _pick_missile_target(game, player, allowed)
  for _, p in ipairs(game.players) do
    if _targetable(p, player, allowed) then
      return p
    end
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
version=4
projectHash=cedb6289ce1764a4
scope.0.id=chunk:src/computer/agent/action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=146
scope.0.semanticHash=fc662821153ceabe
scope.1.id=function:_other_alive
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=8a3f7a0a196e175f
scope.2.id=function:_allowed
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=ac348ee614950dec
scope.3.id=function:_richer
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=cab94bc5f9aa7abd
scope.4.id=function:_richest_other
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=33
scope.4.semanticHash=0c63ec0ae7307725
scope.5.id=function:_is_richest
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=43
scope.5.semanticHash=6de452f81bc8864f
scope.6.id=function:_allow_from_options
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=54
scope.6.semanticHash=95cc6a0684358959
scope.7.id=function:_pick_share_wealth_target
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=61
scope.7.semanticHash=5f6cdd515d293a67
scope.8.id=function:_targetable
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=5ee5490cce7c6ef4
scope.9.id=function:_rich_candidate
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=69
scope.9.semanticHash=0a607d7e645896c7
scope.10.id=function:_pick_deity_target
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=84
scope.10.semanticHash=15d7cffda91ade95
scope.11.id=function:_has_inventory
scope.11.kind=function
scope.11.startLine=86
scope.11.endLine=88
scope.11.semanticHash=73b57fbb9ac5e263
scope.12.id=function:_pick_steal_target
scope.12.kind=function
scope.12.startLine=90
scope.12.endLine=97
scope.12.semanticHash=2a576ce5e537e824
scope.13.id=function:_pick_missile_target
scope.13.kind=function
scope.13.startLine=99
scope.13.endLine=106
scope.13.semanticHash=f1e0b152f43f319c
scope.14.id=function:_pick_send_poor_target
scope.14.kind=function
scope.14.startLine=108
scope.14.endLine=111
scope.14.semanticHash=e4de59c936d40244
scope.15.id=function:action_selector.pick_target_player
scope.15.kind=function
scope.15.startLine=124
scope.15.endLine=129
scope.15.semanticHash=bfec78818646f679
scope.16.id=function:action_selector.pick_roadblock_target
scope.16.kind=function
scope.16.startLine=131
scope.16.endLine=141
scope.16.semanticHash=75522e7196a05f50
]]
