local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local choice = require("src.rules.market.choice")
local purchase_settlement = require("src.rules.market.purchase_settlement")
local market_query = require("src.rules.market.query")
local intent_output_port = require("src.rules.ports.intent_output")
local dirty_tracker = require("src.state.dirty_tracker")
local choice_contract = require("src.config.choice.contract")
local monopoly_event = require("src.foundation.events")

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

local function _patch_market_query(entries, dirty_mark_calls)
  return {
    { target = market_query.eligibility, key = "sorted_entries", value = function() return entries end },
    { target = market_query.eligibility, key = "can_buy_entry", value = function() return true end },
    { target = market_query.eligibility, key = "is_sold_out", value = function() return false end },
    { target = market_query.context, key = "entry_market_enabled", value = function() return true end },
    { target = market_query.context, key = "entry_name", value = function(e) return e.name end },
    { target = market_query.context, key = "entry_price", value = function(e) return e.price end },
    { target = market_query.context, key = "entry_currency", value = function(e) return e.currency end },
    { target = dirty_tracker, key = "mark", value = function(d, domain)
      d.any = true
      d[domain] = true
      if dirty_mark_calls then
        dirty_mark_calls[#dirty_mark_calls + 1] = domain
      end
    end },
  }
end

describe("market.choice _mark_choice_dirty L143-149 via rebuild_pending → _apply_spec", function()
  it("game.dirty present → marks 'turn' and 'market' domains", function()
    local mark_calls = {}
    local game = { dirty = { any = false, turn = false, market = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    _with_patches(_patch_market_query(_make_entries(3), mark_calls), function()
      local ok = choice.session.rebuild_pending(game, pc, _stub_player(1), {})
      _assert_eq(ok, true, "rebuild must succeed")
    end)
    -- mark_calls should include "turn" and "market"
    local turn_seen, market_seen = false, false
    for _, domain in ipairs(mark_calls) do
      if domain == "turn" then turn_seen = true end
      if domain == "market" then market_seen = true end
    end
    assert(turn_seen, "_mark_choice_dirty must mark 'turn'")
    assert(market_seen, "_mark_choice_dirty must mark 'market'")
  end)

  it("game.dirty nil → early return, no mark calls", function()
    local mark_calls = {}
    local game = { dirty = nil }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      local ok = choice.session.rebuild_pending(game, pc, _stub_player(1), {})
      _assert_eq(ok, true, "rebuild succeeds even without dirty tracker")
    end)
    _assert_eq(#mark_calls, 0, "L144 guard: no marks when game.dirty is nil")
  end)
end)

describe("market.choice _current_choice_state L151-156 via rebuild_pending(state=nil)", function()
  it("nil state path: _current_choice_state copies pending_choice active_tab + page_index", function()
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = "item", page_index = 2, page_count = 3,
    }
    local game = { dirty = { any = false } }
    _with_patches(_patch_market_query(_make_entries(25)), function()
      -- state arg = nil → triggers `state or _current_choice_state(pending_choice)`
      local ok = choice.session.rebuild_pending(game, pc, _stub_player(1), nil)
      _assert_eq(ok, true, "rebuild must succeed via _current_choice_state")
      _assert_eq(pc.active_tab, "item", "active_tab survives the round-trip from _current_choice_state")
      _assert_eq(pc.page_index, 2, "page_index 2 from pc must drive builder via _current_choice_state")
    end)
  end)

  it("nil pending_choice fields → builder receives nil → defaults applied", function()
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = nil, page_index = nil, page_count = nil,
    }
    local game = { dirty = { any = false } }
    _with_patches(_patch_market_query(_make_entries(5)), function()
      local ok = choice.session.rebuild_pending(game, pc, _stub_player(1), nil)
      _assert_eq(ok, true, "rebuild succeeds with nil fields → defaults")
      _assert_eq(pc.active_tab, "item", "nil active_tab defaults to 'item'")
      _assert_eq(pc.page_index, 1, "nil page_index defaults to 1 via _clamp_page")
    end)
  end)
end)

describe("market.choice session.rebuild_pending reject paths", function()
  it("nil game → false (L177 guard)", function()
    _assert_eq(choice.session.rebuild_pending(nil, { kind = "market_buy" }, _stub_player(1), {}), false,
      "nil game must yield false")
  end)

  it("nil pending_choice → false (L177 guard)", function()
    _assert_eq(choice.session.rebuild_pending({}, nil, _stub_player(1), {}), false,
      "nil pending_choice must yield false")
  end)

  it("pending_choice.kind != 'market_buy' → false (L177 guard)", function()
    _assert_eq(choice.session.rebuild_pending({}, { kind = "other" }, _stub_player(1), {}), false,
      "non-market_buy kind must yield false")
  end)

  it("nil player → false (L181 guard)", function()
    _assert_eq(choice.session.rebuild_pending({}, { kind = "market_buy" }, nil, {}), false,
      "nil player must yield false")
  end)
end)

describe("market.choice _apply_navigation_action market_tab_select different tab (L199)", function()
  it("tab change resets page_index to 1 (L199 literal '1')", function()
    -- Drive via session.apply_navigation with action.tab != pending_choice.active_tab.
    -- Since TAB_ITEM is the only tab, builder.build will normalize back to "item",
    -- but the intermediate state still shows page_index reset to 1.
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false },
      turn = {},
    }
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = "item", page_index = 3, page_count = 3,
    }
    _with_patches(_patch_market_query(_make_entries(25)), function()
      -- action.tab "different_tab" != pending_choice.active_tab "item" → page_index reset to 1
      local ok = choice.session.apply_navigation(game, pc,
        { type = "market_tab_select", tab = "different_tab" })
      _assert_eq(ok, true, "tab change must apply")
      _assert_eq(pc.page_index, 1, "L199: tab change resets page_index to 1")
    end)
  end)
