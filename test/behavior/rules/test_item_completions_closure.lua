require("test.bootstrap").install_package_paths()
-- luacheck: ignore 143 (busted injects the verified luassert object)
local luassert = assert
-- Closure pins for src/rules/choice_handlers/item_completions.lua.
-- The three completion paths used to branch by phase (post_action early-finished).
-- After the deep-module convergence they delegate to item_phase.resolve_completion
-- / reopen_or_finish and no longer perceive phase differences.
local support = require("test.support.shared_support")
local config_reset = require("test.support.config_reset")
local item_phase = require("src.rules.items.phase")
local item_ids = require("src.config.gameplay.item_ids")

local completions = require("src.rules.choice_handlers.item_completions")
local item_config = require("src.rules.items.config")

local _with_patches = support.with_patches
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end

local function _effect_group(item_id)
  local cfg = item_config.cfg_by_id[item_id]
  return cfg and cfg.effect_group
end

do


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

  describe("TestItemCompletionsClosure", function()
    before_each(function()
      config_reset.reset_all()
    end)
    it("test_delegates_to_item_phase_resolve_completion_for_pre_action", function()
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

    it("test_delegates_to_item_phase_resolve_completion_for_post_action", function()
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

    it("test_passive_followup_delegates_without_registering_an_unsettled_effect", function()
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
      _assert_eq(g.turn.used_effect_groups[_effect_group(item_ids.remote_dice)], nil,
        "window completion alone must not register an unsettled effect")
    end)

    it("test_does_not_mark_effect_group_when_passive_origin_is_absent", function()
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

    it("test_reopens_any_repeatable_phase_not_only_pre_action", function()
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

    it("test_finishes_the_active_phase_for_non_repeatable_phases", function()
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
end


