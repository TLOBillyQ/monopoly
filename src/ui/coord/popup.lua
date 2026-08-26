local role_context = require("src.ui.view.role_context")
local with_client_role = require("src.ui.render.support.with_client_role")
local runtime = require("src.ui.render.support.runtime_ui")
local canvas = require("src.ui.coord.canvas_coordinator")
local runtime_state = require("src.ui.state.runtime")
local modal_state = require("src.ui.state.modal")
local popup_assets = require("src.ui.coord.popup_assets")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local item_atlas_view = require("src.ui.render.widgets.item_atlas")
local role_id_utils = require("src.foundation.identity")

local renderer = {}

local function _is_popup_target(target_canvas)
  return target_canvas == canvas.CANVAS_POPUP or target_canvas == canvas.CANVAS_BANKRUPTCY
end

local function _broadcast_keeps_canvas(broadcast, target_canvas)
  return broadcast and _is_popup_target(target_canvas)
end

local function _resolve_modal_canvas_for_ctx(ctx, kind, target_canvas, fallback_canvas, broadcast)
  if _broadcast_keeps_canvas(broadcast, target_canvas) then
    return target_canvas
  end
  if ctx and ctx.can_operate == true then
    return target_canvas
  end
  if kind == "bankruptcy" then
    return target_canvas
  end
  return fallback_canvas
end

