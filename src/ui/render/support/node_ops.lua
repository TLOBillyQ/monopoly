local runtime = require("src.ui.render.support.runtime_ui")
local debug_nodes = require("src.ui.schema.debug")
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

-- mutate_node 的全量命中变体：同名节点（如「基础_分享动效」×2）一个不漏。
-- 复用 _mutate_name 单槽闭包，与 mutate_node 同步调用风格一致（不可嵌套）。
local function _mutate_all_role_callback()
  local nodes = runtime.query_nodes(_mutate_name)
  for _, node in ipairs(nodes) do
    _mutate_fn(node)
  end
end

local function mutate_nodes_all(name, mutator)
  assert(name ~= nil, "missing ui node name")
  assert(type(mutator) == "function", "missing node mutator")
  local active_role = runtime.get_client_role and runtime.get_client_role() or nil
  _mutate_name = name
  _mutate_fn = mutator
  if active_role ~= nil then
    _mutate_all_role_callback()
    return
  end
  runtime.for_each_role_or_global(_mutate_all_role_callback)
end

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

local function set_touch_enabled_all(_, name, enabled)
  _disabled_val = not enabled
  mutate_nodes_all(name, _disabled_mutator)
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

local _event_log_text
local function _event_log_mutator(node)
  node.text = _event_log_text
end

local function set_event_log(_, text)
  _event_log_text = text or ""
  mutate_node(base_contract.action_log.label, _event_log_mutator)
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

M.query_node = query_node
M.set_text = set_text
M.set_visible = set_visible
M.set_touch_enabled = set_touch_enabled
M.set_touch_enabled_all = set_touch_enabled_all
M.set_event_log = set_event_log
M.set_event_log_visible = set_event_log_visible
M.set_item_slot_image = set_item_slot_image
M.sync_target_choice_buttons = sync_target_choice_buttons

return M

--[[ mutate4lua-manifest
version=4
projectHash=9c4e0db6b5057a5a
scope.0.id=chunk:src/ui/render/support/node_ops.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=157
scope.0.semanticHash=5d1b76cb6ba19c92
scope.1.id=function:_mutate_role_callback
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=14
scope.1.semanticHash=8176a9ac5569a02f
scope.2.id=function:mutate_node
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=28
scope.2.semanticHash=2bc4404372fde279
scope.3.id=function:_text_mutator
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=31
scope.3.semanticHash=a9d82726f0169db1
scope.4.id=function:_visible_mutator
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=34
scope.4.semanticHash=a9d82726f0169db1
scope.5.id=function:_disabled_mutator
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=37
scope.5.semanticHash=a9d82726f0169db1
scope.6.id=function:_mutate_all_role_callback
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=46
scope.6.semanticHash=f76f3db4c50d2ef2
scope.7.id=function:mutate_nodes_all
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=59
scope.7.semanticHash=ff387284ebb3253c
scope.8.id=function:set_text
scope.8.kind=function
scope.8.startLine=61
scope.8.endLine=64
scope.8.semanticHash=27889726b7e0e64c
scope.9.id=function:set_visible
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=69
scope.9.semanticHash=45bfaef7a92086ea
scope.10.id=function:set_touch_enabled
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=74
scope.10.semanticHash=50440baffe75564c
scope.11.id=function:set_touch_enabled_all
scope.11.kind=function
scope.11.startLine=76
scope.11.endLine=79
scope.11.semanticHash=50440baffe75564c
scope.12.id=function:_resolve_target_screen
scope.12.kind=function
scope.12.startLine=81
scope.12.endLine=86
scope.12.semanticHash=6418dc28c6ce6c92
scope.13.id=function:_hide_target_button
scope.13.kind=function
scope.13.startLine=88
scope.13.endLine=95
scope.13.semanticHash=592d060006625244
scope.14.id=function:sync_target_choice_buttons
scope.14.kind=function
scope.14.startLine=97
scope.14.endLine=105
scope.14.semanticHash=03b7b3dba7fa60bc
scope.15.id=function:_event_log_mutator
scope.15.kind=function
scope.15.startLine=108
scope.15.endLine=110
scope.15.semanticHash=a9d82726f0169db1
scope.16.id=function:set_event_log
scope.16.kind=function
scope.16.startLine=112
scope.16.endLine=115
scope.16.semanticHash=366dfae6b8c3a5fb
scope.17.id=function:set_event_log_visible
scope.17.kind=function
scope.17.startLine=117
scope.17.endLine=122
scope.17.semanticHash=12e272685a15d15d
scope.18.id=function:_apply_item_slot
scope.18.kind=function
scope.18.startLine=126
scope.18.endLine=131
scope.18.semanticHash=2b938db5c06332b9
scope.19.id=function:set_item_slot_image
scope.19.kind=function
scope.19.startLine=133
scope.19.endLine=144
scope.19.semanticHash=d0ae1e8c6c3858f9
]]
