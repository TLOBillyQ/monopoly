local move_anim = require("src.ui.render.move_anim")
local support = require("spec.support.move_anim_support")
local item_atlas = require("src.ui.coord.item_atlas")

describe("presentation.move_anim.settlement_flag", function()
  before_each(function()
    item_atlas.reset_for_tests()
  end)

  it("sets ui.move_active true at sequence start", function()
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

    assert(state.ui.move_active == true, "expected move_active=true after sequence start")
  end)

  it("clears ui.move_active when active finish callback runs", function()
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
    assert(finish ~= nil, "expected sequence finish callback to be scheduled")
    finish.fn()
    assert(state.ui.move_active == false, "expected move_active=false after finish")
  end)

  it("stale finish callback does not clear move_active mid-sequence", function()
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
    assert(scheduled[1] ~= nil and scheduled[2] ~= nil, "expected two finish callbacks")
    scheduled[1].fn()
    assert(state.ui.move_active == true,
      "stale finish callback must not clear move_active while a newer sequence is active")
  end)

  it("keeps an open item_atlas on sequence start", function()
    local unit, _ = support.new_unit_spy()
    local scene = support.new_scene_with_linear_tiles(2, {
      units_by_player_id = { [1] = unit },
    })
    local state = { ui = {} }
    item_atlas.open(state, 1)
    assert(state.ui.item_atlas.open == true, "precondition: atlas open")

    support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        state = state, player_id = 1, seq = 1021,
        from_index = 1, to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)

    assert(state.ui.item_atlas.open == true, "move sequence start should not close item_atlas")
  end)
end)
