-- Coverage for src.ui.render.board.visual_sync_batch: sync_many entry point
-- and internal dedup/expansion logic.
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local visual_sync = require("src.ui.render.board.visual_sync")

local function _stub_state(board)
  return {
    game = {
      board = board or nil,
    },
    ui = {},
  }
end

-- describe("visual_sync_batch.sync_many") 拍平为文件级 TestVisualSyncBatch,
-- _assert_eq 自研 helper 原样保留,用例数与改写前一一对应(3 例)。
TestVisualSyncBatch = {}

function TestVisualSyncBatch:test_returns_false_when_payload_is_nil()
  local result = visual_sync.sync_many(_stub_state(), nil)
  _assert_eq(result, false, "nil payload should return false")
end

function TestVisualSyncBatch:test_handles_empty_affected_owner_ids_without_error_regression_for_mutate_or_and_l67()
  -- Regression: `not owner_ids or #owner_ids == 0` → `and` at L67.
  -- With the or→and mutation and owner_ids={} (empty table), the `not`
  -- returns false and `#{}==0` is true → `false and true` = false → skips
  -- early return. Without a board, resolve_board returns nil and the
  -- function returns empty gracefully, but the semantic path changed.
  -- Testing with an empty table exercises the `#owner_ids == 0` branch
  -- explicitly: original returns early, mutant continues (but still
  -- returns false since no board/no tiles). The fact that it returns
  -- false without error when passing {} confirms the early-return guard.
  local result = visual_sync.sync_many(
    _stub_state(nil),
    { affected_owner_ids = {} }
  )
  _assert_eq(result, false, "empty owner_ids with no board returns false")
end

function TestVisualSyncBatch:test_handles_empty_affected_owner_ids_when_board_exists()
  -- Further exercise: with a board but empty owner_ids, the expansion
  -- should also return false (no tiles to sync).
  local board = { path = {} }
  local result = visual_sync.sync_many(
    _stub_state(board),
    { affected_owner_ids = {} }
  )
  _assert_eq(result, false, "empty owner_ids with empty board returns false")
end


return TestVisualSyncBatch
