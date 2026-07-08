local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local choice = require("src.rules.market.choice")
local purchase_settlement = require("src.rules.market.purchase_settlement")
local market_query = require("src.rules.market.query")
local monopoly_event = require("src.foundation.events")
local dirty_tracker = require("src.state.dirty_tracker")

local function _stub_player(id) return { id = id } end

local function _make_entries(n)
  local list = {}
  for i = 1, n do
    list[i] = {
      product_id = "p" .. i, name = "n_" .. i, price = 100, currency = "金币",
      kind = "item", market_enabled = true,
    }
  end
  return list
end

local function _patch_market_query(entries)
  return {
    { target = market_query.eligibility, key = "sorted_entries", value = function() return entries end },
    { target = market_query.eligibility, key = "can_buy_entry", value = function() return true end },
    { target = market_query.eligibility, key = "is_sold_out", value = function() return false end },
    { target = market_query.context, key = "entry_market_enabled", value = function() return true end },
    { target = market_query.context, key = "entry_name", value = function(e) return e.name end },
    { target = market_query.context, key = "entry_price", value = function(e) return e.price end },
    { target = market_query.context, key = "entry_currency", value = function(e) return e.currency end },
    { target = dirty_tracker, key = "mark", value = function() end },
  }
end

local function _reload_choice_with_emit_stub(captured_ref)
  local prev_emit = monopoly_event.emit
  monopoly_event.emit = function(kind, payload)
    captured_ref.kind = kind
    captured_ref.payload = payload
  end
  package.loaded["src.rules.market.choice"] = nil
  local fresh = require("src.rules.market.choice")
  monopoly_event.emit = prev_emit
  package.loaded["src.rules.market.choice"] = nil
  require("src.rules.market.choice")
  return fresh
end

local function _reload_settlement_with_emit_stub(captured_ref)
  local prev_emit = monopoly_event.emit
  monopoly_event.emit = function(kind, payload)
    captured_ref.kind = kind
    captured_ref.payload = payload
  end
  package.loaded["src.rules.market.choice"] = nil
  package.loaded["src.rules.market.purchase_settlement"] = nil
  local fresh = require("src.rules.market.purchase_settlement")
  monopoly_event.emit = prev_emit
  package.loaded["src.rules.market.choice"] = nil
  package.loaded["src.rules.market.purchase_settlement"] = nil
  require("src.rules.market.choice")
  require("src.rules.market.purchase_settlement")
  return fresh
end

describe("market.choice feedback.emit_buy_failed payload entry pass-through (L18-25)", function()
  it("payload.entry must be the entry argument; payload.player must be the player argument", function()
    local cap = {}
    local fresh = _reload_choice_with_emit_stub(cap)
    local player = _stub_player(7)
    local entry = { product_id = "p_x", kind = "item", price = 999 }

    fresh.feedback.emit_buy_failed(player, entry, "no_funds", "现金不足")

    _assert_eq(cap.payload.player, player, "payload.player must be the argument verbatim")
    _assert_eq(cap.payload.entry, entry, "payload.entry must be the argument verbatim")
    _assert_eq(cap.payload.reason, "no_funds", "payload.reason verbatim")
  end)

  it("emit_buy_failed uses monopoly_event.market.buy_failed kind", function()
    local cap = {}
    local fresh = _reload_choice_with_emit_stub(cap)
    fresh.feedback.emit_buy_failed(_stub_player(1), { product_id = "p1" }, "r", "b")
    _assert_eq(cap.kind, monopoly_event.market.buy_failed, "kind must be market.buy_failed event id")
  end)
end)

describe("market.choice feedback.emit_inventory_full payload + kind (L27-33)", function()
  it("emit_inventory_full kind == monopoly_event.market.inventory_full; payload.body literal", function()
    local cap = {}
    local fresh = _reload_choice_with_emit_stub(cap)
    local player = _stub_player(3)
    local entry = { product_id = "p_q", kind = "item" }

    fresh.feedback.emit_inventory_full(player, entry)

    _assert_eq(cap.kind, monopoly_event.market.inventory_full, "kind must be market.inventory_full")
    _assert_eq(cap.payload.player, player, "payload.player verbatim")
    _assert_eq(cap.payload.entry, entry, "payload.entry verbatim")
    _assert_eq(cap.payload.body, "卡槽已满，无法继续购买", "L32 body literal pinned")
  end)
end)

