local role_context = require("src.ui.view.role_context")
local with_client_role = require("src.ui.utils.with_client_role")
local runtime = require("src.ui.render.runtime_ui")
local canvas = require("src.ui.coord.canvas_coordinator")
local runtime_state = require("src.ui.state.runtime")
local popup_assets = require("src.ui.coord.popup_assets")
local renderer = {}
local function _resolve_modal_canvas_for_ctx(ctx, kind, target_canvas, fallback_canvas)
  if ctx and ctx.can_operate == true then
    return target_canvas
  end
  if kind == "bankruptcy" then
    return target_canvas
  end
  return fallback_canvas
end
local function _switch_canvas_for_role(ui, role, target)
  if role then
    canvas.switch_for_role(ui, target, role)
  else
    canvas.switch(ui, target)
  end
end
function renderer.switch_popup_canvas(state, kind, target_canvas, fallback_canvas)
  local ui = state.ui
  runtime.for_each_role_or_global(function(role)
    with_client_role(runtime, role, function()
      local current_model = runtime_state.get_ui_model(state)
      local ctx = role_context.resolve(role, current_model, { runtime = runtime })
      local resolved = _resolve_modal_canvas_for_ctx(ctx, kind, target_canvas, fallback_canvas)
      if resolved ~= nil then
        _switch_canvas_for_role(ui, role, resolved)
      end
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
  local kind = payload.kind or "card"
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
  if (ui.popup_kind or "card") == "bankruptcy" then
    _hide_bankruptcy_popup(state)
  else
    _hide_card_popup(state)
  end
  popup_assets.set_popup_dismiss_touch(ui, false)
end

renderer.hide = _hide_popup

return renderer

--[[ mutate4lua-manifest
version=2
projectHash=70d5f175f88dd6e2
scope.0.id=chunk:src/ui/coord/popup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=7674e02dcc9a5cf7
scope.1.id=function:_resolve_modal_canvas_for_ctx:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=16
scope.1.semanticHash=e9a1b954d76a5be5
scope.2.id=function:_switch_canvas_for_role:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=23
scope.2.semanticHash=57217efddb03fc48
scope.3.id=function:anonymous@27:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=34
scope.3.semanticHash=cc9850d46c1fdeb1
scope.4.id=function:anonymous@26:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=35
scope.4.semanticHash=e55b807a24be74fd
scope.5.id=function:renderer.switch_popup_canvas:24
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=37
scope.5.semanticHash=4d3c4cdab58aeaf5
scope.6.id=function:_render_bankruptcy_popup:39
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=50
scope.6.semanticHash=f3cc02899d2e11b9
scope.7.id=function:_render_card_popup:51
scope.7.kind=function
scope.7.startLine=51
scope.7.endLine=60
scope.7.semanticHash=925b6b5fd32210e2
scope.8.id=function:renderer.show_popup:61
scope.8.kind=function
scope.8.startLine=61
scope.8.endLine=71
scope.8.semanticHash=5211996512f17fd4
scope.9.id=function:_hide_bankruptcy_popup:74
scope.9.kind=function
scope.9.startLine=74
scope.9.endLine=81
scope.9.semanticHash=aebfa6809c48cc9f
scope.10.id=function:_hide_card_popup:82
scope.10.kind=function
scope.10.startLine=82
scope.10.endLine=88
scope.10.semanticHash=5acb77ce88a2a3a9
scope.11.id=function:_hide_popup:89
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=97
scope.11.semanticHash=92ec766bac6e5424
]]
