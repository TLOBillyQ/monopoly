local role_avatar = require("src.presentation.state.UIRoleAvatar")
local runtime = require("src.presentation.api.UIRuntimePort")
local runtime_ports = require("src.core.RuntimePorts")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")

local renderer = {}
local _apply_node_image

local function _with_client_role(role, fn)
  if type(runtime.with_client_role) == "function" then
    return runtime.with_client_role(role, fn)
  end
  runtime.set_client_role(role)
  local ok, err = pcall(fn)
  runtime.set_client_role(nil)
  if not ok then
    error(err)
  end
end

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
  local refs = state and state.ui_refs or nil
  local image_refs = refs and refs.images or nil
  if not image_refs then
    return nil
  end
  return image_refs[tostring(image_ref)] or image_refs[image_ref]
end

local function _set_popup_card_image(state, payload)
  local ui = state and state.ui
  local popup = ui and ui.popup_screen or nil
  if not ui or not popup or not popup.card then
    return
  end
  local card_name = popup.card
  local card_node = ui.query_node(card_name)
  local refs = state and state.ui_refs or nil
  local image_refs = refs and refs.images or nil
  local empty_key = image_refs and image_refs["Empty"] or nil
  _apply_node_image(ui, card_name, card_node, _resolve_popup_image_key(state, payload), empty_key, function(node, key)
    runtime.set_node_texture_keep_size(node, key)
  end, false)
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

local function _set_bankruptcy_avatar_image(state, payload)
  local ui = state and state.ui
  local screen = ui and ui.bankruptcy_screen or nil
  if not ui or not screen or not screen.avatar then
    return
  end
  local avatar_node = ui.query_node(screen.avatar)
  local refs = state and state.ui_refs or nil
  local image_refs = refs and refs.images or nil
  local empty_key = image_refs and image_refs["Empty"] or nil
  -- Avatar policy: keep base panel and bankruptcy popup on the same native-size path.
  _apply_node_image(ui, screen.avatar, avatar_node, _resolve_bankruptcy_avatar_key(payload), empty_key, function(node, key)
    runtime.set_node_texture_native_size(node, key)
  end, true)
end

local function _should_show_modal_for_ctx(ctx, kind)
  if ctx and ctx.can_operate == true then
    return true
  end
  return kind == "chance_card" or kind == "item_card" or kind == "bankruptcy"
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
    _with_client_role(role, function()
      local ctx = require("src.presentation.state.UIRoleContext").resolve(role, state.ui_model, { runtime = runtime })
      if _should_show_modal_for_ctx(ctx, kind) then
        _switch_canvas_for_role(ui, role, target_canvas)
      else
        _switch_canvas_for_role(ui, role, fallback_canvas or canvas.CANVAS_BASE)
      end
    end)
  end)
  runtime.set_client_role(nil)
end

function renderer.show_popup(state, payload)
  local ui = state.ui
  local kind = payload.kind or "card"
  ui.popup_kind = kind
  if kind == "bankruptcy" then
    local screen = ui.bankruptcy_screen
    renderer.switch_popup_canvas(state, kind, canvas.CANVAS_BANKRUPTCY, canvas.CANVAS_BASE)
    if screen and screen.text then
      ui:set_label(screen.text, _resolve_bankruptcy_text(payload))
    end
    _set_bankruptcy_avatar_image(state, payload)
    if screen and screen.root then
      ui:set_visible(screen.root, true)
    end
  else
    local popup = ui.popup_screen
    renderer.switch_popup_canvas(state, kind, canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
    ui:set_label(popup.title, payload.title)
    _set_popup_card_image(state, payload)
    ui:set_visible(popup.root, true)
  end
  _set_popup_dismiss_touch(ui, true)
end

function renderer.hide_popup(state)
  local ui = state.ui
  local kind = ui.popup_kind or "card"
  if kind == "bankruptcy" then
    local screen = ui.bankruptcy_screen
    if screen and screen.root then
      ui:set_visible(screen.root, false)
    end
    _set_bankruptcy_avatar_image(state, nil)
  else
    ui:set_visible(ui.popup_screen.root, false)
    _set_popup_card_image(state, nil)
  end
  _set_popup_dismiss_touch(ui, false)
end

return renderer
