local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local intent_output_port = require("src.rules.ports.intent_output")
local settlement = require("src.rules.items.settlement")
local completions = require("src.rules.choice_handlers.item_completions")
local normalize = require("src.rules.choice_handlers.item_normalize")

local phase_handlers = {}

local function _decorate_phase_followup(choice_spec, meta, item_id, player, passive_origin)
  choice_spec.meta = choice_spec.meta or {}
  choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
  choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
  if passive_origin then
    choice_spec.meta.passive_origin = true
  end
  item_phase.decorate_followup_choice_spec(choice_spec, meta)
end

local function _decorate_non_repeatable_followup(choice_spec, player, item_id)
  settlement.escrow(player, item_id, choice_spec)
end

local function _handle_waiting_result(game, result, meta, player, item_id, phase)
  local intent = result.intent or {}
  local choice_spec = intent.choice_spec
  if type(choice_spec) == "table" then
    if item_phase.is_repeatable(phase) then
      _decorate_phase_followup(choice_spec, meta, item_id, player, false)
    else
      _decorate_non_repeatable_followup(choice_spec, player, item_id)
    end
  end
  intent_output_port.dispatch(game, intent)
  return { stay = true }
end

local function _handle_passive_waiting_result(game, result, meta, player, item_id)
  local intent = result.intent or {}
  local choice_spec = intent.choice_spec
  if type(choice_spec) == "table" then
    _decorate_phase_followup(choice_spec, meta, item_id, player, true)
  end
  intent_output_port.dispatch(game, intent)
  return { stay = true }
end

local function _item_phase_handler(kind, execute_fn)
  return {
    required_meta = { "player_id", "phase" },
    cancel = {
      resolve = function(game, choice)
        item_phase.finish(game, choice.meta and choice.meta.phase or nil)
      end,
    },
    normalize_meta = normalize.item_phase_meta,
    meta_validator = normalize.validate_item_phase_meta,
    normalize_action = function(_, _, action)
      return normalize.choice_action_option_id(kind, action)
    end,
    execute = execute_fn,
  }
end

function phase_handlers.build(helpers)
  local complete = completions.build(helpers)
  local begin_item_use = assert(helpers.begin_item_use, "missing begin_item_use helper")

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local phase = meta.phase
    local item_id = action.option_id

    local result = begin_item_use(game, player, item_id, { phase = phase })
    if type(result) == "table" and result.waiting then
      return _handle_waiting_result(game, result, meta, player, item_id, phase)
    end
    return complete.phase_completion(game, player, meta, result)
  end

  local function _handle_item_phase_passive(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = action.option_id

    local result = begin_item_use(game, player, item_id, { phase = meta.phase })
    assert(result ~= nil, "missing use_item result")
    if type(result) == "table" and result.waiting then
      return _handle_passive_waiting_result(game, result, meta, player, item_id)
    end

    if not (type(result) == "table" and result.ok == false) then
      availability.mark_effect_group_used(game, item_id)
    end
    local reopened = item_phase.reopen_or_finish(game, player, meta)
    return reopened and { stay = true } or nil
  end

  return {
    item_phase_choice = _item_phase_handler("item_phase_choice", _handle_item_phase_choice),
    item_phase_passive = _item_phase_handler("item_phase_passive", _handle_item_phase_passive),
  }
end

return phase_handlers

--[[ mutate4lua-manifest
version=2
projectHash=ba2a8379f0258579
scope.0.id=chunk:src/rules/choice_handlers/item_phase_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=112
scope.0.semanticHash=934c605686d2a7d2
scope.1.id=function:_decorate_phase_followup:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=19
scope.1.semanticHash=d598850bc14dd2ed
scope.2.id=function:_decorate_non_repeatable_followup:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=27
scope.2.semanticHash=fc94e8e518765e24
scope.3.id=function:_handle_waiting_result:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=41
scope.3.semanticHash=68ccfce52eab1be4
scope.4.id=function:_handle_passive_waiting_result:43
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=51
scope.4.semanticHash=666c6a4600df5b86
scope.5.id=function:anonymous@57:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=59
scope.5.semanticHash=f96a923ff3d32f19
scope.6.id=function:anonymous@63:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=65
scope.6.semanticHash=aa5c022ffd4a4899
scope.7.id=function:_item_phase_handler:53
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=68
scope.7.semanticHash=dd28ac0d2f6cf71b
scope.8.id=function:_handle_item_phase_choice:74
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=85
scope.8.semanticHash=76eba5829d94e1de
scope.9.id=function:_handle_item_phase_passive:87
scope.9.kind=function
scope.9.startLine=87
scope.9.endLine=103
scope.9.semanticHash=8c9c97d9842d88b2
scope.10.id=function:phase_handlers.build:70
scope.10.kind=function
scope.10.startLine=70
scope.10.endLine=109
scope.10.semanticHash=861ac73c33b69456
]]
