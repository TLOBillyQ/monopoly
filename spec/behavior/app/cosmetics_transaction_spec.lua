local support = require("spec.support.shared_support")
local with_patches = support.with_patches

local transaction = require("src.app.cosmetics.transaction")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _catalog()
  return {
    { product_id = "skin_1", name = "皮肤一", unlock = "purchase", currency = "金豆", price = 198 },
    { product_id = "skin_2", name = "皮肤二", unlock = "purchase", currency = "金豆", price = 198 },
  }
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
