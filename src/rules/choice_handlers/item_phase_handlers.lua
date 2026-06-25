local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local inventory = require("src.rules.items.inventory")
local intent_output_port = require("src.rules.ports.intent_output")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
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
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
  item_preconsume_policy.decorate_followup_choice_spec(choice_spec, {
    item_id = item_id,
    player_id = player.id,
  })
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
