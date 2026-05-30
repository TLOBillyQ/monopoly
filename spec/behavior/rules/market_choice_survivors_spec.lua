local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local choice = require("src.rules.market.choice")
local market_query = require("src.rules.market.query")
local monopoly_event = require("src.foundation.events")
local dirty_tracker = require("src.state.dirty_tracker")

local function _stub_player(id)
  return { id = id, name = "player_" .. tostring(id) }
end

local function _patch_market_query(entries, opts)
  opts = opts or {}
  return {
    { target = market_query.eligibility, key = "sorted_entries", value = function() return entries end },
    { target = market_query.eligibility, key = "can_buy_entry", value = opts.can_buy or function() return true end },
    { target = market_query.eligibility, key = "is_sold_out", value = opts.is_sold_out or function() return false end },
    { target = market_query.context, key = "entry_market_enabled", value = function() return true end },
    { target = market_query.context, key = "entry_name", value = function(entry) return entry.name end },
    { target = market_query.context, key = "entry_price", value = function(entry) return entry.price end },
    { target = market_query.context, key = "entry_currency", value = function(entry) return entry.currency end },
    { target = dirty_tracker, key = "mark", value = function() end },
  }
end

local function _entry(product_id, name, price, currency)
  return {
    product_id = product_id, name = name, price = price, currency = currency,
    kind = "item", market_enabled = true,
  }
end

local function _make_entries(n)
  local list = {}
  for i = 1, n do
    list[i] = _entry("p" .. i, "name_" .. i, 100 + i, "金币")
  end
  return list
end

describe("market.choice builder.build title literal L124 '黑市'", function()
  it("spec.title is exactly '黑市'", function()
    _with_patches(_patch_market_query({}), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.title, "黑市", "spec.title must be the literal '黑市'")
    end)
  end)
end)

describe("market.choice feedback.emit_buy_failed popup_title literal L16 '黑市'", function()
  it("emit_buy_failed payload.popup.title is exactly '黑市'", function()
    -- choice captures monopoly_event.emit as upvalue at module load (L14).
    -- Stub emit, reload choice so the upvalue points at the stub, then restore.
    local captured
    local prev_emit = monopoly_event.emit
    monopoly_event.emit = function(_, payload) captured = payload end
    package.loaded["src.rules.market.choice"] = nil
    local fresh_choice = require("src.rules.market.choice")
    monopoly_event.emit = prev_emit
    -- Need to ALSO reload the cached top-level `choice` so other describes here still hit the original
    -- emit reference path. fresh_choice has the stub baked in; we use it just for this case.
    package.loaded["src.rules.market.choice"] = nil
    require("src.rules.market.choice")  -- restore the original-emit copy for subsequent specs

    fresh_choice.feedback.emit_buy_failed(_stub_player(1), { product_id = "p1" }, "no_funds", "现金不足")

    assert(captured ~= nil, "emit must be invoked through reloaded upvalue")
    _assert_eq(captured.popup.title, "黑市", "popup.title must be literal '黑市'")
    _assert_eq(captured.popup.body, "现金不足", "popup.body must pass through from arg")
    _assert_eq(captured.reason, "no_funds", "reason must pass through")
  end)
end)

describe("market.choice _resolve_page_count integer boundaries (L102-107)", function()
  it("zero entries → page_count == 1 (L107 total<=0 boundary)", function()
    _with_patches(_patch_market_query({}), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.page_count, 1, "0 entries must yield page_count=1")
    end)
  end)

  it("exactly PAGE_SIZE (10) entries → page_count == 1 (boundary)", function()
    _with_patches(_patch_market_query(_make_entries(10)), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.page_count, 1, "10 entries must yield page_count=1 (floor((10+9)/10))")
    end)
  end)

  it("PAGE_SIZE+1 (11) entries → page_count == 2 (boundary just above)", function()
    _with_patches(_patch_market_query(_make_entries(11)), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.page_count, 2, "11 entries must yield page_count=2")
    end)
  end)

  it("25 entries → page_count == 3", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.page_count, 3, "25 entries must yield page_count=3")
    end)
  end)
end)

