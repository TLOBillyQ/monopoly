local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local availability = require("src.rules.items.availability")
local demolish = require("src.rules.items.demolish")
local facing_policy = require("src.rules.board.facing_policy")
local use_flow = require("src.rules.items.use_flow")

local strategy = {}
function strategy.target_candidates(game, player, item_id)
  local registries = assert(game.registries, "missing game.registries")
  local registry = assert(registries.items, "missing item registry")
  return registry:target_candidates(game, player, item_id)
end

local function _has_obstacle(board, idx)
  return board:has_roadblock(idx) or board:has_mine(idx)
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
    if _has_obstacle(board, current) then
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

local function _successful_flow_result(res)
  if type(res) ~= "table" or res.ok ~= true then
    return nil
  end
  return res
end

local function _ai_actor_id(player)
  return player and player.id or nil
end

local function _try_use_item(game, player, item_id, phase, cond, auto_play)
  phase, cond, auto_play = _resolve_try_use_item_args(game, phase, cond, auto_play)
  if cond and cond() == false then return nil end
  if not _ai_can_use_item(item_id, phase) then
    return nil
  end
  local res = use_flow.begin_item_use(game, _ai_actor_id(player), item_id, {
    phase = phase,
    is_computer_controlled = true,
    auto_play = auto_play,
  })
  return _successful_flow_result(res)
end

local function _has_target_player(game, player, item_id)
  return auto_play_port.pick_target_player(game, player, item_id, strategy.target_candidates(game, player, item_id)) and true or false
end

local function _has_demolish_target(game, player)
  return demolish.find_target(game, player, 3) and true or false
end

local function _try_clear_obstacles(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.clear_obstacles, phase, function()
    return strategy.has_obstacles_ahead(game, player, 12)
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

local function _try_mine(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.mine, phase, nil, auto_play)
end

local function _try_dice_multiplier(game, player, phase, auto_play)
  return _try_use_item(game, player, item_ids.dice_multiplier, phase, nil, auto_play)
end

-- AI auto-play probes, attempted in priority order; first success short-circuits.
local _AUTO_PRE_ACTION_PROBES = {
  _try_clear_obstacles,
  _try_remote_dice,
  _try_mine,
  _try_dice_multiplier,
  _try_roadblock,
  _try_monster,
  _try_target_items,
  _try_deity_items,
}

local function _run_auto_pre_action_probes(game, player, phase, auto_play)
  for _, probe in ipairs(_AUTO_PRE_ACTION_PROBES) do
    local res = probe(game, player, phase, auto_play)
    if res then
      return res
    end
  end
  return nil
end

function strategy.auto_pre_action(game, player, phase)
  if not auto_play_port.is_computer_controlled(game, player) then
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
version=4
projectHash=a35eafb627026b5c
scope.0.id=chunk:src/rules/items/strategy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=183
scope.0.semanticHash=3d8e4c6aca87946b
scope.1.id=function:strategy.target_candidates
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=14
scope.1.semanticHash=7ce1368e3b62317f
scope.2.id=function:_has_obstacle
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=1bb9d6f0c95917fb
scope.3.id=function:strategy.has_obstacles_ahead
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=43
scope.3.semanticHash=f4e173dcf2cacc5c
scope.4.id=function:strategy.can_offer_in_phase
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=48
scope.4.semanticHash=aaf7796a5f455183
scope.5.id=function:_ai_can_use_item
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=52
scope.5.semanticHash=aba9250a8c6b104f
scope.6.id=function:_resolve_try_use_item_args
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=60
scope.6.semanticHash=b8468d78a8c59b68
scope.7.id=function:_successful_flow_result
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=67
scope.7.semanticHash=1530c6246158fd67
scope.8.id=function:_ai_actor_id
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=71
scope.8.semanticHash=616a2ca60599c94f
scope.9.id=function:_try_use_item
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=85
scope.9.semanticHash=7e8ed2e16c0f3990
scope.10.id=function:_has_target_player
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=89
scope.10.semanticHash=d9e2f21d96931a7c
scope.11.id=function:_has_demolish_target
scope.11.kind=function
scope.11.startLine=91
scope.11.endLine=93
scope.11.semanticHash=978e83dfe3faf179
scope.12.id=function:_try_clear_obstacles
scope.12.kind=function
scope.12.startLine=95
scope.12.endLine=99
scope.12.semanticHash=c9e77b8e48bc92a3
scope.13.id=function:<anonymous>
scope.13.kind=function
scope.13.startLine=96
scope.13.endLine=98
scope.13.semanticHash=7858d26980b501d3
scope.14.id=function:_try_remote_dice
scope.14.kind=function
scope.14.startLine=101
scope.14.endLine=106
scope.14.semanticHash=8712ed5eab454066
scope.15.id=function:<anonymous>#2
scope.15.kind=function
scope.15.startLine=102
scope.15.endLine=105
scope.15.semanticHash=db92403813e5c336
scope.16.id=function:_try_roadblock
scope.16.kind=function
scope.16.startLine=108
scope.16.endLine=112
scope.16.semanticHash=8f2c18dc8d69abb1
scope.17.id=function:<anonymous>#3
scope.17.kind=function
scope.17.startLine=109
scope.17.endLine=111
scope.17.semanticHash=59843f5f82e72f71
scope.18.id=function:_try_target_items
scope.18.kind=function
scope.18.startLine=114
scope.18.endLine=120
scope.18.semanticHash=282cda357fa5f614
scope.19.id=function:<anonymous>#4
scope.19.kind=function
scope.19.startLine=116
scope.19.endLine=116
scope.19.semanticHash=02ac9a604d6b4840
scope.20.id=function:_try_deity_items
scope.20.kind=function
scope.20.startLine=122
scope.20.endLine=126
scope.20.semanticHash=57d142834ec10dec
scope.21.id=function:_try_monster
scope.21.kind=function
scope.21.startLine=128
scope.21.endLine=132
scope.21.semanticHash=491f06daf3e49293
scope.22.id=function:<anonymous>#5
scope.22.kind=function
scope.22.startLine=129
scope.22.endLine=131
scope.22.semanticHash=5076d53a4090f1e9
scope.23.id=function:_try_mine
scope.23.kind=function
scope.23.startLine=134
scope.23.endLine=136
scope.23.semanticHash=8a5a7fbf59151db9
scope.24.id=function:_try_dice_multiplier
scope.24.kind=function
scope.24.startLine=138
scope.24.endLine=140
scope.24.semanticHash=8a5a7fbf59151db9
scope.25.id=function:_run_auto_pre_action_probes
scope.25.kind=function
scope.25.startLine=154
scope.25.endLine=162
scope.25.semanticHash=522bc77cd95d758d
scope.26.id=function:strategy.auto_pre_action
scope.26.kind=function
scope.26.startLine=164
scope.26.endLine=169
scope.26.semanticHash=6899602bde9fa33d
]]
