local role_avatar = require("src.ui.view.role_avatar")
local role_context = require("src.ui.view.role_context")
local with_client_role = require("src.ui.utils.with_client_role")
local runtime = require("src.ui.render.runtime_ui")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local canvas = require("src.ui.coord.canvas_coordinator")
local runtime_state = require("src.ui.state.runtime")
local runtime_assets = require("src.config.runtime_assets")
local renderer = {}
local _apply_node_image
local function _resolve_popup_image_key(state, payload)
  if not payload then
    return nil
  end
  if payload.image_key ~= nil then
    return payload.image_key
  end
  local image_ref = payload.image_ref
  if image_ref == nil then
    return nil
  end
  local image = runtime_assets.image_for_popup_card(payload.kind, image_ref, {
    refs = state and state.ui_refs or nil,
  })
  return image.ok == true and image.image_key or nil
end
local function _set_popup_dismiss_touch(ui, enabled)
  local popup = ui and ui.popup_screen or nil
  if not popup then
    return
  end
  local nodes = popup.dismiss_nodes
  if type(nodes) ~= "table" then
    return
  end
  for _, name in ipairs(nodes) do
    ui:set_touch_enabled(name, enabled == true)
  end
end
local function _resolve_bankruptcy_text(payload)
  if payload and payload.text and payload.text ~= "" then
    return payload.text
  end
  if payload and payload.reason and payload.reason ~= "" then
    return payload.reason
  end
  if payload and payload.player_name and payload.player_name ~= "" then
    return payload.player_name .. " 破产出局"
  end
  return "破产出局"
end
local function _resolve_bankruptcy_avatar_key(payload)
  if not payload then
    return nil
  end
  if payload.avatar_key ~= nil then
    local sanitized = role_avatar.sanitize_image_key(payload.avatar_key)
    if sanitized ~= nil then
      return sanitized
    end
  end
  local player_id = payload.player_id
  if not player_id then
    return nil
  end
  local role = runtime_ports.resolve_role(player_id)
  if not role then
    return nil
  end
  return role_avatar.resolve_from_role(role)
end
_apply_node_image = function(ui, node_name, node, image_key, empty_key, set_texture, show_when_empty)
  if image_key ~= nil then
    set_texture(node, image_key)
    ui:set_visible(node_name, true)
    return
  end
  if empty_key ~= nil then
    set_texture(node, empty_key)
    ui:set_visible(node_name, show_when_empty == true)
    return
  end
  ui:set_visible(node_name, false)
end
local function _apply_screen_image(state, screen, node_name, image_key, set_texture, show_when_empty)
  local ui = state and state.ui
  if not ui or not screen or not node_name then
    return
  end
  local empty_image = runtime_assets.empty_image({
    refs = state and state.ui_refs or nil,
  })
  _apply_node_image(ui, node_name, ui.query_node(node_name), image_key, empty_image.image_key, set_texture, show_when_empty)
end
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

local function _set_popup_card_image(state, payload)
  local popup = state and state.ui and state.ui.popup_screen or nil
  _apply_screen_image(state, popup, popup and popup.card or nil, _resolve_popup_image_key(state, payload), function(node, key)
    runtime.set_node_texture_keep_size(node, key)
  end, false)
end
local function _set_bankruptcy_avatar_image(state, payload)
  local screen = state and state.ui and state.ui.bankruptcy_screen or nil
  -- Avatar policy: keep base panel and bankruptcy popup on the same native-size path.
  _apply_screen_image(state, screen, screen and screen.avatar or nil, _resolve_bankruptcy_avatar_key(payload), function(node, key)
    runtime.set_node_texture_native_size(node, key)
  end, true)
end
local function _render_bankruptcy_popup(state, payload)
  local ui = state.ui
  local screen = ui.bankruptcy_screen
  renderer.switch_popup_canvas(state, "bankruptcy", canvas.CANVAS_BANKRUPTCY, nil)
  if screen and screen.text then
    ui:set_label(screen.text, _resolve_bankruptcy_text(payload))
  end
  _set_bankruptcy_avatar_image(state, payload)
  if screen and screen.root then
    ui:set_visible(screen.root, true)
  end
end
local function _render_card_popup(state, kind, payload)
  local ui = state.ui
  local popup = ui.popup_screen
  renderer.switch_popup_canvas(state, kind, canvas.CANVAS_POPUP, nil)
  ui:set_label(popup.title, payload.title)
  _set_popup_card_image(state, payload)
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
  _set_popup_dismiss_touch(ui, true)
end

renderer.show = renderer.show_popup
local function _hide_bankruptcy_popup(state)
  local ui = state.ui
  local screen = ui.bankruptcy_screen
  if screen and screen.root then
    ui:set_visible(screen.root, false)
  end
  _set_bankruptcy_avatar_image(state, nil)
