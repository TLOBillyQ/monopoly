local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local choice = require("src.rules.market.choice")
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

describe("market.choice outcome._should_keep_market_open L290-298", function()
  -- _should_keep_market_open is local; drive via outcome.resolve_purchase observing finish_choice vs stay.

  local function _resolve(entry, result)
    local finish_calls = 0
    local function finish_choice(_, _) finish_calls = finish_calls + 1; return { finished = true } end
    local res = choice.outcome.resolve_purchase({}, {}, _stub_player(1), entry, result, finish_choice)
    return res, finish_calls
  end

  it("result.ok != true → finish_choice path (returns whatever finish returns)", function()
    local _, _ = _resolve({ kind = "item" }, { ok = false })
    -- _should_keep_market_open false → _try_failure_stay → rebuild fails (no real game)... let's just observe via stay flag
    local res, finish_calls = _resolve({ kind = "item" }, { ok = false })
    -- ok=false → _try_failure_stay called → rebuild_pending called with game={} → kind != market_buy → false → not stay
    -- → falls through to _dispatch_and_finish → intent={} → no dispatch → finish_choice called
    assert(finish_calls == 1, "non-keep-open + non-failure-stay path must call finish_choice exactly once")
    _assert_eq(res.finished, true, "result must be the finish_choice return value")
  end)

  it("result.deferred_fulfillment=true → keep_open (stay returned)", function()
    -- _handle_keep_open calls session.rebuild_pending; without market_buy kind it fails → falls to finish_choice
    -- To exercise stay path, give a market_buy choice + valid game so rebuild succeeds.
    local mark_calls = {}
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local finish_calls = 0
    local res
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      res = choice.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, deferred_fulfillment = true },
        function() finish_calls = finish_calls + 1; return { finished = true } end)
    end)
    _assert_eq(res.stay, true, "deferred_fulfillment=true must yield stay=true")
    _assert_eq(finish_calls, 0, "stay path must NOT call finish_choice")
  end)

  it("result.fulfilled_now=true + entry.kind='item' → keep_open (stay)", function()
    local mark_calls = {}
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local res
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      res = choice.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, fulfilled_now = true },
        function() return { finished = true } end)
    end)
    _assert_eq(res.stay, true, "fulfilled_now=true + entry.kind='item' must yield stay")
  end)

  it("result.fulfilled_now=true but entry.kind='other' → NOT keep_open → finish path", function()
    local mark_calls = {}
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local finish_calls = 0
    _with_patches(_patch_market_query(_make_entries(2), mark_calls), function()
      choice.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "vehicle" }, { ok = true, fulfilled_now = true },
        function() finish_calls = finish_calls + 1; return {} end)
    end)
    _assert_eq(finish_calls, 1, "non-item kind blocks keep_open even with fulfilled_now=true")
  end)
end)

describe("market.choice outcome._handle_keep_open full_buy emit (L303-304)", function()
  it("full_buy: entry.kind='item' + fulfilled_now=true + inventory_full_after=true → emit_inventory_full", function()
    local emitted
    local prev_emit = monopoly_event.emit
    monopoly_event.emit = function(_, payload) emitted = payload end
    package.loaded["src.rules.market.choice"] = nil
    local fresh = require("src.rules.market.choice")
    monopoly_event.emit = prev_emit
    package.loaded["src.rules.market.choice"] = nil
    require("src.rules.market.choice")

    -- rebuild succeeds for the freshly loaded module too if we patch market_query at module level.
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    _with_patches(_patch_market_query(_make_entries(2)), function()
      fresh.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, fulfilled_now = true, inventory_full_after = true },
        function() return {} end)
    end)
    assert(emitted ~= nil, "inventory_full event must be emitted on full_buy path")
    _assert_eq(emitted.body, "卡槽已满，无法继续购买", "inventory full body literal")
  end)

  it("not full_buy (inventory_full_after=false): no emit_inventory_full", function()
    local emitted
    local prev_emit = monopoly_event.emit
    monopoly_event.emit = function(_, payload) emitted = payload end
    package.loaded["src.rules.market.choice"] = nil
    local fresh = require("src.rules.market.choice")
    monopoly_event.emit = prev_emit
    package.loaded["src.rules.market.choice"] = nil
    require("src.rules.market.choice")

    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    _with_patches(_patch_market_query(_make_entries(2)), function()
      fresh.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "item" }, { ok = true, fulfilled_now = true, inventory_full_after = false },
        function() return {} end)
    end)
    _assert_eq(emitted, nil, "no emit when inventory_full_after is false")
  end)
end)

