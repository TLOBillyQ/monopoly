local support = require("spec.support.shared_support")
local _new_game = support.new_game
local market_cfg = require("src.config.content.market")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local choice_resolver = require("src.rules.choice.resolver")
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")

local function _contains_product(list, product_id)
  for _, entry in ipairs(list) do
    if entry.product_id == product_id then
      return true
    end
  end
  return false
end

local function _contains_option(options, product_id)
  for _, option in ipairs(options) do
    if option.id == product_id then
      return true
    end
  end
  return false
end

local function _find_option(options, product_id)
  for _, option in ipairs(options or {}) do
    if option.id == product_id then
      return option
    end
  end
  return nil
end

local function _find_paid_item_entry()
  for _, entry in ipairs(market_cfg) do
    if entry.kind == "item" and (entry.currency == "金豆" or entry.currency == "乐园币") and entry.market_enabled ~= false then
      return entry
    end
  end
  return nil
end

local function _new_four_player_game()
  return _new_game({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
  })
end

local function _reload_market_service()
  package.loaded["src.rules.market"] = nil
  package.loaded["src.rules.market.query"] = nil
  package.loaded["src.rules.market.purchase"] = nil
  package.loaded["src.rules.market.auto"] = nil
  package.loaded["src.rules.market.choice"] = nil
  return require("src.rules.market")
end

local function _reset_market_choice_runtime_modules()
  package.loaded["src.rules.market.choice_handlers"] = nil
  package.loaded["src.player.choices.registry"] = nil
  package.loaded["src.player.choices.resolver"] = nil
end

local function _with_paid_gateway(can_start_fn, fn)
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure({
    setup_for_game = function() end,
    can_start = can_start_fn,
    start = function()
      return true
    end,
  })
  local ok, err = pcall(fn)
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  if not ok then
    error(err)
  end
end