end
local function _hide_card_popup(state)
  local ui = state.ui
  if ui.popup_screen and ui.popup_screen.root then
    ui:set_visible(ui.popup_screen.root, false)
  end
  _set_popup_card_image(state, nil)
end
local function _hide_popup(state)
  local ui = state.ui
  if (ui.popup_kind or "card") == "bankruptcy" then
    _hide_bankruptcy_popup(state)
  else
    _hide_card_popup(state)
  end
  _set_popup_dismiss_touch(ui, false)
end

renderer.hide = _hide_popup

return renderer

--[[ mutate4lua-manifest
version=2
projectHash=a40248954bb0a501
scope.0.id=chunk:src/ui/coord/popup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=199
scope.0.semanticHash=11e1fca63b5aa9d5
scope.1.id=function:_resolve_popup_image_key:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=27
scope.1.semanticHash=cc60e27da21ed9fe
scope.2.id=function:_resolve_bankruptcy_text:41
scope.2.kind=function
scope.2.startLine=41
scope.2.endLine=52
scope.2.semanticHash=ddd9a35d8fc4501a
scope.3.id=function:_resolve_bankruptcy_avatar_key:53
scope.3.kind=function
scope.3.startLine=53
scope.3.endLine=72
scope.3.semanticHash=323a6e16a3b8a7e8
scope.4.id=function:anonymous@73:73
scope.4.kind=function
scope.4.startLine=73
scope.4.endLine=85
scope.4.semanticHash=b0cb146a99b270da
scope.5.id=function:_apply_screen_image:86
scope.5.kind=function
scope.5.startLine=86
scope.5.endLine=93
scope.5.semanticHash=3336296701806be1
scope.6.id=function:_should_show_modal_for_ctx:94
scope.6.kind=function
scope.6.startLine=94
scope.6.endLine=99
scope.6.semanticHash=c3cd6a77c23d859d
scope.7.id=function:_switch_canvas_for_role:100
scope.7.kind=function
scope.7.startLine=100
scope.7.endLine=106
scope.7.semanticHash=57217efddb03fc48
scope.8.id=function:anonymous@110:110
scope.8.kind=function
scope.8.startLine=110
scope.8.endLine=118
scope.8.semanticHash=77f9cb06f8e97f75
scope.9.id=function:anonymous@109:109
scope.9.kind=function
scope.9.startLine=109
scope.9.endLine=119
scope.9.semanticHash=c972bd24c676acb9
scope.10.id=function:renderer.switch_popup_canvas:107
scope.10.kind=function
scope.10.startLine=107
scope.10.endLine=121
scope.10.semanticHash=24e91758e27cd6dd
scope.11.id=function:anonymous@125:125
scope.11.kind=function
scope.11.startLine=125
scope.11.endLine=127
scope.11.semanticHash=900f69c3359a07a3
scope.12.id=function:_set_popup_card_image:123
scope.12.kind=function
scope.12.startLine=123
scope.12.endLine=128
scope.12.semanticHash=ec8313ae61f6da1b
scope.13.id=function:anonymous@132:132
scope.13.kind=function
scope.13.startLine=132
scope.13.endLine=134
scope.13.semanticHash=8430e09b7ebb52a5
scope.14.id=function:_set_bankruptcy_avatar_image:129
scope.14.kind=function
scope.14.startLine=129
scope.14.endLine=135
scope.14.semanticHash=c07a513bd134b536
scope.15.id=function:_render_bankruptcy_popup:136
scope.15.kind=function
scope.15.startLine=136
scope.15.endLine=147
scope.15.semanticHash=ee42da25dec91546
scope.16.id=function:_render_card_popup:148
scope.16.kind=function
scope.16.startLine=148
scope.16.endLine=157
scope.16.semanticHash=646fb0c119d2ed0e
scope.17.id=function:renderer.show_popup:158
scope.17.kind=function
scope.17.startLine=158
scope.17.endLine=168
scope.17.semanticHash=099c64e7211f099f
scope.18.id=function:_hide_bankruptcy_popup:171
scope.18.kind=function
scope.18.startLine=171
scope.18.endLine=178
scope.18.semanticHash=b253283c62605910
scope.19.id=function:_hide_card_popup:179
scope.19.kind=function
scope.19.startLine=179
scope.19.endLine=185
scope.19.semanticHash=d407c3661e4a7a64
scope.20.id=function:_hide_popup:186
scope.20.kind=function
scope.20.startLine=186
scope.20.endLine=194
scope.20.semanticHash=69280c47cd2234cd
]]
