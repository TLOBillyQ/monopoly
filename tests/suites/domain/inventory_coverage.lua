local inventory = require("src.rules.items.inventory")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_inventory(items_list)
  local inv = {
    items = items_list or {},
    _suspend_on_change = false,
  }
  function inv:count() return #self.items end
  function inv:is_full() return #self.items >= 5 end
  function inv:add(item) self.items[#self.items + 1] = item end
  function inv:find_index(pred)
    for i, it in ipairs(self.items) do
      if pred(it) then return i end
    end
    return nil
  end
  function inv:remove_by_index(idx) table.remove(self.items, idx) end
  return inv
end

local function _make_player(items_list, opts)
  opts = opts or {}
  return {
    id = opts.id or 1001,
    name = opts.name or "TestPlayer",
    is_ai = opts.is_ai,
    auto = opts.auto,
    inventory = _make_inventory(items_list),
  }
end

-- inventory.cfg

local function test_cfg_known_id_returns_table_or_nil()
  local result = inventory.cfg("strong")
  assert(result == nil or type(result) == "table", "cfg should return table or nil for any id")
end

-- inventory.items

local function test_items_returns_items_list()
  local player = _make_player({ { id = "item_a" } })
  local items = inventory.items(player)
  _assert_eq(#items, 1, "items should return the inventory items list")
  _assert_eq(items[1].id, "item_a", "first item should be item_a")
end

-- inventory.count

local function test_count_returns_item_count()
  local player = _make_player({ { id = "x" }, { id = "y" } })
  _assert_eq(inventory.count(player), 2, "count should return 2")
end

local function test_count_empty_returns_zero()
  local player = _make_player({})
  _assert_eq(inventory.count(player), 0, "count of empty inventory is 0")
end

-- inventory.is_full

local function test_is_full_when_at_limit()
  local player = _make_player({ {}, {}, {}, {}, {} })
  _assert_eq(inventory.is_full(player), true, "5 items should be full")
end

local function test_is_full_when_not_full()
  local player = _make_player({ {}, {} })
  _assert_eq(inventory.is_full(player), false, "2 items should not be full")
end

-- inventory.add

local function test_add_appends_item()
  local player = _make_player({})
  inventory.add(player, { id = "sword" })
  _assert_eq(inventory.count(player), 1, "add should increase count")
  _assert_eq(inventory.items(player)[1].id, "sword", "added item should be present")
end

-- inventory.find_index

local function test_find_index_found()
  local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
  local idx = inventory.find_index(player, "item_b")
  _assert_eq(idx, 2, "find_index should return 2 for item_b")
end

local function test_find_index_not_found()
  local player = _make_player({ { id = "item_a" } })
  local idx = inventory.find_index(player, "item_x")
  _assert_eq(idx, nil, "find_index should return nil when not found")
end

-- inventory.remove_by_index

local function test_remove_by_index_removes_item()
  local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
  inventory.remove_by_index(player, 1)
  _assert_eq(inventory.count(player), 1, "remove should decrease count")
  _assert_eq(inventory.items(player)[1].id, "item_b", "remaining item should be item_b")
end

-- inventory.consume

local function test_consume_removes_first_matching_item()
  local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
  local ok = inventory.consume(player, "item_a")
  _assert_eq(ok, true, "consume should return true")
  _assert_eq(inventory.count(player), 1, "consume should reduce count")
  _assert_eq(inventory.items(player)[1].id, "item_b", "item_b should remain")
end

-- inventory.clear

local function test_clear_removes_all_items()
  local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
  inventory.clear(player)
  _assert_eq(#inventory.items(player), 0, "clear should remove all items")
end

local function test_clear_empty_inventory_is_noop()
  local player = _make_player({})
  inventory.clear(player)
  _assert_eq(#inventory.items(player), 0, "clear on empty should remain empty")
end

-- inventory.give: not full → adds item

local function test_give_adds_item_when_not_full()
  local player = _make_player({}, { name = "P1" })
  local item_ids = require("src.config.gameplay.item_ids")
  local ok = inventory.give(player, item_ids.missile, nil)
  _assert_eq(ok, true, "give should return true when not full")
  _assert_eq(inventory.count(player), 1, "count should be 1 after give")
end

-- inventory.give: full → returns false

local function test_give_returns_false_when_full()
  local player = _make_player({ {}, {}, {}, {}, {} }, { name = "P1" })
  local result = inventory.give(player, "strong", nil)
  _assert_eq(result, false, "give should return false when full")
end

-- inventory.give: full with game.popup_port nil → notify skipped

local function test_give_full_with_game_no_popup_port()
  local player = _make_player({ {}, {}, {}, {}, {} }, { name = "P2" })
  local game = {}
  local result = inventory.give(player, "strong", { game = game })
  _assert_eq(result, false, "give full with no popup_port should return false")
end

-- inventory.give: full with AI player → notify skipped

local function test_give_full_ai_player_skips_notify()
  local player = _make_player({ {}, {}, {}, {}, {} }, { name = "AI", is_ai = true })
  local game = { popup_port = { push_popup = function() error("should not call") end } }
  local result = inventory.give(player, "strong", { game = game })
  _assert_eq(result, false, "give full AI player should return false without error")
end

return {
  name = "domain inventory coverage",
  tests = {
    { name = "cfg known id returns table or nil", run = test_cfg_known_id_returns_table_or_nil },
    { name = "items returns items list", run = test_items_returns_items_list },
    { name = "count returns item count", run = test_count_returns_item_count },
    { name = "count empty returns zero", run = test_count_empty_returns_zero },
    { name = "is_full when at limit", run = test_is_full_when_at_limit },
    { name = "is_full when not full", run = test_is_full_when_not_full },
    { name = "add appends item", run = test_add_appends_item },
    { name = "find_index found", run = test_find_index_found },
    { name = "find_index not found", run = test_find_index_not_found },
    { name = "remove_by_index removes item", run = test_remove_by_index_removes_item },
    { name = "consume removes first matching item", run = test_consume_removes_first_matching_item },
    { name = "clear removes all items", run = test_clear_removes_all_items },
    { name = "clear empty inventory is noop", run = test_clear_empty_inventory_is_noop },
    { name = "give adds item when not full", run = test_give_adds_item_when_not_full },
    { name = "give returns false when full", run = test_give_returns_false_when_full },
    { name = "give full with game no popup_port", run = test_give_full_with_game_no_popup_port },
    { name = "give full AI player skips notify", run = test_give_full_ai_player_skips_notify },
  },
}
