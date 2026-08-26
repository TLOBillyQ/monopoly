local item_preconsume_policy = {}

-- option 既可能是 { id = ... } 表,也可能是裸 id。
local function _option_id_of(option)
  return type(option) == "table" and option.id or option
end

function item_preconsume_policy.is_cancel_action(action)
  return action ~= nil and action.type == "choice_cancel"
end

local function _options_of(choice)
  return choice and choice.options or nil
end

function item_preconsume_policy.each_option(choice, visitor)
  local options = _options_of(choice)
  if type(options) ~= "table" then
    return nil
  end
  for index, option in ipairs(options) do
    local option_id = _option_id_of(option)
    local result = visitor(option, option_id, index)
    if result ~= nil then
      return result
    end
  end
  return nil
end

function item_preconsume_policy.is_preconsumed(choice)
  return choice ~= nil and choice.meta ~= nil and choice.meta.item_preconsumed == true
end

function item_preconsume_policy.first_option_id(choice)
  return item_preconsume_policy.each_option(choice, function(_, option_id)
    return option_id
  end)
end

local function _build_fallback_select(choice, action, option_id)
  return {
    type = "choice_select",
    choice_id = choice and choice.id or nil,
    option_id = option_id,
    actor_role_id = action and action.actor_role_id or nil,
  }
end

function item_preconsume_policy.normalize_cancel_action(choice, action)
  if not item_preconsume_policy.is_cancel_action(action) then
    return action
  end
  if not item_preconsume_policy.is_preconsumed(choice) then
    return action
  end
  local fallback_option_id = item_preconsume_policy.first_option_id(choice)
  if fallback_option_id == nil then
    return action
  end
  return _build_fallback_select(choice, action, fallback_option_id)
end

function item_preconsume_policy.disable_followup_cancel(choice_spec)
  if type(choice_spec) ~= "table" then
    return choice_spec
  end
  choice_spec.allow_cancel = false
  choice_spec.cancel_label = nil
  return choice_spec
end

function item_preconsume_policy.ensure_followup_meta(choice_spec)
  if type(choice_spec) ~= "table" then
    return nil
  end
  choice_spec.meta = choice_spec.meta or {}
  choice_spec.meta.item_preconsumed = true
  return choice_spec.meta
end

-- 只在 context 带值、且 meta 尚未落过该字段时补写(既有值优先)。
local function _fill_missing_field(meta, key, value)
  if value ~= nil then
    meta[key] = meta[key] or value
  end
end

function item_preconsume_policy.merge_preconsume_context(meta, context)
  if type(meta) ~= "table" then
    return meta
  end
  local ctx = context or {}
  _fill_missing_field(meta, "item_id", ctx.item_id)
  _fill_missing_field(meta, "player_id", ctx.player_id)
  return meta
end

-- force_skip 等放弃路径的退还入口:薄适配到结算台账(惰性 require,
-- settlement 不得反向依赖本 policy)。
function item_preconsume_policy.refund(game, choice)
  local settlement = require("src.rules.items.settlement")
  -- #293:abandon 忽略第三参(签名 `(game, choice, _)`),label 是死参数,
  -- 等价变异体处置——删冗余。
  return settlement.abandon(game, choice)
end

function item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)
  if type(choice_spec) ~= "table" then
    return choice_spec
  end
  item_preconsume_policy.disable_followup_cancel(choice_spec)
  local meta = item_preconsume_policy.ensure_followup_meta(choice_spec)
  item_preconsume_policy.merge_preconsume_context(meta, context)
  return choice_spec
end

return item_preconsume_policy

--[[ mutate4lua-manifest
version=4
projectHash=6428d33ee6c76ca9
scope.0.id=chunk:src/rules/choice/item_preconsume_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=a0ddaf0f302780dd
scope.1.id=function:_option_id_of
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=a21febbf33b567dd
scope.2.id=function:item_preconsume_policy.is_cancel_action
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=812996efe26ec454
scope.3.id=function:_options_of
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:item_preconsume_policy.each_option
scope.4.kind=function
scope.4.startLine=16
scope.4.endLine=29
scope.4.semanticHash=f602b8131637625b
scope.5.id=function:item_preconsume_policy.is_preconsumed
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=33
scope.5.semanticHash=cd1bb19b3314f0b0
scope.6.id=function:item_preconsume_policy.first_option_id
scope.6.kind=function
scope.6.startLine=35
scope.6.endLine=39
scope.6.semanticHash=2942d4571fac2ab2
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=36
scope.7.endLine=38
scope.7.semanticHash=75fd9f7ef74ec050
scope.8.id=function:_build_fallback_select
scope.8.kind=function
scope.8.startLine=41
scope.8.endLine=48
scope.8.semanticHash=bac31885529b113c
scope.9.id=function:item_preconsume_policy.normalize_cancel_action
scope.9.kind=function
scope.9.startLine=50
scope.9.endLine=62
scope.9.semanticHash=6998d1be8621ad17
scope.10.id=function:item_preconsume_policy.disable_followup_cancel
scope.10.kind=function
scope.10.startLine=64
scope.10.endLine=71
scope.10.semanticHash=aeda71630b1f968e
scope.11.id=function:item_preconsume_policy.ensure_followup_meta
scope.11.kind=function
scope.11.startLine=73
scope.11.endLine=80
scope.11.semanticHash=a40b4dc15fdee08c
scope.12.id=function:_fill_missing_field
scope.12.kind=function
scope.12.startLine=83
scope.12.endLine=87
scope.12.semanticHash=0450c145cc4e3d4f
scope.13.id=function:item_preconsume_policy.merge_preconsume_context
scope.13.kind=function
scope.13.startLine=89
scope.13.endLine=97
scope.13.semanticHash=adad4fef2909b663
scope.14.id=function:item_preconsume_policy.refund
scope.14.kind=function
scope.14.startLine=101
scope.14.endLine=106
scope.14.semanticHash=21b93cd161fa01ce
scope.15.id=function:item_preconsume_policy.decorate_followup_choice_spec
scope.15.kind=function
scope.15.startLine=108
scope.15.endLine=116
scope.15.semanticHash=f331297556803f69
]]
