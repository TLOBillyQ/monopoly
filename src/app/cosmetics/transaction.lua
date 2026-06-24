local default_catalog = require("src.config.content.skins")
local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local paid_purchase_port = require("src.rules.ports.paid_purchase")

local transaction = {}

local catalog = default_catalog
local archive_adapter = nil
local equip_adapter = nil
local unequip_adapter = nil
local purchase_adapter = nil

local PAGE_SIZE = 6

local function _role_key(role_id)
  if role_id == nil then
    return nil
  end
  return tostring(role_id)
end

local function _ensure_panel(state)
  if state == nil or state.ui == nil then
    return nil, "missing_state"
  end
  state.ui.skin_panel = state.ui.skin_panel or {
    open = false,
    page_index = 1,
    owned_by_role = {},
    selected_by_role = {},
  }
  local panel = state.ui.skin_panel
  panel.owned_by_role = panel.owned_by_role or {}
  panel.selected_by_role = panel.selected_by_role or {}
  panel.pending_skin_purchase_by_role = panel.pending_skin_purchase_by_role or {}
  return panel, nil
end

local function _accepted(panel, fields)
  local result = fields or {}
  result.accepted = true
  result.ok = true
  result.panel = panel
  return result
end

local function _rejected(panel, reason, fields)
  local result = fields or {}
  result.accepted = false
  result.ok = false
  result.reason = reason
  result.panel = panel
  return result
end