describe("market", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("auto_execute_empty_list_no_purchase", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    -- Set player to have no cash so no items are available
    g:set_player_cash(p, 0)

    local before_cash = p.cash
    market_service.auto.execute(g, p)

    assert(p.cash == before_cash, "should not spend money when no items available")
  end)

  it("auto_execute_purchases_first_available_item", function()
    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()

    -- Give player enough cash to buy items
    g:set_player_cash(p, 999999)

    local list = market_service.query.list_available(p, g)
    if #list == 0 then
      return -- skip if no items available
    end

    local before_cash = p.cash

    market_service.auto.execute(g, p)

    -- Should have purchased the cheapest item
    assert(p.cash < before_cash, "should have purchased an item")
  end)

  it("market_global_limit", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()
    local entry = nil
    for _, cfg in ipairs(market_cfg) do
      if cfg.kind == "item" and cfg.currency == "金币" then
        entry = cfg
        break
      end
    end
    assert(entry, "should find a market item with coin currency")
    g:set_player_cash(p, (entry.price or 0) + 1000)
    g.market_limits[entry.product_id] = 1

    local res = market_service.purchase.execute(g, p, entry.product_id)
    local ok = (type(res) == "table" and type(res.ok) ~= "nil") and res.ok or res
    assert(ok, "first purchase should succeed")

    local list = market_service.query.list_available(p, g)
    for _, item in ipairs(list) do
      assert(item.product_id ~= entry.product_id, "sold out item should be excluded from list")
    end

    local spec = market_service.choice.build(p, g)
    if spec and spec.options then
      local found = false
      for _, option in ipairs(spec.options) do
        if option.id == entry.product_id then
          found = true
          assert(option.can_buy == false, "sold out item should remain visible but not buyable in choice")
          assert(option.sold_out == true, "sold out item should have sold_out = true in choice option")
        end
      end
      assert(found == true, "sold out item should remain visible in choice for explicit feedback")
    end
  end)

  it("market_choice_sold_out_flag_false_when_in_stock", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()
    local entry = nil
    for _, cfg in ipairs(market_cfg) do
      if cfg.kind == "item" and cfg.currency == "金币" then
        entry = cfg
        break
      end
    end
    assert(entry, "should find a market item with coin currency")
    g:set_player_cash(p, (entry.price or 0) + 1000)
    g.market_limits[entry.product_id] = 2

    local spec = market_service.choice.build(p, g)
    if spec and spec.options then
      for _, option in ipairs(spec.options) do
        if option.id == entry.product_id then
          assert(option.sold_out == false, "in-stock item should have sold_out = false")
        end
      end
    end
  end)

  it("market_disabled_products_hidden", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    local blocked_product_ids = {}
    for _, entry in ipairs(market_cfg) do
      if entry.market_enabled == false then
        blocked_product_ids[#blocked_product_ids + 1] = entry.product_id
      end
    end
    if #blocked_product_ids == 0 then
      return
    end

    local list = market_service.query.list_available(p, g)
    for _, product_id in ipairs(blocked_product_ids) do
      assert(not _contains_product(list, product_id), "disabled product should be hidden: " .. tostring(product_id))
    end

    local spec = market_service.choice.build(p, g)
    if spec and spec.options then
      for _, product_id in ipairs(blocked_product_ids) do
        assert(not _contains_option(spec.options, product_id), "disabled option should be hidden: " .. tostring(product_id))
      end
    end
  end)

  it("buy_disabled_market_product_rejected", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    local blocked_product_id = nil
    for _, entry in ipairs(market_cfg) do
      if entry.market_enabled == false then
        blocked_product_id = entry.product_id
        break
      end
    end
    if blocked_product_id == nil then
      return
    end

    local res = market_service.purchase.execute(g, p, blocked_product_id)
    assert(type(res) == "table" and res.ok == false, "disabled market product should be rejected")
  end)

  it("market_catalog_contains_items_only", function()
    for _, entry in ipairs(market_cfg) do
      assert(entry.kind == "item", "black market should only expose item entries")
    end
  end)

  it("market_query_rejects_non_item_entries", function()
    local market_query = require("src.rules.market.query")
    local game = {
      market_limits = { [5001] = 1 },
      player_balance = function()
        return 999999
      end,
    }
    local player = { id = 1, name = "P1" }
    local skin_entry = { product_id = 5001, kind = "skin", currency = "金币", price = 1 }

    assert(market_query.eligibility.can_buy_entry(game, player, skin_entry) == false,
      "black market should reject non-item entries before they become purchase options")
  end)

  it("market_query_context_defaults_and_limit_consumption_are_explicit", function()
    local market_query = require("src.rules.market.query")
    local context = market_query.context

    assert(context.entry_name({ product_id = 999999 }) == "999999",
      "entry_name should fall back to product_id text")
    assert(context.entry_price({ product_id = 1 }) == 0,
      "missing price should default to zero")
    assert(context.entry_price({ product_id = 1, price = 7 }) == 7,
      "entry_price should keep explicit price")
    assert(context.entry_currency({ product_id = 1 }) == "金币",
      "missing currency should default to coin")
    assert(context.entry_currency({ product_id = 1, currency = "" }) == "金币",
      "empty currency should default to coin")
    assert(context.entry_currency({ product_id = 1, currency = "金豆" }) == "金豆",
      "entry_currency should keep explicit currency")
    assert(context.entry_market_enabled({ product_id = 1 }) == true,
      "entries should be market-enabled by default")
    assert(context.entry_market_enabled({ product_id = 1, market_enabled = false }) == false,
      "market_enabled=false should disable an entry")

    local game = { market_limits = { [2001] = 2, [2002] = 0 }, dirty = {} }
    context.consume_global_limit(game, 2001)
    assert(game.market_limits[2001] == 1, "global limit should decrement while above zero")
    assert(game.dirty.market == true, "global limit consumption should mark market dirty")

    context.consume_global_limit(game, 2002)
    assert(game.market_limits[2002] == 0, "global limit should clamp at zero")
    assert(market_query.eligibility.is_sold_out(game, { product_id = 2002 }) == true,
      "zero remaining limit should be sold out")
    assert(market_query.eligibility.is_sold_out(game, { product_id = 2001 }) == false,
      "positive remaining limit should not be sold out")
  end)

  it("market_query_can_buy_entry_respects_boundaries", function()
    local market_query = require("src.rules.market.query")
    local entry = { product_id = 2001, kind = "item", currency = "金币", price = 5 }
    local g = _new_game()
    local p = g:current_player()
    g.market_limits[entry.product_id] = 1
    g:set_player_cash(p, 5)

    assert(market_query.eligibility.can_buy_entry(g, p, entry) == true,
      "exact balance and one remaining item should be buyable")

    entry.market_enabled = false
    assert(market_query.eligibility.can_buy_entry(g, p, entry) == false,
      "disabled entries should not be buyable")
    entry.market_enabled = nil

    for _ = 1, 5 do
      p.inventory:add({ id = 2001 })
    end
    assert(market_query.eligibility.can_buy_entry(g, p, entry) == false,
      "full inventory should block market item purchases")

    local paid_entry = { product_id = 2002, kind = "item", currency = "金豆", price = 5 }
    local paid_game = _new_game()
    local paid_player = paid_game:current_player()
    paid_game.market_limits[paid_entry.product_id] = 1
    _with_paid_gateway(function(_, _, candidate)
      return candidate.product_id == paid_entry.product_id
    end, function()
      assert(market_query.eligibility.can_buy_entry(paid_game, paid_player, paid_entry) == true,
        "paid entries should be buyable only when the paid gateway can start")
    end)
    _with_paid_gateway(function()
      return false
    end, function()
      assert(market_query.eligibility.can_buy_entry(paid_game, paid_player, paid_entry) == false,
        "paid entries should be blocked when the paid gateway cannot start")
    end)
  end)

  it("market_query_split_entries_by_buyable_partitions_entries", function()
    local eligibility = require("src.rules.market.query").eligibility
    local buyable_entry = { product_id = 1, kind = "item" }
    local unbuyable_entry = { product_id = 2, kind = "item" }
    local original_sorted_entries = eligibility.sorted_entries
    local original_can_buy_entry = eligibility.can_buy_entry

    eligibility.sorted_entries = function()
      return { buyable_entry, unbuyable_entry }
    end
    eligibility.can_buy_entry = function(_, _, entry)
      return entry.product_id == 1
    end

    local ok, buyable, unbuyable = pcall(function()
      local b, u = eligibility._split_entries_by_buyable({}, {})
      return b, u
    end)
    eligibility.sorted_entries = original_sorted_entries
    eligibility.can_buy_entry = original_can_buy_entry
    assert(ok == true, "split_entries_by_buyable should not fail")
    assert(#buyable == 1 and buyable[1] == buyable_entry,
      "split_entries_by_buyable should keep buyable entries")
    assert(#unbuyable == 1 and unbuyable[1] == unbuyable_entry,
      "split_entries_by_buyable should keep unbuyable entries")
  end)

  it("market_skin_tab_input_normalizes_to_item", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    local spec = market_service.choice.build(p, g, { active_tab = "skin" })
    assert(type(spec) == "table" and spec.kind == "market_buy", "market choice should still build")
    assert(spec.active_tab == "item", "old skin tab input should normalize to item")
    assert(spec.meta.active_tab == "item", "market meta should normalize old skin tab to item")
    assert(type(spec.options) == "table" and #spec.options > 0, "item tab should expose item options")
  end)

  it("market_tab_select_skin_keeps_item_tab", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()
    local spec = market_service.choice.build(p, g, { active_tab = "item" })
    assert(type(spec) == "table" and spec.kind == "market_buy", "initial market choice should be built")

    local pending_choice = {
      id = 999,
      kind = spec.kind,
      owner_role_id = spec.owner_role_id,
      title = spec.title,
      body_lines = spec.body_lines,
      options = spec.options,
      allow_cancel = spec.allow_cancel,
      cancel_label = spec.cancel_label,
      active_tab = spec.active_tab,
      page_index = spec.page_index,
      page_count = spec.page_count,
      meta = spec.meta,
    }

    local applied = market_service.choice.apply_navigation(g, pending_choice, {
      type = "market_tab_select",
      tab = "skin",
    })

    assert(applied == true, "market_tab_select should apply on unbuyable skin tab")
    assert(pending_choice.active_tab == "item", "navigation should normalize skin tab to item")
    assert(type(pending_choice.options) == "table" and #pending_choice.options > 0,
      "navigation should keep visible item options")
  end)

  it("market_choice_build_is_pure_and_session_marks_dirty", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    g.dirty.any = false
    g.dirty.turn = false
    local spec = market_service.choice.build(p, g, { active_tab = "item" })
    assert(type(spec) == "table" and spec.kind == "market_buy", "build should return market choice spec")
    assert(g.dirty.any == false and g.dirty.turn == false, "build should stay pure and not mark dirty")

    local pending_choice = {
      id = 1000,
      kind = spec.kind,
      owner_role_id = spec.owner_role_id,
      title = spec.title,
      body_lines = spec.body_lines,
      options = spec.options,
      allow_cancel = spec.allow_cancel,
      cancel_label = spec.cancel_label,
      active_tab = spec.active_tab,
      page_index = spec.page_index,
      page_count = spec.page_count,
      meta = spec.meta,
    }

    local rebuilt = market_service.choice.rebuild_pending(g, pending_choice, p, { active_tab = "skin", page_index = 1 })
    assert(rebuilt == true, "session should rebuild pending choice")
    assert(pending_choice.active_tab == "item", "session rebuild should normalize requested skin tab")
    assert(g.dirty.any == true and g.dirty.turn == true, "session rebuild should mark choice dirty")
  end)

  it("market_buy_failed_keeps_market_choice_open", function()
    local g = _new_game()
    local p = g:current_player()
    local choice = {
      id = 808,
      kind = "market_buy",
      route_key = "market",
      owner_role_id = p.id,
      options = { { id = 2001, label = "测试商品" } },
      meta = { player_id = p.id },
    }
    g.turn.pending_choice = choice

    local result = nil
    support.with_patches({
      {
        target = require("src.rules.market").purchase,
        key = "execute",
        value = function()
          return { ok = false }
        end,
      },
    }, function()
      result = choice_resolver.resolve(g, choice, {
        type = "choice_select",
        choice_id = choice.id,
        option_id = 2001,
        actor_role_id = p.id,
      })
    end)

    assert(result and result.stay == true, "market buy failed should keep waiting")
    assert(result and result.status == "waiting", "market buy failed should report waiting status")
    assert(g.turn.pending_choice ~= nil and g.turn.pending_choice.kind == "market_buy",
      "market buy failed should keep pending market choice")
  end)

  it("market_sold_out_buy_failed_keeps_choice_open_and_refreshes_sold_out_flag", function()
    _reset_market_choice_runtime_modules()
    local market_service = _reload_market_service()
    local g = _new_four_player_game()
    test_profile_bootstrap.apply(g, "market_sold_out")
    local p = g:current_player()
    local choice = market_service.choice.build(p, g, { active_tab = "item", page_index = 1 })
    choice.id = 812
    g.turn.pending_choice = choice

    local before_limit = g.market_limits[2003]
    local result = choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 2003,
      actor_role_id = p.id,
    })

    assert(result and result.stay == true, "sold out purchase should keep market choice open")
    assert(result and result.status == "waiting", "sold out purchase should keep waiting status")
    assert(g.turn.pending_choice ~= nil and g.turn.pending_choice.kind == "market_buy",
      "sold out purchase should keep pending market choice")
    local option = _find_option(g.turn.pending_choice and g.turn.pending_choice.options, 2003)
    assert(option ~= nil, "sold out option should remain visible after failed purchase")
    assert(option.can_buy == false, "sold out option should stay unbuyable after failed purchase")
    assert(option.sold_out == true, "sold out option should stay flagged after failed purchase")
    assert(g.market_limits[2003] == before_limit, "sold out failed purchase should not consume limit")
  end)

  it("market_item_buy_keeps_choice_open_until_inventory_full", function()
    _reset_market_choice_runtime_modules()
    _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 999999)
    local choice = {
      id = 809,
      kind = "market_buy",
      route_key = "market",
      owner_role_id = p.id,
      options = { { id = 2003, label = "测试商品" } },
      active_tab = "item",
      page_index = 1,
      page_count = 1,
      meta = { player_id = p.id, active_tab = "item", page_index = 1, page_count = 1 },
    }
    g.turn.pending_choice = choice

    local result = choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 2003,
      actor_role_id = p.id,
    })

    assert(result and result.stay == true, "successful item purchase should keep market choice open")
    assert(g.turn.pending_choice ~= nil and g.turn.pending_choice.kind == "market_buy",
      "pending market choice should remain")
  end)

  it("market_item_buy_suppresses_cash_receive_action_anim", function()
    _reset_market_choice_runtime_modules()
    _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 999999)
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    local choice = {
      id = 810,
      kind = "market_buy",
      route_key = "market",
      owner_role_id = p.id,
      options = { { id = 2003, label = "测试商品" } },
      active_tab = "item",
      page_index = 1,
      page_count = 1,
      meta = { player_id = p.id, active_tab = "item", page_index = 1, page_count = 1 },
    }
    g.turn.pending_choice = choice

    choice_resolver.resolve(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 2003,
      actor_role_id = p.id,
    })

    local anim = g.turn.action_anim
    local queue = g.turn.action_anim_queue or {}
    local has_cash_receive = anim and anim.kind == "cash_receive"
    for _, queued in ipairs(queue) do
      if queued.kind == "cash_receive" then
        has_cash_receive = true
      end
    end
    assert(not has_cash_receive,
      "market item purchase should suppress cash_receive action anim for immediate effect")
  end)

  it("market_paid_buy_keeps_choice_open_and_refreshes_after_callback", function()
    _reset_market_choice_runtime_modules()
    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    local target = assert(_find_paid_item_entry(), "test requires paid item market entry")
    g.market_limits[target.product_id] = 1

    local panel_calls = {}
    local purchase_handlers = {}
    local role = {
      get_roleid = function()
        return p.id
      end,
      show_goods_purchase_panel = function(goods_id, show_time)
        panel_calls[#panel_calls + 1] = { goods_id = goods_id, show_time = show_time }
      end,
      set_goods_panel_visible = function() end,
    }

    local spec = nil
    local result = nil
    support.with_patches({
      {
        key = "GameAPI",
        value = {
          random_int = function(min, max)
            return min <= max and min or max
          end,
          get_goods_list = function()
            return { { name = target.name, goods_id = "goods_paid_item_test" } }
          end,
        },
      },
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          if role_id == p.id then
            return role
          end
          return nil
        end,
      },
      {
        key = "EVENT",
        value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" },
      },
      {
        key = "RegisterTriggerEvent",
        value = function(args, callback)
          purchase_handlers[args[2]] = callback
        end,
      },
    }, function()
      spec = market_service.choice.build(p, g, { active_tab = "item", page_index = 1 })
      spec.id = 1809
      g.turn.pending_choice = spec
      result = choice_resolver.resolve(g, spec, {
        type = "choice_select",
        choice_id = spec.id,
        option_id = target.product_id,
        actor_role_id = p.id,
      })
      assert(result and result.stay == true, "paid purchase should keep market choice open")
      assert(g.turn.pending_choice ~= nil and g.turn.pending_choice.kind == "market_buy",
        "paid purchase should keep pending market choice")
      assert(#panel_calls == 1, "paid purchase should open goods purchase panel once")

      local cb = purchase_handlers[p.id]
      assert(type(cb) == "function", "paid purchase should register callback")
      cb(nil, nil, { role = role, goods_id = "goods_paid_item_test" })
    end)

    local option = _find_option(g.turn.pending_choice and g.turn.pending_choice.options, target.product_id)
    assert(option ~= nil, "paid purchase callback should refresh market options")
    assert(option.can_buy == false, "paid purchase callback should refresh sold out entry to unbuyable")
  end)

  it("market_paid_purchase_same_goods_can_fulfill_multiple_times", function()
    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    local target = assert(_find_paid_item_entry(), "test requires paid item market entry")
    local before_count = p.inventory:count()
    local before_limit = g.market_limits[target.product_id]

    local panel_calls = {}
    local purchase_handlers = {}
    local role = {
      get_roleid = function()
        return p.id
      end,
      show_goods_purchase_panel = function(goods_id, show_time)
        panel_calls[#panel_calls + 1] = { goods_id = goods_id, show_time = show_time }
      end,
      set_goods_panel_visible = function() end,
    }

    support.with_patches({
      {
        key = "GameAPI",
        value = {
          random_int = function(min, max)
            return min <= max and min or max
          end,
          get_goods_list = function()
            return { { name = target.name, goods_id = "goods_paid_item_repeat" } }
          end,
        },
      },
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          if role_id == p.id then
            return role
          end
          return nil
        end,
      },
      {
        key = "EVENT",
        value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" },
      },
      {
        key = "RegisterTriggerEvent",
        value = function(args, callback)
          purchase_handlers[args[2]] = callback
        end,
      },
    }, function()
      local first = market_service.purchase.execute(g, p, target.product_id)
      assert(type(first) == "table" and first.ok == true and first.deferred_fulfillment == true,
        "first paid purchase should defer fulfillment")
      local cb = purchase_handlers[p.id]
      assert(type(cb) == "function", "paid purchase callback should be registered")
      cb(nil, nil, { role = role, goods_id = "goods_paid_item_repeat" })

      local second = market_service.purchase.execute(g, p, target.product_id)
      assert(type(second) == "table" and second.ok == true and second.deferred_fulfillment == true,
        "second paid purchase should also defer fulfillment")
      cb(nil, nil, { role = role, goods_id = "goods_paid_item_repeat" })

      assert(#panel_calls == 2, "same paid goods should be purchasable multiple times")
    end)

    assert(p.inventory:count() == before_count + 2, "repeated paid callback should grant the item twice")
    assert(g.market_limits[target.product_id] == before_limit - 2, "repeated paid callback should consume limit twice")
  end)

  it("market_paid_purchase_in_flight_blocks_duplicate", function()
    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    local target = assert(_find_paid_item_entry(), "test requires paid item market entry")

    local panel_calls = {}
    local purchase_handlers = {}
    local scheduled_fns = {}
    local role = {
      get_roleid = function()
        return p.id
      end,
      show_goods_purchase_panel = function(goods_id, show_time)
        panel_calls[#panel_calls + 1] = { goods_id = goods_id, show_time = show_time }
      end,
      set_goods_panel_visible = function() end,
    }

    support.with_patches({
      {
        key = "GameAPI",
        value = {
          random_int = function(min, max)
            return min <= max and min or max
          end,
          get_goods_list = function()
            return { { name = target.name, goods_id = "goods_in_flight_test" } }
          end,
        },
      },
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          if role_id == p.id then
            return role
          end
          return nil
        end,
      },
      {
        target = runtime_ports,
        key = "schedule",
        value = function(_, fn)
          scheduled_fns[#scheduled_fns + 1] = fn
        end,
      },
      {
        key = "EVENT",
        value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" },
      },
      {
        key = "RegisterTriggerEvent",
        value = function(args, callback)
          purchase_handlers[args[2]] = callback
        end,
      },
    }, function()
      local first = market_service.purchase.execute(g, p, target.product_id)
      assert(type(first) == "table" and first.ok == true and first.deferred_fulfillment == true,
        "first paid purchase should succeed")
      assert(#panel_calls == 1, "first purchase should open panel")

      local second = market_service.purchase.execute(g, p, target.product_id)
      assert(type(second) == "table" and second.ok == false and second.reason == "purchase_in_flight",
        "second purchase while in-flight should be blocked")
      assert(#panel_calls == 1, "blocked purchase should not open another panel")

      local cb = purchase_handlers[p.id]
      cb(nil, nil, { role = role, goods_id = "goods_in_flight_test" })

      local third = market_service.purchase.execute(g, p, target.product_id)
      assert(type(third) == "table" and third.ok == true and third.deferred_fulfillment == true,
        "purchase after callback should succeed again")
      assert(#panel_calls == 2, "purchase after callback should open panel")
    end)
  end)

  it("market_paid_in_flight_timeout_restores_purchase_ability", function()
    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    local target = assert(_find_paid_item_entry(), "test requires paid item market entry")

    local panel_calls = {}
    local scheduled_fns = {}
    local role = {
      get_roleid = function()
        return p.id
      end,
      show_goods_purchase_panel = function(goods_id, show_time)
        panel_calls[#panel_calls + 1] = { goods_id = goods_id, show_time = show_time }
      end,
      set_goods_panel_visible = function() end,
    }

    support.with_patches({
      {
        key = "GameAPI",
        value = {
          random_int = function(min, max)
            return min <= max and min or max
          end,
          get_goods_list = function()
            return { { name = target.name, goods_id = "goods_timeout_test" } }
          end,
        },
      },
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          if role_id == p.id then
            return role
          end
          return nil
        end,
      },
      {
        target = runtime_ports,
        key = "schedule",
        value = function(_, fn)
          scheduled_fns[#scheduled_fns + 1] = fn
        end,
      },
      {
        key = "EVENT",
        value = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" },
      },
      {
        key = "RegisterTriggerEvent",
        value = function() end,
      },
    }, function()
      local first = market_service.purchase.execute(g, p, target.product_id)
      assert(first.ok == true, "first purchase should succeed")

      local blocked = market_service.purchase.execute(g, p, target.product_id)
      assert(blocked.ok == false and blocked.reason == "purchase_in_flight",
        "should be blocked while in-flight")

      assert(#scheduled_fns == 1, "should have scheduled one timeout")
      scheduled_fns[1]()

      local after_timeout = market_service.purchase.execute(g, p, target.product_id)
      assert(after_timeout.ok == true and after_timeout.deferred_fulfillment == true,
        "purchase should succeed after timeout clears in-flight")
      assert(#panel_calls == 2, "two successful purchases should open two panels")
    end)
  end)
end)
