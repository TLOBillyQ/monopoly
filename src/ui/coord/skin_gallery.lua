local skins = require("src.config.content.skins")
local host_runtime_ports = require("src.ui.host_bridge")
local number_utils = require("src.foundation.lang.number")

local skin_gallery = {}

local PAGE_SIZE = 4

local function _ensure_state(state)
  assert(state ~= nil, "missing state")
  local ui = assert(state.ui, "missing state.ui")
  ui.skin_gallery = ui.skin_gallery or {
    open = false,
    mode = nil,
    page_index = 1,
    owned_by_role = {},
    selected_by_role = {},
  }
  return ui.skin_gallery
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

local function _current_skin(gallery)
  local index = (gallery.page_index - 1) * PAGE_SIZE + 1
  return skins[index]
end

local function _notify(text, key)
  host_runtime_ports.enqueue_tip({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = "ui.skin_gallery",
  })
end

function skin_gallery.open_skin(state, role_id)
  local gallery = _ensure_state(state)
  gallery.open = true
  gallery.mode = "skin"
  gallery.role_id = role_id
  gallery.page_index = _clamp_page(gallery.page_index)
  _notify("皮肤已打开", "skin_gallery:open_skin:" .. tostring(role_id))
  return gallery
end

function skin_gallery.open_gallery(state, role_id)
  local gallery = _ensure_state(state)
  gallery.open = true
  gallery.mode = "gallery"
  gallery.role_id = role_id
  gallery.page_index = _clamp_page(gallery.page_index)
  _notify("图鉴已打开", "skin_gallery:open_gallery:" .. tostring(role_id))
  return gallery
end

function skin_gallery.close(state)
  local gallery = _ensure_state(state)
  gallery.open = false
  gallery.mode = nil
  _notify("已关闭", "skin_gallery:close")
  return gallery
end

function skin_gallery.page_next(state)
  local gallery = _ensure_state(state)
  gallery.page_index = _clamp_page(gallery.page_index + 1)
  return gallery
end

function skin_gallery.page_prev(state)
  local gallery = _ensure_state(state)
  gallery.page_index = _clamp_page(gallery.page_index - 1)
  return gallery
end

function skin_gallery.unlock_current(state, role_id, source)
  local gallery = _ensure_state(state)
  local skin = _current_skin(gallery)
  if not skin then
    return gallery
  end
  local key = _role_key(role_id or gallery.role_id)
  gallery.owned_by_role[key] = gallery.owned_by_role[key] or {}
  gallery.owned_by_role[key][skin.product_id] = true
  _notify(skin.name .. " 已解锁", "skin_gallery:unlock:" .. key .. ":" .. tostring(skin.product_id) .. ":" .. tostring(source))
  return gallery
end

function skin_gallery.equip_current(state, role_id)
  local gallery = _ensure_state(state)
  local skin = _current_skin(gallery)
  if not skin then
    return gallery
  end
  local key = _role_key(role_id or gallery.role_id)
  local owned = gallery.owned_by_role[key] and gallery.owned_by_role[key][skin.product_id] == true
  if not owned then
    _notify("皮肤尚未解锁", "skin_gallery:not_owned:" .. key .. ":" .. tostring(skin.product_id))
    return gallery
  end
  gallery.selected_by_role[key] = skin.product_id
  _notify("已换装 " .. skin.name, "skin_gallery:equip:" .. key .. ":" .. tostring(skin.product_id))
  return gallery
end

function skin_gallery.handle_action(state, action, role_id)
  if action == "close" then
    return skin_gallery.close(state)
  end
  if action == "next" then
    return skin_gallery.page_next(state)
  end
  if action == "prev" then
    return skin_gallery.page_prev(state)
  end
  if action == "buy" or action == "gift" then
    return skin_gallery.unlock_current(state, role_id, action)
  end
  if action == "equip" then
    return skin_gallery.equip_current(state, role_id)
  end
  return _ensure_state(state)
end

skin_gallery.catalog = skins

return skin_gallery