end)

describe("market.purchase_settlement _should_keep_market_open", function()
  local function _resolve(entry, result)
    local v = purchase_settlement.resolve({}, {}, _stub_player(1), entry, result)
    return v
  end

  it("result.ok != true → not keep_open", function()
    local v = _resolve({ kind = "item" }, { ok = false })
    _assert_eq(v.keep_open, false, "non-keep-open + non-failure-stay path must not keep open")
  end)

  it("result.deferred_fulfillment=true → keep_open", function()
    local mark_calls = {}
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      v = purchase_settlement.resolve(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, deferred_fulfillment = true })
    end)
    _assert_eq(v.keep_open, true, "deferred_fulfillment=true must yield keep_open=true")
  end)

  it("result.fulfilled_now=true + entry.kind='item' → keep_open", function()
    local mark_calls = {}
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      v = purchase_settlement.resolve(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, fulfilled_now = true })
    end)
    _assert_eq(v.keep_open, true, "fulfilled_now=true + entry.kind='item' must yield keep_open=true")
  end)

  it("result.fulfilled_now=true but entry.kind='other' → NOT keep_open → finish path", function()
    local mark_calls = {}
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      v = purchase_settlement.resolve(game, pc, _stub_player(1),
        { kind = "other" }, { ok = true, fulfilled_now = true })
    end)
    _assert_eq(v.keep_open, false, "non-item kind blocks keep_open even with fulfilled_now=true")
  end)
end)

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

describe("market.purchase_settlement _handle_keep_open full_buy emit", function()
  it("full_buy: entry.kind='item' + fulfilled_now=true + inventory_full_after=true → emit_inventory_full", function()
    local emitted = {}
    local fresh = _reload_settlement_with_emit_stub(emitted)

    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2)), function()
      v = fresh.resolve(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, fulfilled_now = true, inventory_full_after = true })
    end)
    _assert_eq(v.keep_open, true, "should keep open")
    assert(emitted ~= nil, "inventory_full event must be emitted on full_buy path")
    _assert_eq(emitted.payload.body, "卡槽已满，无法继续购买", "inventory full body literal")
  end)

  it("not full_buy (inventory_full_after=false): no emit_inventory_full", function()
    local emitted = {}
    local fresh = _reload_settlement_with_emit_stub(emitted)

    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    _with_patches(_patch_market_query(_make_entries(2)), function()
      fresh.resolve(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, fulfilled_now = true, inventory_full_after = false })
    end)
    _assert_eq(emitted.kind, nil, "no emit when inventory_full_after is false")
  end)