describe("market.choice _clamp_page integer boundaries (L46-53)", function()
  it("page_index nil → defaults to 1 (L47 'or 1' fallback)", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = nil })
      _assert_eq(spec.page_index, 1, "nil page_index must default to 1")
    end)
  end)

  it("page_index 0 → clamped up to 1 (lower bound)", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = 0 })
      _assert_eq(spec.page_index, 1, "page_index 0 must clamp to 1")
    end)
  end)

  it("page_index way over count → clamped down to count (upper bound)", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = 99 })
      _assert_eq(spec.page_index, 3, "page_index 99 must clamp to page_count=3")
    end)
  end)
end)

describe("market.choice _build_options_for_page index arithmetic (L75-77/L80-83)", function()
  it("page 1: options reflect entries 1..10 in order", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = 1 })
      _assert_eq(#spec.options, 10, "page 1 must have 10 options")
      _assert_eq(spec.options[1].id, "p1", "first option must be entry 1")
      _assert_eq(spec.options[10].id, "p10", "last option must be entry 10")
    end)
  end)

  it("page 2: options reflect entries 11..20 (start_index = (2-1)*10+1 = 11)", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = 2 })
      _assert_eq(#spec.options, 10, "page 2 must have 10 options")
      _assert_eq(spec.options[1].id, "p11", "page 2 first option must be entry 11")
      _assert_eq(spec.options[10].id, "p20", "page 2 last option must be entry 20")
    end)
  end)

  it("page 3 partial: options reflect entries 21..25 (last_index clipped by slot==nil break)", function()
    _with_patches(_patch_market_query(_make_entries(25)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = 3 })
      _assert_eq(#spec.options, 5, "page 3 must have 5 options (partial)")
      _assert_eq(spec.options[1].id, "p21", "page 3 first option must be entry 21")
      _assert_eq(spec.options[5].id, "p25", "page 3 last option must be entry 25")
    end)
  end)

  it("body_lines parallel to options in same order", function()
    _with_patches(_patch_market_query(_make_entries(3)), function()
      local spec = choice.builder.build(_stub_player(1), {}, { page_index = 1 })
      _assert_eq(#spec.body_lines, 3, "body_lines length must equal options length")
      assert(spec.body_lines[1] == spec.options[1].label, "body_lines[1] must equal options[1].label")
      assert(spec.body_lines[3] == spec.options[3].label, "body_lines[3] must equal options[3].label")
    end)
  end)
end)

describe("market.choice _build_options_for_page label format (L87-89)", function()
  it("label exactly 'name - <int> currency' (separator literals pinned)", function()
    local entries = { _entry("p_label_1", "苹果", 250, "金豆") }
    _with_patches(_patch_market_query(entries), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.options[1].label, "苹果 - 250 金豆",
        "label must match exact format 'name - price currency'")
      _assert_eq(spec.body_lines[1], "苹果 - 250 金豆", "body_lines also match")
    end)
  end)

  it("entry currency surfaces verbatim into label", function()
    local entries = { _entry("p2", "面包", 99, "现金") }
    _with_patches(_patch_market_query(entries), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.options[1].label, "面包 - 99 现金", "alternate currency must surface")
    end)
  end)
end)