describe("market.choice outcome._try_failure_stay L308-311", function()
  it("ok=false + rebuild succeeds → stay=true", function()
    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local res
    _with_patches(_patch_market_query(_make_entries(2)), function()
      res = choice.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "item" }, { ok = false }, function() return {} end)
    end)
    _assert_eq(res.stay, true, "failure stay path must yield stay=true")
  end)

  it("ok=false + rebuild fails (non-market_buy kind) → finish path", function()
    local pc = { kind = "other_kind" }
    local finish_calls = 0
    choice.outcome.resolve_purchase({}, pc, _stub_player(1),
      { kind = "item" }, { ok = false },
      function() finish_calls = finish_calls + 1; return {} end)
    _assert_eq(finish_calls, 1, "rebuild failure on failure_stay must fall through to finish")
  end)
end)

describe("market.choice outcome._dispatch_and_finish + _INTENT_HANDLERS L268-L320", function()
  it("intent.kind='need_choice' + choice_spec + open_choice non-nil → returns stay (L271 ~= nil arm)", function()
    local open_choice_calls = {}
    _with_patches({
      { target = intent_output_port, key = "open_choice", value = function(_, spec, opts)
        open_choice_calls[#open_choice_calls + 1] = { spec = spec, opts = opts }
        return { id = "opened" }  -- non-nil → handler returns true
      end },
    }, function()
      local res = choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "need_choice", choice_spec = { x = 1 }, opts = { y = 2 } } },
        function() return { finished = true } end)
      _assert_eq(res.stay, true, "need_choice with open_choice non-nil → stay")
    end)
    _assert_eq(#open_choice_calls, 1, "open_choice invoked once")
    _assert_eq(open_choice_calls[1].opts.y, 2, "opts passed through")
  end)

  it("intent.kind='need_choice' but choice_spec nil → handler returns false → finish path", function()
    local finish_calls = 0
    _with_patches({
      { target = intent_output_port, key = "open_choice", value = function() return { id = "x" } end },
    }, function()
      choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "need_choice", choice_spec = nil } },
        function() finish_calls = finish_calls + 1; return {} end)
    end)
    -- need_choice handler returns false → _dispatch_intent returns false → still need_choice check below uses intent.kind
    -- Actually re-reading: _dispatch_intent returns false but flow then checks `if intent.kind == 'need_choice' then return stay`
    -- So even when dispatch returns false, if intent.kind == 'need_choice' the result is still stay.
    -- Wait, no — let me re-read:
    -- local function _dispatch_and_finish(game, result, finish_choice)
    --   if type(result) == "table" then
    --     local intent = result.intent or {}
    --     _dispatch_intent(game, intent)
    --     if intent.kind == "need_choice" then return { stay = true } end
    --   end
    --   return finish_choice(game, false)
    -- end
    -- So the `intent.kind == 'need_choice'` check is on the kind, regardless of dispatch result.
    -- This sub-case still returns stay even if open_choice was bypassed.
    -- finish_calls should still be 0.
    _assert_eq(finish_calls, 0, "need_choice kind → stay regardless of dispatch outcome")
  end)

  it("intent.kind='push_popup' + payload + push_popup=true → handler true; kind != need_choice → finish path", function()
    local push_calls = {}
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function(_, payload, opts)
        push_calls[#push_calls + 1] = { payload = payload, opts = opts }
        return true
      end },
    }, function()
      local finish_called = false
      choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = { msg = "hi" }, popup_opts = { p = 1 } } },
        function() finish_called = true; return {} end)
      _assert_eq(finish_called, true, "push_popup kind → finish_choice called (not stay)")
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
      choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = {}, opts = { a = 1 } } },
        function() return {} end)
    end)
    _assert_eq(opts_seen.a, 1, "L275: popup_opts or intent.opts fallback")
  end)

  it("intent.kind='push_popup' + payload=nil → handler false; finish_choice called", function()
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function() error("must NOT be called when payload nil") end },
    }, function()
      local finish_called = false
      choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = nil } },
        function() finish_called = true; return {} end)
      _assert_eq(finish_called, true, "nil payload → handler false → finish_choice")
    end)
  end)

  it("intent.kind='push_popup' + push_popup returns false → handler returns false (L275 ==true arm)", function()
    local push_called = false
    _with_patches({
      { target = intent_output_port, key = "push_popup", value = function() push_called = true; return false end },
    }, function()
      local finish_called = false
      choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
        { ok = true, intent = { kind = "push_popup", payload = { x = 1 } } },
        function() finish_called = true; return {} end)
      _assert_eq(push_called, true, "push_popup invoked even though result is false")
      _assert_eq(finish_called, true, "push returns false → handler false → still finish_choice")
    end)
  end)

  it("intent.kind unknown → _dispatch_intent returns false → finish_choice", function()
    local finish_called = false
    choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
      { ok = true, intent = { kind = "unknown_kind" } },
      function() finish_called = true; return {} end)
    _assert_eq(finish_called, true, "unknown intent kind → finish_choice")
  end)

  it("result.intent absent → intent={} → dispatch false → finish_choice", function()
    local finish_called = false
    choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
      { ok = true },  -- no intent
      function() finish_called = true; return {} end)
    _assert_eq(finish_called, true, "no intent → empty intent → finish_choice")
  end)

  it("result not a table → _dispatch_and_finish skips intent dispatch entirely → finish_choice", function()
    local finish_called = false
    choice.outcome.resolve_purchase({}, { kind = "other" }, _stub_player(1), nil,
      "not_a_table",  -- non-table result
      function() finish_called = true; return {} end)
    _assert_eq(finish_called, true, "L314 type check: non-table result → finish_choice directly")
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

describe("market.choice outcome.resolve_purchase L291 _should_keep_market_open `or → and`", function()
  -- Original: ok != true → return false (skip keep_open, take failure_stay path).
  -- Mutated `or → and`: requires BOTH (type != table AND ok != true). With ok=false table, `false AND true = false` →
  --   continues to deferred_fulfillment check → returns true → enters _handle_keep_open path.
  -- Observable diff: emit_inventory_full fires only via keep_open with full_buy=true (entry.kind="item" + fulfilled_now + inventory_full_after).
  -- With ok=false, original path bypasses keep_open → no emit; mutated path enters keep_open with full_buy=true → emit fires.

  it("ok=false + deferred + fulfilled + inventory_full_after=true: NO emit_inventory_full (kills L291 or→and)", function()
    local emitted
    local prev_emit = monopoly_event.emit
    monopoly_event.emit = function(_, payload) emitted = payload end
    package.loaded["src.rules.market.choice"] = nil
    local fresh = require("src.rules.market.choice")
    monopoly_event.emit = prev_emit
    package.loaded["src.rules.market.choice"] = nil
    require("src.rules.market.choice")

    local game = { dirty = { any = false } }
    local pc = { kind = "market_buy", owner_role_id = 1, active_tab = "item", page_index = 1, page_count = 1 }
    local result = {
      ok = false,
      deferred_fulfillment = true,
      fulfilled_now = true,
      inventory_full_after = true,
    }
    _with_patches(_patch_market_query(_make_entries(2)), function()
      fresh.outcome.resolve_purchase(game, pc, _stub_player(1),
        { kind = "item" }, result, function() return {} end)
    end)
    _assert_eq(emitted, nil,
      "ok=false MUST short-circuit keep_open at L291 disjunction; failure_stay path does not emit inventory_full")
  end)
end)

describe("market.choice _handle_keep_open L302 finish_choice(game, false) → nil", function()
  -- Original L302: `if not rebuilt then return finish_choice(game, false) end`.
  -- Mutated: `return nil`. finish_choice NOT called.
  -- Trigger keep_open path + invalid pending_choice kind → rebuild_pending guards return false → L302 fires.

  it("keep_open path + rebuild failure → finish_choice called once", function()
    local finish_calls = 0
    -- pending_choice kind != "market_buy" → rebuild_pending L177 guard returns false → L302 fires
    choice.outcome.resolve_purchase({}, { kind = "wrong_kind" }, _stub_player(1),
      { kind = "item" }, { ok = true, deferred_fulfillment = true },
      function() finish_calls = finish_calls + 1; return { finished = true } end)
    _assert_eq(finish_calls, 1,
      "L302: rebuild fail in keep_open path MUST call finish_choice exactly once (mutated `return nil` would yield 0)")
  end)

  it("keep_open path + rebuild failure → finish_choice receives (game, false) literals", function()
    local last_args
    choice.outcome.resolve_purchase({ id = "g-302" }, { kind = "wrong_kind" }, _stub_player(1),
      { kind = "item" }, { ok = true, deferred_fulfillment = true },
      function(g, finished_flag)
        last_args = { game = g, finished = finished_flag }
        return {}
      end)
    assert(last_args ~= nil, "finish_choice must have been invoked")
    _assert_eq(last_args.game.id, "g-302", "L302: finish_choice receives game arg")
    _assert_eq(last_args.finished, false, "L302: finish_choice receives literal `false` second arg")
  end)
end)
