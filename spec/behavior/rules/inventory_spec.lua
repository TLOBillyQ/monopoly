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


-- inventory.items


-- inventory.count



-- inventory.is_full



-- inventory.add


-- inventory.find_index



-- inventory.remove_by_index


-- inventory.consume


-- inventory.clear



-- inventory.give: not full → adds item


-- inventory.give: full → returns false


-- inventory.give: full with game.popup_port nil → notify skipped


-- inventory.give: full with AI player → notify skipped

describe("domain inventory coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("cfg known id returns table or nil", function()
    local result = inventory.cfg("strong")
    assert(result == nil or type(result) == "table", "cfg should return table or nil for any id")
  end)

  it("items returns items list", function()
    local player = _make_player({ { id = "item_a" } })
    local items = inventory.items(player)
    _assert_eq(#items, 1, "items should return the inventory items list")
    _assert_eq(items[1].id, "item_a", "first item should be item_a")
  end)

  it("count returns item count", function()
    local player = _make_player({ { id = "x" }, { id = "y" } })
    _assert_eq(inventory.count(player), 2, "count should return 2")
  end)

  it("count empty returns zero", function()
    local player = _make_player({})
    _assert_eq(inventory.count(player), 0, "count of empty inventory is 0")
  end)

  it("is_full when at limit", function()
    local player = _make_player({ {}, {}, {}, {}, {} })
    _assert_eq(inventory.is_full(player), true, "5 items should be full")
  end)

  it("is_full when not full", function()
    local player = _make_player({ {}, {} })
    _assert_eq(inventory.is_full(player), false, "2 items should not be full")
  end)

  it("add appends item", function()
    local player = _make_player({})
    inventory.add(player, { id = "sword" })
    _assert_eq(inventory.count(player), 1, "add should increase count")
    _assert_eq(inventory.items(player)[1].id, "sword", "added item should be present")
  end)

  it("find_index found", function()
    local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
    local idx = inventory.find_index(player, "item_b")
    _assert_eq(idx, 2, "find_index should return 2 for item_b")
  end)

  it("find_index not found", function()
    local player = _make_player({ { id = "item_a" } })
    local idx = inventory.find_index(player, "item_x")
    _assert_eq(idx, nil, "find_index should return nil when not found")
  end)

  it("remove_by_index removes item", function()
    local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
    inventory.remove_by_index(player, 1)
    _assert_eq(inventory.count(player), 1, "remove should decrease count")
    _assert_eq(inventory.items(player)[1].id, "item_b", "remaining item should be item_b")
  end)

  it("consume removes first matching item", function()
    local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
    local ok = inventory.consume(player, "item_a")
    _assert_eq(ok, true, "consume should return true")
    _assert_eq(inventory.count(player), 1, "consume should reduce count")
    _assert_eq(inventory.items(player)[1].id, "item_b", "item_b should remain")
  end)

  it("clear removes all items", function()
    local player = _make_player({ { id = "item_a" }, { id = "item_b" } })
    inventory.clear(player)
    _assert_eq(#inventory.items(player), 0, "clear should remove all items")
  end)

  it("clear empty inventory is noop", function()
    local player = _make_player({})
    inventory.clear(player)
    _assert_eq(#inventory.items(player), 0, "clear on empty should remain empty")
  end)

  it("give adds item when not full", function()
    local player = _make_player({}, { name = "P1" })
    local item_ids = require("src.config.gameplay.item_ids")
    local ok = inventory.give(player, item_ids.missile, nil)
    _assert_eq(ok, true, "give should return true when not full")
    _assert_eq(inventory.count(player), 1, "count should be 1 after give")
  end)

  it("give returns false when full", function()
    local player = _make_player({ {}, {}, {}, {}, {} }, { name = "P1" })
    local result = inventory.give(player, "strong", nil)
    _assert_eq(result, false, "give should return false when full")
  end)

  it("give full with game no popup_port", function()
    local player = _make_player({ {}, {}, {}, {}, {} }, { name = "P2" })
    local game = {}
    local result = inventory.give(player, "strong", { game = game })
    _assert_eq(result, false, "give full with no popup_port should return false")
  end)

  it("give full AI player skips notify", function()
    local player = _make_player({ {}, {}, {}, {}, {} }, { name = "AI", is_ai = true })
    local game = { popup_port = { push_popup = function() error("should not call") end } }
    local result = inventory.give(player, "strong", { game = game })
    _assert_eq(result, false, "give full AI player should return false without error")
  end)
end)
