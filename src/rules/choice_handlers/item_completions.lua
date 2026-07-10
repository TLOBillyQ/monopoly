local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local normalize = require("src.rules.choice_handlers.item_normalize")

local completions = {}

function completions.build(helpers)
  local finish_choice = helpers.finish_choice
  local finish_active_item_phase = helpers.finish_active_item_phase

  local function _resolve_phase_completion(game, player, meta, result)
    return item_phase.resolve_completion(game, player, meta, result)
  end

  local function _resolve_followup_completion(game, choice, player, result)
    local meta = choice.meta or {}
    if meta.passive_origin and meta.item_id then
      availability.mark_effect_group_used(game, meta.item_id)
    end
    if normalize.is_repeatable_phase_meta(meta) then
      return item_phase.resolve_completion(game, player, meta, result)
    end
    finish_active_item_phase(game)
    return normalize.merge_after_action_anim(result, finish_choice(game, false))
  end

  local function _resolve_followup_cancel(game, choice)
    local meta = choice and choice.meta or nil
    if normalize.is_repeatable_phase_meta(meta) then
      local player = normalize.validate_item_player(game, choice.kind, meta)
      local open_opts = {
        elapsed_seconds = game.turn.choice_elapsed_seconds or 0,
      }
      if item_phase.reopen_or_finish(game, player, meta, open_opts) then
        return { stay = true }
      end
      return nil
    end
    finish_active_item_phase(game)
    return nil
  end

  return {
    phase_completion = _resolve_phase_completion,
    followup_completion = _resolve_followup_completion,
    followup_cancel = _resolve_followup_cancel,
  }
end

function completions.item_target_handler(kind, execute_fn, complete, opts)
  opts = opts or {}
  return {
    required_meta = { "player_id", "item_id" },
    cancel = {
      resolve = function(game, choice)
        return complete.followup_cancel(game, choice)
      end,
    },
    normalize_meta = opts.normalize_meta or normalize.item_target_meta,
    meta_validator = opts.meta_validator or normalize.validate_item_owner_meta,
    normalize_action = function(_, _, action)
      return normalize.choice_action_option_id(kind, action)
    end,
    execute = execute_fn,
  }
end

return completions
