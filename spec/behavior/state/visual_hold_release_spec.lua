---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local event_log = require("src.state.event_log")
local landing_visual_hold = require("src.state.visual_hold")

describe("visual_hold_release", function()
  it("defer_dirty_initializes_bucket_and_merges_inventory", function()
    local state = {}
    local dirty = {
      any = true,
      players = true,
      inventory_ids = {
        [1] = true,
        [2] = true,
      },
    }

    local deferred = landing_visual_hold.defer_dirty(state, dirty)
    assert(deferred.any == true and deferred.players == true, "defer_dirty should merge boolean dirty flags")
    assert(deferred.inventory_ids[1] == true and deferred.inventory_ids[2] == true,
      "defer_dirty should merge inventory_ids into initialized deferred bucket")
  end)

  it("release_flushes_event_buffer_and_replays_deferred", function()
    local state = {}
    local game = {
      state = {
        event_log = event_log.new(),
      },
      dirty = {},
      turn = {
        landing_visual_hold_active = false,
        landing_visual_release_pending = false,
      },
    }

    local replayed_visual_syncs = {}
    local replayed_runtime_events = {}
    local replayed_popups = {}

    landing_visual_hold.start(game)
    landing_visual_hold.mark_release_pending(game)

    local hold = landing_visual_hold.sync_state_from_game(state, game)
    event_log.append(game.state.event_log, {
      kind = "test",
      text = "deferred event during hold",
    })

    landing_visual_hold.defer_board_visual_sync(state, { sync_data = true }, function(payload)
      replayed_visual_syncs[#replayed_visual_syncs + 1] = payload
    end)

    landing_visual_hold.defer_runtime_event(state, "test_event", { event_data = true }, function(payload)
      replayed_runtime_events[#replayed_runtime_events + 1] = payload
    end)

    landing_visual_hold.defer_popup(state, { popup_data = true }, { opt = 1 }, function(payload, opts)
      replayed_popups[#replayed_popups + 1] = { payload = payload, opts = opts }
    end)

    _assert_eq(#hold.release_callbacks, 3, "release should register all deferred callbacks")
    _assert_eq(hold.release_callbacks[1].key, "board_visual_sync", "visual sync should register first")
    _assert_eq(hold.release_callbacks[2].key, "runtime_event", "runtime event should register second")
    _assert_eq(hold.release_callbacks[3].key, "popup", "popup should register third")

    local released = landing_visual_hold.release(state, game)

    _assert_eq(released, true, "release should return true when release was pending")
    _assert_eq(#replayed_visual_syncs, 1, "release should replay deferred visual syncs")
    _assert_eq(replayed_visual_syncs[1].sync_data, true, "visual sync payload should be preserved")
    _assert_eq(#replayed_runtime_events, 1, "release should replay deferred runtime events")
    _assert_eq(replayed_runtime_events[1].event_data, true, "runtime event payload should be preserved")
    _assert_eq(#replayed_popups, 1, "release should replay deferred popups")
    _assert_eq(replayed_popups[1].payload.popup_data, true, "popup payload should be preserved")

    local text = event_log.get_text(game.state.event_log)
    assert(string.find(text, "deferred event during hold", 1, true) ~= nil, "release should flush event buffer")
  end)

  it("release_orders_wrappers_by_priority", function()
    local state = {}
    local game = {
      dirty = {},
      turn = {
        landing_visual_hold_active = false,
        landing_visual_release_pending = false,
      },
    }
    local calls = {}

    landing_visual_hold.start(game)
    landing_visual_hold.mark_release_pending(game)
    local hold = landing_visual_hold.sync_state_from_game(state, game)

    landing_visual_hold.defer_popup(state, { name = "popup" }, nil, function(payload)
      calls[#calls + 1] = payload.name
    end)
    landing_visual_hold.defer_bankruptcy_clear(state, game, { id = 1 }, { 2 }, function(_, player)
      calls[#calls + 1] = "bankruptcy_" .. tostring(player.id)
    end)
    landing_visual_hold.defer_owner_change(state, 7, 8, function(tile_id, owner_id)
      calls[#calls + 1] = "owner_" .. tostring(tile_id) .. "_" .. tostring(owner_id)
    end)
    landing_visual_hold.defer_tile_update(state, 5, 6, function(tile_id, level)
      calls[#calls + 1] = "tile_" .. tostring(tile_id) .. "_" .. tostring(level)
    end)
    landing_visual_hold.defer_runtime_event(state, "evt", { name = "runtime" }, function(payload)
      calls[#calls + 1] = payload.name
    end)
    landing_visual_hold.defer_board_visual_sync(state, { name = "board" }, function(payload)
      calls[#calls + 1] = payload.name
    end)

    _assert_eq(#hold.release_callbacks, 6, "all wrapper helpers should register release callbacks")
    _assert_eq(landing_visual_hold.release(state, game), true, "release should flush deferred callbacks")
    _assert_eq(table.concat(calls, ","), "board,runtime,tile_5_6,owner_7_8,bankruptcy_1,popup",
      "release should replay wrapper callbacks in configured priority order")
  end)

  it("release_skips_when_not_pending", function()
    local state = {}
    local game = {
      dirty = {},
      turn = {
        landing_visual_hold_active = false,
        landing_visual_release_pending = false,
      },
    }

    landing_visual_hold.start(game)

    local released = landing_visual_hold.release(state, game)
    _assert_eq(released, false, "release should return false when release_pending is false")
  end)
end)
