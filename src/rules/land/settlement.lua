local card_choice = require("src.rules.land.settlement_card_choice")
local effect_choice = require("src.rules.land.settlement_effect_choice")
local landing = require("src.rules.land.settlement_landing")
local shared = require("src.rules.land.settlement_shared")

local settlement = {}

function settlement.begin_landing_settlement(game, actor_id, context)
  return landing.begin_landing_settlement(game, actor_id, context)
end

local function _kind_of(choice)
  return choice and choice.kind or nil
end

function settlement.resolve_landing_settlement_choice(game, choice, action)
  local kind = _kind_of(choice)
  if kind == "landing_optional_effect" then
    return effect_choice.resolve(game, choice, action)
  end
  if kind == "rent_card_prompt" then
    return card_choice.resolve_rent(game, choice, action)
  end
  if kind == "tax_card_prompt" then
    return card_choice.resolve_tax(game, choice, action)
  end
  return shared.reject("not_landing_choice")
end

settlement._M_test = {
  _has_pending_relocation_action_anim = landing._M_test._has_pending_relocation_action_anim,
  _option_is_offered = effect_choice._M_test._option_is_offered,
}

return settlement

--[[ mutate4lua-manifest
version=4
projectHash=40418530f271e5fe
scope.0.id=chunk:src/rules/land/settlement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=73638604fda3821f
scope.1.id=function:settlement.begin_landing_settlement
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=d590c542c8c308c5
scope.2.id=function:_kind_of
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=14
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:settlement.resolve_landing_settlement_choice
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=28
scope.3.semanticHash=5afca8ea8560ff1f
]]
