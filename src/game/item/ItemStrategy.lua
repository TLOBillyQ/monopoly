local Agent = require("src.game.game.Agent")
local ItemEffects = require("src.game.item.ItemPostEffects")
local GameplayRules = require("Config.GameplayRules")
local Logger = require("src.core.Logger")
local Inventory = require("src.game.item.ItemInventory")
local Executor = require("src.game.item.ItemExecutor")
local Demolish = require("src.game.item.ItemDemolish")
local ItemRegistry = require("src.game.item.ItemRegistry")

local Strategy = {}
local ITEM_IDS = GameplayRules.item_ids

function Strategy.TargetCandidates(game, player, item_id)
  return ItemRegistry.TargetCandidates(game, player, item_id)
end

function Strategy.HasObstaclesAhead(game, player, distance)
  local board = game.board
  distance = distance or 12
  local parity = distance
  local current = player.position
  local facing = player.status.move_dir

  for _ = 1, distance do
    local next_index, _passed, step_dir = board:StepForwardByFacing(current, facing, parity)
    current = next_index
    facing = step_dir or facing
    if board:HasRoadblock(current) or board:HasMine(current) then
      return true
    end
  end
  return false
end

local PHASE_TIMING = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, manual = true, turn = true },
}

function Strategy.TimingAllowed(phase, timing, allow_missing_phase)
  if not phase then
    return allow_missing_phase
  end
  local allowed = PHASE_TIMING[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

function Strategy.AutoPreAction(game, player, phase)
  if not Agent.IsAutoPlayer(player) then
    return nil
  end

  local function _CanUse(item_id)
    local cfg = Inventory.Cfg(item_id)
    local timing = cfg.timing
    return Strategy.TimingAllowed(phase, timing, true)
  end

  local function _TryUse(item_id, cond)
    if cond and cond() == false then return nil end
    if _CanUse(item_id) then
    else
      return nil
    end
    if Inventory.FindIndex(player, item_id) then
    else
      return nil
    end
    local res = Executor.UseItem(game, player, item_id, { by_ai = true })
    if type(res) == "table" and (res.waiting or res.intent or res.kind or res.action_anim) then
      return res
    end
    return nil
  end

  local function _HasTarget(item_id)
    return Agent.PickTargetPlayer(game, player, item_id, Strategy.TargetCandidates(game, player, item_id)) and true or false
  end

  local function _HasDemolishTarget()
    return Demolish.FindTarget(game, player, 3) and true or false
  end

  local clear_result = _TryUse(ITEM_IDS.clear_obstacles, function()
    local found = Strategy.HasObstaclesAhead(game, player, 12)
    if found then Logger.Event(player.name .. " 前方发现障碍，准备使用清障卡") end
    return found
  end)
  if clear_result then return clear_result end

  local dice_result = _TryUse(ITEM_IDS.remote_dice, function()
    local dice_count = player:DiceCount()
    return Agent.PickRemoteDiceValue(game, player, dice_count) and true or false
  end)
  if dice_result then return dice_result end

  local mine_result = _TryUse(ITEM_IDS.mine)
  if mine_result then return mine_result end

  local double_result = _TryUse(ITEM_IDS.dice_multiplier)
  if double_result then return double_result end

  local roadblock_result = _TryUse(ITEM_IDS.roadblock, function()
    return Agent.PickRoadblockTarget(game, player) and true or false
  end)
  if roadblock_result then return roadblock_result end

  local monster_result = _TryUse(ITEM_IDS.monster, _HasDemolishTarget)
  if monster_result then return monster_result end
  local missile_result = _TryUse(ITEM_IDS.missile, _HasDemolishTarget)
  if missile_result then return missile_result end

  for _, id in ipairs(ItemEffects.TargetItemIds()) do
    local res = _TryUse(id, function() return _HasTarget(id) end)
    if res then return res end
  end

  return _TryUse(ITEM_IDS.rich) or _TryUse(ITEM_IDS.angel)
end

return Strategy


