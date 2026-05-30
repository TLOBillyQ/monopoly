local skin_panel = require("src.ui.coord.skin_panel")
local item_atlas = require("src.ui.coord.item_atlas")

local skin_gallery = {}

local function _ensure_compat_state(state)
  local ui = assert(assert(state, "missing state").ui, "missing state.ui")
  ui.skin_gallery = ui.skin_gallery or {
    open = false,
    mode = nil,
    page_index = 1,
    owned_by_role = {},
    selected_by_role = {},
  }
  return ui.skin_gallery
end

local function _sync_from_skin_panel(state, mode)
  local compat = _ensure_compat_state(state)
  local panel = state.ui.skin_panel
  if panel then
    compat.open = panel.open
    compat.mode = mode or compat.mode
    compat.page_index = panel.page_index
    compat.role_id = panel.role_id
    compat.owned_by_role = panel.owned_by_role
    compat.selected_by_role = panel.selected_by_role
  end
  return compat
end

function skin_gallery.open_skin(state, role_id)
  skin_panel.open(state, role_id)
  return _sync_from_skin_panel(state, "skin")
end

function skin_gallery.open_gallery(state, role_id)
  local atlas = item_atlas.open(state, role_id)
  local compat = _ensure_compat_state(state)
  compat.open = atlas.open
  compat.mode = "gallery"
  compat.role_id = atlas.role_id
  compat.page_index = atlas.page_index
  return compat
end

local function _close(state)
  local compat = _ensure_compat_state(state)
  if compat.mode == "skin" then
    skin_panel.close(state)
  elseif compat.mode == "gallery" then
    item_atlas.close(state)
  end
  compat.open = false
  compat.mode = nil
  return compat
end

local function _unlock_current(state, role_id, source)
  skin_panel.unlock(state, role_id, source, 1)
  return _sync_from_skin_panel(state, "skin")
end

local function _equip_current(state, role_id)
  skin_panel.equip(state, role_id, 1)
  return _sync_from_skin_panel(state, "skin")
end

function skin_gallery.handle_action(state, action, role_id)
  if action == "close" then
    return _close(state)
  end
  if action == "buy" or action == "gift" then
    return _unlock_current(state, role_id, action)
  end
  if action == "equip" then
    return _equip_current(state, role_id)
  end
  return _ensure_compat_state(state)
end

skin_gallery.catalog = skin_panel.catalog

return skin_gallery

--[[ mutate4lua-manifest
version=2
projectHash=9da1fe43fd2769b9
scope.0.id=chunk:src/ui/coord/skin_gallery.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=5d0b4e4decf1b2a4
scope.1.id=function:_ensure_compat_state:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=16
scope.1.semanticHash=79314d53fe9a578a
scope.2.id=function:_sync_from_skin_panel:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=30
scope.2.semanticHash=fb0c00c4a197fb9f
scope.3.id=function:skin_gallery.open_skin:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=35
scope.3.semanticHash=9ba6ec30a0b49c87
scope.4.id=function:skin_gallery.open_gallery:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=45
scope.4.semanticHash=5d033a52b4b46909
scope.5.id=function:_close:47
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=57
scope.5.semanticHash=126cc218bc928d06
scope.6.id=function:_unlock_current:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=62
scope.6.semanticHash=da2b9fd9c7bf129d
scope.7.id=function:_equip_current:64
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=67
scope.7.semanticHash=efa655f4eb661c43
scope.8.id=function:skin_gallery.handle_action:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=80
scope.8.semanticHash=de7d951e335fb850
]]
