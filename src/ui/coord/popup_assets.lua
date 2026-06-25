local role_avatar = require("src.ui.view.role_avatar")
local runtime = require("src.ui.render.runtime_ui")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_assets = require("src.config.runtime_assets")

local M = {}

local function _payload_image_ref(payload)
  if payload == nil then
    return nil
  end
  return payload.image_ref
end

local function _payload_image_key(payload)
  if payload == nil then
    return nil
  end
  if payload.image_key ~= nil then
    return payload.image_key
  end
  return nil
end

local function _image_result_key(image)
  return image.ok == true and image.image_key or nil
end

local function _resolve_popup_image_key(state, payload)
  local image_key = _payload_image_key(payload)
  if image_key ~= nil then
    return image_key
  end
  local image_ref = _payload_image_ref(payload)
  if image_ref == nil then
    return nil
  end
  local image = runtime_assets.image_for_popup_card(payload.kind, image_ref, runtime_assets.asset_context(state))
  return _image_result_key(image)
end

local function _dismiss_nodes(ui)
  local popup = ui and ui.popup_screen or nil
  if popup == nil then
    return nil
  end
  local nodes = popup.dismiss_nodes
  if type(nodes) ~= "table" then
    return nil
  end
  return nodes
end

function M.set_popup_dismiss_touch(ui, enabled)
  local nodes = _dismiss_nodes(ui)
  if nodes == nil then
    return
  end
  for _, name in ipairs(nodes) do
    ui:set_touch_enabled(name, enabled == true)
  end
end

function M.resolve_bankruptcy_text(payload)
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

local function _avatar_from_payload(payload)
  local avatar_key = payload and payload.avatar_key or nil
  if avatar_key == nil then
    return nil
  end
  return role_avatar.sanitize_image_key(avatar_key)
end

local function _role_for_player(player_id)
  if not player_id then
    return nil
  end
  return runtime_ports.resolve_role(player_id)
end

local function _avatar_from_role(role)
  if role == nil then
    return nil
  end
  return role_avatar.resolve_from_role(role)
end

local function _resolve_bankruptcy_avatar_key(payload)
  if not payload then
    return nil
  end
  local avatar_key = _avatar_from_payload(payload)
  if avatar_key ~= nil then
    return avatar_key
  end
  return _avatar_from_role(_role_for_player(payload.player_id))
end

local function _apply_node_image(ui, node_name, node, image_key, empty_key, set_texture, show_when_empty)
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
  local empty_image = runtime_assets.empty_image(runtime_assets.asset_context(state))
  _apply_node_image(ui, node_name, ui.query_node(node_name), image_key, empty_image.image_key, set_texture, show_when_empty)
end

function M.set_popup_card_image(state, payload)
  local popup = state and state.ui and state.ui.popup_screen or nil
  _apply_screen_image(state, popup, popup and popup.card or nil, _resolve_popup_image_key(state, payload), function(node, key)
    runtime.set_node_texture_keep_size(node, key)
  end, false)
end

function M.set_bankruptcy_avatar_image(state, payload)
  local screen = state and state.ui and state.ui.bankruptcy_screen or nil
  _apply_screen_image(state, screen, screen and screen.avatar or nil, _resolve_bankruptcy_avatar_key(payload), function(node, key)
    runtime.set_node_texture_native_size(node, key)
  end, true)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=3ee822468a1e89c8
scope.0.id=chunk:src/ui/coord/popup_assets.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=148
scope.0.semanticHash=88bd475130d94bad
scope.1.id=function:_payload_image_ref:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=c9507e9913d30fac
scope.2.id=function:_payload_image_key:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=23
scope.2.semanticHash=25153e05ef4a2967
scope.3.id=function:_image_result_key:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=6232fb94144d0334
scope.4.id=function:_resolve_popup_image_key:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=40
scope.4.semanticHash=fd5c201187e6973f
scope.5.id=function:_dismiss_nodes:42
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=52
scope.5.semanticHash=f74f11df86d7d26e
scope.6.id=function:M.resolve_bankruptcy_text:64
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=75
scope.6.semanticHash=06ec387cb587af76
scope.7.id=function:_avatar_from_payload:77
scope.7.kind=function
scope.7.startLine=77
scope.7.endLine=83
scope.7.semanticHash=ab251b544893f357
scope.8.id=function:_role_for_player:85
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=90
scope.8.semanticHash=51be8a6411a4f619
scope.9.id=function:_avatar_from_role:92
scope.9.kind=function
scope.9.startLine=92
scope.9.endLine=97
scope.9.semanticHash=a1665ef324b11b01
scope.10.id=function:_resolve_bankruptcy_avatar_key:99
scope.10.kind=function
scope.10.startLine=99
scope.10.endLine=108
scope.10.semanticHash=750caf610d507d82
scope.11.id=function:_apply_node_image:110
scope.11.kind=function
scope.11.startLine=110
scope.11.endLine=122
scope.11.semanticHash=c78083fe72be95f0
scope.12.id=function:_apply_screen_image:124
scope.12.kind=function
scope.12.startLine=124
scope.12.endLine=131
scope.12.semanticHash=5913bafee255e44d
scope.13.id=function:anonymous@135:135
scope.13.kind=function
scope.13.startLine=135
scope.13.endLine=137
scope.13.semanticHash=900f69c3359a07a3
scope.14.id=function:M.set_popup_card_image:133
scope.14.kind=function
scope.14.startLine=133
scope.14.endLine=138
scope.14.semanticHash=6c73719530e82e87
scope.15.id=function:anonymous@142:142
scope.15.kind=function
scope.15.startLine=142
scope.15.endLine=144
scope.15.semanticHash=8430e09b7ebb52a5
scope.16.id=function:M.set_bankruptcy_avatar_image:140
scope.16.kind=function
scope.16.startLine=140
scope.16.endLine=145
scope.16.semanticHash=9be239e45acdcb8a
]]
