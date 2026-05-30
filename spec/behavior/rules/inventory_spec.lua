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

  -- T16 mutation-pinning addendum.

  describe("draw_random (L83/L86 weighted-pick contract)", function()
    require("spec.support.test_env")

    it("returns a config item table with id and weight fields", function()
      local picked = inventory.draw_random()
      assert(type(picked) == "table", "draw_random must return a table; got " .. type(picked))
      assert(picked.id ~= nil, "drawn item must carry an id field")
    end)

    it("returns the picked[1] from weight-list, not items_cfg[1] (L86 'or' + first '1' kills)", function()
      -- Force LuaAPI.rand to pick the LAST item in the weighted list deterministically.
      -- choice_weight_list iterates items 1..N accumulating weight; first item whose
      -- cumulative weight >= rand*total_weight wins. rand close to 1.0 → last item wins.
      local items_cfg = require("src.config.content.items")
      local last_item = items_cfg[#items_cfg]
      assert(last_item.id ~= items_cfg[1].id, "fixture invariant: last cfg item differs from first")

      local saved_rand = LuaAPI.rand
      LuaAPI.rand = function() return 0.999999 end -- forces last bucket
      local picked = inventory.draw_random()
      LuaAPI.rand = saved_rand

      assert(picked.id == last_item.id,
        "draw_random must return picked[1] from weighted choice (last item under rand=~1); " ..
        "L86 'or→and' or first '1→0' mutation returns items_cfg[1].id=" ..
        tostring(items_cfg[1].id) .. " instead. Got id=" .. tostring(picked.id))
    end)
  end)

  describe("clear toggles _suspend_on_change around items reset (L77/L79)", function()
    it("clear leaves _suspend_on_change false after returning", function()
      local player = _make_player({ { id = "a" }, { id = "b" } })
      -- Force pre-clear state to true so L79 'false' mutation is observable.
      player.inventory._suspend_on_change = true
      inventory.clear(player)
      _assert_eq(player.inventory._suspend_on_change, false,
        "clear must leave _suspend_on_change=false at exit; mutation L79 would leave it true")
    end)

    it("clear sets _suspend_on_change=true during items reset (observable via __newindex)", function()
      -- Build inventory whose items field uses a __newindex hook to capture the
      -- _suspend_on_change value at the exact moment items is overwritten.
      local captured_during_write = nil
      local player = _make_player({ { id = "a" } })
      local raw_inv = player.inventory
      local proxy = setmetatable({}, {
        __index = raw_inv,
        __newindex = function(_, key, value)
          if key == "items" then
            captured_during_write = raw_inv._suspend_on_change
          end
          rawset(raw_inv, key, value)
        end,
      })
      player.inventory = proxy
      inventory.clear(player)
      _assert_eq(captured_during_write, true,
        "during items reset _suspend_on_change must be true; L77 mutation makes it false")
    end)
  end)

  describe("_notify_full popup_port fallback via ensure_popup_port (L92/L93)", function()
    it("pushes popup via intent_output_port when popup_port resolves from ensure", function()
      local pushed = {}
      local resolved_port = { -- this is what ensure_popup_port returns
        push_popup = function() end,
      }
      local game = {
        popup_port = nil,
        ensure_popup_port = function() return resolved_port end,
        intent_output_port = {
          push_popup = function(_, payload)
            pushed[#pushed + 1] = payload
            return true
          end,
        },
      }
      local item_ids = require("src.config.gameplay.item_ids")
      local player = _make_player({ {}, {}, {}, {}, {} }, { name = "P3" })
      local result = inventory.give(player, item_ids.free_rent, { game = game })
      _assert_eq(result, false, "give full must report failure")
      assert(#pushed >= 1,
        "_notify_full must invoke intent_output_port:push_popup when ensure_popup_port " ..
        "resolves a port. L92/L93 mutations skip the assignment or zero it out → " ..
        "popup_port stays nil → early return at L95 → no push. Captured " .. #pushed)
      assert(pushed[1].title == "道具", "popup title must be '道具'; got " .. tostring(pushed[1].title))
      assert(tostring(pushed[1].body):find("P3"),
        "popup body must include player name; got " .. tostring(pushed[1].body))
    end)
  end)
end)
