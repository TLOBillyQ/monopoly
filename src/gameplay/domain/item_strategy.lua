local constants = require("src.config.constants")
local Agent = require("src.gameplay.ai.agent")
local ItemEffects = require("src.gameplay.domain.item_post_effects")
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
  local parity = 1
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
    if cond and not cond() then
      return nil
    end
    if not inventory.find_index(player, item_id) then
      return nil
    end
    if item_id == 2006 then
      logger.event(player.name .. " 使用清障卡，尝试清理前方障碍")
    end
    local res = use_item(game, player, item_id, { by_ai = true })
    if type(res) == "table" and (res.waiting or res.intent or res.kind) then
      return res
    end
    return nil
  end

  local function has_target(item_id)
    return Strategy.pick_target_player(game, player, item_id, Strategy.target_candidates(game, player, item_id)) ~= nil
  end

  local rules = {
    {
      id = 2006,
      cond = function()
        local found = Strategy.has_obstacles_ahead(game, player, 12)
        if found and inventory.find_index(player, 2006) then
          logger.event(player.name .. " 前方发现障碍，准备使用清障卡")
        end
        return found
      end,
    },
    {
      id = 2002,
      cond = function()
        local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
        local value = Agent.pick_remote_dice_value(game, player, dice_count)
        return value ~= nil
      end,
    },
    { id = 2003 },
    { id = 2004, cond = function() return Agent.pick_roadblock_target(game, player) ~= nil end },
    {
      id = 2008,
      cond = function()
        if deps.find_monster_target then
          return deps.find_monster_target(game, player, 3) ~= nil
        end
        return false
      end,
    },
    {
      id = 2013,
      cond = function()
        if deps.find_missile_target then
          return deps.find_missile_target(game, player, 3) ~= nil
        end
        return false
      end,
    },
    { id = 2011, cond = function() return has_target(2011) end },
    { id = 2012, cond = function() return has_target(2012) end },
    { id = 2014, cond = function() return has_target(2014) end },
    { id = 2015, cond = function() return has_target(2015) end },
    { id = 2016, cond = function() return has_target(2016) end },
    { id = 2018, cond = function() return has_target(2018) end },
  }

  for _, r in ipairs(rules) do
    local waiting = try_use(r.id, r.cond)
    if waiting then
      return waiting
    end
  end

  return try_use(2017) or try_use(2019)
end

return Strategy