describe("market.choice _build_tab_entries can_buy + sold_out propagation (L60-69)", function()
  it("can_buy true entries listed as options with can_buy=true", function()
    local entries = _make_entries(2)
    _with_patches(_patch_market_query(entries, {
      can_buy = function(_, _, entry) return entry.product_id == "p1" end,
      is_sold_out = function() return false end,
    }), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(#spec.options, 2, "both entries appear as options")
      _assert_eq(spec.options[1].can_buy, true, "p1 can_buy=true")
      _assert_eq(spec.options[2].can_buy, false, "p2 can_buy=false")
    end)
  end)

  it("sold_out flag propagates to option.sold_out", function()
    local entries = _make_entries(2)
    _with_patches(_patch_market_query(entries, {
      can_buy = function() return true end,
      is_sold_out = function(_, entry) return entry.product_id == "p2" end,
    }), function()
      local spec = choice.builder.build(_stub_player(1), {}, {})
      _assert_eq(spec.options[1].sold_out, false, "p1 sold_out=false")
      _assert_eq(spec.options[2].sold_out, true, "p2 sold_out=true")
    end)
  end)
end)

describe("market.choice session.apply_navigation rejects (L194-220 warn paths)", function()
  it("nil game → false", function()
    _assert_eq(choice.session.apply_navigation(nil, { kind = "market_buy" }, { type = "market_tab_select", tab = "item" }), false,
      "nil game must yield false")
  end)

  it("nil pending_choice → false", function()
    _assert_eq(choice.session.apply_navigation({}, nil, { type = "market_tab_select", tab = "item" }), false,
      "nil pending_choice must yield false")
  end)

  it("wrong kind → false", function()
    _assert_eq(choice.session.apply_navigation({}, { kind = "other_choice" }, { type = "market_tab_select", tab = "item" }), false,
      "non-market_buy kind must yield false")
  end)
end)

describe("market.choice _apply_navigation_action returns (L194-205)", function()
  -- Drive via session.apply_navigation with stubbed builder so we can observe page_index/active_tab moves.
  local function _drive(action, initial)
    local result_spec
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false, turn = false, market = false },
      turn = {},
    }
    local pending_choice = {
      kind = "market_buy",
      owner_role_id = 1,
      active_tab = initial.tab,
      page_index = initial.page_index,
      page_count = initial.page_count,
    }
    _with_patches(_patch_market_query(_make_entries(initial.entries or 25)), function()
      local applied = choice.session.apply_navigation(game, pending_choice, action)
      result_spec = applied and pending_choice or nil
    end)
    return result_spec
  end

  it("market_page_next: page_index increments", function()
    local pc = _drive({ type = "market_page_next" },
      { tab = "item", page_index = 1, page_count = 3, entries = 25 })
    _assert_eq(pc.page_index, 2, "page_next from 1 must move to 2")
  end)

  it("market_page_prev: page_index decrements (clamped at 1)", function()
    local pc = _drive({ type = "market_page_prev" },
      { tab = "item", page_index = 2, page_count = 3, entries = 25 })
    _assert_eq(pc.page_index, 1, "page_prev from 2 must move to 1")
  end)

  it("market_page_prev from 1: clamps to 1 (clamp lower)", function()
    local pc = _drive({ type = "market_page_prev" },
      { tab = "item", page_index = 1, page_count = 3, entries = 25 })
    _assert_eq(pc.page_index, 1, "page_prev from 1 must clamp at 1")
  end)

  it("market_tab_select same tab: returns true with unchanged=true (no rebuild)", function()
    local pc = _drive({ type = "market_tab_select", tab = "item" },
      { tab = "item", page_index = 2, page_count = 3, entries = 25 })
    -- unchanged path returns true early without rebuild → pending_choice page_index stays 2
    _assert_eq(pc.page_index, 2, "tab_select with same tab must leave page_index untouched (unchanged early return)")
    _assert_eq(pc.active_tab, "item", "active_tab stays")
  end)

  it("unknown action type: page_index and active_tab unchanged via builder rebuild", function()
    local pc = _drive({ type = "unknown_action" },
      { tab = "item", page_index = 2, page_count = 3, entries = 25 })
    -- _apply_navigation_action default branch returns (active_tab, page_index, false) → triggers rebuild with same coords
    _assert_eq(pc.page_index, 2, "unknown action must preserve page_index through rebuild")
    _assert_eq(pc.active_tab, "item", "unknown action must preserve active_tab through rebuild")
  end)
end)

