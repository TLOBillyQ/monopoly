local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local logger = require("src.core.utils.logger")
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
    local next_index, _passed, next_facing, step_entered_inner = board:step_forward_by_facing(current, facing, {
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

function strategy.can_offer_in_phase(game, player, item_id, phase, _auto_play)
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
  if _ai_can_use_item(item_id, phase) then
  else
    return nil
  end
  if inventory.find_index(player, item_id) then
  else
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

local function _auto_pre_action_probes(game, player, phase, auto_play)
  return {
    function()
      return _try_clear_obstacles(game, player, phase, auto_play)
    end,
    function()
      return _try_remote_dice(game, player, phase, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.mine, phase, nil, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.dice_multiplier, phase, nil, auto_play)
    end,
    function()
      return _try_roadblock(game, player, phase, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.monster, phase, function()
        return _has_demolish_target(game, player)
      end, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.missile, phase, function()
        return _has_demolish_target(game, player)
      end, auto_play)
    end,
    function()
      return _try_target_items(game, player, phase, auto_play)
    end,
    function()
      return _try_deity_items(game, player, phase, auto_play)
    end,
  }
end

local function _run_auto_pre_action_probes(game, player, phase, auto_play)
  for _, probe in ipairs(_auto_pre_action_probes(game, player, phase, auto_play)) do
    local result = probe()
    if result then
      return result
    end
  end
  return nil
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
