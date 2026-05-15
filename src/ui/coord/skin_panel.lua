local skins = require("src.config.content.skins")
local host_runtime_ports = require("src.ui.host_bridge")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")

local skin_panel = {}

local PAGE_SIZE = 6
local equip_callback = nil

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

local function _page_count()
  return math.max(1, math.floor((#skins + PAGE_SIZE - 1) / PAGE_SIZE))
end

local function _clamp_page(page_index)
  local page = number_utils.to_integer(page_index) or 1
  return number_utils.clamp(page, 1, _page_count())
end

local function _role_key(role_id)
  return tostring(assert(role_id, "missing role_id"))
end

local function _slot_index(panel, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return (panel.page_index - 1) * PAGE_SIZE + slot
end

local function _skin_at(panel, slot_index)
  return skins[_slot_index(panel, slot_index)]
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

function skin_panel.reset_for_tests()
  equip_callback = nil
end

function skin_panel.open(state, role_id)
  local panel = _ensure_state(state)
  panel.open = true
  panel.role_id = role_id
  panel.page_index = _clamp_page(panel.page_index)
  _notify("皮肤已打开", "skin_panel:open:" .. tostring(role_id))
  return panel
end

function skin_panel.close(state)
  local panel = _ensure_state(state)
  panel.open = false
  _notify("已关闭", "skin_panel:close")
  return panel
end

function skin_panel.page_next(state)
  local panel = _ensure_state(state)
  panel.page_index = _clamp_page(panel.page_index + 1)
  return panel
end

function skin_panel.page_prev(state)
  local panel = _ensure_state(state)
  panel.page_index = _clamp_page(panel.page_index - 1)
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

function skin_panel.equip(state, role_id, slot_index)
  local panel = _ensure_state(state)
  local skin = _skin_at(panel, slot_index)
  if not skin then
    return panel
  end
  local key = _role_key(role_id or panel.role_id)
  local owned = panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id] == true
  if not owned then
    _notify("皮肤尚未解锁", "skin_panel:not_owned:" .. key .. ":" .. tostring(skin.product_id))
    return panel
  end
  panel.last_equip_ok_by_role = panel.last_equip_ok_by_role or {}
  panel.last_equip_ok_by_role[key] = _apply_equip_callback(role_id or panel.role_id, skin)
  panel.selected_by_role[key] = skin.product_id
  _notify("已换装 " .. skin.name, "skin_panel:equip:" .. key .. ":" .. tostring(skin.product_id))
  return panel
end

function skin_panel.unequip(state, role_id)
  local panel = _ensure_state(state)
  local key = _role_key(role_id or panel.role_id)
  panel.selected_by_role[key] = nil
  _notify("已脱下皮肤", "skin_panel:unequip:" .. key)
  return panel
end

function skin_panel.handle_action(state, action, role_id)
  local action_type = _action_type(action)
  if action_type == "close" then
    return skin_panel.close(state)
  end
  if action_type == "next" then
    return skin_panel.page_next(state)
  end
  if action_type == "prev" then
    return skin_panel.page_prev(state)
  end
  if action_type == "buy" or action_type == "gift" then
    return skin_panel.unlock(state, role_id, action_type, _action_slot_index(action))
  end
  if action_type == "equip" then
    return skin_panel.equip(state, role_id, _action_slot_index(action))
  end
  if action_type == "unequip" then
    return skin_panel.unequip(state, role_id)
  end
  local slot_index = number_utils.to_integer(action)
  if slot_index ~= nil then
    return skin_panel.equip(state, role_id, slot_index)
  end
  return _ensure_state(state)
end

skin_panel.catalog = skins
skin_panel.page_size = PAGE_SIZE

return skin_panel