describe("market.choice _build_tab_entries L59-60 `and` combinator (kills `and→or`)", function()
  -- Goal: differentiate `kind == active_tab AND market_enabled` from `kind == active_tab OR market_enabled`.
  -- Strategy: mixed entries where some have wrong kind but enabled=true, others have right kind but enabled=false.

  it("entry with wrong kind but market_enabled=true is EXCLUDED (kind-mismatch arm of AND)", function()
    local entries = {
      { product_id = "right_kind",  name = "rk",  price = 100, currency = "金币", kind = "item",  market_enabled = true },
      { product_id = "wrong_kind",  name = "wk",  price = 200, currency = "金币", kind = "vehicle", market_enabled = true },
    }
    _with_patches({
      { target = market_query.eligibility, key = "sorted_entries",     value = function() return entries end },
      { target = market_query.eligibility, key = "can_buy_entry",      value = function() return true end },
      { target = market_query.eligibility, key = "is_sold_out",        value = function() return false end },
      -- entry_market_enabled returns true for BOTH — so mutation `and→or` would let wrong_kind slip through.
      { target = market_query.context,     key = "entry_market_enabled", value = function() return true end },
      { target = market_query.context,     key = "entry_name",          value = function(e) return e.name end },
      { target = market_query.context,     key = "entry_price",         value = function(e) return e.price end },
      { target = market_query.context,     key = "entry_currency",      value = function(e) return e.currency end },
      { target = dirty_tracker, key = "mark", value = function() end },
    }, function()
      local spec = choice.builder.build(_stub_player(1), {}, { active_tab = "item" })
      _assert_eq(#spec.options, 1, "L60 `and`: only kind=='item' AND enabled must surface (would be 2 under `or`)")
      _assert_eq(spec.options[1].id, "right_kind",
        "L59-60 conjunction must drop kind!=active_tab even when market_enabled=true")
    end)
  end)

  it("entry with kind match but market_enabled=false is EXCLUDED (enabled-arm of AND)", function()
    local entries = {
      { product_id = "right_kind_on",  name = "rkn", price = 100, currency = "金币", kind = "item", market_enabled = true },
      { product_id = "right_kind_off", name = "rko", price = 200, currency = "金币", kind = "item", market_enabled = false },
    }
    _with_patches({
      { target = market_query.eligibility, key = "sorted_entries",     value = function() return entries end },
      { target = market_query.eligibility, key = "can_buy_entry",      value = function() return true end },
      { target = market_query.eligibility, key = "is_sold_out",        value = function() return false end },
      -- per-entry market_enabled echoes flag → `and` keeps only the on row, `or` would keep both via kind match.
      { target = market_query.context,     key = "entry_market_enabled", value = function(e) return e.market_enabled end },
      { target = market_query.context,     key = "entry_name",          value = function(e) return e.name end },
      { target = market_query.context,     key = "entry_price",         value = function(e) return e.price end },
      { target = market_query.context,     key = "entry_currency",      value = function(e) return e.currency end },
      { target = dirty_tracker, key = "mark", value = function() end },
    }, function()
      local spec = choice.builder.build(_stub_player(1), {}, { active_tab = "item" })
      _assert_eq(#spec.options, 1, "L60 `and`: enabled=false must drop entry even when kind matches")
      _assert_eq(spec.options[1].id, "right_kind_on",
        "L60 conjunction must require market_enabled=true on the entry surface")
    end)
  end)
end)

describe("market.choice _apply_navigation_action L197 unchanged flag (kills `true→false`)", function()
  -- Strategy: original `unchanged=true` short-circuits without rebuild → no _mark_choice_dirty.
  -- Mutated `unchanged=false` falls through to rebuild → _apply_spec → _mark_choice_dirty fires.
  -- Observe via dirty_tracker.mark call count.

  it("same-tab market_tab_select must NOT trigger rebuild → 0 dirty_tracker.mark calls", function()
    local mark_calls = {}
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false, turn = false, market = false },
      turn = {},
    }
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = "item", page_index = 2, page_count = 3,
    }
    _with_patches({
      { target = market_query.eligibility, key = "sorted_entries",     value = function() return _make_entries(25) end },
      { target = market_query.eligibility, key = "can_buy_entry",      value = function() return true end },
      { target = market_query.eligibility, key = "is_sold_out",        value = function() return false end },
      { target = market_query.context,     key = "entry_market_enabled", value = function() return true end },
      { target = market_query.context,     key = "entry_name",          value = function(e) return e.name end },
      { target = market_query.context,     key = "entry_price",         value = function(e) return e.price end },
      { target = market_query.context,     key = "entry_currency",      value = function(e) return e.currency end },
      { target = dirty_tracker, key = "mark", value = function(_, domain)
        mark_calls[#mark_calls + 1] = domain
      end },
    }, function()
      choice.session.apply_navigation(game, pc, { type = "market_tab_select", tab = "item" })
    end)
    _assert_eq(#mark_calls, 0,
      "L197 unchanged=true: same-tab early return MUST skip rebuild → 0 dirty marks " ..
      "(mutated unchanged=false → rebuild → dirty marks)")
  end)
end)

