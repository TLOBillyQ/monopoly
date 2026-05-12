local availability = require("src.rules.items.availability")
local intent_output_port = require("src.rules.ports.intent_output")
local inventory = require("src.rules.items.inventory")
local item_phase = require("src.rules.items.phase")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local normalize = require("src.rules.choice_handlers.item.normalize")
local completions = require("src.rules.choice_handlers.item.completions")

local M = {}

function M.build(helpers)
  local complete = completions.build(helpers)
  local use_item = helpers.use_item

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local phase = meta.phase
    local item_id = action.option_id

    local result = use_item(game, player, item_id)
    if type(result) == "table" and result.waiting then
      local intent = result.intent or {}
      local choice_spec = intent.choice_spec
      if type(choice_spec) == "table" then
        if item_phase.is_repeatable(phase) then
          choice_spec.meta = choice_spec.meta or {}
          choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
          choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
          item_phase.decorate_followup_choice_spec(choice_spec, meta)
        else
          assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
          item_preconsume_policy.decorate_followup_choice_spec(choice_spec, {
            item_id = item_id,
            player_id = player.id,
          })
        end
      end
      intent_output_port.dispatch(game, intent)
      return { stay = true }
    end
    return complete.phase_completion(game, player, meta, result)
  end

  local function _handle_item_phase_passive(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = action.option_id

    local result = use_item(game, player, item_id)
    assert(result ~= nil, "missing use_item result")
    if type(result) == "table" and result.waiting then
      local intent = result.intent or {}
      local choice_spec = intent.choice_spec
      if type(choice_spec) == "table" then
        choice_spec.meta = choice_spec.meta or {}
        choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
        choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
        choice_spec.meta.passive_origin = true
        item_phase.decorate_followup_choice_spec(choice_spec, meta)
      end
      intent_output_port.dispatch(game, intent)
      return { stay = true }
    end

    availability.mark_effect_group_used(game, item_id)
    local reopened = item_phase.reopen_or_finish(game, player, meta)
    return reopened and { stay = true } or nil
  end

  return {
    item_phase_choice = {
      required_meta = { "player_id", "phase" },
      cancel = {
        resolve = function(game, choice)
          item_phase.finish(game, choice.meta and choice.meta.phase or nil)
        end,
      },
      normalize_meta = normalize.item_phase_meta,
      meta_validator = normalize.validate_item_phase_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id("item_phase_choice", action)
      end,
      execute = _handle_item_phase_choice,
    },
    item_phase_passive = {
      required_meta = { "player_id", "phase" },
      cancel = {
        resolve = function(game, choice)
          item_phase.finish(game, choice.meta and choice.meta.phase or nil)
        end,
      },
      normalize_meta = normalize.item_phase_meta,
      meta_validator = normalize.validate_item_phase_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id("item_phase_passive", action)
      end,
      execute = _handle_item_phase_passive,
    },
  }
end

return M
