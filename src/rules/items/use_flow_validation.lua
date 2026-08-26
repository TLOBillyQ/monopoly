local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")
local flow_context = require("src.rules.items.use_flow_context")
local flow_result = require("src.rules.items.use_flow_result")

local validation = {}

local function _reject_missing_begin_subject(game, player, item_id)
  if game == nil then
    return flow_result.rejected("missing_game")
  end
  if player == nil then
    return flow_result.rejected("missing_actor", { item_id = item_id })
  end
  return nil
end

local function _reject_unusable_item(player, item_id)
  if inventory.cfg(item_id) == nil then
    return flow_result.rejected("missing_item_cfg", { actor = player, actor_id = player.id, item_id = item_id })
  end
  if inventory.find_index(player, item_id) == nil then
    return flow_result.rejected("item_not_in_inventory", { actor = player, actor_id = player.id, item_id = item_id })
  end
  return nil
end

local function _reject_phase_unavailable(game, player, item_id, phase)
  if phase == nil then
    return nil
  end
  local can_offer, deny_reason = availability.can_offer_in_phase(game, player, item_id, phase)
  if can_offer == true then
    return nil
  end
  return flow_result.rejected(deny_reason or "item_unavailable", {
    actor = player,
    actor_id = player.id,
    item_id = item_id,
  })
end

function validation.validate_begin(game, player, item_id, use_context)
  local invalid = _reject_missing_begin_subject(game, player, item_id)
  if invalid ~= nil then return invalid end

  invalid = _reject_unusable_item(player, item_id)
  if invalid ~= nil then return invalid end

  invalid = _reject_phase_unavailable(game, player, item_id, use_context.phase)
  if invalid ~= nil then return invalid end

  return nil
end

local function _option_matches(option, option_id)
  return option == option_id
    or tostring(option) == tostring(option_id)
    or (type(option) == "table" and (option.id == option_id or tostring(option.id) == tostring(option_id)))
end

local function _choice_has_option(choice, option_id)
  for _, option in ipairs(choice and choice.options or {}) do
    if _option_matches(option, option_id) then
      return true
    end
  end
  return false
end

local function _reject_missing_choice_subject(game, choice, action)
  if game == nil then
    return flow_result.rejected("missing_game")
  end
  if type(choice) ~= "table" then
    return flow_result.rejected("missing_choice")
  end
  if action == nil then
    return flow_result.rejected("missing_action", { choice = choice })
  end
  return nil
end

local function _reject_choice_mismatch(choice, action)
  if action.choice_id ~= nil and choice.id ~= nil and tostring(action.choice_id) ~= tostring(choice.id) then
    return flow_result.rejected("choice_mismatch", { choice = choice })
  end
  return nil
end

local function _resolve_choice_actor(game, choice, action, meta)
  local player = flow_context.resolve_actor(game, meta.player_id)
  if player == nil then
    return nil, flow_result.rejected("missing_actor", { choice = choice })
  end
  if action.actor_role_id ~= nil and tostring(action.actor_role_id) ~= tostring(player.id) then
    return nil, flow_result.rejected("actor_mismatch", { actor = player, actor_id = player.id, choice = choice })
  end
  return player, nil
end

local function _reject_item_mismatch(player, choice, meta, use_context)
  if use_context.item_id ~= nil and meta.item_id ~= nil and tostring(use_context.item_id) ~= tostring(meta.item_id) then
    return flow_result.rejected("item_mismatch", { actor = player, actor_id = player.id, choice = choice })
  end
  return nil
end

local function _reject_invalid_option(player, choice, action)
  if not _choice_has_option(choice, action.option_id) then
    return flow_result.rejected("invalid_option", { actor = player, actor_id = player.id, choice = choice })
  end
  return nil
end

local function _validate_choice_subject(game, choice, action)
  local invalid = _reject_missing_choice_subject(game, choice, action)
  if invalid ~= nil then return nil, invalid end

  invalid = _reject_choice_mismatch(choice, action)
  if invalid ~= nil then return nil, invalid end

  return choice.meta or {}, nil
end

local function _validate_choice_target(game, choice, action, use_context, meta)
  local player, invalid = _resolve_choice_actor(game, choice, action, meta)
  if invalid ~= nil then return nil, invalid end

  invalid = _reject_item_mismatch(player, choice, meta, use_context)
  if invalid ~= nil then return nil, invalid end

  invalid = _reject_invalid_option(player, choice, action)
  if invalid ~= nil then return nil, invalid end

  return player, nil
end

function validation.validate_choice(game, choice, action, use_context)
  local meta, invalid = _validate_choice_subject(game, choice, action)
  if invalid ~= nil then return nil, nil, nil, invalid end

  local player
  player, invalid = _validate_choice_target(game, choice, action, use_context, meta)
  if invalid ~= nil then return nil, nil, nil, invalid end

  return meta, player, meta.item_id or use_context.item_id, nil
end

return validation

--[[ mutate4lua-manifest
version=4
projectHash=177552d93639a667
scope.0.id=chunk:src/rules/items/use_flow_validation.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=e3ddd8c89732b38e
scope.1.id=function:_reject_missing_begin_subject
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=16
scope.1.semanticHash=16510b553a67c877
scope.2.id=function:_reject_unusable_item
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=70ccd8d07da0e376
scope.3.id=function:_reject_phase_unavailable
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=41
scope.3.semanticHash=de34ee7f6a4385c5
scope.4.id=function:validation.validate_begin
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=54
scope.4.semanticHash=f1e2d98d6e0eca08
scope.5.id=function:_option_matches
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=60
scope.5.semanticHash=712a6faf95dee633
scope.6.id=function:_choice_has_option
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=69
scope.6.semanticHash=c5c8538d0ffb6a9d
scope.7.id=function:_reject_missing_choice_subject
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=82
scope.7.semanticHash=9bd82363d93d9cce
scope.8.id=function:_reject_choice_mismatch
scope.8.kind=function
scope.8.startLine=84
scope.8.endLine=89
scope.8.semanticHash=ab557bea873a9646
scope.9.id=function:_resolve_choice_actor
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=100
scope.9.semanticHash=f709754377a9712b
scope.10.id=function:_reject_item_mismatch
scope.10.kind=function
scope.10.startLine=102
scope.10.endLine=107
scope.10.semanticHash=d3ee348080818fa3
scope.11.id=function:_reject_invalid_option
scope.11.kind=function
scope.11.startLine=109
scope.11.endLine=114
scope.11.semanticHash=295cb37b65c99c61
scope.12.id=function:_validate_choice_subject
scope.12.kind=function
scope.12.startLine=116
scope.12.endLine=124
scope.12.semanticHash=5bf20646f2913a19
scope.13.id=function:_validate_choice_target
scope.13.kind=function
scope.13.startLine=126
scope.13.endLine=137
scope.13.semanticHash=539545a78ccbf02a
scope.14.id=function:validation.validate_choice
scope.14.kind=function
scope.14.startLine=139
scope.14.endLine=148
scope.14.semanticHash=5abd7f3e64b28988
]]
