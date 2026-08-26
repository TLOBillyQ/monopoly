local logger = require("src.foundation.log")
local availability = require("src.rules.items.availability")
local denial_tip = require("src.turn.actions.item_slot_denial_tip")

local item_slot_denial = {}

local function _option_id(option)
  return type(option) == "table" and option.id or option
end

function item_slot_denial.choice_offers_item(choice, item_id)
  local options = choice.options
  if type(options) ~= "table" then
    return false
  end
  for _, option in ipairs(options) do
    if _option_id(option) == item_id then
      return true
    end
  end
  return false
end

-- 卡在窗里没被 offer 的具体原因由 rules 的可用性判定给出；判不出（ok / 未知）
-- 属设计不可达，走通用文案并留 warn。
local function _phase_of(choice)
  return choice.meta and choice.meta.phase or nil
end

local function _invalid_phase(phase)
  return type(phase) ~= "string" or phase == ""
end

function item_slot_denial.unavailable_reason(game, actor, choice, item_id)
  local phase = _phase_of(choice)
  if _invalid_phase(phase) then
    logger.warn("item slot window without phase:", tostring(choice.id), tostring(item_id))
    return "unknown"
  end
  local can_offer, deny_reason = availability.can_offer_in_phase(game, actor, item_id, phase)
  if can_offer then
    logger.warn("item slot missing from options while offerable:", tostring(item_id), tostring(phase))
    return "unknown"
  end
  return deny_reason or "unknown"
end

function item_slot_denial.deny(game, actor_role_id, item_id, reason)
  denial_tip.emit(game, actor_role_id, item_id, reason)
  return { status = "denied", reason = reason }
end

return item_slot_denial

--[[ mutate4lua-manifest
version=4
projectHash=37fbe4b5091a00ed
scope.0.id=chunk:src/turn/actions/item_slot_denial.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=199a981dfe037c3e
scope.1.id=function:item_slot_denial.choice_offers_item
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=18
scope.1.semanticHash=60a681e476f077b7
scope.2.id=function:item_slot_denial.unavailable_reason
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=34
scope.2.semanticHash=ccbe0c46db22b9cf
scope.3.id=function:item_slot_denial.deny
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=39
scope.3.semanticHash=f3fe6bb3361fcbcd
]]
