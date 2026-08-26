-- read-model/state pin — src/app/cosmetics/transaction_state.lua 与
-- src/app/cosmetics/transaction_result.lua 的内部形状钉子。
--
-- 这些断言直测子模块的内部返回形状（panel 默认字段、role guard、accepted/
-- rejected 结果结构、owned map 载入、equip 结果字段），没有门面级可观察替身，
-- 不可经 transaction 门面等价覆盖。为降低门面 spec 的连带面（#241），从
-- test_cosmetics_transaction.lua 等价迁出，独立成本 pin spec。
-- 这里是内部契约的钉子而非门面行为规约：门面级可观察行为仍住门面 spec。
--
-- 原生 LuaUnit 改写:describe 带 before_each/after_each → setUp/tearDown,
-- 用例数与改写前一一对应(4 例)。

local lu = require("luaunit")
local support = require("test.support.shared_support")

local transaction = require("src.app.cosmetics.transaction")
local transaction_result = require("src.app.cosmetics.transaction_result")
local transaction_state = require("src.app.cosmetics.transaction_state")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

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

TestCosmeticsTransactionStatePin = {}

function TestCosmeticsTransactionStatePin:setUp()
  transaction.reset_for_tests()
  transaction.configure_catalog_for_tests(_catalog())
end

function TestCosmeticsTransactionStatePin:tearDown()
  transaction.reset_for_tests()
  paid_purchase_port.reset_for_tests()
  -- 拆了共享端口基线必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

function TestCosmeticsTransactionStatePin:test_state_module_pins_panel_result_defaults_and_role_guards()
  local missing_panel, missing_reason = transaction_state.ensure_panel(nil)
  _assert_eq(missing_panel, nil, "missing state should not create a panel")
  _assert_eq(missing_reason, "missing_state", "missing state reason should be stable")

  local root = { ui = {} }
  local panel = assert(transaction_state.ensure_panel(root))
  _assert_eq(panel.open, false, "new panel should be closed")
  _assert_eq(panel.page_index, 1, "new panel should start on page 1")
  lu.assertEvalToTrue(type(panel.owned_by_role) == "table", "new panel should have an ownership bucket")
  lu.assertEvalToTrue(type(panel.selected_by_role) == "table", "new panel should have a selection bucket")
  lu.assertEvalToTrue(type(panel.pending_skin_purchase_by_role) == "table", "new panel should have a pending purchase bucket")
  _assert_eq(transaction_state.slot_index(nil, 1), 1, "nil panel slot math should use page 1")

  local partial = { ui = { skin_panel = { owned_by_role = {} } } }
  local ensured_partial = assert(transaction_state.ensure_panel(partial))
  lu.assertEvalToTrue(type(ensured_partial.selected_by_role) == "table", "ensure_panel should backfill missing selected table")
  lu.assertEvalToTrue(type(ensured_partial.pending_skin_purchase_by_role) == "table",
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
end

function TestCosmeticsTransactionStatePin:test_state_module_loads_owned_maps_and_preserves_existing_selection()
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
end

function TestCosmeticsTransactionStatePin:test_equipped_product_pins_nil_guards_and_effective_role_fallback()
  -- equipped_product 的 nil guard 链是第 114 行的核心防御：panel / key /
  -- selected_by_role 三者之一缺失即返回 nil。这里直接测所有 guard 分支以消灭
  -- 该行的全部等价变异体。
  _assert_eq(transaction_state.equipped_product(nil), nil,
    "nil panel without role defaults to nil")
  _assert_eq(transaction_state.equipped_product(nil, 1), nil,
    "explicit role with nil panel returns nil")

  local panel = assert(transaction_state.ensure_panel({ ui = {} }))
  _assert_eq(transaction_state.equipped_product(panel, nil), nil,
    "nil role with non-nil panel returns nil before accessing selected_by_role")
  _assert_eq(transaction_state.equipped_product(panel, 1), nil,
    "non-nil role with empty selected_by_role returns nil")

  panel.selected_by_role["1"] = "skin_1"
  _assert_eq(transaction_state.equipped_product(panel, 1), "skin_1",
    "equipped_product returns the selected product for the role")

  -- panel.role_id as effective_role fallback
  panel.role_id = 2
  panel.selected_by_role["2"] = "skin_2"
  _assert_eq(transaction_state.equipped_product(panel), "skin_2",
    "equipped_product falls back to panel.role_id when no explicit role is given")
  _assert_eq(transaction_state.equipped_product(panel, 1), "skin_1",
    "explicit role takes priority over panel.role_id fallback")
end

function TestCosmeticsTransactionStatePin:test_result_module_pins_missing_panel_and_equip_result_fields()
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

  lu.assertEvalToTrue(result.accepted == true, "equipped result should be accepted")
  _assert_eq(result.panel_should_close, true, "equipped result should close the panel")
  _assert_eq(result.slot_view_dirty, true, "equipped result should refresh slots")
  _assert_eq(result.host_action_attempted, true, "equipped result should report configured host adapter")
  _assert_eq(result.host_action_result, true, "equipped result should expose adapter result")
  _assert_eq(result.equipped_product, "skin_1", "equipped result should expose product")
end


return TestCosmeticsTransactionStatePin