-- 旁观者回屏按「关闭时刻」的面板态重解析(与 resolve_canvas_after_popup 的回屏
-- 原则一致,不做开屏快照):展示期间面板被其它流程关掉时,回基础屏而不是过期画面。
-- 面板→canvas 映射住 canvas_coordinator(#583 起与黑市开屏分道共用一份)。
local function _resolve_bystander_return_canvas(state, role_id)
  local ui = state and state.ui
  return canvas.resolve_role_panel_canvas(ui, role_id) or canvas.CANVAS_BASE
end

local function _switch_canvas_for_role(ui, role, target)
  if role then
    canvas.switch_for_role(ui, target, role)
  else
    canvas.switch(ui, target)
  end
end

local function _resolve_role_id(ctx, role)
  return ctx and ctx.role_id or runtime.resolve_role_id(role)
end

-- 旁观者兜底 canvas:仅广播关闭弹窗且操作者本人不开时,把旁观角色切回
-- 其返回 canvas;条件不齐时返回 nil,调用方沿用已解析 canvas。
local function _resolve_bystander_canvas(state, ctx, role, switch_ctx)
  if not (switch_ctx.broadcast and not switch_ctx.is_opening) then
    return nil
  end
  local role_id = _resolve_role_id(ctx, role)
  if role_id == nil or role_id_utils.equals(role_id, switch_ctx.operator_role_id) then
    return nil
  end
  return _resolve_bystander_return_canvas(state, role_id)
end

-- #583:旁观者回图鉴屏前清掉陈旧放大卡——放大覆盖层三节点住图鉴 canvas,
-- 不清理会随回屏复活/滞留。本函数在 with_client_role 扇出内被调,覆盖层
-- 显隐按 per-role 落到该旁观者客户端。
local function _clear_stale_atlas_enlarged(state)
  local atlas = state.ui and state.ui.item_atlas
  if type(atlas) ~= "table" then
    return
  end
  atlas.selected_item_id = nil
  item_atlas_view.hide_enlarged(state)
end

-- 买家免展示口径(2026-08-25):载荷排除的角色(黑市买家)开屏不切去弹窗、
-- 收屏也不回切——其 canvas 全程未离开(黑市屏不动),任何切换都是多余抖动。
local function _is_excluded_role(switch_ctx, ctx, role)
  if switch_ctx.exclude_role_id == nil then
    return false
  end
  local role_id = _resolve_role_id(ctx, role)
  return role_id ~= nil and role_id_utils.equals(role_id, switch_ctx.exclude_role_id)
end

local function _resolve_and_switch_for_role(state, role, switch_ctx)
  local current_model = runtime_state.get_ui_model(state)
  local ctx = role_context.resolve(role, current_model, { runtime = runtime })
  if _is_excluded_role(switch_ctx, ctx, role) then
    return
  end
  local resolved = _resolve_modal_canvas_for_ctx(ctx, switch_ctx.kind, switch_ctx.target_canvas, switch_ctx.fallback_canvas, switch_ctx.broadcast)
  if resolved == nil then
    return
  end
  local bystander = _resolve_bystander_canvas(state, ctx, role, switch_ctx)
  if bystander == item_atlas_nodes.canvas then
    _clear_stale_atlas_enlarged(state)
  end
  _switch_canvas_for_role(state.ui, role, bystander or resolved)
end

function renderer.switch_popup_canvas(state, kind, target_canvas, fallback_canvas)
  local ui = state.ui
  local switch_ctx = {
    kind = kind,
    target_canvas = target_canvas,
    fallback_canvas = fallback_canvas,
    broadcast = ui and ui.popup_broadcast == true,
    exclude_role_id = ui and ui.popup_exclude_role_id or nil,
    is_opening = _is_popup_target(target_canvas),
    operator_role_id = modal_state.operator_role_id(state),
  }

  runtime.for_each_role_or_global(function(role)
    with_client_role(runtime, role, function()
      _resolve_and_switch_for_role(state, role, switch_ctx)
    end)
  end)
  runtime.set_client_role(nil)
end

local function _render_bankruptcy_popup(state, payload)
  local ui = state.ui
  local screen = ui.bankruptcy_screen
  renderer.switch_popup_canvas(state, "bankruptcy", canvas.CANVAS_BANKRUPTCY, nil)
  if screen and screen.text then
    ui:set_label(screen.text, popup_assets.resolve_bankruptcy_text(payload))
  end
  popup_assets.set_bankruptcy_avatar_image(state, payload)
  if screen and screen.root then
    ui:set_visible(screen.root, true)
  end
end
local function _render_card_popup(state, kind, payload)
  local ui = state.ui
  local popup = ui.popup_screen
  renderer.switch_popup_canvas(state, kind, canvas.CANVAS_POPUP, nil)
  ui:set_label(popup.title, payload.title)
  popup_assets.set_popup_card_image(state, payload)
  if popup and popup.root then
    ui:set_visible(popup.root, true)
  end
end
function renderer.show_popup(state, payload)
  local ui = state.ui
  -- kind 缺省(nil)与 "card" 同走卡牌分支;popup_kind 的三个读者
  -- (本文件 _hide_popup、popup_presenter、modal)对 nil 各自回落卡牌,
  -- 这里的 `or "card"` 与 _hide_popup 的成对死防御(#262 删除)。
  local kind = payload.kind
  ui.popup_kind = kind
  if kind == "bankruptcy" then
    _render_bankruptcy_popup(state, payload)
  else
    _render_card_popup(state, kind, payload)
  end
  popup_assets.set_popup_dismiss_touch(ui, true)
end

renderer.show = renderer.show_popup
local function _hide_bankruptcy_popup(state)
  local ui = state.ui
  local screen = ui.bankruptcy_screen
  if screen and screen.root then
    ui:set_visible(screen.root, false)
  end
  popup_assets.set_bankruptcy_avatar_image(state, nil)
end
local function _hide_card_popup(state)
  local ui = state.ui
  if ui.popup_screen and ui.popup_screen.root then
    ui:set_visible(ui.popup_screen.root, false)
  end
  popup_assets.set_popup_card_image(state, nil)
end
local function _hide_popup(state)
  local ui = state.ui
  if ui.popup_kind == "bankruptcy" then
    _hide_bankruptcy_popup(state)
  else
    _hide_card_popup(state)
  end
  popup_assets.set_popup_dismiss_touch(ui, false)
end

renderer.hide = _hide_popup

return renderer

--[[ mutate4lua-manifest
version=4
projectHash=42b537791a038d41
scope.0.id=chunk:src/ui/coord/popup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=193
scope.0.semanticHash=8b910c2d6fae2d47
scope.1.id=function:_is_popup_target
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=16
scope.1.semanticHash=011bb4e329947854
scope.2.id=function:_broadcast_keeps_canvas
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=ae1c7b43edb1d9a1
scope.3.id=function:_resolve_modal_canvas_for_ctx
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=33
scope.3.semanticHash=d2f25e19de9a0dd7
scope.4.id=function:_resolve_bystander_return_canvas
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=41
scope.4.semanticHash=252d12361cae6ebd
scope.5.id=function:_switch_canvas_for_role
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=49
scope.5.semanticHash=315f6c47777a341f
scope.6.id=function:_resolve_role_id
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=53
scope.6.semanticHash=57ed54f641b77289
scope.7.id=function:_resolve_bystander_canvas
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=66
scope.7.semanticHash=8c7bc278253ef40a
scope.8.id=function:_clear_stale_atlas_enlarged
scope.8.kind=function
scope.8.startLine=71
scope.8.endLine=78
scope.8.semanticHash=0ffbb7fca04cb8ce
scope.9.id=function:_is_excluded_role
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=88
scope.9.semanticHash=1ca4d503685c8f19
scope.10.id=function:_resolve_and_switch_for_role
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=105
scope.10.semanticHash=8a1e7791bcc98dd8
scope.11.id=function:renderer.switch_popup_canvas
scope.11.kind=function
scope.11.startLine=107
scope.11.endLine=125
scope.11.semanticHash=9f149ae138757755
scope.12.id=function:<anonymous>
scope.12.kind=function
scope.12.startLine=119
scope.12.endLine=123
scope.12.semanticHash=4a00cfb8dadf7d0f
scope.13.id=function:<anonymous>#2
scope.13.kind=function
scope.13.startLine=120
scope.13.endLine=122
scope.13.semanticHash=4ac65c65acb92f3b
scope.14.id=function:_render_bankruptcy_popup
scope.14.kind=function
scope.14.startLine=127
scope.14.endLine=138
scope.14.semanticHash=d19b7cde2d2800df
scope.15.id=function:_render_card_popup
scope.15.kind=function
scope.15.startLine=139
scope.15.endLine=148
scope.15.semanticHash=ba11cbbd37d463f8
scope.16.id=function:renderer.show_popup
scope.16.kind=function
scope.16.startLine=149
scope.16.endLine=162
scope.16.semanticHash=609e0103a08d555d
scope.17.id=function:_hide_bankruptcy_popup
scope.17.kind=function
scope.17.startLine=165
scope.17.endLine=172
scope.17.semanticHash=1345ff882832d47b
scope.18.id=function:_hide_card_popup
scope.18.kind=function
scope.18.startLine=173
scope.18.endLine=179
scope.18.semanticHash=8b8df79e77def259
scope.19.id=function:_hide_popup
scope.19.kind=function
scope.19.startLine=180
scope.19.endLine=188
scope.19.semanticHash=feb53ffc15c5541f
]]
