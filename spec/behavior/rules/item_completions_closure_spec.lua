-- Closure pins for src/rules/choice_handlers/item_completions.lua.
-- The three completion paths used to branch by phase (post_action early-finished).
-- After the deep-module convergence they delegate to item_phase.resolve_completion
-- / reopen_or_finish and no longer perceive phase differences.
local support = require("spec.support.shared_support")
local config_reset = require("spec.support.config_reset")
local item_phase = require("src.rules.items.phase")
local item_ids = require("src.config.gameplay.item_ids")

local completions = require("src.rules.choice_handlers.item_completions")
local item_config = require("src.rules.items.config")

local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local function _effect_group(item_id)
  local cfg = item_config.cfg_by_id[item_id]
  return cfg and cfg.effect_group
end

describe("item_completions closure", function()
  before_each(function() config_reset.reset_all() end)

  local function _build_complete()
    return completions.build({
      finish_choice = function(_, stay) return { status = stay and "waiting" or "resolved", stay = stay } end,
      finish_active_item_phase = function(game)
        local phase = game.turn.item_phase_active
        if phase and phase ~= "" then
          item_phase.finish(game, phase)
        end
      end,
    })
  end

  describe("phase_completion", function()
    it("delegates to item_phase.resolve_completion for pre_action", function()
      local g = support.new_game()
      local called = {}
      local complete = _build_complete()
      _with_patches({
        { target = item_phase, key = "resolve_completion", value = function(_, player, meta, result)
          called = { player = player, meta = meta, result = result }
          return { stay = true }
        end },
      }, function()
        local p = g.players[1]
        local res = complete.phase_completion(g, p, { phase = "pre_action" }, { ok = true })
        _assert_eq(res.stay, true, "delegate result is returned")
      end)
      _assert_eq(called.meta.phase, "pre_action", "phase meta is forwarded")
      _assert_eq(called.result.ok, true, "result is forwarded")
      _assert_eq(called.player.id, g.players[1].id, "player is forwarded")
    end)

    it("delegates to item_phase.resolve_completion for post_action", function()
      local g = support.new_game()
      local called = {}
      local complete = _build_complete()
      _with_patches({
        { target = item_phase, key = "resolve_completion", value = function(_, player, meta, result)
          called = { player = player, meta = meta, result = result }
          return { stay = true }
        end },
      }, function()
        local p = g.players[1]
        local res = complete.phase_completion(g, p, { phase = "post_action" }, { ok = true })
        _assert_eq(res.stay, true, "delegate result is returned")
      end)
      _assert_eq(called.meta.phase, "post_action", "post_action phase meta is forwarded")
    end)
  end)

  describe("followup_completion", function()
    it("marks effect group used for passive_origin and delegates", function()
      local g = support.new_game()
      local p = g.players[1]
      local called = {}
      local complete = _build_complete()
      _with_patches({
        { target = item_phase, key = "resolve_completion", value = function(_, player, meta, result)
          called = { player = player, meta = meta, result = result }
          return { stay = true }
        end },
      }, function()
        local choice = { meta = { phase = "post_action", item_id = item_ids.remote_dice, passive_origin = true } }
        local res = complete.followup_completion(g, choice, p, { ok = true })
        _assert_eq(res.stay, true, "delegate result is returned")
      end)
      _assert_eq(called.meta.item_id, item_ids.remote_dice, "item id meta is forwarded")
      _assert_eq(g.turn.used_effect_groups[_effect_group(item_ids.remote_dice)], true,
        "passive_origin item marks its effect group used")
    end)

    it("does not mark effect group when passive_origin is absent", function()
      local g = support.new_game()
      local p = g.players[1]
      local complete = _build_complete()
      _with_patches({
        { target = item_phase, key = "resolve_completion", value = function() return { stay = true } end },
      }, function()
        local choice = { meta = { phase = "post_action", item_id = item_ids.remote_dice } }
        complete.followup_completion(g, choice, p, { ok = true })
      end)
      _assert_eq(g.turn.used_effect_groups[_effect_group(item_ids.remote_dice)], nil,
        "non-passive followup must not mark effect group used")
    end)
  end)

  describe("followup_cancel", function()
    it("reopens any repeatable phase, not only pre_action", function()
      local g = support.new_game()
      local complete = _build_complete()
      _with_patches({
        { target = item_phase, key = "reopen_or_finish", value = function(_, player, meta, opts)
          _assert_eq(meta.phase, "post_action", "post_action cancel reopens the same phase")
          _assert_eq(opts.elapsed_seconds, 7, "elapsed is carried through reopen opts")
          return true
        end },
      }, function()
        g.turn.choice_elapsed_seconds = 7
        local choice = { kind = "roadblock_target", meta = { phase = "post_action", player_id = g.players[1].id } }
        local res = complete.followup_cancel(g, choice)
        _assert_eq(res.stay, true, "post_action cancel stays in the item window")
      end)
    end)

    it("finishes the active phase for non-repeatable phases", function()
      local g = support.new_game()
      g.turn.item_phase_active = "pre_move"
      item_phase.mark_active(g, "pre_move")
      local complete = _build_complete()
      local choice = { kind = "remote_dice_value", meta = { phase = "pre_move", player_id = g.players[1].id } }
      local res = complete.followup_cancel(g, choice)
      _assert_eq(res, nil, "non-repeatable cancel returns nil")
      _assert_eq(g.turn.item_phase.pre_move.done, true, "non-repeatable phase is finished")
    end)
  end)
end)
