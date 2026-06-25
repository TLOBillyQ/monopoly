local support = require("spec.support.shared_support")
local with_patches = support.with_patches

local transaction = require("src.app.cosmetics.transaction")
local transaction_result = require("src.app.cosmetics.transaction_result")
local transaction_state = require("src.app.cosmetics.transaction_state")
local transaction_purchase = require("src.app.cosmetics.transaction_purchase")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local logger = require("src.foundation.log")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _assert_rejected(result, reason)
  assert(result and result.accepted == false, "transaction should reject")
  _assert_eq(result.reason, reason, "rejection reason should be stable")
end

local function _catalog()
  return {
    { product_id = "skin_1", name = "皮肤一", unlock = "purchase", currency = "金豆", price = 198 },
    { product_id = "skin_2", name = "皮肤二", unlock = "purchase", currency = "金豆", price = 198 },
  }
end

local function _catalog_size(count)
  local catalog = {}
  for i = 1, count do
    catalog[#catalog + 1] = {
      product_id = "skin_" .. tostring(i),
      name = "皮肤" .. tostring(i),
      unlock = "purchase",
      currency = "金豆",
      price = 198,
    }
  end
  return catalog
end

local function _state(player)
  player = player or { id = 1 }
  return {
    ui = {},
    game = {
      find_player_by_id = function(_, role_id)
        if tostring(role_id) == tostring(player.id) then
          return player
        end
        return nil
      end,
    },
  }, player
end

