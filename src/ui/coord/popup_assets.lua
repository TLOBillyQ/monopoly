local role_avatar = require("src.ui.view.role_avatar")
local runtime = require("src.ui.render.support.runtime_ui")
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

local function _non_empty_field(payload, key)
  local value = payload and payload[key] or nil
  if value ~= nil and value ~= "" then
    return value
  end
  return nil
end

function M.resolve_bankruptcy_text(payload)
  local text = _non_empty_field(payload, "text")
  if text ~= nil then
    return text
  end
  local reason = _non_empty_field(payload, "reason")
  if reason ~= nil then
    return reason
  end
  local player_name = _non_empty_field(payload, "player_name")
  if player_name ~= nil then
    return player_name .. " 破产出局"
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

local function _ui_screen(state, key)
  local ui = state and state.ui or nil
  return ui and ui[key] or nil
end

function M.set_popup_card_image(state, payload)
  local popup = _ui_screen(state, "popup_screen")
  _apply_screen_image(state, popup, popup and popup.card or nil, _resolve_popup_image_key(state, payload), function(node, key)
    runtime.set_node_texture_keep_size(node, key)
  end, false)
end

function M.set_bankruptcy_avatar_image(state, payload)
  local screen = _ui_screen(state, "bankruptcy_screen")
  _apply_screen_image(state, screen, screen and screen.avatar or nil, _resolve_bankruptcy_avatar_key(payload), function(node, key)
    runtime.set_node_texture_native_size(node, key)
  end, true)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=7aea57f06a59928d
scope.0.id=chunk:src/ui/coord/popup_assets.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=164
scope.0.semanticHash=ad7f111c381b3f1a
scope.1.id=function:_payload_image_ref
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=fecf6e8094b12276
scope.2.id=function:_payload_image_key
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=23
scope.2.semanticHash=959789b061fff20c
scope.3.id=function:_image_result_key
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=b1625996ef9f2332
scope.4.id=function:_resolve_popup_image_key
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=40
scope.4.semanticHash=3e36f70cbae07797
scope.5.id=function:_dismiss_nodes
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=52
scope.5.semanticHash=469a4c6a339d5e1f
scope.6.id=function:M.set_popup_dismiss_touch
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=62
scope.6.semanticHash=eef46ce54fb34b73
scope.7.id=function:_non_empty_field
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=70
scope.7.semanticHash=fbb8963dfa7f6077
scope.8.id=function:M.resolve_bankruptcy_text
scope.8.kind=function
scope.8.startLine=72
scope.8.endLine=86
scope.8.semanticHash=37842fee9aee7c2f
scope.9.id=function:_avatar_from_payload
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=94
scope.9.semanticHash=f33fc56c8e6ec30d
scope.10.id=function:_role_for_player
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=101
scope.10.semanticHash=01913dbfd4593436
scope.11.id=function:_avatar_from_role
scope.11.kind=function
scope.11.startLine=103
scope.11.endLine=108
scope.11.semanticHash=4d0700d0f9defcb3
scope.12.id=function:_resolve_bankruptcy_avatar_key
scope.12.kind=function
scope.12.startLine=110
scope.12.endLine=119
scope.12.semanticHash=0b8d32754bdbe9bf
scope.13.id=function:_apply_node_image
scope.13.kind=function
scope.13.startLine=121
scope.13.endLine=133
scope.13.semanticHash=b4896f6bb448f65b
scope.14.id=function:_apply_screen_image
scope.14.kind=function
scope.14.startLine=135
scope.14.endLine=142
scope.14.semanticHash=e74ba4a4004d9c39
scope.15.id=function:_ui_screen
scope.15.kind=function
scope.15.startLine=144
scope.15.endLine=147
scope.15.semanticHash=cf16f0b255f57613
scope.16.id=function:M.set_popup_card_image
scope.16.kind=function
scope.16.startLine=149
scope.16.endLine=154
scope.16.semanticHash=418fc99a5002e8d7
scope.17.id=function:<anonymous>
scope.17.kind=function
scope.17.startLine=151
scope.17.endLine=153
scope.17.semanticHash=4ad1b5cb81e9ede6
scope.18.id=function:M.set_bankruptcy_avatar_image
scope.18.kind=function
scope.18.startLine=156
scope.18.endLine=161
scope.18.semanticHash=001987f357e408d4
scope.19.id=function:<anonymous>#2
scope.19.kind=function
scope.19.startLine=158
scope.19.endLine=160
scope.19.semanticHash=4ad1b5cb81e9ede6
]]