end)

describe("market.purchase_settlement _try_failure_stay", function()
  it("ok=false + rebuild succeeds → keep_open=true", function()
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local v
    _with_patches(_patch_market_query(_make_entries(2)), function()
      v = purchase_settlement.resolve(game, pc, _stub_player(1),
        { kind = "item" }, { ok = false })
    end)
    _assert_eq(v.keep_open, true, "failure stay path must yield keep_open=true")
  end)

  it("ok=false + rebuild fails (non-market_buy kind) → not keep_open", function()
    local pc = { kind = "other_kind" }
    local v = purchase_settlement.resolve({}, pc, _stub_player(1),
      { kind = "item" }, { ok = false })
    _assert_eq(v.keep_open, false, "rebuild failure on failure_stay must fall through to finish")
  end)
end)

describe("market.purchase_settlement _dispatch_intent + _INTENT_HANDLERS", function()
  it("intent.kind='need_choice' + choice_spec + open_choice non-nil → keep_open=true", function()
    local open_choice_calls = {}
    _with_patches({
      { target = intent_output_port, key = "open_choice", value = function(_, spec, opts)
        open_choice_calls[#open_choice_calls + 1] = { spec = spec, opts = opts }
        return { id = "opened" }  -- non-nil → handler returns true
      end },
    }, function()
      local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "need_choice", choice_spec = { x = 1 }, opts = { y = 2 } } })
      _assert_eq(v.keep_open, true, "need_choice with open_choice non-nil → keep_open=true")
    end)
    _assert_eq(#open_choice_calls, 1, "open_choice invoked once")
    _assert_eq(open_choice_calls[1].opts.y, 2, "opts passed through")
  end)

  it("intent.kind='need_choice' but choice_spec nil → keep_open=true", function()
    _with_patches({
      { target = intent_output_port, key = "open_choice", value = function() return { id = "x" } end },
    }, function()
      local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "need_choice", choice_spec = nil } })
      _assert_eq(v.keep_open, true, "need_choice kind → keep_open=true regardless of dispatch outcome")
    end)
  end)

  it("intent.kind='push_popup' + payload + push_popup=true → not keep_open", function()
    local push_calls = {}
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function(_, payload, opts)
        push_calls[#push_calls + 1] = { payload = payload, opts = opts }
        return true
      end },
    }, function()
      local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = { msg = "hi" }, popup_opts = { p = 1 } } })
      _assert_eq(v.keep_open, false, "push_popup kind → not keep_open")
    end)
    _assert_eq(#push_calls, 1, "push_popup invoked once")
    _assert_eq(push_calls[1].payload.msg, "hi", "payload passed through")
    _assert_eq(push_calls[1].opts.p, 1, "popup_opts passed through")
  end)

  it("intent.kind='push_popup' fallback opts: intent.opts used if no popup_opts", function()
    local opts_seen
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function(_, _, opts)
        opts_seen = opts
        return true
      end },
    }, function()
      purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = {}, opts = { a = 1 } } })
    end)
    _assert_eq(opts_seen.a, 1, "L275: popup_opts or intent.opts fallback")
  end)

  it("intent.kind='push_popup' + payload=nil → not keep_open", function()
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function() error("must NOT be called when payload nil") end },
    }, function()
      local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = nil } })
      _assert_eq(v.keep_open, false, "nil payload → handler false → not keep_open")
    end)
  end)

  it("intent.kind='push_popup' + push_popup returns false → not keep_open", function()
    local push_called = false
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function() push_called = true; return false end },
    }, function()
      local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = { x = 1 } } })
      _assert_eq(push_called, true, "push_popup invoked even though result is false")
      _assert_eq(v.keep_open, false, "push returns false → handler false → not keep_open")
    end)
  end)

  it("intent.kind unknown → not keep_open", function()
    local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
      { ok = true, intent = { kind = "unknown_kind" } })
    _assert_eq(v.keep_open, false, "unknown intent kind → not keep_open")
  end)

  it("result.intent absent → not keep_open", function()
    local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
      { ok = true })  -- no intent
    _assert_eq(v.keep_open, false, "no intent → not keep_open")
  end)

  it("result not a table → not keep_open", function()
    local v = purchase_settlement.resolve({}, { kind = "other" }, _stub_player(1), nil,
      "not_a_table")  -- non-table result
    _assert_eq(v.keep_open, false, "non-table result → not keep_open")
  end)