local function _archive(owned, equipped)
  local store = {
    owned = owned or {},
    equipped = equipped or {},
    marked = {},
  }
  return {
    store = store,
    load_owned = function(role_id)
      return store.owned[tostring(role_id)]
    end,
    mark_owned = function(role_id, product_id)
      store.owned[tostring(role_id)] = store.owned[tostring(role_id)] or {}
      store.owned[tostring(role_id)][#store.owned[tostring(role_id)] + 1] = product_id
      store.marked[#store.marked + 1] = product_id
    end,
    load_equipped = function(role_id)
      return store.equipped[tostring(role_id)]
    end,
    save_equipped = function(role_id, product_id)
      store.equipped[tostring(role_id)] = product_id
    end,
  }
end

describe("app.cosmetics.transaction", function()
  before_each(function()
    transaction.reset_for_tests()
    transaction.configure_catalog_for_tests(_catalog())
  end)

  after_each(function()
    transaction.reset_for_tests()
    paid_purchase_port.reset_for_tests()
  end)

  it("open_restores_owned_and_auto_equips_archived_skin", function()
    local state = _state()
    local archive = _archive({ ["1"] = { "skin_1" } }, { ["1"] = "skin_1" })
    local equipped = {}
    transaction.configure_archive(archive)
    transaction.configure_equip(function(role_id, skin)
      equipped[#equipped + 1] = { role_id = role_id, product_id = skin.product_id }
      return true
    end)

    local result = transaction.handle_skin_transaction(state, 1, { type = "open" })

    assert(result.accepted == true, "open should be accepted")
    _assert_eq(state.ui.skin_panel.owned_by_role["1"]["skin_1"], true, "archive owned skin should seed panel state")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], "skin_1", "owned archived equipped skin should be selected")
    _assert_eq(equipped[1] and equipped[1].product_id, "skin_1", "open should apply equipped skin to host adapter")
  end)

  it("page_commands_return_results_and_support_aliases", function()
    transaction.configure_catalog_for_tests(_catalog_size(7))
    local state = _state()
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    local next_result = transaction.handle_skin_transaction(state, 1, "next")
    assert(next_result.accepted == true, "next alias should be accepted")
    _assert_eq(next_result.action, "page", "next alias should return a page result")
    _assert_eq(next_result.slot_view_dirty, true, "page result should dirty slots")
    _assert_eq(state.ui.skin_panel.page_index, 2, "next alias should advance the page")

    local page_next_result = transaction.handle_skin_transaction(state, 1, { type = "page_next" })
    assert(page_next_result.accepted == true, "page_next should be accepted at max page")
    _assert_eq(state.ui.skin_panel.page_index, 2, "page_next should clamp at max page")

    local prev_result = transaction.handle_skin_transaction(state, 1, "prev")
    assert(prev_result.accepted == true, "prev alias should be accepted")
    _assert_eq(prev_result.action, "page", "prev alias should return a page result")
    _assert_eq(state.ui.skin_panel.page_index, 1, "prev alias should move back")

    local page_prev_result = transaction.handle_skin_transaction(state, 1, { type = "page_prev" })
    assert(page_prev_result.accepted == true, "page_prev should be accepted at min page")
    _assert_eq(state.ui.skin_panel.page_index, 1, "page_prev should clamp at min page")
  end)

  it("unlock_commands_support_request_slot_aliases_sources_and_string_fallbacks", function()
    transaction.configure_catalog_for_tests(_catalog_size(3))
    local state = _state()
    local archive = _archive()
    transaction.configure_archive(archive)
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    local purchase_result = transaction.handle_skin_transaction(state, 1, {
      type = "unlock_slot",
      index = 2,
      source = "purchase",
    })
    assert(purchase_result.accepted == true, "unlock_slot with index alias should be accepted")
    _assert_eq(purchase_result.action, "unlock", "unlock_slot should return an unlock result")
    _assert_eq(purchase_result.product_id, "skin_2", "index alias should select the indexed skin")
    _assert_eq(archive.store.marked[1], "skin_2", "purchase source should persist ownership")

    local gift_result = transaction.handle_skin_transaction(state, 1, {
      type = "gift",
      slot = 3,
    })
    assert(gift_result.accepted == true, "gift with slot alias should be accepted")
    _assert_eq(gift_result.product_id, "skin_3", "slot alias should select the requested skin")

    local buy_result = transaction.handle_skin_transaction(state, 1, "buy")
    assert(buy_result.accepted == true, "string buy should use the fallback handler")
    _assert_eq(buy_result.product_id, "skin_1", "string buy should default to slot 1")

    local table_buy_result = transaction.handle_skin_transaction(state, 1, { type = "buy" })
    assert(table_buy_result.accepted == true, "table buy without slot should be accepted")
    _assert_eq(table_buy_result.product_id, "skin_1", "table buy should default to slot 1")

    local string_gift_result = transaction.handle_skin_transaction(state, 1, "gift")
    assert(string_gift_result.accepted == true, "string gift should use the fallback handler")
    _assert_eq(string_gift_result.product_id, "skin_1", "string gift should default to slot 1")
  end)

  it("unknown_transaction_returns_stable_rejection_with_panel", function()
    local state = _state()
    state.ui.skin_panel = {
      open = true,
      page_index = 1,
      owned_by_role = {},
      selected_by_role = {},
    }
    local existing_panel = state.ui.skin_panel

    local result = transaction.handle_skin_transaction(state, 1, { type = "bogus" })

    _assert_rejected(result, "unknown_skin_transaction")
    assert(result.panel == existing_panel, "unknown transaction should still expose the ensured panel")
  end)

  it("locked_purchase_starts_paid_entry_and_completion_fulfills_original_product", function()
    local state, player = _state()
    local archive = _archive()
    local equipped = {}
    local captured = nil
    transaction.configure_archive(archive)
    transaction.configure_equip(function(_, skin)
      equipped[#equipped + 1] = skin.product_id
      return true
    end)

    transaction.handle_skin_transaction(state, 1, { type = "open" })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function(game, start_player, entry)
          captured = { game = game, player = start_player, entry = entry }
          return true
        end,
      },
    }, function()
      local result = transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 })
      assert(result.accepted == true, "purchase start should be accepted")
      assert(result.pending_purchase == true, "locked purchase should create pending purchase")
    end)

    _assert_eq(captured and captured.game, state.game, "paid entry should use state game")
    _assert_eq(captured and captured.player, player, "paid entry should use resolved player")
    _assert_eq(captured and captured.entry.kind, "skin", "paid entry should be tagged as skin")
    _assert_eq(captured and captured.entry.product_id, "skin_1", "paid entry should keep product id")
    _assert_eq(captured and captured.entry.currency, "金豆", "paid entry should keep currency")
    _assert_eq(captured and captured.entry.price, 198, "paid entry should keep price")

    state.ui.skin_panel.page_index = 2
    _assert_eq(captured.entry.on_purchase(), true, "host callback should fulfill through transaction seam")
    _assert_eq(state.ui.skin_panel.owned_by_role["1"]["skin_1"], true, "fulfilled purchase should mark owned")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], "skin_1", "fulfilled purchase should equip original product")
    _assert_eq(equipped[1], "skin_1", "fulfillment should apply equip adapter")
    _assert_eq(archive.store.marked[1], "skin_1", "fulfillment should persist ownership")
  end)

  it("locked_purchase_rejects_missing_paid_purchase_contexts", function()
    local missing_game = { ui = {} }
    transaction.handle_skin_transaction(missing_game, 1, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(missing_game, 1, { type = "equip_slot", slot_index = 1 }),
      "missing_game"
    )

    local missing_lookup = { ui = {}, game = {} }
    transaction.handle_skin_transaction(missing_lookup, 1, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(missing_lookup, 1, { type = "equip_slot", slot_index = 1 }),
      "missing_player_lookup"
    )

    local missing_player = {
      ui = {},
      game = {
        find_player_by_id = function()
          return nil
        end,
      },
    }
    transaction.handle_skin_transaction(missing_player, 1, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(missing_player, 1, { type = "equip_slot", slot_index = 1 }),
      "missing_player"
    )
  end)

  it("locked_purchase_preserves_paid_gateway_rejection_reasons_and_clears_pending", function()
    local state = _state()
    local starts = 0
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          starts = starts + 1
          return false, "gateway_says_no"
        end,
      },
    }, function()
      _assert_rejected(
        transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 }),
        "gateway_says_no"
      )
      _assert_rejected(
        transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 }),
        "gateway_says_no"
      )
    end)

    _assert_eq(starts, 2, "failed paid gateway starts should clear pending state")
  end)

  it("locked_purchase_uses_default_paid_gateway_rejection_reason", function()
    local state = _state()
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          return false
        end,
      },
    }, function()
      _assert_rejected(
        transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 }),
        "paid_gateway_rejected"
      )
    end)
  end)

  it("locked_purchase_rejects_paid_gateway_errors", function()
    local state = _state()
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          error("gateway unavailable")
        end,
      },
    }, function()
      _assert_rejected(
        transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 }),
        "paid_gateway_missing"
      )
    end)
  end)

  it("locked_purchase_rejects_legacy_adapter_failure_paths", function()
    local state = _state()
    local warnings = 0
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    transaction.configure_purchase(function()
      error("legacy adapter unavailable")
    end)
    with_patches({
      {
        target = logger,
        key = "warn",
        value = function()
          warnings = warnings + 1
        end,
      },
    }, function()
      _assert_rejected(
        transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 }),
        "purchase_callback_failed"
      )
    end)
    _assert_eq(warnings, 1, "legacy adapter error should be logged once")

    transaction.configure_purchase(function()
      return false
    end)
    _assert_rejected(
      transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 }),
      "purchase_callback_rejected"
    )
  end)

  it("locked_purchase_legacy_adapter_completion_uses_on_success_status", function()
    local state = _state()
    transaction.configure_equip(function()
      return true
    end)
    transaction.configure_purchase(function(_, _, on_success)
      return on_success()
    end)
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    local result = transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 })

    assert(result.accepted == true, "legacy purchase completion should be accepted")
    _assert_eq(result.action, "purchase_complete", "legacy adapter success should complete the purchase")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], "skin_1", "legacy completion should equip purchased skin")
  end)

  it("complete_skin_purchase_rejects_duplicate_or_mismatched_callback", function()
    local state = _state()
    local captured = nil
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function(_, _, entry)
          captured = entry
          return true
        end,
      },
    }, function()
      transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 1 })
    end)

    local mismatch = transaction.complete_skin_purchase(state, 1, "skin_2")
    assert(mismatch.accepted == false, "wrong product callback should reject")
    _assert_eq(mismatch.reason, "pending_purchase_mismatch", "wrong callback should have stable reason")

    _assert_eq(captured.on_purchase(), true, "original callback should still fulfill")
    local duplicate = transaction.complete_skin_purchase(state, 1, "skin_1")
    assert(duplicate.accepted == false, "duplicate callback should reject")
    _assert_eq(duplicate.reason, "pending_purchase_missing", "duplicate callback should have stable reason")
  end)

  it("locked_purchase_rejects_invalid_purchase_inputs_and_duplicate_starts", function()
    local missing_slot_state = _state()
    transaction.handle_skin_transaction(missing_slot_state, 1, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(missing_slot_state, 1, { type = "equip_slot", slot_index = 9 }),
      "missing_skin"
    )

    transaction.configure_catalog_for_tests({
      { product_id = "gift_skin", name = "礼物皮肤", unlock = "gift" },
    })
    local gift_state = _state()
    transaction.handle_skin_transaction(gift_state, 1, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(gift_state, 1, { type = "equip_slot", slot_index = 1 }),
      "invalid_purchase_skin"
    )

    transaction.configure_catalog_for_tests({
      { name = "缺失商品", unlock = "purchase" },
    })
    local missing_product_state = _state()
    transaction.handle_skin_transaction(missing_product_state, 1, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(missing_product_state, 1, { type = "equip_slot", slot_index = 1 }),
      "invalid_purchase_skin"
    )

    transaction.configure_catalog_for_tests(_catalog())
    local missing_role_state = _state()
    transaction.handle_skin_transaction(missing_role_state, nil, { type = "open" })
    _assert_rejected(
      transaction.handle_skin_transaction(missing_role_state, nil, { type = "equip_slot", slot_index = 1 }),
      "missing_role"
    )

    local duplicate_state = _state()
    transaction.handle_skin_transaction(duplicate_state, 1, { type = "open" })
    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          return true
        end,
      },
    }, function()
      local first = transaction.handle_skin_transaction(duplicate_state, 1, { type = "equip_slot", slot_index = 1 })
      assert(first.accepted == true, "first purchase start should be accepted")
      _assert_rejected(
        transaction.handle_skin_transaction(duplicate_state, 1, { type = "equip_slot", slot_index = 1 }),
        "purchase_in_flight"
      )
    end)
  end)

  it("purchase_module_guards_internal_public_entrypoints", function()
    local state = _state()
    transaction.handle_skin_transaction(state, 1, { type = "open" })
    local panel = state.ui.skin_panel

    _assert_rejected(
      transaction_purchase.start(state, panel, 1, nil, function()
        return true
      end),
      "missing_skin"
    )

    panel.pending_skin_purchase_by_role["1"] = { product_id = "skin_1" }
    transaction_purchase.clear_pending(panel, nil)
    assert(panel.pending_skin_purchase_by_role["1"] ~= nil, "nil role clear should leave existing pending state intact")
  end)

  it("is_slot_equipped_guards_panel_role_and_slot_state", function()
    assert(transaction.is_slot_equipped(nil, 1) == false, "nil root state should not report equipped")
    assert(transaction.is_slot_equipped({ ui = {} }, 1) == false, "missing panel should not report equipped")

    local state = _state()
    transaction.handle_skin_transaction(state, 1, { type = "open" })
    assert(transaction.is_slot_equipped(state, 1) == false, "unselected skin should not report equipped")
    assert(transaction.is_slot_equipped(state, 9) == false, "missing catalog slot should not report equipped")

    local panel = state.ui.skin_panel
    panel.role_id = nil
    panel.selected_by_role["1"] = "skin_1"
    assert(transaction.is_slot_equipped(state, 1) == false, "missing panel role should not report equipped")

    panel.role_id = 1
    assert(transaction.is_slot_equipped(state, 1) == true, "selected skin should report equipped")
    assert(transaction.is_slot_equipped(state, 2) == false, "different slot should not report equipped")

    panel.role_id = 2
    assert(transaction.is_slot_equipped(state, 1) == false, "selection should be scoped to panel role")
  end)

  it("state_module_pins_panel_result_defaults_and_role_guards", function()
    local missing_panel, missing_reason = transaction_state.ensure_panel(nil)
    _assert_eq(missing_panel, nil, "missing state should not create a panel")
    _assert_eq(missing_reason, "missing_state", "missing state reason should be stable")

    local root = { ui = {} }
    local panel = assert(transaction_state.ensure_panel(root))
    _assert_eq(panel.open, false, "new panel should be closed")
    _assert_eq(panel.page_index, 1, "new panel should start on page 1")
    assert(type(panel.owned_by_role) == "table", "new panel should have an ownership bucket")
    assert(type(panel.selected_by_role) == "table", "new panel should have a selection bucket")
    assert(type(panel.pending_skin_purchase_by_role) == "table", "new panel should have a pending purchase bucket")
    _assert_eq(transaction_state.slot_index(nil, 1), 1, "nil panel slot math should use page 1")

    local partial = { ui = { skin_panel = { owned_by_role = {} } } }
    local ensured_partial = assert(transaction_state.ensure_panel(partial))
    assert(type(ensured_partial.selected_by_role) == "table", "ensure_panel should backfill missing selected table")
    assert(type(ensured_partial.pending_skin_purchase_by_role) == "table",
      "ensure_panel should backfill missing pending table")

    local accepted = transaction_state.accepted(panel, { action = "pin" })
    _assert_eq(accepted.accepted, true, "accepted result should set accepted=true")
    _assert_eq(accepted.ok, true, "accepted result should set ok=true")
    _assert_eq(accepted.panel, panel, "accepted result should expose panel")

    local rejected = transaction_state.rejected(panel, "reason_pin")
    _assert_eq(rejected.accepted, false, "rejected result should set accepted=false")
    _assert_eq(rejected.ok, false, "rejected result should set ok=false")
    _assert_eq(rejected.reason, "reason_pin", "rejected result should expose reason")
    _assert_eq(rejected.panel, panel, "rejected result should expose panel")

    _assert_eq(transaction_state.mark_owned(panel, nil, _catalog()[1], "purchase"), false,
      "mark_owned should reject missing role")
    _assert_eq(transaction_state.mark_owned(panel, 1, nil, "purchase"), false,
      "mark_owned should reject missing skin")
    _assert_eq(transaction_state.mark_owned(panel, 1, _catalog()[1], "gift"), true,
      "mark_owned should accept a valid role and skin")
    _assert_eq(transaction_state.apply_equip(panel, nil, _catalog()[1]), false,
      "apply_equip should reject missing role")
    _assert_eq(transaction_state.apply_unequip(panel, nil), false,
      "apply_unequip should reject missing role")
    _assert_eq(transaction_state.apply_unequip(panel, 1), true,
      "apply_unequip should accept a valid role")
  end)

  it("state_module_loads_owned_maps_and_preserves_existing_selection", function()
    transaction.configure_catalog_for_tests(_catalog())
    local archive = _archive({ ["1"] = { skin_1 = true, skin_2 = false } }, { ["1"] = "skin_2" })
    transaction.configure_archive(archive)
    local panel = assert(transaction_state.ensure_panel({ ui = {} }))

    transaction_state.load_owned(panel, 1)

    _assert_eq(panel.owned_by_role["1"].skin_1, true, "owned map true values should seed ownership")
    _assert_eq(panel.owned_by_role["1"].skin_2, nil, "owned map false values should not seed ownership")

    panel.owned_by_role["1"].skin_2 = true
    panel.selected_by_role["1"] = "skin_1"
    local seeded = transaction_state.seed_equipped(panel, 1)
    _assert_eq(seeded, nil, "seed_equipped should skip when a role already has a selection")
    _assert_eq(panel.selected_by_role["1"], "skin_1", "seed_equipped should preserve existing selection")
  end)

  it("result_module_pins_missing_panel_and_equip_result_fields", function()
    local panel, rejected = transaction_result.panel_or_rejection(nil)
    _assert_eq(panel, nil, "missing root state should not return a panel")
    _assert_rejected(rejected, "missing_state")

    local root = { ui = {} }
    local existing_panel = assert(transaction_state.ensure_panel(root))
    transaction.configure_equip(function()
      return true
    end)

    local result = transaction_result.accepted_equipped_skin(existing_panel, 1, _catalog()[1], {
      action = "equip_pin",
    })

    assert(result.accepted == true, "equipped result should be accepted")
    _assert_eq(result.panel_should_close, true, "equipped result should close the panel")
    _assert_eq(result.slot_view_dirty, true, "equipped result should refresh slots")
    _assert_eq(result.host_action_attempted, true, "equipped result should report configured host adapter")
    _assert_eq(result.host_action_result, true, "equipped result should expose adapter result")
    _assert_eq(result.equipped_product, "skin_1", "equipped result should expose product")
  end)

  it("owned_skin_equips_without_paid_purchase_and_unequip_clears_archive", function()
    local state = _state()
    local archive = _archive({ ["1"] = { "skin_2" } }, {})
    local paid_starts = 0
    local unequipped = nil
    transaction.configure_archive(archive)
    transaction.configure_equip(function() return true end)
    transaction.configure_unequip(function(role_id) unequipped = role_id end)
    transaction.handle_skin_transaction(state, 1, { type = "open" })

    with_patches({
      {
        target = paid_purchase_port,
        key = "start",
        value = function()
          paid_starts = paid_starts + 1
          return true
        end,
      },
    }, function()
      local equip_result = transaction.handle_skin_transaction(state, 1, { type = "equip_slot", slot_index = 2 })
      assert(equip_result.accepted == true, "owned skin should equip")
    end)

    _assert_eq(paid_starts, 0, "owned equip should not start paid purchase")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], "skin_2", "owned equip should select product")

    local unequip_result = transaction.handle_skin_transaction(state, 1, { type = "unequip" })
    assert(unequip_result.accepted == true, "unequip should be accepted")
    _assert_eq(state.ui.skin_panel.selected_by_role["1"], nil, "unequip should clear selected product")
    _assert_eq(archive.store.equipped["1"], nil, "unequip should persist cleared equipped product")
    _assert_eq(unequipped, 1, "unequip should call host adapter")
  end)
end)
