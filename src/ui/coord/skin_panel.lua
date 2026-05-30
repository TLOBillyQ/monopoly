local _default_catalog = require("src.config.content.skins")
local host_runtime_ports = require("src.ui.host_bridge")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local skin_nodes = require("src.ui.schema.skin")
local skin_panel_view = require("src.ui.render.skin_panel")
local panel_helpers = require("src.ui.coord.panel_helpers")

local skin_panel = {}

local PAGE_SIZE = skin_nodes.page_size
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

local function _refresh_slots_for_owner(state, panel)
  return panel_helpers.with_owner_role(state, panel.role_id, function()
    return skin_panel_view.refresh_slots(state, _catalog)
  end)
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

local function _configure_callback(callback, label)
  if callback ~= nil then
    assert(type(callback) == "function", "invalid skin " .. label .. " callback")
  end
  return callback
end

function skin_panel.configure_equip(callback)
  equip_callback = _configure_callback(callback, "equip")
end

function skin_panel.configure_purchase(callback)
  purchase_callback = _configure_callback(callback, "purchase")
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
  _refresh_slots_for_owner(state, panel)
  _notify("皮肤已打开", "skin_panel:open:" .. tostring(role_id))
  return panel
end

function skin_panel.close(state, role_id, opts)
  local panel = _ensure_state(state)
  panel.open = false
  canvas.switch_by_role_id(state and state.ui, base_nodes.canvas, role_id or panel.role_id)
  if not (opts and opts.silent == true) then
    _notify("已关闭", "skin_panel:close")
  end
  return panel
end

local function _unlock_skin(panel, role_id, skin, source)
  local key = _role_key(role_id or panel.role_id)
  panel.owned_by_role[key] = panel.owned_by_role[key] or {}
  panel.owned_by_role[key][skin.product_id] = true
  _notify(skin.name .. " 已解锁", "skin_panel:unlock:" .. key .. ":" .. tostring(skin.product_id) .. ":" .. tostring(source))
  return panel
end

function skin_panel.unlock(state, role_id, source, slot_index)
  local panel = _ensure_state(state)
  local skin = _skin_at(panel, slot_index)
  if not skin then
    return panel
  end
  return _unlock_skin(panel, role_id, skin, source)
end

local function _equip_owned_skin(state, panel, role_id, skin)
  local key = _role_key(role_id)
  panel.last_equip_ok_by_role = panel.last_equip_ok_by_role or {}
  panel.last_equip_ok_by_role[key] = _apply_equip_callback(role_id, skin)
  panel.selected_by_role[key] = skin.product_id
  _refresh_slots_for_owner(state, panel)
  _notify("已换装 " .. skin.name, "skin_panel:equip:" .. key .. ":" .. tostring(skin.product_id))
  return skin_panel.close(state, role_id, { silent = true })
end

local function _initiate_purchase(state, role_id, slot_index)
  local panel = _ensure_state(state)
  local skin = _skin_at(panel, slot_index)
  if type(purchase_callback) ~= "function" then
    _notify("皮肤尚未解锁", "skin_panel:not_owned:" .. _role_key(role_id) .. ":" .. tostring(skin and skin.product_id))
    return panel
  end
  local on_success = function()
    local current_panel = _ensure_state(state)
    _unlock_skin(current_panel, role_id, skin, "purchase")
    return _equip_owned_skin(state, current_panel, role_id, skin)
  end
  local ok, err = pcall(purchase_callback, role_id, skin, on_success, state)
  if not ok then
    logger.warn("skin_panel: purchase callback failed", "role_id=" .. tostring(role_id), tostring(err))
  end
  return panel
end

local function _owns_skin(panel, key, skin)
  return panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id] == true
end

local function _handle_locked_skin(state, role_id, slot_index, key, skin)
  if skin.unlock == "purchase" then
    return _initiate_purchase(state, role_id, slot_index)
  end
  _notify("皮肤尚未解锁", "skin_panel:not_owned:" .. key .. ":" .. tostring(skin.product_id))
  return _ensure_state(state)
end