local function _slot_index(panel, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return ((panel and panel.page_index or 1) - 1) * PAGE_SIZE + slot
end

local function _skin_at(panel, slot_index)
  return catalog[_slot_index(panel, slot_index)]
end

local function _skin_by_product(product_id)
  for _, skin in ipairs(catalog) do
    if skin.product_id == product_id then
      return skin
    end
  end
  return nil
end

local function _archive_call(method, role_id, product_id)
  if type(archive_adapter) ~= "table" or type(archive_adapter[method]) ~= "function" then
    return nil
  end
  local ok, result = pcall(archive_adapter[method], role_id, product_id)
  if ok then
    return result
  end
  return nil
end

local function _owned_bucket(panel, key)
  panel.owned_by_role[key] = panel.owned_by_role[key] or {}
  return panel.owned_by_role[key]
end

local function _mark_owned(panel, role_id, skin, source)
  local key = _role_key(role_id)
  if key == nil or skin == nil then
    return false
  end
  _owned_bucket(panel, key)[skin.product_id] = true
  if source == "purchase" then
    _archive_call("mark_owned", role_id, skin.product_id)
  end
  return true
end

local function _load_owned(panel, role_id)
  local key = _role_key(role_id)
  if key == nil then
    return
  end
  local owned = _archive_call("load_owned", role_id)
  if type(owned) ~= "table" then
    return
  end
  local bucket = _owned_bucket(panel, key)
  for _, product_id in ipairs(owned) do
    bucket[product_id] = true
  end
  for product_id, is_owned in pairs(owned) do
    if is_owned == true then
      bucket[product_id] = true
    end
  end
end

local function _owns_skin(panel, role_id, skin)
  local key = _role_key(role_id)
  local bucket = key and panel.owned_by_role[key] or nil
  return bucket ~= nil and skin ~= nil and bucket[skin.product_id] == true
end

local function _apply_equip(panel, role_id, skin)
  local key = _role_key(role_id)
  if key == nil then
    return false
  end
  local applied = false
  if type(equip_adapter) == "function" then
    local ok, result = pcall(equip_adapter, role_id, skin)
    if ok then
      applied = result == true
    end
  end
  panel.last_equip_ok_by_role = panel.last_equip_ok_by_role or {}
  panel.last_equip_ok_by_role[key] = applied
  panel.selected_by_role[key] = skin.product_id
  _archive_call("save_equipped", role_id, skin.product_id)
  return applied
end

local function _apply_unequip(panel, role_id)
  local key = _role_key(role_id)
  if key == nil then
    return false
  end
  panel.selected_by_role[key] = nil
  _archive_call("save_equipped", role_id, nil)
  if type(unequip_adapter) == "function" then
    local ok, err = pcall(unequip_adapter, role_id)
    if not ok then
      logger.warn(
        "skin_panel: unequip callback failed",
        "role_id=" .. tostring(role_id),
        tostring(err)
      )
    end
  end
  return true
end

local function _seed_equipped(panel, role_id)
  local key = _role_key(role_id)
  if key == nil or panel.selected_by_role[key] ~= nil then
    return nil
  end
  local product_id = _archive_call("load_equipped", role_id)
  if product_id == nil then
    return nil
  end
  local skin = _skin_by_product(product_id)
  if skin == nil or not _owns_skin(panel, role_id, skin) then
    return nil
  end
  _apply_equip(panel, role_id, skin)
  return skin.product_id
end

local function _open(state, role_id)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  panel.open = true
  panel.role_id = role_id
  panel.page_index = 1
  _load_owned(panel, role_id)
  local equipped_product = _seed_equipped(panel, role_id)
  return _accepted(panel, {
    action = "open",
    slot_view_dirty = true,
    equipped_product = equipped_product,
    notification = "皮肤已打开",
  })
end

local function _clamp_page(page_index)
  return number_utils.clamp(page_index, 1, number_utils.page_count(#catalog, PAGE_SIZE))
end

local function _page_delta(state, delta)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  panel.page_index = _clamp_page((panel.page_index or 1) + delta)
  return _accepted(panel, {
    action = "page",
    slot_view_dirty = true,
  })
end

local function _close(state, role_id)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  panel.open = false
  return _accepted(panel, {
    action = "close",
    panel_should_close = true,
    role_id = role_id or panel.role_id,
    notification = "已关闭",
  })
end

local function _resolve_player(state, role_id)
  local game = state and state.game or nil
  if game == nil then
    return nil, nil, "missing_game"
  end
  if type(game.find_player_by_id) ~= "function" then
    return game, nil, "missing_player_lookup"
  end
  local player = game:find_player_by_id(role_id)
  if player == nil then
    return game, nil, "missing_player"
  end
  return game, player, nil
end

local function _purchase_entry(state, role_id, skin)
  return {
    kind = "skin",
    product_id = skin.product_id,
    name = skin.name,
    currency = skin.currency,
    price = skin.price,
    on_purchase = function()
      local result = transaction.complete_skin_purchase(state, role_id, skin.product_id, {
        source = "paid_purchase",
      })
      return result.accepted == true
    end,
  }
end

local function _start_via_paid_port(state, role_id, skin, entry)
  local game, player, player_reason = _resolve_player(state, role_id)
  if player_reason ~= nil then
    return false, player_reason
  end
  local ok, started, reason = pcall(paid_purchase_port.start, game, player, entry)
  if not ok then
    return false, "paid_gateway_missing"
  end
  if started ~= true then
    return false, reason or "paid_gateway_rejected"
  end
  return true, nil
end

local function _start_via_legacy_adapter(state, role_id, skin)
  if type(purchase_adapter) ~= "function" then
    return nil, nil
  end
  local completed = nil
  local on_success = function()
    completed = transaction.complete_skin_purchase(state, role_id, skin.product_id, {
      source = "purchase_callback",
    })
    return completed.accepted == true
  end
  local ok, started = pcall(purchase_adapter, role_id, skin, on_success, state)
  if not ok then
    logger.warn(
      "skin_panel: purchase callback failed",
      "role_id=" .. tostring(role_id),
      tostring(started)
    )
    return false, "purchase_callback_failed"
  end
  if started == false then
    return false, "purchase_callback_rejected"
  end
  return true, nil, completed
end

local function _record_pending(panel, role_id, skin)
  local key = _role_key(role_id)
  if key == nil then
    return nil
  end
  panel.pending_skin_purchase_by_role[key] = {
    role_id = role_id,
    product_id = skin.product_id,
  }
  return key
end

local function _clear_pending(panel, role_id)
  local key = _role_key(role_id)
  if key ~= nil and panel.pending_skin_purchase_by_role then
    panel.pending_skin_purchase_by_role[key] = nil
  end
end

local function _start_purchase(state, panel, role_id, skin)
  if skin == nil then
    return _rejected(panel, "missing_skin")
  end
  if skin.unlock ~= "purchase" or skin.product_id == nil then
    return _rejected(panel, "invalid_purchase_skin", {
      notification = "皮肤尚未解锁",
    })
  end
  local key = _role_key(role_id)
  if key == nil then
    return _rejected(panel, "missing_role")
  end
  if panel.pending_skin_purchase_by_role[key] ~= nil then
    return _rejected(panel, "purchase_in_flight")
  end

  _record_pending(panel, role_id, skin)
  local started, reason, completed = _start_via_legacy_adapter(state, role_id, skin)
  if started == nil then
    started, reason = _start_via_paid_port(state, role_id, skin, _purchase_entry(state, role_id, skin))
  end
  if started ~= true then
    _clear_pending(panel, role_id)
    return _rejected(panel, reason or "purchase_start_failed", {
      notification = "皮肤尚未解锁",
    })
  end
  if completed ~= nil then
    return completed
  end
  return _accepted(panel, {
    action = "purchase_start",
    pending_purchase = true,
    product_id = skin.product_id,
    host_action_attempted = true,
    notification = nil,
  })
end

local function _equip_slot(state, role_id, slot_index)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  role_id = role_id or panel.role_id
  local skin = _skin_at(panel, slot_index)
  if skin == nil then
    return _rejected(panel, "missing_skin")
  end
  if not _owns_skin(panel, role_id, skin) then
    return _start_purchase(state, panel, role_id, skin)
  end
  local applied = _apply_equip(panel, role_id, skin)
  panel.open = false
  return _accepted(panel, {
    action = "equip",
    equipped_product = skin.product_id,
    panel_should_close = true,
    slot_view_dirty = true,
    host_action_attempted = type(equip_adapter) == "function",
    host_action_result = applied,
    notification = "已换装 " .. tostring(skin.name),
  })
end

local function _unlock_slot(state, role_id, slot_index, source)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  role_id = role_id or panel.role_id
  local skin = _skin_at(panel, slot_index)
  if skin == nil then
    return _rejected(panel, "missing_skin")
  end
  _mark_owned(panel, role_id, skin, source)
  return _accepted(panel, {
    action = "unlock",
    ownership_changed = true,
    product_id = skin.product_id,
    slot_view_dirty = true,
    notification = tostring(skin.name) .. " 已解锁",
  })
end

local function _unequip(state, role_id)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  role_id = role_id or panel.role_id
  _apply_unequip(panel, role_id)
  return _accepted(panel, {
    action = "unequip",
    unequipped = true,
    slot_view_dirty = true,
    host_action_attempted = type(unequip_adapter) == "function",
    notification = "已脱下皮肤",
  })
end

local function _request_type(request)
  if type(request) == "table" then
    return request.type or request.action
  end
  return request
end

local function _request_slot(request)
  if type(request) == "table" then
    return request.slot_index or request.index or request.slot or 1
  end
  return 1
end

function transaction.handle_skin_transaction(state, role_id, request)
  local kind = _request_type(request)
  if kind == "open" then
    return _open(state, role_id)
  end
  if kind == "close" then
    return _close(state, role_id)
  end
  if kind == "page_next" or kind == "next" then
    return _page_delta(state, 1)
  end
  if kind == "page_prev" or kind == "prev" then
    return _page_delta(state, -1)
  end
  if kind == "unlock_slot" or kind == "buy" or kind == "gift" then
    local source = type(request) == "table" and request.source or kind
    return _unlock_slot(state, role_id, _request_slot(request), source)
  end
  if kind == "equip_slot" or kind == "equip" or kind == "activate_slot" then
    return _equip_slot(state, role_id, _request_slot(request))
  end
  if kind == "unequip" then
    return _unequip(state, role_id)
  end
  local panel = _ensure_panel(state)
  return _rejected(panel, "unknown_skin_transaction")
end

function transaction.complete_skin_purchase(state, role_id, product_id)
  local panel, err = _ensure_panel(state)
  if panel == nil then
    return _rejected(nil, err)
  end
  local key = _role_key(role_id)
  local pending = key and panel.pending_skin_purchase_by_role[key] or nil
  if pending == nil then
    return _rejected(panel, "pending_purchase_missing")
  end
  if pending.product_id ~= product_id then
    return _rejected(panel, "pending_purchase_mismatch")
  end
  local skin = _skin_by_product(product_id)
  if skin == nil then
    return _rejected(panel, "missing_product")
  end
  _clear_pending(panel, role_id)
  _mark_owned(panel, role_id, skin, "purchase")
  local applied = _apply_equip(panel, role_id, skin)
  panel.open = false
  return _accepted(panel, {
    action = "purchase_complete",
    purchase_fulfilled = true,
    ownership_changed = true,
    equipped_product = skin.product_id,
    panel_should_close = true,
    slot_view_dirty = true,
    host_action_attempted = type(equip_adapter) == "function",
    host_action_result = applied,
    notification = "已换装 " .. tostring(skin.name),
  })
end

function transaction.is_slot_equipped(state, slot_index)
  local panel = state and state.ui and state.ui.skin_panel or nil
  if panel == nil or panel.role_id == nil then
    return false
  end
  local skin = _skin_at(panel, slot_index)
  if skin == nil then
    return false
  end
  local key = _role_key(panel.role_id)
  return key ~= nil and panel.selected_by_role[key] == skin.product_id
end

function transaction.configure_equip(callback)
  assert(callback == nil or type(callback) == "function", "invalid skin equip callback")
  equip_adapter = callback
end

function transaction.configure_unequip(callback)
  assert(callback == nil or type(callback) == "function", "invalid skin unequip callback")
  unequip_adapter = callback
end

function transaction.configure_purchase(callback)
  assert(callback == nil or type(callback) == "function", "invalid skin purchase callback")
  purchase_adapter = callback
end

function transaction.configure_archive(archive)
  assert(archive == nil or type(archive) == "table", "invalid skin archive")
  archive_adapter = archive
end

function transaction.configure_catalog_for_tests(new_catalog)
  catalog = new_catalog or default_catalog
  transaction.catalog = catalog
end

function transaction.reset_for_tests()
  catalog = default_catalog
  archive_adapter = nil
  equip_adapter = nil
  unequip_adapter = nil
  purchase_adapter = nil
  transaction.catalog = catalog
end

transaction.catalog = catalog

return transaction