describe("market.choice _apply_navigation_action L203 (kills `1→0` in nil-page page_next)", function()
  -- Strategy: pending_choice.page_index=nil triggers the `or 1` fallback at L203.
  -- Original `... + 1` with nil page → 1+1=2. Mutated `... + 0` (1→0) → 1+0=1.
  -- With page_count >= 2, clamp yields different observable values.

  it("nil pending_choice.page_index + market_page_next + 25 entries → page_index lands on 2", function()
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false, turn = false, market = false },
      turn = {},
    }
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = "item",
      page_index = nil,  -- crucial: triggers `or 1` fallback
      page_count = 3,
    }
    _with_patches(_patch_market_query(_make_entries(25)), function()
      choice.session.apply_navigation(game, pc, { type = "market_page_next" })
    end)
    _assert_eq(pc.page_index, 2,
      "L203: nil page + 1 must = 2 (mutated +0 would yield 1)")
  end)
end)

describe("market.choice _apply_navigation_action L205 (kills `false→true` default unchanged)", function()
  -- Strategy: unknown action returns (active_tab, page_index, false) → rebuild → clamps page_index.
  -- Mutated `unchanged=true` skips rebuild → out-of-bounds page_index stays unclamped.
  -- Observe via out-of-bounds page_index passing through rebuild's clamp.

  it("unknown action + out-of-bounds page_index → rebuild clamps; mutated would skip clamp", function()
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false, turn = false, market = false },
      turn = {},
    }
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = "item",
      page_index = 99,  -- out of bounds → rebuild's _clamp_page would clamp to page_count (3)
      page_count = 3,
    }
    _with_patches(_patch_market_query(_make_entries(25)), function()
      choice.session.apply_navigation(game, pc, { type = "totally_unknown_action_type" })
    end)
    _assert_eq(pc.page_index, 3,
      "L205 unchanged=false: rebuild runs → clamp 99 → 3. Mutated unchanged=true would stay 99")
  end)
end)

describe("market.choice _apply_navigation_action page_index arithmetic sharpening (kills L201/L203 sign mutations)", function()
  -- These tests use a dedicated local driver so we can pin pre-rebuild page_index movement.
  local function _drive_nav(action, initial)
    local game = {
      find_player_by_id = function() return _stub_player(1) end,
      dirty = { any = false, turn = false, market = false },
      turn = {},
    }
    local pc = {
      kind = "market_buy", owner_role_id = 1,
      active_tab = initial.tab,
      page_index = initial.page_index,
      page_count = initial.page_count,
    }
    _with_patches(_patch_market_query(_make_entries(initial.entries or 25)), function()
      choice.session.apply_navigation(game, pc, action)
    end)
    return pc
  end

  it("market_page_next from page 2 → page 3 (kills L203 `+1 → -1` and `+1 → +0`)", function()
    local pc = _drive_nav({ type = "market_page_next" },
      { tab = "item", page_index = 2, page_count = 3, entries = 25 })
    _assert_eq(pc.page_index, 3, "L203 page_next from 2 must land on 3 (-1 would yield 1, +0 would yield 2)")
  end)

  it("market_page_prev from page 3 → page 2 (kills L201 `-1 → +1` and `-1 → -0`)", function()
    local pc = _drive_nav({ type = "market_page_prev" },
      { tab = "item", page_index = 3, page_count = 3, entries = 25 })
    _assert_eq(pc.page_index, 2, "L201 page_prev from 3 must land on 2 (+1 would clamp to 3, -0 would stay 3)")
  end)

  it("market_tab_select different tab from page 3 → page_index reset to 1 (L199 literal '1')", function()
    local pc = _drive_nav({ type = "market_tab_select", tab = "different_tab" },
      { tab = "item", page_index = 3, page_count = 3, entries = 25 })
    -- Even though TAB_ITEM is the only tab and builder normalizes back, the L199 literal 1 drives
    -- the page_index reset before rebuild. With 25 entries, page_count=3, builder uses page_index=1.
    _assert_eq(pc.page_index, 1, "L199: tab change MUST reset page_index to literal 1 (kills 1→2 / 1→0)")
  end)
end)
