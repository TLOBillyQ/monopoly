local transaction = require("src.app.cosmetics.transaction")
local host_runtime_ports = require("src.ui.host_bridge")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local skin_nodes = require("src.ui.schema.skin")
local skin_panel_view = require("src.ui.render.skin_panel")
local panel_helpers = require("src.ui.coord.panel_helpers")
local panel_state = require("src.ui.coord.skin_panel_state")
local panel_actions = require("src.ui.coord.skin_panel_actions")

local skin_panel = {}

local _catalog = transaction.catalog

local function _notify(text, key)
  host_runtime_ports.enqueue_tip({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = "ui.skin_panel",
  })
end

local function _sync_catalog()
  _catalog = transaction.catalog
  skin_panel.catalog = _catalog
end

local function _refresh_slots_for_owner(state, panel)
  return panel_helpers.with_owner_role(state, panel.role_id, function()
    return skin_panel_view.refresh_slots(state, _catalog)
  end)
end

local function _panel_from_result(state, result)
  if result and result.panel then
    return result.panel
  end
  return panel_state.ensure(state)
end

local function _result_key(result, role_id)
  if result == nil then
    return "skin_panel:unknown:" .. tostring(role_id)
  end
  local product_id = result.product_id or result.equipped_product or ""
  return "skin_panel:" .. tostring(result.action or "unknown")
    .. ":" .. tostring(role_id)
    .. ":" .. tostring(product_id)
end

local function _notify_result(result, role_id, opts)
  if opts and opts.silent == true then
    return
  end
  if result == nil or result.notification == nil then
    return
  end
  _notify(result.notification, _result_key(result, role_id))
end

local function _apply_transaction_result(state, role_id, result, opts)
  local panel = _panel_from_result(state, result)
  local effective_role = role_id or panel.role_id
  if result and result.action == "open" then
    canvas.switch_by_role_id(state and state.ui, skin_nodes.canvas, effective_role)
  end
  if result and result.slot_view_dirty == true then
    _refresh_slots_for_owner(state, panel)
  end
  if result and result.panel_should_close == true then
    canvas.switch_by_role_id(state and state.ui, base_nodes.canvas, result.role_id or effective_role)
  end
  _notify_result(result, effective_role, opts)
  return panel
end

function skin_panel.is_slot_equipped(state, slot_index)
  return transaction.is_slot_equipped(state, slot_index)
end

function skin_panel.configure_equip(callback)
  transaction.configure_equip(callback)
end

function skin_panel.configure_purchase(callback)
  transaction.configure_purchase(callback)
end

function skin_panel.configure_unequip(callback)
  transaction.configure_unequip(callback)
end

function skin_panel.configure_archive(archive)
  transaction.configure_archive(archive)
end

function skin_panel.configure_catalog_for_tests(catalog)
  transaction.configure_catalog_for_tests(catalog)
  _sync_catalog()
end

function skin_panel.reset_for_tests()
  transaction.reset_for_tests()
  _sync_catalog()
end

function skin_panel.open(state, role_id)
  local result = transaction.handle_skin_transaction(state, role_id, { type = "open" })
  return _apply_transaction_result(state, role_id, result)
end

function skin_panel.close(state, role_id, opts)
  local result = transaction.handle_skin_transaction(state, role_id, { type = "close" })
  return _apply_transaction_result(state, role_id, result, opts)
end

function skin_panel.unlock(state, role_id, source, slot_index)
  local result = transaction.handle_skin_transaction(state, role_id, {
    type = "unlock_slot",
    source = source,
    slot_index = slot_index,
  })
  return _apply_transaction_result(state, role_id, result)
end

function skin_panel.equip(state, role_id, slot_index)
  local result = transaction.handle_skin_transaction(state, role_id, {
    type = "equip_slot",
    slot_index = slot_index,
  })
  return _apply_transaction_result(state, role_id, result)
end

local function _unequip(state, role_id)
  local result = transaction.handle_skin_transaction(state, role_id, { type = "unequip" })
  return _apply_transaction_result(state, role_id, result)
end

local function _page_next(state)
  local result = transaction.handle_skin_transaction(state, nil, { type = "page_next" })
  return _apply_transaction_result(state, nil, result, { silent = true })
end

local function _page_prev(state)
  local result = transaction.handle_skin_transaction(state, nil, { type = "page_prev" })
  return _apply_transaction_result(state, nil, result, { silent = true })
end

local _ACTION_HANDLERS = {
  close   = function(state, role_id, _)  return skin_panel.close(state, role_id) end,
  buy     = function(state, role_id, a)  return skin_panel.unlock(state, role_id, "buy", panel_actions.slot_index(a)) end,
  gift    = function(state, role_id, a)  return skin_panel.unlock(state, role_id, "gift", panel_actions.slot_index(a)) end,
  equip   = function(state, role_id, a)  return skin_panel.equip(state, role_id, panel_actions.slot_index(a)) end,
  unequip = function(state, role_id, _)  return _unequip(state, role_id) end,
  next    = function(state, _, _)        return _page_next(state) end,
  prev    = function(state, _, _)        return _page_prev(state) end,
}

function skin_panel.handle_action(state, action, role_id)
  local action_type = panel_actions.kind(action)
  local handler = _ACTION_HANDLERS[action_type]
  if handler then return handler(state, role_id, action) end
  local slot_index = panel_actions.numeric_slot(action)
  if slot_index ~= nil then return skin_panel.equip(state, role_id, slot_index) end
  return panel_state.ensure(state)
end

skin_panel.catalog = _catalog

return skin_panel
