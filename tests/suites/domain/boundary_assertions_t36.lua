local inventory = require("src.rules.items.inventory")
local balance_ops = require("src.player.actions.state_ops.balance_ops")
local dirty_tracker = require("src.core.utils.dirty_tracker")

local function _assert_contains(text, fragment, message)
  assert(type(text) == "string", (message or "expected string") .. ": non-string error")
  assert(string.find(text, fragment, 1, true) ~= nil, (message or "missing fragment") .. ": " .. text)
end

local function _test_inventory_remove_by_index_asserts_out_of_bounds()
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

  assert(ok == false, "remove_by_index should assert on out-of-bounds index")
  _assert_contains(err, "remove_by_index: index out of bounds: 2", "unexpected out-of-bounds assertion message")
end

local function _test_deduct_player_cash_asserts_negative_balance()
  local game = setmetatable({}, { __index = balance_ops })
  local player = { cash = 5 }

  local ok, err = pcall(function()
    game:deduct_player_cash(player, 6)
  end)

  assert(ok == false, "deduct_player_cash should assert on negative balance")
  _assert_contains(err, "negative balance: -1", "unexpected negative balance assertion message")
end

local function _test_dirty_tracker_mark_asserts_unknown_domain()
  local dirty = dirty_tracker.new()
  local ok, err = pcall(function()
    dirty_tracker.mark(dirty, "unknown_domain")
  end)

  assert(ok == false, "dirty_tracker.mark should assert on unknown domain")
  _assert_contains(err, "unknown dirty domain: unknown_domain", "unexpected dirty domain assertion message")
end

return {
  name = "boundary_assertions_t36",
  tests = {
    { name = "inventory_remove_by_index_asserts_out_of_bounds", run = _test_inventory_remove_by_index_asserts_out_of_bounds },
    { name = "deduct_player_cash_asserts_negative_balance", run = _test_deduct_player_cash_asserts_negative_balance },
    { name = "dirty_tracker_mark_asserts_unknown_domain", run = _test_dirty_tracker_mark_asserts_unknown_domain },
  },
}
