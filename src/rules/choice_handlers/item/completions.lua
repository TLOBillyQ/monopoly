local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local normalize = require("src.rules.choice_handlers.item.normalize")

local completions = {}

function completions.build(helpers)
  local finish_choice = helpers.finish_choice

  local function _finish_followup_choice(game)
    helpers.finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function _resume_pre_action_phase(game, player, meta)
    if not item_phase.reopen_or_finish(game, player, meta) then
      return finish_choice(game, false)
    end
    if game.turn.action_anim then
      return {
        after_action_anim = {
          next_state = "wait_choice",
          next_args = item_phase.build_wait_choice_args(meta),
        },
      }
    end
    return { stay = true }
  end

  local function _resolve_phase_completion(game, player, meta, result)
    if not normalize.is_repeatable_phase_meta(meta) then
      normalize.finish_item_phase_by_name(game, meta and meta.phase or nil)
      return normalize.merge_after_action_anim(result, finish_choice(game, false))
    end
    if meta.phase == "post_action" then
      return normalize.merge_after_action_anim(result, finish_choice(game, false))
    end
    local resumed = _resume_pre_action_phase(game, player, meta)
    if resumed.stay then
      return resumed
    end
    return normalize.merge_after_action_anim(result, resumed)
  end

  local function _resolve_followup_completion(game, choice, player, result)
    local meta = choice.meta or {}
    if meta.passive_origin and meta.item_id then
      availability.mark_effect_group_used(game, meta.item_id)
    end
    if normalize.is_repeatable_phase_meta(meta) then
      return _resolve_phase_completion(game, player, meta, result)
    end
    return normalize.merge_after_action_anim(result, _finish_followup_choice(game))
  end

  local function _resolve_followup_cancel(game, choice)
    local meta = choice and choice.meta or nil
    if normalize.is_repeatable_phase_meta(meta) then
      if meta.phase == "pre_action" then
        local player = normalize.validate_item_player(game, choice.kind, meta)
        if item_phase.reopen_or_finish(game, player, meta) then
          return { stay = true }
        end
      end
      return nil
    end
    local phase = game.turn.item_phase_active
    if phase and phase ~= "" then
      item_phase.finish(game, phase)
    end
    return nil
  end

  return {
    finish_followup_choice = _finish_followup_choice,
    resume_pre_action_phase = _resume_pre_action_phase,
    phase_completion = _resolve_phase_completion,
    followup_completion = _resolve_followup_completion,
    followup_cancel = _resolve_followup_cancel,
  }
end

return completions
