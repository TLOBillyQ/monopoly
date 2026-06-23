local _default_catalog = require("src.config.content.item_atlas")
local number_utils = require("src.foundation.number")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local item_atlas_view = require("src.ui.render.item_atlas")
local panel_helpers = require("src.ui.coord.panel_helpers")
local panel_tip = require("src.ui.coord.panel_tip")
local role_id_utils = require("src.foundation.identity")

local item_atlas = {}

local PAGE_SIZE = item_atlas_nodes.page_size
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

local function _clamp_page(page_index)
  local page = number_utils.to_integer(page_index)
  if page == nil then
    return 1
  end
  return number_utils.clamp(page, 1, number_utils.page_count(#_catalog, PAGE_SIZE))
end

local function _item_at(atlas, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return _catalog[(atlas.page_index - 1) * PAGE_SIZE + slot]
end

local function _notify(text, key)
  panel_tip.enqueue("ui.item_atlas", text, key)
end

local function _refresh_page_for_owner(state, atlas)
  return panel_helpers.with_owner_role(state, atlas.role_id, function()
    return item_atlas_view.refresh_page(state, _catalog, atlas.page_index)
  end)
end

local function _hide_enlarged_for_owner(state, atlas)
  return panel_helpers.with_owner_role(state, atlas.role_id, function()
    return item_atlas_view.hide_enlarged(state)
  end)
end

local function _show_enlarged_for_owner(state, atlas, item_id)
  return panel_helpers.with_owner_role(state, atlas.role_id, function()
    return item_atlas_view.show_enlarged(state, item_id)
  end)
end

local function _current_item_get_reveal(state)
  local anim = state
    and state.game
    and state.game.turn
    and state.game.turn.action_anim
    or nil
  if anim and anim.kind == "item_get_reveal" then
    return anim
  end
  return nil
end

local function _complete_reveal_if_owner(state, actor_role_id)
  local anim = _current_item_get_reveal(state)
  if anim == nil then
    return
  end
  local owner_role_id = anim.owner_role_id or anim.player_id
  if not role_id_utils.equals(actor_role_id, owner_role_id) then
    return
  end
  local game = state and state.game or nil
  if game and type(game.dispatch_action) == "function" then
    game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
  end
end

function item_atlas.open(state, role_id)
  local atlas = _ensure_state(state)
  atlas.open = true
  atlas.role_id = role_id
  atlas.page_index = _clamp_page(atlas.page_index)
  atlas.selected_item_id = nil
  canvas.switch_by_role_id(state and state.ui, item_atlas_nodes.canvas, role_id)
  _refresh_page_for_owner(state, atlas)
  _hide_enlarged_for_owner(state, atlas)
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

local function _move_page(state, role_id, delta)
  local atlas = _ensure_state(state)
  atlas.role_id = role_id or atlas.role_id
  atlas.page_index = _clamp_page(atlas.page_index + delta)
  atlas.selected_item_id = nil
  _refresh_page_for_owner(state, atlas)
  _hide_enlarged_for_owner(state, atlas)
  return atlas
end

local function _page_next(state, role_id)
  return _move_page(state, role_id, 1)
end

local function _page_prev(state, role_id)
  return _move_page(state, role_id, -1)
end

local function _dismiss(state, role_id)
  local atlas = _ensure_state(state)
  atlas.role_id = role_id or atlas.role_id
  atlas.selected_item_id = nil
  _hide_enlarged_for_owner(state, atlas)
  _complete_reveal_if_owner(state, atlas.role_id)
  return atlas
end

local function _select_slot(state, slot_index, role_id)
  local atlas = _ensure_state(state)
  atlas.role_id = role_id or atlas.role_id
  local item = _item_at(atlas, slot_index)
  if item and atlas.selected_item_id == item.id then
    atlas.selected_item_id = nil
    _hide_enlarged_for_owner(state, atlas)
  elseif item then
    atlas.selected_item_id = item.id
    _show_enlarged_for_owner(state, atlas, item.id)
  end
  return atlas
end

local _STRING_ACTION_HANDLERS = {
  close   = function(state, role_id, _)    return item_atlas.close(state, role_id) end,
  next    = function(state, role_id, _)    return _page_next(state, role_id) end,
  prev    = function(state, role_id, _)    return _page_prev(state, role_id) end,
  dismiss = function(state, role_id, _)    return _dismiss(state, role_id) end,
}

function item_atlas.handle_action(state, action, role_id)
  local handler = _STRING_ACTION_HANDLERS[action]
  if handler then return handler(state, role_id, action) end
  if type(action) == "table" and action.type == "select" then
    return _select_slot(state, action.slot_index, role_id)
  end
  local slot_index = number_utils.to_integer(action)
  if slot_index ~= nil then return _select_slot(state, slot_index, role_id) end
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

--[[ mutate4lua-manifest
version=2
projectHash=a4d66329e1a3b2e5
scope.0.id=chunk:src/ui/coord/item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=170
scope.0.semanticHash=4a87e3a2ddd2c936
scope.0.lastMutatedAt=2026-05-25T13:32:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_ensure_state:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=26
scope.1.semanticHash=d0fe462103f94789
scope.1.lastMutatedAt=2026-05-25T13:32:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_clamp_page:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=34
scope.2.semanticHash=0ea6d6fc3dc99cf0
scope.2.lastMutatedAt=2026-05-25T13:32:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_item_at:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=39
scope.3.semanticHash=ba79f8226e68649e
scope.3.lastMutatedAt=2026-05-25T13:32:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_notify:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=43
scope.4.semanticHash=2aa67e11cfa65811
scope.4.lastMutatedAt=2026-05-25T13:32:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_resolve_runtime:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=48
scope.5.semanticHash=e6aff2eac7167a35
scope.5.lastMutatedAt=2026-05-25T13:32:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=4
scope.5.lastMutationKilled=4
scope.6.id=function:_with_owner_role:50
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=56
scope.6.semanticHash=9cbcf6d6f6eb4930
scope.6.lastMutatedAt=2026-05-25T13:32:24Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:anonymous@59:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=61
scope.7.semanticHash=0e24d8c5455f00a2
scope.7.lastMutatedAt=2026-05-25T13:32:24Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:_refresh_page_for_owner:58
scope.8.kind=function
scope.8.startLine=58
scope.8.endLine=62
scope.8.semanticHash=9e1812a05ec15b83
scope.8.lastMutatedAt=2026-05-25T13:32:24Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:anonymous@65:65
scope.9.kind=function
scope.9.startLine=65
scope.9.endLine=67
scope.9.semanticHash=c4a47cdcc00239ef
scope.9.lastMutatedAt=2026-05-25T13:32:24Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=no_sites
scope.9.lastMutationSites=0
scope.9.lastMutationKilled=0
scope.10.id=function:_hide_enlarged_for_owner:64
scope.10.kind=function
scope.10.startLine=64
scope.10.endLine=68
scope.10.semanticHash=f9bee9a19890665c
scope.10.lastMutatedAt=2026-05-25T13:32:24Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:anonymous@71:71
scope.11.kind=function
scope.11.startLine=71
scope.11.endLine=73
scope.11.semanticHash=67307b60d0002801
scope.11.lastMutatedAt=2026-05-25T13:32:24Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=no_sites
scope.11.lastMutationSites=0
scope.11.lastMutationKilled=0
scope.12.id=function:_show_enlarged_for_owner:70
scope.12.kind=function
scope.12.startLine=70
scope.12.endLine=74
scope.12.semanticHash=ab9c7e8afa2ab800
scope.12.lastMutatedAt=2026-05-25T13:32:24Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:item_atlas.open:76
scope.13.kind=function
scope.13.startLine=76
scope.13.endLine=87
scope.13.semanticHash=9d06167fe31099d8
scope.13.lastMutatedAt=2026-05-25T13:32:24Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=7
scope.13.lastMutationKilled=7
scope.14.id=function:item_atlas.close:89
scope.14.kind=function
scope.14.startLine=89
scope.14.endLine=95
scope.14.semanticHash=3787004c71e2bd6b
scope.14.lastMutatedAt=2026-05-25T13:32:24Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=4
scope.14.lastMutationKilled=4
scope.15.id=function:_move_page:97
scope.15.kind=function
scope.15.startLine=97
scope.15.endLine=105
scope.15.semanticHash=f42fa43d4a155ef4
scope.15.lastMutatedAt=2026-05-25T13:32:24Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=5
scope.15.lastMutationKilled=5
scope.16.id=function:_page_next:107
scope.16.kind=function
scope.16.startLine=107
scope.16.endLine=109
scope.16.semanticHash=9ec0fd3e59765eaf
scope.16.lastMutatedAt=2026-05-25T13:32:24Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
scope.17.id=function:_page_prev:111
scope.17.kind=function
scope.17.startLine=111
scope.17.endLine=113
scope.17.semanticHash=e4e8530a46aeb2d8
scope.17.lastMutatedAt=2026-05-25T13:32:24Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:_dismiss:115
scope.18.kind=function
scope.18.startLine=115
scope.18.endLine=121
scope.18.semanticHash=bec0a7a88d4a03e3
scope.18.lastMutatedAt=2026-05-25T13:32:24Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=3
scope.18.lastMutationKilled=3
scope.19.id=function:_select_slot:123
scope.19.kind=function
scope.19.startLine=123
scope.19.endLine=135
scope.19.semanticHash=c4fa4e0d3f283669
scope.19.lastMutatedAt=2026-05-25T13:32:24Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=7
scope.19.lastMutationKilled=7
scope.20.id=function:anonymous@138:138
scope.20.kind=function
scope.20.startLine=138
scope.20.endLine=138
scope.20.semanticHash=e953b99df82dd68a
scope.20.lastMutatedAt=2026-05-25T13:32:24Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:anonymous@139:139
scope.21.kind=function
scope.21.startLine=139
scope.21.endLine=139
scope.21.semanticHash=c8f008c74fddfb55
scope.21.lastMutatedAt=2026-05-25T13:32:24Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=1
scope.21.lastMutationKilled=1
scope.22.id=function:anonymous@140:140
scope.22.kind=function
scope.22.startLine=140
scope.22.endLine=140
scope.22.semanticHash=ca88ceca90c2c1c1
scope.22.lastMutatedAt=2026-05-25T13:32:24Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=1
scope.22.lastMutationKilled=1
scope.23.id=function:anonymous@141:141
scope.23.kind=function
scope.23.startLine=141
scope.23.endLine=141
scope.23.semanticHash=c67f0a8180ae5530
scope.23.lastMutatedAt=2026-05-25T13:32:24Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:item_atlas.handle_action:144
scope.24.kind=function
scope.24.startLine=144
scope.24.endLine=155
scope.24.semanticHash=ba60047c6ba9bb25
scope.24.lastMutatedAt=2026-05-25T13:32:24Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=13
scope.24.lastMutationKilled=13
scope.25.id=function:item_atlas.configure_catalog_for_tests:157
scope.25.kind=function
scope.25.startLine=157
scope.25.endLine=160
scope.25.semanticHash=b3942110091c7757
scope.25.lastMutatedAt=2026-05-25T13:32:24Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=1
scope.25.lastMutationKilled=1
scope.26.id=function:item_atlas.reset_for_tests:162
scope.26.kind=function
scope.26.startLine=162
scope.26.endLine=165
scope.26.semanticHash=4b95fb3133a2fe69
scope.26.lastMutatedAt=2026-05-25T13:32:24Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=no_sites
scope.26.lastMutationSites=0
scope.26.lastMutationKilled=0
]]
