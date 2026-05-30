local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local logger = require("src.foundation.log")
local inventory = require("src.rules.items.inventory")
local executor = require("src.rules.items.executor")
local availability = require("src.rules.items.availability")
local demolish = require("src.rules.items.demolish")
local facing_policy = require("src.rules.board.facing_policy")

local strategy = {}
function strategy.target_candidates(game, player, item_id)
  local registries = assert(game.registries, "missing game.registries")
  local registry = assert(registries.items, "missing item registry")
  return registry:target_candidates(game, player, item_id)
end

function strategy.has_obstacles_ahead(game, player, distance)
  local board = game.board
  distance = distance or 12
  local parity = distance
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("fresh_forward", player)
  local entered_inner = false

  for _ = 1, distance do
    local next_index, _, next_facing, step_entered_inner = board:step_forward_by_facing(current, facing, {
      parity = parity,
      entered_inner = entered_inner,
    })
    current = next_index
    facing = next_facing
    if step_entered_inner then
      entered_inner = true
    end
    if board:has_roadblock(current) or board:has_mine(current) then
      return true
    end
  end
  return false
end

function strategy.can_offer_in_phase(game, player, item_id, phase)
  local ok = availability.can_offer_in_phase(game, player, item_id, phase)
  return ok == true
end

local function _ai_can_use_item(item_id, phase)
  return availability.can_auto_consider_item(item_id, phase)
end

local function _resolve_try_use_item_args(game, phase_or_cond, cond_or_auto_play, auto_play)
  if type(phase_or_cond) == "string" then
    return phase_or_cond, cond_or_auto_play, auto_play
  end
  local phase = game and game.turn and game.turn.phase or nil
  return phase, phase_or_cond, cond_or_auto_play
end

local function _try_use_item(game, player, item_id, phase, cond, auto_play)
  phase, cond, auto_play = _resolve_try_use_item_args(game, phase, cond, auto_play)
  if cond and cond() == false then return nil end
  if not _ai_can_use_item(item_id, phase) then
    return nil
  end
  if not inventory.find_index(player, item_id) then
    return nil
  end
  local res = executor.use_item(game, player, item_id, { by_ai = true, auto_play = auto_play })
  if type(res) == "table" and (res.waiting or res.intent or res.kind or res.action_anim) then
    return res
  end
  return nil
end

local function _has_target_player(game, player, item_id)
  return auto_play_port.pick_target_player(game, player, item_id, strategy.target_candidates(game, player, item_id)) and true or false
end

local function _has_demolish_target(game, player)
  return demolish.find_target(game, player, 3) and true or false
end

local function _try_clear_obstacles(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.clear_obstacles, phase, function()
    local found = strategy.has_obstacles_ahead(game, player, 12)
    -- migrated as DEV: AI internal planning diagnostic, not player-visible event
    if found then logger.info(player.name .. " 前方发现障碍，准备使用清障卡") end
    return found
  end, auto_play)
end

local function _try_remote_dice(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.remote_dice, phase, function()
    local dice_count = game:player_dice_count(player)
    return auto_play_port.pick_remote_dice_value(game, player, dice_count) and true or false
  end, auto_play)
end

local function _try_roadblock(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.roadblock, phase, function()
    return auto_play_port.pick_roadblock_target(game, player) and true or false
  end, auto_play)
end

local function _try_target_items(game, player, phase, auto_play)
  for _, id in ipairs(effects.target_item_ids()) do
    local res = _try_use_item(game, player, id, phase, function() return _has_target_player(game, player, id) end, auto_play)
    if res then return res end
  end
  return nil
end

local function _try_deity_items(game, player, phase, auto_play)
  local rich_result = _try_use_item(game, player, item_ids.rich, phase, nil, auto_play)
  if rich_result then return rich_result end
  return _try_use_item(game, player, item_ids.angel, phase, nil, auto_play)
end

local function _try_monster(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.monster, phase, function()
    return _has_demolish_target(game, player)
  end, auto_play)
end

local function _run_auto_pre_action_probes(game, player, phase, auto_play)
  return _try_clear_obstacles(game, player, phase, auto_play)
    or _try_remote_dice(game, player, phase, auto_play)
    or _try_use_item(game, player, item_ids.mine, phase, nil, auto_play)
    or _try_use_item(game, player, item_ids.dice_multiplier, phase, nil, auto_play)
    or _try_roadblock(game, player, phase, auto_play)
    or _try_monster(game, player, phase, auto_play)
    or _try_target_items(game, player, phase, auto_play)
    or _try_deity_items(game, player, phase, auto_play)
