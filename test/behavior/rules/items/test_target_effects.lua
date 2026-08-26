-- target_effects 直测(#259 变异清扫 survivor 闭合):
-- exile apply 的 queued 初值 false -> true(无深山格时变异体伪装成已排队)
-- 与 queued 路径返回表(action_anim 字面值、next_state "move_followup");
-- send_poor require_user 的 `return false` -> `return true`。
local support = require("test.support.shared_support")
local target_effects = require("src.rules.items.target_effects")
local item_ids = require("src.config.gameplay.item_ids")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")

local _assert_eq = support.assert_eq

local function _exile_apply(game, target)
  return target_effects.get(item_ids.exile).apply(game, { id = 1, name = "P1" }, target)
end

TestTargetEffects = {}

function TestTargetEffects:test_exile_without_a_mountain_tile_falls_through_to_the_immediate_path()
  -- kills `local queued = false` false -> true: the mutant would pretend an
  -- anim was queued and skip the event + mountain effects entirely.
  local effects_applied = 0
  local published = 0
  local game = {
    angel_immune_to_item = function() return false end,
    board = { find_first_by_type = function() return nil end },
    player_apply_mountain_effects = function() effects_applied = effects_applied + 1 end,
  }
  local result
  support.with_patches({
    { target = event_feed, key = "publish", value = function() published = published + 1 end },
  }, function()
    result = _exile_apply(game, { id = 2, name = "P2", position = 3 })
  end)
  _assert_eq(result, true, "no mountain tile means the plain true result")
  _assert_eq(published, 1, "the exile event should be published immediately")
  _assert_eq(effects_applied, 1, "mountain effects should apply immediately")
end

function TestTargetEffects:test_exile_with_a_queued_anim_returns_the_followup_descriptor()
  -- kills the queued-path return table's `action_anim = true` true -> false
  -- and `next_state = "move_followup"` -> nil.
  local game = {
    angel_immune_to_item = function() return false end,
    board = { find_first_by_type = function() return 8 end },
    player_relocate = function() return 8 end,
  }
  local result
  support.with_patches({
    { target = action_anim_port, key = "queue", value = function() return true end },
  }, function()
    result = _exile_apply(game, { id = 2, name = "P2", position = 3 })
  end)
  _assert_eq(result.ok, true, "queued exile resolves ok")
  _assert_eq(result.action_anim, true, "queued exile reports the anim")
  _assert_eq(result.after_action_anim.next_state, "move_followup",
    "queued exile defers to the move_followup state")
  _assert_eq(result.after_action_anim.next_args.effects[1].effect, "mountain",
    "the followup applies mountain effects")
end

function TestTargetEffects:test_require_user_rejects_a_user_without_the_poor_deity()
  -- kills require_user's `return false` -> `return true`.
  local spec = target_effects.get(item_ids.send_poor)
  local without = { player_has_deity = function() return false end }
  local with = { player_has_deity = function() return true end }
  _assert_eq(spec.require_user(without, { id = 1 }), false, "no poor deity means not required/allowed")
  _assert_eq(spec.require_user(with, { id = 1 }), true, "poor deity holder passes")
end


return TestTargetEffects
