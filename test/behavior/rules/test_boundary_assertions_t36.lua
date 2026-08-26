local lu = require("luaunit")
local luax = require("test.support.luax")
local inventory = require("src.rules.items.inventory")
local balance_ops = require("src.player.actions.balance")
local dirty_tracker = require("src.state.dirty_tracker")
local _config_reset = require("test.support.config_reset")

local function _assert_contains(text, fragment, message)
  assert(type(text) == "string", (message or "expected string") .. ": non-string error")
  assert(string.find(text, fragment, 1, true) ~= nil, (message or "missing fragment") .. ": " .. text)
end

TestBoundaryAssertionsT36 = {}

function TestBoundaryAssertionsT36:setUp()
  _config_reset.reset_all()
end

function TestBoundaryAssertionsT36:test_inventory_remove_by_index_asserts_out_of_bounds()
  local player = {
    inventory = {
      items = {
        { id = 2001 },
      },
      remove_by_index = function(self, idx)
        return table.remove(self.items, idx)
      end,
    },
  }

  local ok, err = pcall(function()
    inventory.remove_by_index(player, 2)
  end)

  lu.assertFalse(ok, "remove_by_index should assert on out-of-bounds index")
  _assert_contains(err, "remove_by_index: index out of bounds: 2", "unexpected out-of-bounds assertion message")
end

function TestBoundaryAssertionsT36:test_deduct_player_cash_asserts_negative_balance()
  local game = setmetatable({}, { __index = balance_ops })
  local player = {
    id = 1,
    _coin_role = balance_ops.new_memory_coin_role(5),
  }

  local ok, err = pcall(function()
    game:deduct_player_cash(player, 6)
  end)

  lu.assertFalse(ok, "deduct_player_cash should assert on negative balance")
  _assert_contains(err, "余额不足: -1", "unexpected negative balance assertion message")
end

function TestBoundaryAssertionsT36:test_dirty_tracker_mark_asserts_unknown_domain()
  local dirty = dirty_tracker.new()
  local ok, err = pcall(function()
    dirty_tracker.mark(dirty, "unknown_domain")
  end)

  lu.assertFalse(ok, "dirty_tracker.mark should assert on unknown domain")
  _assert_contains(err, "unknown dirty domain: unknown_domain", "unexpected dirty domain assertion message")
end

function TestBoundaryAssertionsT36:test_dirty_tracker_merge_into_ignores_non_table_arguments()
  lu.assertEvalToTrue(dirty_tracker.merge_into(nil, {}) == nil,
    "merge_into should tolerate a nil target")
  lu.assertEvalToTrue(type(dirty_tracker.merge_into({}, nil)) == "table",
    "merge_into should tolerate a nil dirty table")
  lu.assertEvalToTrue(type(dirty_tracker.merge_into("bad", { any = true })) == "string",
    "merge_into should leave non-table targets untouched")
end

TestBoundaryAssertionsT36InventoryGuardMessageClosure = {}

local function _player()
  return {
    inventory = {
      items = { { id = 2001 } },
      count = function() return 1 end,
      remove_by_index = function(self, idx) return table.remove(self.items, idx) end,
    },
  }
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_count_rejects_a_nil_player_with_the_guard_message()
  -- kills _inv's "missing player" -> nil.
  luax.has_error(function()
    inventory.count(nil)
  end, "missing player")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_count_rejects_a_player_without_inventory_with_the_guard_message()
  -- kills _inv's "missing player.inventory" -> nil.
  luax.has_error(function()
    inventory.count({})
  end, "missing player.inventory")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_add_rejects_a_nil_item_with_the_guard_message()
  -- kills inventory.add's "missing item" -> nil.
  luax.has_error(function()
    inventory.add(_player(), nil)
  end, "missing item")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_remove_by_index_rejects_a_nil_index_with_the_guard_message()
  -- kills inventory.remove_by_index's "missing index" -> nil.
  luax.has_error(function()
    inventory.remove_by_index(_player(), nil)
  end, "missing index")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_remove_by_index_rejects_index_0_as_out_of_bounds()
  -- kills the bounds check `idx >= 1` 1 -> 0: the mutant lets 0 through and
  -- table.remove(self.items, 0) raises a different error, not the guard's.
  luax.has_error(function()
    inventory.remove_by_index(_player(), 0)
  end, "remove_by_index: index out of bounds: 0")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestBoundaryAssertionsT36,
  TestBoundaryAssertionsT36InventoryGuardMessageClosure
)
