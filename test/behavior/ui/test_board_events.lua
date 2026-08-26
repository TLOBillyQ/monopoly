-- src.ui.render.board.events 薄壳直测：on_tile_upgraded / on_tile_owner_changed
-- 委托 _sync_single_tile 的结果原样回传；nil tile_id 走降级 return false。
-- 此前只有聚合消费点 patch 这两个入口,本模块自身的返回语义没人钉——
-- "委托断线 return nil" / "nil 降级翻成 true" 变异全幸存(#293 清 events.lua
-- 幸存者的测错维度 bug:行为车道用 patch 而非直测,量不到这个薄壳)。
local lu = require("luaunit")
local board_events = require("src.ui.render.board.events")

local function _stub_state()
  return { game = { board = nil }, ui = {} }
end

TestBoardEvents = {}

function TestBoardEvents:test_nil_tile_id_degrades_to_false_on_both_handlers()
  lu.assertFalse(board_events.on_tile_upgraded(_stub_state(), nil), "nil tile downgrades to false")
  lu.assertFalse(board_events.on_tile_owner_changed(_stub_state(), nil), "nil tile downgrades to false")
end

function TestBoardEvents:test_handlers_propagate_sync_many_result_unchanged()
  -- 无 board 时 sync_many 返回 false；薄壳应原样回传，而不是吞成 nil。
  lu.assertFalse(board_events.on_tile_upgraded(_stub_state(), 5), "upgrade propagates sync result")
  lu.assertFalse(board_events.on_tile_owner_changed(_stub_state(), 5), "owner change propagates sync result")
end

function TestBoardEvents:test_sync_many_entry_is_the_visual_sync_delegate()
  -- 薄壳的 sync_many 直挂 visual_sync.sync_many，返回语义一致。
  local visual_sync = require("src.ui.render.board.visual_sync")
  lu.assertIs(board_events.sync_many, visual_sync.sync_many)
end

return TestBoardEvents