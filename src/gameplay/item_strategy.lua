local Agent = require("src.gameplay.agent")
local ItemEffects = require("src.gameplay.item_post_effects")
local logger = require("src.util.logger")

local Strategy = {}

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

function Strategy.pick_target_player(game, player, item_id, candidates)
  return Agent.pick_target_player(game, player, item_id, candidates)
end

function Strategy.has_obstacles_ahead(game, player, distance)
  local board = game.board
  distance = distance or 12
  local parity = distance
  local current = player.position
  local facing = player.status and player.status.move_dir or nil
  
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

function Strategy.auto_pre_action(game, player, deps)
  if not Agent.is_auto_player(player) then
    return nil
  end

  local inventory = assert(deps.inventory, "inventory deps required")
  local use_item = assert(deps.use_item, "use_item deps required")

  local function try_use(item_id, cond)
    if cond and not cond() then return nil end
    if not inventory.find_index(player, item_id) then return nil end
    local res = use_item(game, player, item_id, { by_ai = true })
    if type(res) == "table" and (res.waiting or res.intent or res.kind) then
      return res
    end
    return nil
  end

  local function has_target(item_id)
    return Strategy.pick_target_player(game, player, item_id, Strategy.target_candidates(game, player, item_id)) ~= nil
  end

  local function has_demolish_target()
    return deps.find_monster_target and deps.find_monster_target(game, player, 3) ~= nil
  end

  -- 优先使用清障卡
  local clear_result = try_use(2006, function()
    local found = Strategy.has_obstacles_ahead(game, player, 12)
    if found then logger.event(player.name .. " 前方发现障碍，准备使用清障卡") end
    return found
  end)
  if clear_result then return clear_result end

  -- 遥控骰子
  local dice_result = try_use(2002, function()
    local dice_count = player:dice_count()
    return Agent.pick_remote_dice_value(game, player, dice_count) ~= nil
  end)
  if dice_result then return dice_result end

  -- 骰子加倍
  local double_result = try_use(2003)
  if double_result then return double_result end

  -- 路障卡
  local roadblock_result = try_use(2004, function() return Agent.pick_roadblock_target(game, player) ~= nil end)
  if roadblock_result then return roadblock_result end

  -- 怪兽/导弹
  local monster_result = try_use(2008, has_demolish_target)
  if monster_result then return monster_result end
  local missile_result = try_use(2013, has_demolish_target)
  if missile_result then return missile_result end

  -- 针对目标玩家的道具
  local target_items = { 2011, 2012, 2014, 2015, 2016, 2018 }
  for _, id in ipairs(target_items) do
    local res = try_use(id, function() return has_target(id) end)
    if res then return res end
  end

  -- 附身类道具
  return try_use(2017) or try_use(2019)
end

return Strategy
