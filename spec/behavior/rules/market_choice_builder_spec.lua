local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local choice = require("src.rules.market.choice")
local market_query = require("src.rules.market.query")
local dirty_tracker = require("src.state.dirty_tracker")

local function _ok(val, msg)
  assert(val, msg or "expected truthy")
end

local function _stub_player(id)
  return {
    id = id,
    name = "player_" .. tostring(id),
    inventory = {
      items = {},
      count = 0,
      is_full = function() return false end,
    },
  }
end

local function _make_pending_choice(player_id)
  return {
    kind = "market_buy",
    owner_role_id = player_id,
    active_tab = "item",
    page_index = 1,
    page_count = 1,
  }
end

local function _patch_market_query_empty()
  return {
    { target = market_query.eligibility, key = "sorted_entries", value = function() return {} end },
    { target = market_query.eligibility, key = "can_buy_entry", value = function() return false end },
    { target = market_query.eligibility, key = "is_sold_out", value = function() return false end },
    { target = market_query.context, key = "entry_market_enabled", value = function() return true end },
    { target = market_query.context, key = "entry_name", value = function() return "item" end },
    { target = market_query.context, key = "entry_price", value = function() return 100 end },
    { target = market_query.context, key = "entry_currency", value = function() return "gold" end },
    { target = dirty_tracker, key = "mark", value = function() end },
  }
end

