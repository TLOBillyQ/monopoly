local _default_catalog = require("src.config.content.skins")
local host_runtime_ports = require("src.ui.host_bridge")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local skin_nodes = require("src.ui.schema.skin")
local skin_panel_view = require("src.ui.render.skin_panel")

local skin_panel = {}

local PAGE_SIZE = 6
local equip_callback = nil
local purchase_callback = nil
local _catalog = _default_catalog

local function _ensure_state(state)
  assert(state ~= nil, "missing state")
  local ui = assert(state.ui, "missing state.ui")
  ui.skin_panel = ui.skin_panel or {
    open = false,
    page_index = 1,
    owned_by_role = {},
    selected_by_role = {},
  }
  return ui.skin_panel
end

local function _role_key(role_id)
  return tostring(assert(role_id, "missing role_id"))
end

local function _slot_index(panel, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return (panel.page_index - 1) * PAGE_SIZE + slot
end

local function _skin_at(panel, slot_index)
  return _catalog[_slot_index(panel, slot_index)]
end

local function _notify(text, key)
  host_runtime_ports.enqueue_tip({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = "ui.skin_panel",
  })
end

local function _action_type(action)
  if type(action) == "table" then
    return action.type or action.action
  end
  return action
end

local function _action_slot_index(action)
  if type(action) == "table" then
    return action.slot_index or action.index or action.slot or 1
  end
  return 1
end

local function _apply_equip_callback(role_id, skin)
  if type(equip_callback) ~= "function" then
    return false
  end
  local ok, applied = pcall(equip_callback, role_id, skin)
  if not ok then
    logger.warn(
      "skin_panel: equip callback failed",
      "role_id=" .. tostring(role_id),
      "product_id=" .. tostring(skin and skin.product_id or nil),
      tostring(applied)
    )
    return false
  end
  return applied == true
end

function skin_panel.configure_equip(callback)
  if callback ~= nil then
    assert(type(callback) == "function", "invalid skin equip callback")
  end
  equip_callback = callback
end

function skin_panel.configure_purchase(callback)
  if callback ~= nil then
    assert(type(callback) == "function", "invalid skin purchase callback")
  end
  purchase_callback = callback
end

function skin_panel.configure_catalog_for_tests(catalog)
  _catalog = catalog or _default_catalog
  skin_panel.catalog = _catalog
end

function skin_panel.reset_for_tests()
  equip_callback = nil
  purchase_callback = nil
  _catalog = _default_catalog
  skin_panel.catalog = _catalog
end

function skin_panel.open(state, role_id)
  local panel = _ensure_state(state)
  panel.open = true
  panel.role_id = role_id
  panel.page_index = 1
  canvas.switch_by_role_id(state and state.ui, skin_nodes.canvas, role_id)
  skin_panel_view.refresh_slots(state, _catalog)
  _notify("皮肤已打开", "skin_panel:open:" .. tostring(role_id))
  return panel
end

function skin_panel.close(state, role_id)
  local panel = _ensure_state(state)
  panel.open = false
  canvas.switch_by_role_id(state and state.ui, base_nodes.canvas, role_id or panel.role_id)
  _notify("已关闭", "skin_panel:close")
  return panel
end

function skin_panel.unlock(state, role_id, source, slot_index)
  local panel = _ensure_state(state)
  local skin = _skin_at(panel, slot_index)
  if not skin then
    return panel
  end
  local key = _role_key(role_id or panel.role_id)
  panel.owned_by_role[key] = panel.owned_by_role[key] or {}
  panel.owned_by_role[key][skin.product_id] = true
  _notify(skin.name .. " 已解锁", "skin_panel:unlock:" .. key .. ":" .. tostring(skin.product_id) .. ":" .. tostring(source))
  return panel
end

local function _initiate_purchase(state, role_id, slot_index)
  local panel = _ensure_state(state)
  local skin = _skin_at(panel, slot_index)
  if type(purchase_callback) ~= "function" then
    _notify("皮肤尚未解锁", "skin_panel:not_owned:" .. _role_key(role_id) .. ":" .. tostring(skin and skin.product_id))
    return panel
  end
  local on_success = function()
    skin_panel.unlock(state, role_id, "purchase", slot_index)
    skin_panel.equip(state, role_id, slot_index)
  end
  local ok, err = pcall(purchase_callback, role_id, skin, on_success)
  if not ok then
    logger.warn("skin_panel: purchase callback failed", "role_id=" .. tostring(role_id), tostring(err))
  end
  return panel
end

function skin_panel.equip(state, role_id, slot_index)
  local panel = _ensure_state(state)
  role_id = role_id or panel.role_id
  local skin = _skin_at(panel, slot_index)
  if not skin then
    return panel
  end
  local key = _role_key(role_id)
  local owned = panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id] == true
  if not owned then
    if skin.unlock == "purchase" then
      return _initiate_purchase(state, role_id, slot_index)
    end
    _notify("皮肤尚未解锁", "skin_panel:not_owned:" .. key .. ":" .. tostring(skin.product_id))
    return panel
  end
  panel.last_equip_ok_by_role = panel.last_equip_ok_by_role or {}
  panel.last_equip_ok_by_role[key] = _apply_equip_callback(role_id, skin)
  panel.selected_by_role[key] = skin.product_id
  skin_panel_view.refresh_slots(state, _catalog)
  _notify("已换装 " .. skin.name, "skin_panel:equip:" .. key .. ":" .. tostring(skin.product_id))
  return panel
end

local function _unequip(state, role_id)
  local panel = _ensure_state(state)
  local key = _role_key(role_id or panel.role_id)
  panel.selected_by_role[key] = nil
  _notify("已脱下皮肤", "skin_panel:unequip:" .. key)
  return panel
end

local function _page_count()
  return math.max(1, math.floor((#_catalog + PAGE_SIZE - 1) / PAGE_SIZE))
end

local function _clamp_page(page_index)
  local page = number_utils.to_integer(page_index) or 1
  return number_utils.clamp(page, 1, _page_count())
end

local function _page_next(state)
  local panel = _ensure_state(state)
  panel.page_index = _clamp_page(panel.page_index + 1)
  skin_panel_view.refresh_slots(state, _catalog)
  return panel
end

local function _page_prev(state)
  local panel = _ensure_state(state)
  panel.page_index = _clamp_page(panel.page_index - 1)
  skin_panel_view.refresh_slots(state, _catalog)
  return panel
end

local _ACTION_HANDLERS = {
  close   = function(state, role_id, _)  return skin_panel.close(state, role_id) end,
  buy     = function(state, role_id, a)  return skin_panel.unlock(state, role_id, "buy", _action_slot_index(a)) end,
  gift    = function(state, role_id, a)  return skin_panel.unlock(state, role_id, "gift", _action_slot_index(a)) end,
  equip   = function(state, role_id, a)  return skin_panel.equip(state, role_id, _action_slot_index(a)) end,
  unequip = function(state, role_id, _)  return _unequip(state, role_id) end,
  next    = function(state, _, _)        return _page_next(state) end,
  prev    = function(state, _, _)        return _page_prev(state) end,
}

function skin_panel.handle_action(state, action, role_id)
  local action_type = _action_type(action)
  local handler = _ACTION_HANDLERS[action_type]
  if handler then return handler(state, role_id, action) end
  local slot_index = number_utils.to_integer(action)
  if slot_index ~= nil then return skin_panel.equip(state, role_id, slot_index) end
  return _ensure_state(state)
end

skin_panel.catalog = _catalog

return skin_panel