end)

describe("market.choice session.refresh_after_paid_callback L245-264", function()
  it("nil pending_choice → false", function()
    local game = { turn = { pending_choice = nil } }
    _assert_eq(choice.session.refresh_after_paid_callback(game, _stub_player(1), { product_id = "p1" }), false,
      "nil pending → false")
  end)

  it("wrong kind → false", function()
    local game = { turn = { pending_choice = { kind = "other" } } }
    _assert_eq(choice.session.refresh_after_paid_callback(game, _stub_player(1), { product_id = "p1" }), false,
      "non-market_buy kind → false")
  end)

  it("owner mismatch → false", function()
    local game = { turn = { pending_choice = { kind = "market_buy", owner_role_id = 99 } } }
    -- _resolve_owner_role_id returns 99; player.id = 1; mismatch
    local prev_resolve = choice_contract.resolve_owner_role_id
    choice_contract.resolve_owner_role_id = function(pc) return pc.owner_role_id end
    _assert_eq(choice.session.refresh_after_paid_callback(game, _stub_player(1), { product_id = "p1" }), false,
      "owner mismatch → false")
    choice_contract.resolve_owner_role_id = prev_resolve
  end)

  it("owner matches + rebuild succeeds → true", function()
    local game = {
      turn = {
        pending_choice = { kind = "market_buy", owner_role_id = 1,
          active_tab = "item", page_index = 1, page_count = 1 },
      },
      dirty = { any = false },
    }
    local prev_resolve = choice_contract.resolve_owner_role_id
    choice_contract.resolve_owner_role_id = function(pc) return pc.owner_role_id end
    _with_patches(_patch_market_query(_make_entries(2)), function()
      _assert_eq(choice.session.refresh_after_paid_callback(game, _stub_player(1), { product_id = "p1" }), true,
        "owner match + rebuild ok → true")
    end)
    choice_contract.resolve_owner_role_id = prev_resolve
  end)
end)

describe("market.purchase_settlement _should_keep_market_open `or → and`", function()
  -- Original: ok != true → return false (skip keep_open, take failure_stay path).
  -- Mutated `or → and`: requires BOTH (type != table AND ok != true). With ok=false table, `false AND true = false` →
  --   continues to deferred_fulfillment check → returns true → enters _handle_keep_open path.
  -- Observable diff: emit_inventory_full fires only via keep_open with full_buy=true (entry.kind="item" + fulfilled_now + inventory_full_after).
  -- With ok=false, original path bypasses keep_open → no emit; mutated path enters keep_open with full_buy=true → emit fires.

  it("ok=false + deferred + fulfilled + inventory_full_after=true: NO emit_inventory_full (kills or→and)", function()
    local emitted = {}
    local fresh = _reload_settlement_with_emit_stub(emitted)

    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local result = {
      ok = false,
      deferred_fulfillment = true,
      fulfilled_now = true,
      inventory_full_after = true,
    }
    _with_patches(_patch_market_query(_make_entries(2)), function()
      fresh.resolve(game, pc, _stub_player(1),
        { kind = "item" }, result)
    end)
    _assert_eq(emitted.kind, nil,
      "ok=false MUST short-circuit keep_open at disjunction; failure_stay path does not emit inventory_full")
  end)
end)

describe("market.purchase_settlement _handle_keep_open rebuild failure", function()
  it("keep_open path + rebuild failure → keep_open=false", function()
    local v = purchase_settlement.resolve({}, { kind = "wrong_kind" }, _stub_player(1),
      { kind = "item" }, { ok = true, deferred_fulfillment = true })
    _assert_eq(v.keep_open, false,
      "rebuild fail in keep_open path MUST return keep_open=false")
  end)
end)
