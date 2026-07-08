local runtime = require("src.ui.render.runtime_ui")
local debug_nodes = require("src.ui.schema.debug")
local secondary_confirm_nodes = require("src.ui.schema.secondary_confirm")
local base_contract = require("src.ui.schema.base_contract")

local M = {}

local query_node = runtime.query_node

local _mutate_name
local _mutate_fn
local function _mutate_role_callback()
  local node = query_node(_mutate_name)
  _mutate_fn(node)
end

local function mutate_node(name, mutator)
  assert(name ~= nil, "missing ui node name")
  assert(type(mutator) == "function", "missing node mutator")
  local active_role = runtime.get_client_role and runtime.get_client_role() or nil
  if active_role ~= nil then
    local node = query_node(name)
    mutator(node)
    return
  end
  _mutate_name = name
  _mutate_fn = mutator
  runtime.for_each_role_or_global(_mutate_role_callback)
end

local _text_val
local function _text_mutator(node) node.text = _text_val end

local _visible_val
local function _visible_mutator(node) node.visible = _visible_val end

local _disabled_val
local function _disabled_mutator(node) node.disabled = _disabled_val end

local function set_text(_, name, text)
  _text_val = text or ""
  mutate_node(name, _text_mutator)
end

local function set_visible(_, name, visible)
  _visible_val = visible == true
  mutate_node(name, _visible_mutator)
end

local function set_touch_enabled(_, name, enabled)
  _disabled_val = not enabled
  mutate_node(name, _disabled_mutator)
end

local function _resolve_target_screen(ui)
  if not ui then
    return nil
  end
  return ui.choice_screens and ui.choice_screens.target or nil
end

local function _hide_target_button(ui, button_name)
  if not button_name then
    return
  end
  ui:set_button(button_name, "")
  ui:set_visible(button_name, false)
  ui:set_touch_enabled(button_name, false)
end

local function sync_target_choice_buttons(state)
  local ui = state and state.ui or nil
  local screen = _resolve_target_screen(ui)
  if not screen then
    return
  end
  _hide_target_button(ui, screen.confirm)
  _hide_target_button(ui, screen.cancel)
end

local function set_event_log(_, text)
  set_text(nil, base_contract.action_log.label, text)
end

local function set_event_log_visible(ui, visible)
  if ui then
    ui.debug_visible = visible == true
  end
  set_visible(nil, debug_nodes.canvas, visible)
end

local _slot_name_val
local _image_key_val
local function _apply_item_slot()
  local nodes = runtime.query_nodes(_slot_name_val)
  for _, node in ipairs(nodes) do
    runtime.set_node_texture_keep_size(node, _image_key_val)
  end
end

local function set_item_slot_image(slot_name, image_key)
  assert(slot_name ~= nil, "missing slot name")
  assert(image_key ~= nil, "missing image key for slot: " .. tostring(slot_name))
  local active_role = runtime.get_client_role and runtime.get_client_role() or nil
  _slot_name_val = slot_name
  _image_key_val = image_key
  if active_role ~= nil then
    _apply_item_slot()
    return
  end
  runtime.for_each_role_or_global(_apply_item_slot)
end

local function build_choice_screens()
  local screens = require("src.ui.screens.registry").build_choice_screens()  -- 已迁移屏
  screens.secondary_confirm = screens.secondary_confirm or {
    key = "secondary_confirm",
    root = secondary_confirm_nodes.canvas,
    title = secondary_confirm_nodes.title,
    body = secondary_confirm_nodes.body,
    confirm = secondary_confirm_nodes.confirm,
    cancel = secondary_confirm_nodes.cancel,
  }
  return screens
end

M.query_node = query_node
M.set_text = set_text
M.set_visible = set_visible
M.set_touch_enabled = set_touch_enabled
M.set_event_log = set_event_log
M.set_event_log_visible = set_event_log_visible
M.set_item_slot_image = set_item_slot_image
M.build_choice_screens = build_choice_screens
M.sync_target_choice_buttons = sync_target_choice_buttons

return M

--[[ mutate4lua-manifest
version=2
projectHash=832bdc3a4c7033ca
scope.0.id=chunk:src/ui/render/node_ops.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=165
scope.0.semanticHash=f88e5cd64be607df
scope.0.lastMutatedAt=2026-05-28T15:46:09Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_mutate_role_callback:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=18
scope.1.semanticHash=6d36d0481b3bd8df
scope.1.lastMutatedAt=2026-05-28T15:46:09Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:mutate_node:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=32
scope.2.semanticHash=4073110a47cc201c
scope.2.lastMutatedAt=2026-05-28T15:46:09Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=9
scope.2.lastMutationKilled=9
scope.3.id=function:_text_mutator:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=35
scope.3.semanticHash=0e42f44ebca928c4
scope.4.id=function:_visible_mutator:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=38
scope.4.semanticHash=04aa088805a7de07
scope.5.id=function:_disabled_mutator:41
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=41
scope.5.semanticHash=c231b1e337a96c11
scope.6.id=function:set_text:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=46
scope.6.semanticHash=5635f3b544dd5fbf
scope.6.lastMutatedAt=2026-05-28T15:46:09Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:set_visible:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=51
scope.7.semanticHash=65adf9876ee37751
scope.7.lastMutatedAt=2026-05-28T15:46:09Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:set_touch_enabled:53
scope.8.kind=function
scope.8.startLine=53
scope.8.endLine=56
scope.8.semanticHash=a64d1d59a3a2b2bb
scope.8.lastMutatedAt=2026-05-28T15:46:09Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=2
scope.8.lastMutationKilled=2
scope.9.id=function:_resolve_target_screen:58
scope.9.kind=function
scope.9.startLine=58
scope.9.endLine=63
scope.9.semanticHash=fba5db9cf48eb480
scope.9.lastMutatedAt=2026-05-28T15:46:09Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=3
scope.9.lastMutationKilled=3
scope.10.id=function:_hide_target_button:65
scope.10.kind=function
scope.10.startLine=65
scope.10.endLine=72
scope.10.semanticHash=d4aebb12932d6488
scope.10.lastMutatedAt=2026-05-28T15:46:09Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=4
scope.10.lastMutationKilled=4
scope.11.id=function:sync_target_choice_buttons:74
scope.11.kind=function
scope.11.startLine=74
scope.11.endLine=82
scope.11.semanticHash=a2cb25f56c4f4b9b
scope.11.lastMutatedAt=2026-05-28T15:46:09Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=6
scope.11.lastMutationKilled=6
scope.12.id=function:set_event_log:84
scope.12.kind=function
scope.12.startLine=84
scope.12.endLine=86
scope.12.semanticHash=f5e39c289276e6f9
scope.12.lastMutatedAt=2026-05-28T15:46:09Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:set_event_log_visible:88
scope.13.kind=function
scope.13.startLine=88
scope.13.endLine=93
scope.13.semanticHash=2f85ea7c779a8c46
scope.13.lastMutatedAt=2026-05-28T15:46:09Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=3
scope.13.lastMutationKilled=3
scope.14.id=function:set_item_slot_image:104
scope.14.kind=function
scope.14.startLine=104
scope.14.endLine=115
scope.14.semanticHash=10bd0b7eac8688c4
scope.14.lastMutatedAt=2026-05-28T15:46:09Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=8
scope.14.lastMutationKilled=8
scope.15.id=function:build_choice_screens:117
scope.15.kind=function
scope.15.startLine=117
scope.15.endLine=152
scope.15.semanticHash=4eea9e192600b8e9
scope.15.lastMutatedAt=2026-05-28T15:46:09Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=4
scope.15.lastMutationKilled=4
]]
