local logger = require("src.util.logger")
local Services = require("src.util.services")

local TargetEffects = {}

local function ensure_status(game, action)
  local status = Services.status(game)
  if not status then
    logger.warn("缺少 StatusService，无法" .. action)
  end
  return status
end

local function ensure_bankruptcy(game, action)
  local bankruptcy = Services.bankruptcy(game)
  if not bankruptcy then
    logger.warn("缺少 BankruptcyService，无法" .. action)
  end
  return bankruptcy
end

local function find_item_index(player, item_id)
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

local SPECS = {
  [2011] = {
    apply = function(_, user, target)
      local total = user.cash + target.cash
      local half = math.floor(total / 2)
      user:set_cash(half)
      target:set_cash(total - half)
      logger.event(user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
      return true
    end,
  },
  [2012] = {
    apply = function(game, user, target)
      local status = ensure_status(game, "流放")
      if not status then
        return false
      end
      status.send_to_mountain(game, target)
      logger.event(user.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
      return true
    end,
  },
  [2014] = {
    apply = function(game, user, target)
      local status = ensure_status(game, "查税")
      if not status then
        return false
      end
      if status.has_angel(target) then
        logger.event(target.name .. " 有天使，查税无效")
        return true
      end
      local tax_free = find_item_index(target, 2010)
      if tax_free then
        target.inventory:remove_by_index(tax_free)
        logger.event(target.name .. " 使用免税卡抵消查税")
        return true
      end
      local fee = math.floor(target.cash * 0.5)
      target:deduct_cash(fee)
      logger.event(user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
      if target.cash < 0 then
        local bankruptcy = ensure_bankruptcy(game, "淘汰破产玩家")
        if bankruptcy then
          bankruptcy.eliminate(game, target)
        end
      end
      return true
    end,
  },
  [2015] = {
    filter_target = function(_, _, target)
      return target.status.deity ~= nil
    end,
    apply = function(_, user, target)
      if not target.status.deity then
        logger.warn("没有可请的神")
        return false
      end
      local deity = target.status.deity
      target:set_deity(nil)
      user:set_deity(deity.type, deity.remaining)
      logger.event(user.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. deity.type)
      return true
    end,
  },
  [2016] = {
    require_user = function(user)
      if not user:has_deity("poor") then
        logger.warn("未附身穷神，无法送神")
        return false
      end
      return true
    end,
    apply = function(_, user, target)
      local remaining = user.status.deity and user.status.deity.remaining or nil
      target:set_deity("poor", remaining)
      user:set_deity(nil)
      logger.event(user.name .. " 使用送神卡，将穷神送给 " .. target.name)
      return true
    end,
  },
  [2018] = {
    apply = function(_, user, target)
      target:set_deity("poor")
      logger.event(user.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
      return true
    end,
  },
}

function TargetEffects.get_spec(item_id)
  return SPECS[item_id]
end

function TargetEffects.apply(game, user, item_id, target)
  local spec = SPECS[item_id]
  if not spec or not spec.apply then
    return false
  end
  return spec.apply(game, user, target)
end

return TargetEffects