describe("market.purchase_settlement _handle_keep_open full_buy quadruple AND middle-arm pinning", function()
  -- full_buy = entry and entry.kind == "item" and result.fulfilled_now == true and result.inventory_full_after == true
  -- coder pins: all-true (emit), inventory_full_after=false (no emit).
  -- mid-arm closures: entry.kind != "item" path is never reached because _should_keep_market_open
  -- requires entry.kind == "item" for the fulfilled_now branch; deferred_fulfillment is the alternate path.

  it("deferred_fulfillment=true with entry.kind='other': handle_keep_open runs but full_buy=false → no emit", function()
    -- _should_keep_market_open returns true via deferred_fulfillment arm regardless of entry.kind.
    -- _handle_keep_open's full_buy requires entry.kind == "item" → false for "other" → no inventory_full emit.
    local cap = {}
    local fresh = _reload_settlement_with_emit_stub(cap)
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2)), function()
      v = fresh.resolve(game, pc, _stub_player(1),
        { kind = "other" }, { ok = true, deferred_fulfillment = true, fulfilled_now = true, inventory_full_after = true })
    end)
    _assert_eq(v.keep_open, true, "deferred_fulfillment=true must yield keep_open=true")
    _assert_eq(cap.kind, nil, "non-item entry.kind must NOT emit inventory_full even with all other flags true")
  end)

  it("entry nil with deferred_fulfillment=true: keep_open via deferred arm, full_buy=false → no emit", function()
    -- _should_keep_market_open: type(result)=='table' + result.ok==true + deferred_fulfillment==true → return true.
    -- _handle_keep_open: full_buy starts with `entry and ...` → entry==nil short-circuits → false → no emit.
    local cap = {}
    local fresh = _reload_settlement_with_emit_stub(cap)
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2)), function()
      v = fresh.resolve(game, pc, _stub_player(1),
        nil, { ok = true, deferred_fulfillment = true, fulfilled_now = true, inventory_full_after = true })
    end)
    _assert_eq(v.keep_open, true, "entry nil + deferred_fulfillment=true → keep_open=true")
    _assert_eq(cap.kind, nil, "entry nil → no inventory_full emit even with other flags true")
  end)
end)

describe("market.purchase_settlement _should_keep_market_open deferred_fulfillment literal == true", function()
  it("deferred_fulfillment='yes' (truthy string but != true) → keep_open arm rejects → not keep_open", function()
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2)), function()
      v = purchase_settlement.resolve(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, deferred_fulfillment = "yes", fulfilled_now = false })
    end)
    _assert_eq(v.keep_open, false, "non-literal-true deferred_fulfillment must NOT trigger keep_open arm")
  end)
end)

describe("market.choice _apply_navigation_action unknown action.type returns unchanged=false (L205)", function()
  it("unknown action.type drives rebuild via builder; pending_choice gets reapplied", function()
    -- Coder asserts page/tab equality but the L205 `false` for unchanged means the rebuild path runs.
    -- Verify rebuild side-effect: dirty.market and dirty.turn get marked.
    local marks = {}
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false, turn = false, market = false },
      turn = {},
    }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 2, page_count = 3 }
    local patches = _patch_market_query(_make_entries(25))
    -- swap dirty_tracker.mark patch to capture
    for i, p in ipairs(patches) do
      if p.target == dirty_tracker and p.key == "mark" then
        patches[i] = { target = dirty_tracker, key = "mark", value = function(_, domain) marks[#marks+1] = domain end }
      end
    end
    _with_patches(patches, function()
      local ok = choice.session.apply_navigation(game, pc, { type = "unknown_action_type" })
      _assert_eq(ok, true, "unknown action type still must succeed via builder rebuild")
    end)
    local turn_seen, market_seen = false, false
    for _, d in ipairs(marks) do
      if d == "turn" then turn_seen = true end
      if d == "market" then market_seen = true end
    end
    assert(turn_seen and market_seen, "unknown action → unchanged=false → builder rebuild → dirty.mark turn+market")
  end)
end)

describe("market.purchase_settlement _handle_keep_open rebuild failure", function()
  it("when rebuild_pending fails (kind != market_buy) keep_open returns false", function()
    local v = purchase_settlement.resolve({}, { kind = "wrong" }, _stub_player(1),
      { kind = "item" }, { ok = true, deferred_fulfillment = true })
    _assert_eq(v.keep_open, false, "rebuild failure in keep_open path must return keep_open=false")
  end)
end)
