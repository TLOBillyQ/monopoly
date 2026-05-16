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
  skin_panel.close(state)
  item_atlas.close(state)
  local compat = _ensure_compat_state(state)
  compat.open = false
  compat.mode = nil
  return compat
end

local function _page_next(state)
  skin_panel.page_next(state)
  return _sync_from_skin_panel(state)
end

local function _page_prev(state)
  skin_panel.page_prev(state)
  return _sync_from_skin_panel(state)
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
  if action == "next" then
    return _page_next(state)
  end
  if action == "prev" then
    return _page_prev(state)
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