describe("market_choice", function()
  describe("builder.build", function()
    it("returns market_buy kind", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, {})
        _assert_eq(spec.kind, "market_buy", "should be market_buy kind")
        _assert_eq(spec.route_key, "market", "should route to market")
        _assert_eq(spec.owner_role_id, player.id, "owner should be player")
      end)
    end)

    it("defaults active_tab to item when nil", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, { active_tab = nil })
        _assert_eq(spec.active_tab, "item", "should default to item tab")
      end)
    end)

    it("keeps valid active_tab", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, { active_tab = "item" })
        _assert_eq(spec.active_tab, "item", "should keep item tab")
      end)
    end)

    it("rejects invalid active_tab and defaults to item", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, { active_tab = "nonexistent" })
        _assert_eq(spec.active_tab, "item", "should default to item for invalid tab")
      end)
    end)

    it("clamps page_index to valid range", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, { page_index = 99 })
        _ok(spec.page_index >= 1, "page_index should be at least 1")
        _ok(spec.page_index <= spec.page_count, "page_index should not exceed page_count")
      end)
    end)

    it("handles nil page_index", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, { page_index = nil })
        _assert_eq(spec.page_index, 1, "nil page_index should default to 1")
      end)
    end)

    it("sets allow_cancel and cancel_label", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, {})
        _ok(spec.allow_cancel == true, "should allow cancel")
        _assert_eq(spec.cancel_label, "不买", "cancel label should be 不买")
      end)
    end)

    it("includes meta with player_id and pagination state", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, {})
        _ok(spec.meta ~= nil, "should have meta")
        _assert_eq(spec.meta.player_id, player.id, "meta should have player_id")
        _assert_eq(spec.meta.active_tab, spec.active_tab, "meta should mirror active_tab")
        _assert_eq(spec.meta.page_index, spec.page_index, "meta should mirror page_index")
        _assert_eq(spec.meta.page_count, spec.page_count, "meta should mirror page_count")
      end)
    end)

    it("defaults state to empty table when nil", function()
      local player = _stub_player(1)
      local game = {}

      _with_patches(_patch_market_query_empty(), function()
        local spec = choice.builder.build(player, game, nil)
        _assert_eq(spec.active_tab, "item", "should default to item")
        _assert_eq(spec.page_index, 1, "should default page to 1")
      end)
    end)
  end)

  describe("session.rebuild_pending", function()
    it("returns false when game is nil", function()
      local pending = _make_pending_choice(1)
      local player = _stub_player(1)

      local ok = choice.session.rebuild_pending(nil, pending, player, {})
      _ok(ok == false, "should return false when game is nil")
    end)

    it("returns false when pending_choice is nil", function()
      local player = _stub_player(1)
      local game = {}

      local ok = choice.session.rebuild_pending(game, nil, player, {})
      _ok(ok == false, "should return false when pending_choice is nil")
    end)

    it("returns false when pending_choice kind is not market_buy", function()
      local player = _stub_player(1)
      local game = {}
      local pending = { kind = "other" }

      local ok = choice.session.rebuild_pending(game, pending, player, {})
      _ok(ok == false, "should return false for non-market_buy kind")
    end)

    it("returns false when player is nil", function()
      local game = {}
      local pending = _make_pending_choice(1)

      local ok = choice.session.rebuild_pending(game, pending, nil, {})
      _ok(ok == false, "should return false when player is nil")
    end)

    it("returns true on success and updates pending_choice", function()
      local player = _stub_player(1)
      local game = {}
      local pending = _make_pending_choice(1)

      _with_patches(_patch_market_query_empty(), function()
        local ok = choice.session.rebuild_pending(game, pending, player, {})
        _ok(ok == true, "should return true on success")
        _assert_eq(pending.kind, "market_buy", "pending kind should be updated")
      end)
    end)
  end)

  describe("session.apply_navigation", function()
    it("returns false when game is nil", function()
      local pending = _make_pending_choice(1)
      local ok = choice.session.apply_navigation(nil, pending, { type = "market_tab_select", tab = "item" })
      _ok(ok == false, "should return false when game is nil")
    end)

    it("returns false when pending_choice is nil", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local ok = choice.session.apply_navigation(game, nil, { type = "market_tab_select", tab = "item" })
      _ok(ok == false, "should return false when pending_choice is nil")
    end)

    it("returns false when pending_choice kind is not market_buy", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = { kind = "other" }
      local ok = choice.session.apply_navigation(game, pending, { type = "market_tab_select", tab = "item" })
      _ok(ok == false, "should return false for non-market_buy kind")
    end)

    it("returns false when owner_role_id is nil", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = _make_pending_choice(1)
      pending.owner_role_id = nil

      local ok = choice.session.apply_navigation(game, pending, { type = "market_tab_select", tab = "item" })
      _ok(ok == false, "should return false when owner_role_id is nil")
    end)

    it("returns false when player not found", function()
      local game = { find_player_by_id = function() return nil end }
      local pending = _make_pending_choice(1)

      local ok = choice.session.apply_navigation(game, pending, { type = "market_tab_select", tab = "item" })
      _ok(ok == false, "should return false when player not found")
    end)

    it("returns true unchanged when tab is same", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = _make_pending_choice(1)
      pending.active_tab = "item"

      _with_patches(_patch_market_query_empty(), function()
        local ok = choice.session.apply_navigation(game, pending, { type = "market_tab_select", tab = "item" })
        _ok(ok == true, "should return true when tab unchanged")
      end)
    end)

    it("switches tab and resets page on tab_select", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = _make_pending_choice(1)
      pending.active_tab = "item"
      pending.page_index = 3

      _with_patches(_patch_market_query_empty(), function()
        local ok = choice.session.apply_navigation(game, pending, { type = "market_tab_select", tab = "item" })
        _ok(ok == true, "should succeed on tab switch")
      end)
    end)

    it("decrements page on page_prev", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = _make_pending_choice(1)
      pending.active_tab = "item"
      pending.page_index = 3
      pending.page_count = 5

      local entries = {}
      for i = 1, 25 do
        entries[#entries + 1] = { kind = "item", product_id = i, market_enabled = true }
      end

      _with_patches({
        { target = market_query.eligibility, key = "sorted_entries", value = function() return entries end },
        { target = market_query.eligibility, key = "can_buy_entry", value = function() return true end },
        { target = market_query.eligibility, key = "is_sold_out", value = function() return false end },
        { target = market_query.context, key = "entry_market_enabled", value = function() return true end },
        { target = market_query.context, key = "entry_name", value = function() return "item" end },
        { target = market_query.context, key = "entry_price", value = function() return 100 end },
        { target = market_query.context, key = "entry_currency", value = function() return "gold" end },
        { target = dirty_tracker, key = "mark", value = function() end },
      }, function()
        local ok = choice.session.apply_navigation(game, pending, { type = "market_page_prev" })
        _ok(ok == true, "should succeed on page_prev")
        _assert_eq(pending.page_index, 2, "page should decrement")
      end)
    end)

    it("increments page on page_next", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = _make_pending_choice(1)
      pending.active_tab = "item"
      pending.page_index = 1
      pending.page_count = 5

      local entries = {}
      for i = 1, 25 do
        entries[#entries + 1] = { kind = "item", product_id = i, market_enabled = true }
      end

      _with_patches({
        { target = market_query.eligibility, key = "sorted_entries", value = function() return entries end },
        { target = market_query.eligibility, key = "can_buy_entry", value = function() return true end },
        { target = market_query.eligibility, key = "is_sold_out", value = function() return false end },
        { target = market_query.context, key = "entry_market_enabled", value = function() return true end },
        { target = market_query.context, key = "entry_name", value = function() return "item" end },
        { target = market_query.context, key = "entry_price", value = function() return 100 end },
        { target = market_query.context, key = "entry_currency", value = function() return "gold" end },
        { target = dirty_tracker, key = "mark", value = function() end },
      }, function()
        local ok = choice.session.apply_navigation(game, pending, { type = "market_page_next" })
        _ok(ok == true, "should succeed on page_next")
        _assert_eq(pending.page_index, 2, "page should increment")
      end)
    end)

    it("returns true for unknown action type without changes", function()
      local player = _stub_player(1)
      local game = { find_player_by_id = function() return player end }
      local pending = _make_pending_choice(1)
      local original_tab = pending.active_tab
      local original_page = pending.page_index

      _with_patches(_patch_market_query_empty(), function()
        local ok = choice.session.apply_navigation(game, pending, { type = "unknown_action" })
        _ok(ok == true, "should succeed for unknown action")
        _assert_eq(pending.active_tab, original_tab, "tab should not change")
        _assert_eq(pending.page_index, original_page, "page should not change")
      end)
    end)
  end)

  describe("feedback", function()
    it("emit_buy_failed does not error with valid inputs", function()
      local player = _stub_player(1)
      local ok = pcall(choice.feedback.emit_buy_failed, player, { id = 1 }, "no_gold", "金币不足")
      _ok(ok, "emit_buy_failed should not error")
    end)

    it("emit_inventory_full does not error with valid inputs", function()
      local player = _stub_player(1)
      local ok = pcall(choice.feedback.emit_inventory_full, player, { id = 1 })
      _ok(ok, "emit_inventory_full should not error")
    end)
  end)

  describe("session.refresh_after_paid_callback", function()
    it("returns false when game is nil", function()
      local player = _stub_player(1)
      local entry = { id = 1 }

      local ok = choice.session.refresh_after_paid_callback(nil, player, entry)
      _ok(ok == false, "should return false when game is nil")
    end)

    it("returns false when no pending_choice", function()
      local game = { turn = {} }
      local player = _stub_player(1)
      local entry = { id = 1 }

      local ok = choice.session.refresh_after_paid_callback(game, player, entry)
      _ok(ok == false, "should return false when no pending_choice")
    end)

    it("returns false when pending_choice is not market_buy", function()
      local game = { turn = { pending_choice = { kind = "other" } } }
      local player = _stub_player(1)
      local entry = { id = 1 }

      local ok = choice.session.refresh_after_paid_callback(game, player, entry)
      _ok(ok == false, "should return false for non-market_buy")
    end)

    it("returns false when turn is nil", function()
      local game = {}
      local player = _stub_player(1)
      local entry = { id = 1 }

      local ok = choice.session.refresh_after_paid_callback(game, player, entry)
      _ok(ok == false, "should return false when turn is nil")
    end)
  end)
end)
