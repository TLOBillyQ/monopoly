-- item_atlas 面板面(自 screens/item_atlas.lua 拆分,>100 mutation sites 行为保持):
-- 开屏/翻页/图集选择/放大隐藏/点击派发。
-- #543:图鉴放大卡回归纯浏览用途,不再承担获得展示,dismiss 只收浏览放大卡,
-- 不向回合机派发 action_anim_done(获得展示的提前关闭归卡牌展示屏弹窗)。
local number_utils = require("src.foundation.number")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local item_atlas_view = require("src.ui.render.widgets.item_atlas")
local panel_helpers = require("src.ui.render.support.panel_helpers")
local panel_tip = require("src.ui.coord.panel_tip")
local atlas_state = require("src.ui.screens.item_atlas.item_atlas_state")

local panel = {}

local function _notify(text, key)
  panel_tip.enqueue("ui.item_atlas", text, key)
end

local function _refresh_page_for_owner(state, atlas)
  return panel_helpers.with_owner_role(state, atlas.role_id, function()
    return item_atlas_view.refresh_page(state, atlas_state.catalog(), atlas.page_index)
  end)
end

local function _hide_enlarged_for_owner(state, atlas)
  return panel_helpers.with_owner_role(state, atlas.role_id, function()
    return item_atlas_view.hide_enlarged(state)
  end)
end

