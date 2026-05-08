local support = require("support.domain_support")
local _new_game = support.new_game
local market_cfg = require("src.config.content.market")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local monopoly_event = require("src.foundation.events")
local choice_resolver = require("src.rules.choice.resolver")
local number_utils = require("src.foundation.lang.number")
local runtime_refs = require("src.config.content.runtime_refs")
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
  package.loaded["src.rules.market.query.context"] = nil
  package.loaded["src.rules.market.query.eligibility"] = nil
  package.loaded["src.rules.market.purchase.core"] = nil
  package.loaded["src.rules.market.auto"] = nil
  package.loaded["src.rules.market.choice.builder"] = nil
  package.loaded["src.rules.market.choice.session"] = nil
  return require("src.rules.market")
end

local function _reset_market_choice_runtime_modules()
  package.loaded["src.rules.market.choice_handlers"] = nil
  package.loaded["src.player.choices.registry"] = nil
  package.loaded["src.player.choices.resolver"] = nil
end

describe("market", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("ai_skips_auto_buy_at_market", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local ai_player = g.players[2]
    assert(ai_player.is_ai, "player 2 should be AI")

    g:set_player_cash(ai_player, 1000)

    local before_cash = ai_player.cash
    market_service.auto.execute(g, ai_player)

    assert(ai_player.cash == before_cash, "AI should not spend money on auto_buy")
  end)

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

  it("market_full_inventory_blocks_items", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()
    g:set_player_cash(p, 999999)
    for _ = 1, p.inventory.max_slots do
      p.inventory:add({ id = 2001 })
    end

    local list = market_service.query.list_available(p, g)
    for _, entry in ipairs(list) do
      assert(entry.kind ~= "item", "item should be excluded when inventory full")
    end
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

    local res = market_service.purchase.execute(g, p, entry.product_id, nil)
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

    local res = market_service.purchase.execute(g, p, blocked_product_id, nil)
    assert(type(res) == "table" and res.ok == false, "disabled market product should be rejected")
  end)

  it("skin_entry_can_buy_but_no_effect", function()
    local target = nil
    for _, entry in ipairs(market_cfg) do
      if entry.kind == "skin" and entry.market_enabled ~= false then
        target = entry
        break
      end
    end
    assert(target ~= nil, "test requires at least one enabled skin market entry")

    local market_service = _reload_market_service()
    local g = _new_game()
    local p = g:current_player()
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    local price = target.price or 0
    local currency = target.currency or "金币"
    if currency == "金币" then
      g:set_player_cash(p, price + 1000)
    end

    local change_skin_creature_key = nil
    local change_skin_include_custom_model = nil
    local change_skin_inherit_scale = nil
    local change_skin_inherit_capsule_size = nil

    local before_count = p.inventory:count()
    local before_limit = g.market_limits[target.product_id]
    local panel_calls = {}
    local purchase_handlers = {}
    local ctrl_unit = {
      set_model_by_creature_key = function(...)
        assert(select("#", ...) == 4, "set_model_by_creature_key should be called with creature_key and 3 flags")
        change_skin_creature_key = select(1, ...)
        change_skin_include_custom_model = select(2, ...)
        change_skin_inherit_scale = select(3, ...)
        change_skin_inherit_capsule_size = select(4, ...)
      end,
    }

    local role = {
      get_roleid = function(...)
        assert(select("#", ...) == 0, "get_roleid should be called without implicit self")
        return p.id
      end,
      show_goods_purchase_panel = function(goods_id, show_time)
        panel_calls[#panel_calls + 1] = { goods_id = goods_id, show_time = show_time }
      end,
      get_ctrl_unit = function(...)
        assert(select("#", ...) == 0, "get_ctrl_unit should be called without implicit self")
        return ctrl_unit
      end,
    }
    local res = nil
    support.with_patches({
      {
        key = "GameAPI",
        value = {
          random_int = function(min, max)
            return min <= max and min or max
          end,
          get_goods_list = function()
            return { { name = target.name, goods_id = "goods_skin_test" } }
          end,
        },
      },
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          if role_id == p.id then
            return {
              get_roleid = role.get_roleid,
              show_goods_purchase_panel = role.show_goods_purchase_panel,
              get_ctrl_unit = role.get_ctrl_unit,
            }
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
      local list = market_service.query.list_available(p, g)
      assert(_contains_product(list, target.product_id), "skin entry should be available when goods mapping is ready")
      res = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(type(res) == "table" and res.ok == true and res.deferred_fulfillment == true,
        "skin entry purchase should start external goods flow")
      assert(#panel_calls == 1, "skin entry should open purchase panel")
      assert(g.market_limits[target.product_id] == before_limit, "skin purchase should not consume global limit before callback")

      local cb = purchase_handlers[p.id]
      assert(type(cb) == "function", "skin purchase callback should be registered")
      cb(nil, nil, { role = role, goods_id = "goods_skin_test" })
    end)

    assert(g.market_limits[target.product_id] == before_limit - 1, "skin callback should consume global limit")
    assert(p.inventory:count() == before_count, "skin purchase should not change inventory")
    local expected_creature_key = runtime_refs.skins[tostring(target.product_id)] or number_utils.to_integer(target.product_id)
    assert(change_skin_creature_key == expected_creature_key,
      "skin purchase should call set_model_by_creature_key with creature_key")
    assert(change_skin_include_custom_model == true, "skin purchase should keep custom model data")
    assert(change_skin_inherit_scale == true, "skin purchase should inherit scale")
    assert(change_skin_inherit_capsule_size == true, "skin purchase should inherit capsule size")
  end)

  it("market_choice_marks_skin_options_for_pre_confirm", function()
    local target = nil
    for _, entry in ipairs(market_cfg) do
      if entry.kind == "skin" and entry.market_enabled ~= false then
        target = entry
        break
      end
    end
    assert(target ~= nil, "test requires at least one enabled skin market entry")

    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    local spec = market_service.choice.build(p, g, { active_tab = "skin" })
    assert(type(spec) == "table" and spec.kind == "market_buy", "skin tab should build market choice")

    local target_option = _find_option(spec.options, target.product_id)
    assert(target_option ~= nil, "skin tab should expose skin option")
    assert(target_option.requires_pre_confirm == nil, "skin option should not request pre-confirm")
    assert(target_option.pre_confirm_kind == nil, "skin option should not declare pre-confirm kind")
    assert(target_option.confirm_title == nil, "skin option should not provide confirm title")
    assert(target_option.confirm_body == nil, "skin option should not provide confirm body")
  end)

  it("market_tab_all_unbuyable_still_builds_market_choice", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    g:set_player_cash(p, 0)

    local spec = market_service.choice.build(p, g, { active_tab = "skin" })
    assert(type(spec) == "table" and spec.kind == "market_buy",
      "skin tab should still build market_buy choice when all options are unbuyable")
    assert(type(spec.options) == "table" and #spec.options > 0, "skin tab should keep visible options")
    for _, option in ipairs(spec.options) do
      assert(option.can_buy == false, "all skin options should be marked unbuyable in this setup")
    end
  end)

  it("market_tab_select_navigation_applies_with_unbuyable_tab", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    g:set_player_cash(p, 0)

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
    assert(pending_choice.active_tab == "skin", "navigation should switch active tab to skin")
    assert(type(pending_choice.options) == "table" and #pending_choice.options > 0,
      "navigation should keep visible options on skin tab")
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
    assert(pending_choice.active_tab == "skin", "session rebuild should apply requested active tab")
    assert(g.dirty.any == true and g.dirty.turn == true, "session rebuild should mark choice dirty")
  end)

  it("market_tab_select_empty_tab_keeps_choice_and_emits_buy_failed_tip_event", function()
    local market_service = require("src.rules.market")
    local g = _new_game()
    local p = g:current_player()

    local skin_entries = {}
    for _, entry in ipairs(market_cfg) do
      if entry.kind == "skin" then
        skin_entries[#skin_entries + 1] = {
          entry = entry,
          market_enabled = entry.market_enabled,
        }
        entry.market_enabled = false
      end
    end
    assert(#skin_entries > 0, "test requires at least one skin market entry")

    local emitted = {}
    local ok, err = pcall(function()
      local spec = market_service.choice.build(p, g, { active_tab = "item" })
      assert(type(spec) == "table" and spec.kind == "market_buy", "initial market choice should be built")

      local pending_choice = {
        id = 1001,
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

      support.with_patches({
        {
          target = runtime_ports,
          key = "emit_event",
          value = function(kind, payload)
            emitted[#emitted + 1] = { kind = kind, payload = payload }
          end,
        },
      }, function()
        local applied = market_service.choice.apply_navigation(g, pending_choice, {
          type = "market_tab_select",
          tab = "skin",
        })
        assert(applied == true, "empty target tab should still apply navigation")
        assert(pending_choice.active_tab == "skin", "empty target tab should still switch active tab")
        assert(type(pending_choice.options) == "table" and #pending_choice.options == 0,
          "empty target tab should refresh options to empty list")
      end)
    end)

    for _, snapshot in ipairs(skin_entries) do
      snapshot.entry.market_enabled = snapshot.market_enabled
    end

    if not ok then
      error(err)
    end
    assert(#emitted >= 1, "empty tab navigation should emit feedback event")
    local last = emitted[#emitted]
    assert(last.kind == monopoly_event.market.buy_failed, "empty tab feedback should reuse market buy_failed event")
    assert(last.payload and last.payload.reason == "empty_tab", "empty tab feedback reason should be empty_tab")
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
      local first = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(type(first) == "table" and first.ok == true and first.deferred_fulfillment == true,
        "first paid purchase should defer fulfillment")
      local cb = purchase_handlers[p.id]
      assert(type(cb) == "function", "paid purchase callback should be registered")
      cb(nil, nil, { role = role, goods_id = "goods_paid_item_repeat" })

      local second = market_service.purchase.execute(g, p, target.product_id, nil)
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
      local first = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(type(first) == "table" and first.ok == true and first.deferred_fulfillment == true,
        "first paid purchase should succeed")
      assert(#panel_calls == 1, "first purchase should open panel")

      local second = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(type(second) == "table" and second.ok == false and second.reason == "purchase_in_flight",
        "second purchase while in-flight should be blocked")
      assert(#panel_calls == 1, "blocked purchase should not open another panel")

      local cb = purchase_handlers[p.id]
      cb(nil, nil, { role = role, goods_id = "goods_in_flight_test" })

      local third = market_service.purchase.execute(g, p, target.product_id, nil)
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
      local first = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(first.ok == true, "first purchase should succeed")

      local blocked = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(blocked.ok == false and blocked.reason == "purchase_in_flight",
        "should be blocked while in-flight")

      assert(#scheduled_fns == 1, "should have scheduled one timeout")
      scheduled_fns[1]()

      local after_timeout = market_service.purchase.execute(g, p, target.product_id, nil)
      assert(after_timeout.ok == true and after_timeout.deferred_fulfillment == true,
        "purchase should succeed after timeout clears in-flight")
      assert(#panel_calls == 2, "two successful purchases should open two panels")
    end)
  end)
end)
