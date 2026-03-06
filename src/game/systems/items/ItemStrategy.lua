local agent = require("src.game.core.runtime.Agent")
local item_effects = require("src.game.systems.items.ItemPostEffects")
local gameplay_rules = require("src.core.config.GameplayRules")
local logger = require("src.core.Logger")
local inventory = require("src.game.systems.items.ItemInventory")
local executor = require("src.game.systems.items.ItemExecutor")
local demolish = require("src.game.systems.items.ItemDemolish")
local roadblock = require("src.game.systems.items.ItemRoadblock")

local strategy = {}
local item_ids = gameplay_rules.item_ids
local target_item_set = {}
for _, target_item_id in ipairs(item_effects.target_item_ids()) do
  target_item_set[target_item_id] = true
end

function strategy.target_candidates(game, player, item_id)
  local registries = assert(game.registries, "missing game.registries")
  local item_registry = assert(registries.items, "missing item registry")
  return item_registry:target_candidates(game, player, item_id)
end

function strategy.has_obstacles_ahead(game, player, distance)
  local board = game.board
  distance = distance or 12
  local parity = distance
  local current = player.position
  local facing = player.status.move_dir

  for _ = 1, distance do
    local next_index, _passed, step_dir = board:step_forward_by_facing(current, facing, parity)
    current = next_index
    facing = step_dir or facing
    if board:has_roadblock(current) or board:has_mine(current) then
      return true
    end
  end
  return false
end

local phase_timing = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, manual = true, turn = true },
}

function strategy.timing_allowed(phase, timing, allow_missing_phase)
  if not phase then
    return allow_missing_phase
  end
  local allowed = phase_timing[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

function strategy.can_offer_in_phase(game, player, item_id, phase)
  local cfg = inventory.cfg(item_id)
  if not cfg then
    return false
  end
  if not strategy.timing_allowed(phase, cfg.timing, false) then
    return false
  end

  if item_id == item_ids.roadblock then
    local candidates = nil
    if agent.is_auto_player(player) then
      candidates = roadblock.auto_candidates(game, player, 3)
    else
      candidates = roadblock.ui_candidates(game, player, 3)
    end
    return type(candidates) == "table" and #candidates > 0
  end

  if item_id == item_ids.monster or item_id == item_ids.missile then
    return demolish.find_target(game, player, 3) ~= nil
  end

  if target_item_set[item_id] then
    local candidates = strategy.target_candidates(game, player, item_id)
    return type(candidates) == "table" and #candidates > 0
  end

  return true
end

function strategy.auto_pre_action(game, player, phase)
  if not agent.is_auto_player(player) then
    return nil
  end

  local function _can_use(item_id)
    local cfg = inventory.cfg(item_id)
    local timing = cfg.timing
    return strategy.timing_allowed(phase, timing, true)
  end

  local function _try_use(item_id, cond)
    if cond and cond() == false then return nil end
    if _can_use(item_id) then
    else
      return nil
    end
    if inventory.find_index(player, item_id) then
    else
      return nil
    end
    local res = executor.use_item(game, player, item_id, { by_ai = true })
    if type(res) == "table" and (res.waiting or res.intent or res.kind or res.action_anim) then
      return res
    end
    return nil
  end

  local function _has_target(item_id)
    return agent.pick_target_player(game, player, item_id, strategy.target_candidates(game, player, item_id)) and true or false
  end

  local function _has_demolish_target()
    return demolish.find_target(game, player, 3) and true or false
  end

  local clear_result = _try_use(item_ids.clear_obstacles, function()
    local found = strategy.has_obstacles_ahead(game, player, 12)
    if found then logger.event(player.name .. " 前方发现障碍，准备使用清障卡") end
    return found
  end)
  if clear_result then return clear_result end

  local dice_result = _try_use(item_ids.remote_dice, function()
    local dice_count = game:player_dice_count(player)
    return agent.pick_remote_dice_value(game, player, dice_count) and true or false
  end)
  if dice_result then return dice_result end

  local mine_result = _try_use(item_ids.mine)
  if mine_result then return mine_result end

  local double_result = _try_use(item_ids.dice_multiplier)
  if double_result then return double_result end

  local roadblock_result = _try_use(item_ids.roadblock, function()
    return agent.pick_roadblock_target(game, player) and true or false
  end)
  if roadblock_result then return roadblock_result end

  local monster_result = _try_use(item_ids.monster, _has_demolish_target)
  if monster_result then return monster_result end
  local missile_result = _try_use(item_ids.missile, _has_demolish_target)
  if missile_result then return missile_result end

  for _, id in ipairs(item_effects.target_item_ids()) do
    local res = _try_use(id, function() return _has_target(id) end)
    if res then return res end
  end

  return _try_use(item_ids.rich) or _try_use(item_ids.angel)
end

return strategy