end

function strategy.auto_pre_action(game, player, phase)
  if not auto_play_port.is_auto_player(game, player) then
    return nil
  end
  return _run_auto_pre_action_probes(game, player, phase, nil)
end

-- Export helpers for testability
strategy._ai_can_use_item = _ai_can_use_item
strategy._try_use_item = _try_use_item
strategy._has_target_player = _has_target_player
strategy._has_demolish_target = _has_demolish_target
strategy._try_clear_obstacles = _try_clear_obstacles
strategy._try_remote_dice = _try_remote_dice
strategy._try_roadblock = _try_roadblock
strategy._try_target_items = _try_target_items
strategy._try_deity_items = _try_deity_items

return strategy

--[[ mutate4lua-manifest
version=2
projectHash=6c59e6e064b89374
scope.0.id=chunk:src/rules/items/strategy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=156
scope.0.semanticHash=e2866728f585d475
scope.1.id=function:strategy.target_candidates:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=16
scope.1.semanticHash=02e0f96ec268c89f
scope.2.id=function:strategy.can_offer_in_phase:43
scope.2.kind=function
scope.2.startLine=43
scope.2.endLine=46
scope.2.semanticHash=03edba23288039a2
scope.3.id=function:_ai_can_use_item:48
scope.3.kind=function
scope.3.startLine=48
scope.3.endLine=50
scope.3.semanticHash=7203afdfbb79a1c7
scope.4.id=function:_resolve_try_use_item_args:52
scope.4.kind=function
scope.4.startLine=52
scope.4.endLine=58
scope.4.semanticHash=c8f9d611964ce339
scope.5.id=function:_try_use_item:60
scope.5.kind=function
scope.5.startLine=60
scope.5.endLine=74
scope.5.semanticHash=833d9e5358a3df86
scope.6.id=function:_has_target_player:76
scope.6.kind=function
scope.6.startLine=76
scope.6.endLine=78
scope.6.semanticHash=42af06a3f82f9dc3
scope.7.id=function:_has_demolish_target:80
scope.7.kind=function
scope.7.startLine=80
scope.7.endLine=82
scope.7.semanticHash=4f6ee0dd9664fb6b
scope.8.id=function:anonymous@85:85
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=90
scope.8.semanticHash=2bdd8127b7d0f0ba
scope.9.id=function:_try_clear_obstacles:84
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=91
scope.9.semanticHash=8b3e15f963c97e12
scope.10.id=function:anonymous@94:94
scope.10.kind=function
scope.10.startLine=94
scope.10.endLine=97
scope.10.semanticHash=5918e2837a15d00d
scope.11.id=function:_try_remote_dice:93
scope.11.kind=function
scope.11.startLine=93
scope.11.endLine=98
scope.11.semanticHash=b72c4061e1a56519
scope.12.id=function:anonymous@101:101
scope.12.kind=function
scope.12.startLine=101
scope.12.endLine=103
scope.12.semanticHash=2b1984710e284173
scope.13.id=function:_try_roadblock:100
scope.13.kind=function
scope.13.startLine=100
scope.13.endLine=104
scope.13.semanticHash=8894676ddee187f3
scope.14.id=function:anonymous@108:108
scope.14.kind=function
scope.14.startLine=108
scope.14.endLine=108
scope.14.semanticHash=2f86fbaddba251df
scope.15.id=function:_try_deity_items:114
scope.15.kind=function
scope.15.startLine=114
scope.15.endLine=118
scope.15.semanticHash=aec98491ae50cad6
scope.16.id=function:anonymous@121:121
scope.16.kind=function
scope.16.startLine=121
scope.16.endLine=123
scope.16.semanticHash=b62571ed3083a824
scope.17.id=function:_try_monster:120
scope.17.kind=function
scope.17.startLine=120
scope.17.endLine=124
scope.17.semanticHash=ac1883178aa04094
scope.18.id=function:_run_auto_pre_action_probes:126
scope.18.kind=function
scope.18.startLine=126
scope.18.endLine=135
scope.18.semanticHash=73f27f9818a029fa
scope.19.id=function:strategy.auto_pre_action:137
scope.19.kind=function
scope.19.startLine=137
scope.19.endLine=142
scope.19.semanticHash=a43c43665664d740
]]
