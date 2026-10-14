-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- Direct coverage for src.ui.state.canvas_store.patch_slice across its four
-- patch shapes (nil / table / function / invalid). The invalid-type branch and
-- the function-patch argument contract are only reachable by calling directly.
--
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local canvas_store = require("src.ui.state.canvas_store")

describe("TestCanvasStore", function()

it("test_handles_nil_table_function_and_invalid_patches", function()
  local state = { ui = {} }

  -- nil patch: marks dirty and returns the slice without mutation.
  local slice = canvas_store.patch_slice(state, "board", nil)
  luassert.truthy(type(slice) == "table", "patch_slice should return the slice table")
  _assert_eq(state.ui.canvas_store.dirty.board, true, "nil patch should still mark the key dirty")

  -- table patch: shallow-copies keys onto the slice.
  canvas_store.patch_slice(state, "board", { zoom = 3, mode = "fit" })
  local board = canvas_store.get_slice(state, "board")
  _assert_eq(board.zoom, 3, "table patch should copy numeric field")
  _assert_eq(board.mode, "fit", "table patch should copy string field")

  -- function patch: receives (slice, ui, state_or_ui) and mutates in place.
  local seen_ui, seen_state = nil, nil
  canvas_store.patch_slice(state, "board", function(target, ui, raw)
    target.flag = true
    seen_ui, seen_state = ui, raw
  end)
  _assert_eq(canvas_store.get_slice(state, "board").flag, true, "function patch should mutate the slice")
  _assert_eq(seen_ui, state.ui, "function patch should receive the resolved ui")
  _assert_eq(seen_state, state, "function patch should receive the original state arg")

  -- invalid patch type: raises a descriptive error.
  local ok, err = pcall(canvas_store.patch_slice, state, "board", 42)
  _assert_eq(ok, false, "a non-table/function patch must raise")
  luassert.truthy(tostring(err):find("expects table/function patch", 1, true),
    "invalid patch error should name the contract")
end)

it("test_accepts_all_configured_dirty_keys", function()
  -- kills _allowed_dirty_keys 的 true->false 位点:每个已配置 key 都必须
  -- 是合法 dirty 键,不能只有 board 一个。
  local state = { ui = {} }
  for _, key in ipairs({ "permanent", "base", "board", "choice", "effects", "market" }) do
    local ok = pcall(canvas_store.patch_slice, state, key, nil)
    luassert.truthy(ok, "configured dirty key should be accepted: " .. tostring(key))
  end
end)

it("test_initial_store_reports_dirty_any", function()
  -- kills _init_store 的 dirty.any=true 换 false:新 store 首次 consume 必须
  -- 报 any=true(首帧需要渲染)。
  local state = { ui = {} }
  canvas_store.ensure(state)
  local dirty = canvas_store.consume_dirty(state)
  _assert_eq(dirty.any, true, "a fresh store should report dirty on first consume")
end)

it("test_get_slice_without_key_returns_nil", function()
  -- kills get_slice 的 `not store or not key` or->and:key 缺省时必须返回 nil,
  -- 不能落到 slices[nil] 分支。
  local state = { ui = {} }
  luassert.truthy(canvas_store.get_slice(state, nil) == nil,
    "get_slice without a key should return nil")
end)

it("test_consume_dirty_resets_any_after_consumption", function()
  -- kills consume_dirty 的 spare.any=false 换 true:消费后再次 consume 必须
  -- 报 any=false(无新 dirty),否则渲染循环会恒脏。
  local state = { ui = {} }
  canvas_store.patch_slice(state, "board", { zoom = 1 })
  local first = canvas_store.consume_dirty(state)
  _assert_eq(first.any, true, "first consume should report the pending dirty")
  local second = canvas_store.consume_dirty(state)
  _assert_eq(second.any, false, "second consume should report no dirty")
  local third = canvas_store.consume_dirty(state)
  _assert_eq(third.any, false, "third consume should also report no dirty")
end)

it("test_consume_dirty_without_a_store_returns_clean", function()
  -- kills consume_dirty 的 `return { any = false }` false->true:无效 state
  -- (无 ui 可解析)必须按无脏回报。
  local dirty = canvas_store.consume_dirty(nil)
  _assert_eq(dirty.any, false, "consume without a store should report clean")
end)


end)
