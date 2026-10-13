-- 规则层边界断言直测(T36):越界索引、负余额、未知 dirty 域、守卫消息闭包。
--
-- 断言层迁移(#74 第一步「先断言、后结构」):断言后端换成项目工具缓存里的真
-- luassert,结构、用例集合与期望值不变。迁移口径见 CODING_STANDARDS.md。
--
-- 本文件的三类译法值得单独记:
--   - lu.assertFalse 是**严格布尔**(pcall 的 ok 恰好是布尔,故 is_false 等价);
--   - lu.assertEvalToTrue 是 truthiness → luassert 的 truthy;
--   - luax.has_error(fn, msg) 与 luassert 的 has_error(fn, msg) 同口径
--     (先剥一层 `文件:行: ` 位置前缀,字符串精确比较、表深比较),故直接换名。
--     精确文本不是子串——子串口径要写成 has_error.match(fn, pat, 1, true)。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())
local inventory = require("src.rules.items.inventory")
local balance_ops = require("src.player.actions.balance")
local dirty_tracker = require("src.state.dirty_tracker")
local _config_reset = require("test.support.config_reset")

-- 文件内局部断言 helper:调用点与语义(先断言 text 是字符串,再断言含子串)不变,
-- 只把后端换成 luassert。子串口径 = matches 的 plain 模式。
local function _assert_contains(text, fragment, message)
  luassert.is_string(text, message)
  luassert.matches(fragment, text, 1, true, message)
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

  luassert.is_false(ok, "remove_by_index should assert on out-of-bounds index")
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

  luassert.is_false(ok, "deduct_player_cash should assert on negative balance")
  _assert_contains(err, "余额不足: -1", "unexpected negative balance assertion message")
end

function TestBoundaryAssertionsT36:test_dirty_tracker_mark_asserts_unknown_domain()
  local dirty = dirty_tracker.new()
  local ok, err = pcall(function()
    dirty_tracker.mark(dirty, "unknown_domain")
  end)

  luassert.is_false(ok, "dirty_tracker.mark should assert on unknown domain")
  _assert_contains(err, "unknown dirty domain: unknown_domain", "unexpected dirty domain assertion message")
end

function TestBoundaryAssertionsT36:test_dirty_tracker_merge_into_ignores_non_table_arguments()
  luassert.truthy(dirty_tracker.merge_into(nil, {}) == nil,
    "merge_into should tolerate a nil target")
  luassert.truthy(type(dirty_tracker.merge_into({}, nil)) == "table",
    "merge_into should tolerate a nil dirty table")
  luassert.truthy(type(dirty_tracker.merge_into("bad", { any = true })) == "string",
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
  luassert.has_error(function()
    inventory.count(nil)
  end, "missing player")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_count_rejects_a_player_without_inventory_with_the_guard_message()
  -- kills _inv's "missing player.inventory" -> nil.
  luassert.has_error(function()
    inventory.count({})
  end, "missing player.inventory")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_add_rejects_a_nil_item_with_the_guard_message()
  -- kills inventory.add's "missing item" -> nil.
  luassert.has_error(function()
    inventory.add(_player(), nil)
  end, "missing item")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_remove_by_index_rejects_a_nil_index_with_the_guard_message()
  -- kills inventory.remove_by_index's "missing index" -> nil.
  luassert.has_error(function()
    inventory.remove_by_index(_player(), nil)
  end, "missing index")
end

function TestBoundaryAssertionsT36InventoryGuardMessageClosure:test_remove_by_index_rejects_index_0_as_out_of_bounds()
  -- kills the bounds check `idx >= 1` 1 -> 0: the mutant lets 0 through and
  -- table.remove(self.items, 0) raises a different error, not the guard's.
  luassert.has_error(function()
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