function skin_panel.equip(state, role_id, slot_index)
  local panel = _ensure_state(state)
  role_id = role_id or panel.role_id
  local skin = _skin_at(panel, slot_index)
  if not skin then
    return panel
  end
  local key = _role_key(role_id)
  if not _owns_skin(panel, key, skin) then
    return _handle_locked_skin(state, role_id, slot_index, key, skin)
  end
  return _equip_owned_skin(state, panel, role_id, skin)
end

local function _unequip(state, role_id)
  local panel = _ensure_state(state)
  local key = _role_key(role_id or panel.role_id)
  panel.selected_by_role[key] = nil
  _refresh_slots_for_owner(state, panel)
  _notify("已脱下皮肤", "skin_panel:unequip:" .. key)
  return panel
end

local function _clamp_page(page_index)
  local page = number_utils.to_integer(page_index)
  return number_utils.clamp(page, 1, number_utils.page_count(#_catalog, PAGE_SIZE))
end

local function _page_next(state)
  local panel = _ensure_state(state)
  panel.page_index = _clamp_page(panel.page_index + 1)
  _refresh_slots_for_owner(state, panel)
  return panel
end

local function _page_prev(state)
  local panel = _ensure_state(state)
  panel.page_index = _clamp_page(panel.page_index - 1)
  _refresh_slots_for_owner(state, panel)
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

--[[ mutate4lua-manifest
version=2
projectHash=6d0586a376e3cfad
scope.0.id=chunk:src/ui/coord/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=260
scope.0.semanticHash=cedb72a9272df74d
scope.0.lastMutatedAt=2026-05-29T06:47:15Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=9
scope.0.lastMutationKilled=9
scope.1.id=function:_ensure_state:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=28
scope.1.semanticHash=5c9e7cc6f3b42add
scope.1.lastMutatedAt=2026-05-26T12:23:49Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_role_key:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=32
scope.2.semanticHash=f99005f60b9085b8
scope.2.lastMutatedAt=2026-05-26T12:23:49Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_slot_index:34
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=37
scope.3.semanticHash=e54d9f514712c02a
scope.3.lastMutatedAt=2026-05-26T12:23:49Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_skin_at:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=41
scope.4.semanticHash=492ec49d5d888ee2
scope.4.lastMutatedAt=2026-05-26T12:23:49Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_notify:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=51
scope.5.semanticHash=4954ead30edb0436
scope.5.lastMutatedAt=2026-05-26T12:23:49Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:anonymous@54:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=56
scope.6.semanticHash=496b82e8d3606200
scope.6.lastMutatedAt=2026-05-26T12:23:49Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=no_sites
scope.6.lastMutationSites=0
scope.6.lastMutationKilled=0
scope.7.id=function:_refresh_slots_for_owner:53
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=57
scope.7.semanticHash=1a7c6ecd7c3404fe
scope.7.lastMutatedAt=2026-05-26T12:23:49Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:_action_type:59
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=64
scope.8.semanticHash=b61a5fc534a67702
scope.8.lastMutatedAt=2026-05-26T12:23:49Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:_action_slot_index:66
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=71
scope.9.semanticHash=ca80299c341a2e06
scope.9.lastMutatedAt=2026-05-26T12:23:49Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=8
scope.9.lastMutationKilled=8
scope.10.id=function:_apply_equip_callback:73
scope.10.kind=function
scope.10.startLine=73
scope.10.endLine=88
scope.10.semanticHash=abb16920602659f9
scope.10.lastMutatedAt=2026-05-26T12:23:49Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=10
scope.10.lastMutationKilled=10
scope.11.id=function:_configure_callback:90
scope.11.kind=function
scope.11.startLine=90
scope.11.endLine=95
scope.11.semanticHash=3ec1c8dfc6a142bc
scope.11.lastMutatedAt=2026-05-26T12:23:49Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=2
scope.11.lastMutationKilled=2
scope.12.id=function:skin_panel.configure_equip:97
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=99
scope.12.semanticHash=e1c6026b6e2e9d4d
scope.12.lastMutatedAt=2026-05-26T12:23:49Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:skin_panel.configure_purchase:101
scope.13.kind=function
scope.13.startLine=101
scope.13.endLine=103
scope.13.semanticHash=460f64b28e33642e
scope.13.lastMutatedAt=2026-05-26T12:23:49Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:skin_panel.configure_catalog_for_tests:105
scope.14.kind=function
scope.14.startLine=105
scope.14.endLine=108
scope.14.semanticHash=6f58c3f6346e7bfb
scope.14.lastMutatedAt=2026-05-26T12:23:49Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:skin_panel.reset_for_tests:110
scope.15.kind=function
scope.15.startLine=110
scope.15.endLine=115
scope.15.semanticHash=c68211e0fe3c8c04
scope.15.lastMutatedAt=2026-05-26T12:23:49Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=no_sites
scope.15.lastMutationSites=0
scope.15.lastMutationKilled=0
scope.16.id=function:skin_panel.open:117
scope.16.kind=function
scope.16.startLine=117
scope.16.endLine=126
scope.16.semanticHash=f35cbcdbe265e22d
scope.16.lastMutatedAt=2026-05-26T12:23:49Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=6
scope.16.lastMutationKilled=6
scope.17.id=function:skin_panel.close:128
scope.17.kind=function
scope.17.startLine=128
scope.17.endLine=136
scope.17.semanticHash=87857f70fc9ec344
scope.17.lastMutatedAt=2026-05-26T12:23:49Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=8
scope.17.lastMutationKilled=8
scope.18.id=function:_unlock_skin:138
scope.18.kind=function
scope.18.startLine=138
scope.18.endLine=144
scope.18.semanticHash=c9633468fff4f065
scope.18.lastMutatedAt=2026-05-29T06:47:15Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=4
scope.18.lastMutationKilled=4
scope.19.id=function:skin_panel.unlock:146
scope.19.kind=function
scope.19.startLine=146
scope.19.endLine=153
scope.19.semanticHash=e4c225f6e64fc679
scope.19.lastMutatedAt=2026-05-29T06:47:15Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=4
scope.19.lastMutationKilled=4
scope.20.id=function:_equip_owned_skin:155
scope.20.kind=function
scope.20.startLine=155
scope.20.endLine=163
scope.20.semanticHash=68e6a26516403b14
scope.20.lastMutatedAt=2026-05-29T06:47:15Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=6
scope.20.lastMutationKilled=6
scope.21.id=function:anonymous@172:172
scope.21.kind=function
scope.21.startLine=172
scope.21.endLine=176
scope.21.semanticHash=63efaecd778d1d52
scope.21.lastMutatedAt=2026-05-29T06:47:15Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=3
scope.21.lastMutationKilled=3
scope.22.id=function:_initiate_purchase:165
scope.22.kind=function
scope.22.startLine=165
scope.22.endLine=182
scope.22.semanticHash=fc4e35318378a74c
scope.22.lastMutatedAt=2026-05-29T06:47:15Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=9
scope.22.lastMutationKilled=9
scope.23.id=function:_owns_skin:184
scope.23.kind=function
scope.23.startLine=184
scope.23.endLine=186
scope.23.semanticHash=339bfcb93cd84272
scope.23.lastMutatedAt=2026-05-29T06:47:15Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=3
scope.23.lastMutationKilled=3
scope.24.id=function:_handle_locked_skin:188
scope.24.kind=function
scope.24.startLine=188
scope.24.endLine=194
scope.24.semanticHash=e142e772cf120ecc
scope.24.lastMutatedAt=2026-05-29T06:47:15Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=5
scope.24.lastMutationKilled=5
scope.25.id=function:skin_panel.equip:196
scope.25.kind=function
scope.25.startLine=196
scope.25.endLine=208
scope.25.semanticHash=698ed35cca86596f
scope.25.lastMutatedAt=2026-05-29T06:47:15Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=9
scope.25.lastMutationKilled=9
scope.26.id=function:_unequip:210
scope.26.kind=function
scope.26.startLine=210
scope.26.endLine=217
scope.26.semanticHash=a2ef83a0be5c50aa
scope.26.lastMutatedAt=2026-05-29T06:47:15Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=passed
scope.26.lastMutationSites=4
scope.26.lastMutationKilled=4
scope.27.id=function:_clamp_page:219
scope.27.kind=function
scope.27.startLine=219
scope.27.endLine=222
scope.27.semanticHash=a796bea73bf03774
scope.27.lastMutatedAt=2026-05-29T06:47:15Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=2
scope.27.lastMutationKilled=2
scope.28.id=function:_page_next:224
scope.28.kind=function
scope.28.startLine=224
scope.28.endLine=229
scope.28.semanticHash=ca90719558e5265b
scope.28.lastMutatedAt=2026-05-29T06:47:15Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=3
scope.28.lastMutationKilled=3
scope.29.id=function:_page_prev:231
scope.29.kind=function
scope.29.startLine=231
scope.29.endLine=236
scope.29.semanticHash=f1916d9096086a95
scope.29.lastMutatedAt=2026-05-29T06:47:15Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=3
scope.29.lastMutationKilled=3
scope.30.id=function:anonymous@239:239
scope.30.kind=function
scope.30.startLine=239
scope.30.endLine=239
scope.30.semanticHash=2b8509b5927576b5
scope.30.lastMutatedAt=2026-05-29T06:47:15Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=1
scope.30.lastMutationKilled=1
scope.31.id=function:anonymous@240:240
scope.31.kind=function
scope.31.startLine=240
scope.31.endLine=240
scope.31.semanticHash=a674fc45ebbf533a
scope.31.lastMutatedAt=2026-05-29T06:47:15Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=1
scope.31.lastMutationKilled=1
scope.32.id=function:anonymous@241:241
scope.32.kind=function
scope.32.startLine=241
scope.32.endLine=241
scope.32.semanticHash=a007a0d48e3f57ae
scope.32.lastMutatedAt=2026-05-29T06:47:15Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=1
scope.32.lastMutationKilled=1
scope.33.id=function:anonymous@242:242
scope.33.kind=function
scope.33.startLine=242
scope.33.endLine=242
scope.33.semanticHash=467dbf0841655a5e
scope.33.lastMutatedAt=2026-05-29T06:47:15Z
scope.33.lastMutationLane=behavior
scope.33.lastMutationStatus=passed
scope.33.lastMutationSites=1
scope.33.lastMutationKilled=1
scope.34.id=function:anonymous@243:243
scope.34.kind=function
scope.34.startLine=243
scope.34.endLine=243
scope.34.semanticHash=3dc0150394e77abd
scope.34.lastMutatedAt=2026-05-29T06:47:15Z
scope.34.lastMutationLane=behavior
scope.34.lastMutationStatus=passed
scope.34.lastMutationSites=1
scope.34.lastMutationKilled=1
scope.35.id=function:anonymous@244:244
scope.35.kind=function
scope.35.startLine=244
scope.35.endLine=244
scope.35.semanticHash=becb3627b205cbd4
scope.35.lastMutatedAt=2026-05-29T06:47:15Z
scope.35.lastMutationLane=behavior
scope.35.lastMutationStatus=passed
scope.35.lastMutationSites=1
scope.35.lastMutationKilled=1
scope.36.id=function:anonymous@245:245
scope.36.kind=function
scope.36.startLine=245
scope.36.endLine=245
scope.36.semanticHash=d566a0b2dd069614
scope.36.lastMutatedAt=2026-05-29T06:47:15Z
scope.36.lastMutationLane=behavior
scope.36.lastMutationStatus=passed
scope.36.lastMutationSites=1
scope.36.lastMutationKilled=1
scope.37.id=function:skin_panel.handle_action:248
scope.37.kind=function
scope.37.startLine=248
scope.37.endLine=255
scope.37.semanticHash=642eaf3b12a609d9
scope.37.lastMutatedAt=2026-05-29T06:47:15Z
scope.37.lastMutationLane=behavior
scope.37.lastMutationStatus=passed
scope.37.lastMutationSites=6
scope.37.lastMutationKilled=6
]]
