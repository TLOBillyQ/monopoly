-- bootstrap 装配的 item 类 choice 取消路径:followup_cancel 在非可重复
-- 阶段 meta 下调用 helpers.finish_active_item_phase,触达装配层回调。
local lu = require("luaunit")

local bootstrap = require("src.rules.bootstrap")

TestBootstrapPhaseFinish = {}

function TestBootstrapPhaseFinish:test_item_choice_cancel_finishes_inactive_phase()
  local registries = bootstrap.create_registries()
  local descriptor = registries.choices:descriptor_for("item_target_player")
  lu.assertNotNil(descriptor, "item_target_player should be registered by bootstrap")
  local game = { turn = {} }
  local result = descriptor.cancel.resolve(game, { meta = { player_id = "p1", item_id = "x" } })
  lu.assertNil(result, "non-repeatable cancel should resolve without a stay window")
  lu.assertNil(game.turn.item_phase_active,
    "inactive phase should stay untouched by the cancel path")
end

function TestBootstrapPhaseFinish:test_item_choice_cancel_finishes_active_phase()
  local registries = bootstrap.create_registries()
  local descriptor = registries.choices:descriptor_for("item_target_player")
  local game = { turn = { item_phase_active = "post_action" }, dirty = {} }
  local result = descriptor.cancel.resolve(
    game,
    { meta = { player_id = "p1", item_id = "x" } }
  )
  lu.assertNil(result, "non-repeatable cancel should resolve without a stay window")
  lu.assertEvalToTrue(game.turn.item_phase_active == "",
    "active phase should be cleared after cancel finish")
  lu.assertEvalToTrue(game.turn.item_phase ~= nil
    and game.turn.item_phase.post_action ~= nil
    and game.turn.item_phase.post_action.done == true,
    "finished phase should be recorded as done")
  lu.assertEvalToTrue(game.dirty.turn == true,
    "phase finish should mark turn dirty")
end


function TestBootstrapPhaseFinish:test_item_choice_cancel_with_empty_phase_skips_finish()
  -- #293:finish_active_item_phase 的 `phase ~= ""` 守卫(`""`→nil 变异会让
  -- 空阶段被 finish,写出 item_phase[""] 键)未测。
  local registries = bootstrap.create_registries()
  local descriptor = registries.choices:descriptor_for("item_target_player")
  local game = { turn = { item_phase_active = "" }, dirty = {} }
  descriptor.cancel.resolve(game, { meta = { player_id = "p1", item_id = "x" } })
  lu.assertEvalToTrue(game.turn.item_phase == nil
    or game.turn.item_phase[""] == nil,
    "empty phase should not be recorded as finished")
  lu.assertEvalToTrue(game.turn.item_phase_active == "",
    "empty phase marker should stay empty")
end

return TestBootstrapPhaseFinish
