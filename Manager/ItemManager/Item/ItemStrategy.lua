local Agent = require("Manager.GameManager.Agent")
local ItemEffects = require("Manager.ItemManager.Item.ItemPostEffects")
local gameplay_constants = require("Manager.GameManager.Constants")
local logger = require("Library.Monopoly.Logger")

local Strategy = {}
local ITEM_IDS = gameplay_constants.item_ids

function Strategy.target_candidates(game, player, item_id)
  local spec = ItemEffects.get_target_spec(item_id)
  if not spec then
    return {}
  end

  if spec.require_user and not spec.require_user(player) then
    return {}
  end

  local candidates = {}
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated then
      if not spec.filter_target or spec.filter_target(game, player, p) then
        table.insert(candidates, p)
      end
    end
  end
  return candidates
end

function Strategy.has_obstacles_ahead(game, player, distance)
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

local PHASE_TIMING = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, manual = true, turn = true },
}

function Strategy.timing_allowed(phase, timing, allow_missing_phase)
  if not phase then
    return allow_missing_phase
  end
  local allowed = PHASE_TIMING[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

function Strategy.auto_pre_action(game, player, deps, phase)
  if not Agent.is_auto_player(player) then
    return nil
  end

  local inventory = assert(deps.inventory, "inventory deps required")
  local use_item = assert(deps.use_item, "use_item deps required")

  local function can_use(item_id)
    local cfg = inventory.cfg(item_id)
    local timing = cfg.timing
    return Strategy.timing_allowed(phase, timing, true)
  end

  local function try_use(item_id, cond)
    if cond and not cond() then return nil end
    if not can_use(item_id) then return nil end
    if not inventory.find_index(player, item_id) then return nil end
    local res = use_item(game, player, item_id, { by_ai = true })
    if type(res) == "table" and (res.waiting or res.intent or res.kind or res.action_anim) then
      return res
    end
    return nil
  end

  local function has_target(item_id)
    return Agent.pick_target_player(game, player, item_id, Strategy.target_candidates(game, player, item_id)) ~= nil
  end

  local function has_demolish_target()
    return deps.find_monster_target and deps.find_monster_target(game, player, 3) ~= nil
  end

  local clear_result = try_use(ITEM_IDS.clear_obstacles, function()
    local found = Strategy.has_obstacles_ahead(game, player, 12)
    if found then logger.event(player.name .. " 前方发现障碍，准备使用清障卡") end
    return found
  end)
  if clear_result then return clear_result end

  local dice_result = try_use(ITEM_IDS.remote_dice, function()
    local dice_count = player:dice_count()
    return Agent.pick_remote_dice_value(game, player, dice_count) ~= nil
  end)
  if dice_result then return dice_result end

  local mine_result = try_use(ITEM_IDS.mine)
  if mine_result then return mine_result end

  local double_result = try_use(ITEM_IDS.dice_multiplier)
  if double_result then return double_result end

  local roadblock_result = try_use(ITEM_IDS.roadblock, function() return Agent.pick_roadblock_target(game, player) ~= nil end)
  if roadblock_result then return roadblock_result end

  local monster_result = try_use(ITEM_IDS.monster, has_demolish_target)
  if monster_result then return monster_result end
  local missile_result = try_use(ITEM_IDS.missile, has_demolish_target)
  if missile_result then return missile_result end

  for _, id in ipairs(ItemEffects.target_item_ids()) do
    local res = try_use(id, function() return has_target(id) end)
    if res then return res end
  end

  return try_use(ITEM_IDS.rich) or try_use(ITEM_IDS.angel)
end

return Strategy

