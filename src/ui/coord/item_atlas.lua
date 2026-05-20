local _default_catalog = require("src.config.content.item_atlas")
local host_runtime_ports = require("src.ui.host_bridge")
local number_utils = require("src.foundation.number")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local item_atlas_view = require("src.ui.render.item_atlas")

local item_atlas = {}

local PAGE_SIZE = 8
local _catalog = _default_catalog

local function _ensure_state(state)
  assert(state ~= nil, "missing state")
  local ui = assert(state.ui, "missing state.ui")
  ui.item_atlas = ui.item_atlas or {
    open = false,
    page_index = 1,
    selected_item_id = nil,
  }
  return ui.item_atlas
end

local function _page_count()
  return math.max(1, math.floor((#_catalog + PAGE_SIZE - 1) / PAGE_SIZE))
end

local function _clamp_page(page_index)
  local page = number_utils.to_integer(page_index) or 1
  return number_utils.clamp(page, 1, _page_count())
end

local function _item_at(atlas, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return _catalog[(atlas.page_index - 1) * PAGE_SIZE + slot]
end

local function _notify(text, key)
  host_runtime_ports.enqueue_tip({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = "ui.item_atlas",
  })
end

function item_atlas.open(state, role_id)
  local atlas = _ensure_state(state)
  atlas.open = true
  atlas.role_id = role_id
  atlas.page_index = _clamp_page(atlas.page_index)
  atlas.selected_item_id = nil
  canvas.switch_by_role_id(state and state.ui, item_atlas_nodes.canvas, role_id)
  item_atlas_view.refresh_page(state, _catalog, atlas.page_index)
  item_atlas_view.hide_enlarged(state)
  _notify("图鉴已打开", "item_atlas:open:" .. tostring(role_id))
  return atlas
end

function item_atlas.close(state, role_id)
  local atlas = _ensure_state(state)
  atlas.open = false
  canvas.switch_by_role_id(state and state.ui, base_nodes.canvas, role_id or atlas.role_id)
  _notify("已关闭", "item_atlas:close")
  return atlas
end

local function _page_next(state)
  local atlas = _ensure_state(state)
  atlas.page_index = _clamp_page(atlas.page_index + 1)
  atlas.selected_item_id = nil
  item_atlas_view.refresh_page(state, _catalog, atlas.page_index)
  item_atlas_view.hide_enlarged(state)
  return atlas
end

local function _page_prev(state)
  local atlas = _ensure_state(state)
  atlas.page_index = _clamp_page(atlas.page_index - 1)
  atlas.selected_item_id = nil
  item_atlas_view.refresh_page(state, _catalog, atlas.page_index)
  item_atlas_view.hide_enlarged(state)
  return atlas
end

local function _dismiss(state)
  local atlas = _ensure_state(state)
  atlas.selected_item_id = nil
  item_atlas_view.hide_enlarged(state)
  return atlas
end

local function _select_slot(state, slot_index)
  local atlas = _ensure_state(state)
  local item = _item_at(atlas, slot_index)
  if item and atlas.selected_item_id == item.id then
    atlas.selected_item_id = nil
    item_atlas_view.hide_enlarged(state)
  elseif item then
    atlas.selected_item_id = item.id
    item_atlas_view.show_enlarged(state, item.id)
  end
  return atlas
end

local _STRING_ACTION_HANDLERS = {
  close   = function(state, _, _)    return item_atlas.close(state) end,
  next    = function(state, _, _)    return _page_next(state) end,
  prev    = function(state, _, _)    return _page_prev(state) end,
  dismiss = function(state, _, _)    return _dismiss(state) end,
}

function item_atlas.handle_action(state, action, role_id)
  local handler = _STRING_ACTION_HANDLERS[action]
  if handler then return handler(state, role_id, action) end
  if type(action) == "table" and action.type == "select" then
    return _select_slot(state, action.slot_index)
  end
  local slot_index = number_utils.to_integer(action)
  if slot_index ~= nil then return _select_slot(state, slot_index) end
  local atlas = _ensure_state(state)
  atlas.role_id = role_id or atlas.role_id
  return atlas
end

function item_atlas.configure_catalog_for_tests(catalog)
  _catalog = catalog or _default_catalog
  item_atlas.catalog = _catalog
end

function item_atlas.reset_for_tests()
  _catalog = _default_catalog
  item_atlas.catalog = _catalog
end

item_atlas.catalog = _catalog

return item_atlas