-- 选中态 + 放大覆盖层显隐的原子清理(#583):open/close/翻页/点空白/取消选中
-- 全部经此收口——close 曾漏掉这对调用,导致陈旧放大卡随图鉴 canvas 复活。
local function _clear_enlarged(state, atlas)
  atlas.selected_item_id = nil
  return _hide_enlarged_for_owner(state, atlas)
end

local function _show_enlarged_for_owner(state, atlas, item_id)
  return panel_helpers.with_owner_role(state, atlas.role_id, function()
    return item_atlas_view.show_enlarged(state, item_id)
  end)
end

function panel.open(state, role_id)
  local atlas = atlas_state.ensure(state)
  atlas.open = true
  atlas.role_id = role_id
  atlas.page_index = atlas_state.clamp_page(atlas.page_index)
  canvas.switch_by_role_id(state and state.ui, item_atlas_nodes.canvas, role_id)
  _refresh_page_for_owner(state, atlas)
  _clear_enlarged(state, atlas)
  _notify("图鉴已打开", "item_atlas:open:" .. tostring(role_id))
  return atlas
end

-- #583:close 与 open/翻页/点空白同口径经 _clear_enlarged 清理放大覆盖层
-- (选中态 + 三节点 per-role 显隐)——覆盖层住图鉴 canvas,关屏不清会让陈旧
-- 放大卡随图鉴 canvas 的下次显示复活/滞留。覆盖层显隐按图鉴 owner
-- (atlas.role_id)落,与关屏 canvas 切换的显式 role_id 互不干扰。
function panel.close(state, role_id)
  local atlas = atlas_state.ensure(state)
  atlas.open = false
  _clear_enlarged(state, atlas)
  canvas.switch_by_role_id(state and state.ui, base_nodes.canvas, role_id or atlas.role_id)
  _notify("已关闭", "item_atlas:close")
  return atlas
end

local function _move_page(state, role_id, delta)
  local atlas = atlas_state.ensure(state)
  atlas.role_id = role_id or atlas.role_id
  atlas.page_index = atlas_state.clamp_page(atlas.page_index + delta)
  _refresh_page_for_owner(state, atlas)
  _clear_enlarged(state, atlas)
  return atlas
end

local function _page_next(state, role_id)
  return _move_page(state, role_id, 1)
end

local function _page_prev(state, role_id)
  return _move_page(state, role_id, -1)
end

local function _dismiss(state, role_id)
  local atlas = atlas_state.ensure(state)
  atlas.role_id = role_id or atlas.role_id
  _clear_enlarged(state, atlas)
  return atlas
end

local function _select_slot(state, slot_index, role_id)
  local atlas = atlas_state.ensure(state)
  atlas.role_id = role_id or atlas.role_id
  local item = atlas_state.item_at(atlas, slot_index)
  if item and atlas.selected_item_id == item.id then
    _clear_enlarged(state, atlas)
  elseif item then
    atlas.selected_item_id = item.id
    _show_enlarged_for_owner(state, atlas, item.id)
  end
  return atlas
end

local _STRING_ACTION_HANDLERS = {
  close   = function(state, role_id, _)    return panel.close(state, role_id) end,
  next    = function(state, role_id, _)    return _page_next(state, role_id) end,
  prev    = function(state, role_id, _)    return _page_prev(state, role_id) end,
  dismiss = function(state, role_id, _)    return _dismiss(state, role_id) end,
}

local function _ensure_atlas_for_role(state, role_id)
  local atlas = atlas_state.ensure(state)
  atlas.role_id = role_id or atlas.role_id
  return atlas
end

function panel.handle_action(state, action, role_id)
  local handler = _STRING_ACTION_HANDLERS[action]
  if handler then return handler(state, role_id, action) end
  -- select 分支必须无条件调 _select_slot（slot_index 允许为 nil）。
  if type(action) == "table" and action.type == "select" then
    return _select_slot(state, action.slot_index, role_id)
  end
  local slot_index = number_utils.to_integer(action)
  if slot_index ~= nil then return _select_slot(state, slot_index, role_id) end
  return _ensure_atlas_for_role(state, role_id)
end

return panel

--[[ mutate4lua-manifest
version=4
projectHash=a9c0434b4b5eb6a0
scope.0.id=chunk:src/ui/screens/item_atlas/panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=133
scope.0.semanticHash=606c9737d8921bbf
scope.1.id=function:_notify
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=5e40ff65f5cc8d6c
scope.2.id=function:_refresh_page_for_owner
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=24
scope.2.semanticHash=8df984c3d558b389
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=ef900a41f9da18c6
scope.4.id=function:_hide_enlarged_for_owner
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=30
scope.4.semanticHash=7f1729f5e77de5e1
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=29
scope.5.semanticHash=7bbf31ab6751de78
scope.6.id=function:_clear_enlarged
scope.6.kind=function
scope.6.startLine=34
scope.6.endLine=37
scope.6.semanticHash=35474dea92aea862
scope.7.id=function:_show_enlarged_for_owner
scope.7.kind=function
scope.7.startLine=39
scope.7.endLine=43
scope.7.semanticHash=645aa125908869b7
scope.8.id=function:<anonymous>#3
scope.8.kind=function
scope.8.startLine=40
scope.8.endLine=42
scope.8.semanticHash=5076d53a4090f1e9
scope.9.id=function:panel.open
scope.9.kind=function
scope.9.startLine=45
scope.9.endLine=55
scope.9.semanticHash=14ff508ca19b1465
scope.10.id=function:panel.close
scope.10.kind=function
scope.10.startLine=61
scope.10.endLine=68
scope.10.semanticHash=9dafc065772a5208
scope.11.id=function:_move_page
scope.11.kind=function
scope.11.startLine=70
scope.11.endLine=77
scope.11.semanticHash=3ba32ac07a8304c9
scope.12.id=function:_page_next
scope.12.kind=function
scope.12.startLine=79
scope.12.endLine=81
scope.12.semanticHash=86fdcac65d7d3c39
scope.13.id=function:_page_prev
scope.13.kind=function
scope.13.startLine=83
scope.13.endLine=85
scope.13.semanticHash=56d754098456a122
scope.14.id=function:_dismiss
scope.14.kind=function
scope.14.startLine=87
scope.14.endLine=92
scope.14.semanticHash=908e2ce937dd6176
scope.15.id=function:_select_slot
scope.15.kind=function
scope.15.startLine=94
scope.15.endLine=105
scope.15.semanticHash=dff46d6a147ae15a
scope.16.id=function:<anonymous>#4
scope.16.kind=function
scope.16.startLine=108
scope.16.endLine=108
scope.16.semanticHash=3c26bf1ea8e4b724
scope.17.id=function:<anonymous>#5
scope.17.kind=function
scope.17.startLine=109
scope.17.endLine=109
scope.17.semanticHash=3c26bf1ea8e4b724
scope.18.id=function:<anonymous>#6
scope.18.kind=function
scope.18.startLine=110
scope.18.endLine=110
scope.18.semanticHash=3c26bf1ea8e4b724
scope.19.id=function:<anonymous>#7
scope.19.kind=function
scope.19.startLine=111
scope.19.endLine=111
scope.19.semanticHash=3c26bf1ea8e4b724
scope.20.id=function:_ensure_atlas_for_role
scope.20.kind=function
scope.20.startLine=114
scope.20.endLine=118
scope.20.semanticHash=95fc57be4dc4a83a
scope.21.id=function:panel.handle_action
scope.21.kind=function
scope.21.startLine=120
scope.21.endLine=130
scope.21.semanticHash=a734f19cbc47a1b3
]]
