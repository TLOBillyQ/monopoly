local lu = require("luaunit")
local move_anim = require("src.ui.render.move_anim")
local support = require("test.support.move_anim_support")
local item_atlas = require("src.ui.screens.item_atlas")

TestMoveAnimSettlementFlag = {}

function TestMoveAnimSettlementFlag:setUp()
  item_atlas.reset_for_tests()
end

function TestMoveAnimSettlementFlag:test_sets_ui_move_active_true_at_sequence_start()
  local unit, _ = support.new_unit_spy()
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = { [1] = unit },
  })
  local state = { ui = {} }

  support.capture_scheduled_callbacks(function()
    move_anim.play_sequence(scene, {
      state = state,
      player_id = 1,
      seq = 1001,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  lu.assertEvalToTrue(state.ui.move_active == true, "expected move_active=true after sequence start")
end

function TestMoveAnimSettlementFlag:test_clears_ui_move_active_when_active_finish_callback_runs()
  local unit, _ = support.new_unit_spy()
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = { [1] = unit },
  })
  local state = { ui = {} }

  local scheduled = support.capture_scheduled_callbacks(function()
    move_anim.play_sequence(scene, {
      state = state,
      player_id = 1,
      seq = 1002,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)
  -- the final scheduled callback is the sequence finish stop
  local finish = scheduled[#scheduled]
  lu.assertEvalToTrue(finish ~= nil, "expected sequence finish callback to be scheduled")
  finish.fn()
  lu.assertEvalToTrue(state.ui.move_active == false, "expected move_active=false after finish")
end

function TestMoveAnimSettlementFlag:test_stale_finish_callback_does_not_clear_move_active_mid_sequence()
  local unit, _ = support.new_unit_spy()
  local scene = support.new_scene_with_linear_tiles(3, {
    units_by_player_id = { [1] = unit },
  })
  local state = { ui = {} }

  local scheduled = support.capture_scheduled_callbacks(function()
    move_anim.play_sequence(scene, {
      state = state, player_id = 1, seq = 1011,
      from_index = 1, to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
    move_anim.play_sequence(scene, {
      state = state, player_id = 1, seq = 1012,
      from_index = 2, to_index = 3,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)
  -- two finish callbacks scheduled, one per sequence; the first is stale (seq 1011)
  lu.assertEvalToTrue(scheduled[1] ~= nil and scheduled[2] ~= nil, "expected two finish callbacks")
  scheduled[1].fn()
  lu.assertEvalToTrue(state.ui.move_active == true,
    "stale finish callback must not clear move_active while a newer sequence is active")
end

function TestMoveAnimSettlementFlag:test_keeps_an_open_item_atlas_on_sequence_start()
  local unit, _ = support.new_unit_spy()
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = { [1] = unit },
  })
  local state = { ui = {} }
  item_atlas.open(state, 1)
  lu.assertEvalToTrue(state.ui.item_atlas.open == true, "precondition: atlas open")

  support.capture_scheduled_callbacks(function()
    move_anim.play_sequence(scene, {
      state = state, player_id = 1, seq = 1021,
      from_index = 1, to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  lu.assertEvalToTrue(state.ui.item_atlas.open == true, "move sequence start should not close item_atlas")
end


return TestMoveAnimSettlementFlag
