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

local function _mountain_skipped(result)
  return result ~= nil and result.event == "rent_skipped_mountain"
end

local function _ok_result(result)
  return result ~= nil and result.ok
end

function land_actions.execute_pay_rent(game, player_id, tile_id)
  local result = land_rules.execute_pay_rent(game, player_id, tile_id)
  if _mountain_skipped(result) then
    land_events.apply(game, result)
    return false
  end
  if _ok_result(result) then
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
version=4
projectHash=6a7165d054d563e7
scope.0.id=chunk:src/rules/land/actions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=68
scope.0.semanticHash=a9d991bd831652b7
scope.1.id=function:land_actions.resolve_rent_owner
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=21
scope.1.semanticHash=81c3c974d53e4402
scope.2.id=function:_execute_and_apply
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=2136e0d5ccd1e59c
scope.3.id=function:land_actions.execute_strong_card
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=33
scope.3.semanticHash=4fe8677a94a446bb
scope.4.id=function:land_actions.execute_free_card
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=37
scope.4.semanticHash=4fe8677a94a446bb
scope.5.id=function:_mountain_skipped
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=41
scope.5.semanticHash=812996efe26ec454
scope.6.id=function:_ok_result
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=45
scope.6.semanticHash=6efffdae1054701b
scope.7.id=function:land_actions.execute_pay_rent
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=57
scope.7.semanticHash=30fc3836918ced9d
scope.8.id=function:land_actions.execute_tax_free_card
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=61
scope.8.semanticHash=dc26f1875d1eb3b7
scope.9.id=function:land_actions.execute_pay_tax
scope.9.kind=function
scope.9.startLine=63
scope.9.endLine=65
scope.9.semanticHash=dc26f1875d1eb3b7
]]
