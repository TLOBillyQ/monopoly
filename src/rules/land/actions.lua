local land_actions = {}
local land_events = require("src.rules.land.events")
local land_rules = require("src.rules.land.landing_rules")
land_actions.safe_tile_state = land_rules.safe_tile_state

function land_actions.resolve_rent_owner(game, tile, state_fn)
  local owner, st, skip = land_rules.resolve_rent_owner(game, tile, state_fn)
  if skip and skip.reason == "mountain" then
    land_events.apply(game, {
      ok = false,
      event = "rent_skipped_mountain",
      payload = {
        owner = skip.owner,
        tile = tile,
        text = skip.owner.name .. " 在深山，租金不收取",
      },
    })
    return nil, st
  end
  return owner, st
end

local function _execute_and_apply(rule_fn, game, ...)
  local result = rule_fn(game, ...)
  if result and result.ok then
    land_events.apply(game, result)
  end
  return result and result.ok == true
end

function land_actions.execute_strong_card(game, player_id, tile_id)
  return _execute_and_apply(land_rules.execute_strong_card, game, player_id, tile_id)
end

function land_actions.execute_free_card(game, player_id, tile_id)
  return _execute_and_apply(land_rules.execute_free_card, game, player_id, tile_id)
end

function land_actions.execute_pay_rent(game, player_id, tile_id)
  local result = land_rules.execute_pay_rent(game, player_id, tile_id)
  if result and result.event == "rent_skipped_mountain" then
    land_events.apply(game, result)
    return false
  end
  if result and result.ok then
    land_events.apply(game, result)
  end
  return result and result.ok == true
end

function land_actions.execute_tax_free_card(game, player_id)
  return _execute_and_apply(land_rules.execute_tax_free_card, game, player_id)
end

function land_actions.execute_pay_tax(game, player_id)
  return _execute_and_apply(land_rules.execute_pay_tax, game, player_id)
end

return land_actions

--[[ mutate4lua-manifest
version=2
projectHash=93925de458522eb7
scope.0.id=chunk:src/rules/land/actions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=6fd7b3c09b2107bf
scope.1.id=function:land_actions.resolve_rent_owner:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=21
scope.1.semanticHash=b4c0f97e9acd8af6
scope.2.id=function:_execute_and_apply:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=25125c1e64463b6e
scope.3.id=function:land_actions.execute_strong_card:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=33
scope.3.semanticHash=c13106a5728df627
scope.4.id=function:land_actions.execute_free_card:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=37
scope.4.semanticHash=f1ed7798aeb9132b
scope.5.id=function:land_actions.execute_pay_rent:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=49
scope.5.semanticHash=1074c8b398aef92f
scope.6.id=function:land_actions.execute_tax_free_card:51
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=53
scope.6.semanticHash=645be50c3b1f3c4b
scope.7.id=function:land_actions.execute_pay_tax:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=8f59dd76c261aa17
]]
