local logger = require("src.foundation.log")
local runtime = require("src.ui.render.support.runtime_ui")
local base_contract = require("src.ui.schema.base_contract")
local ui_touch_policy = require("src.ui.input.touch")
local tip_queue = require("src.foundation.tips")
local ui_manager_nodes = require("Data.UIManagerNodes")

local bindings = {}

local missing_button_tips = {}
local GLOBAL_ROLE_SCOPE = "__global"

local function _show_missing_button_tip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  tip_queue.enqueue({
    text = "UI 节点未适配: " .. tostring(name),
    duration = 2.0,
    dedupe_key = "ui_missing_button:" .. tostring(name),
    blocks_inter_turn = false,
    source = "ui.missing_button",
  })
end

local function _report_register_node_click_failure(name)
  -- tip 只弹一次且转瞬即逝,留 warn 让注册失败在 log.txt 有痕可查。
  logger.warn("ui node click registration failed:", tostring(name))
  _show_missing_button_tip(name)
end

local function _is_registered(registered, name, scope_key)
  local scopes = registered[name]
  if scopes == true then
    return true
  end
  return type(scopes) == "table" and scopes[scope_key] == true
end

local function _mark_registered(registered, name, scope_key)
  local scopes = registered[name]
  if type(scopes) ~= "table" then
    scopes = {}
    registered[name] = scopes
  end
  scopes[scope_key] = true
end

local function _cache_key(name, scope_key)
  return tostring(name) .. "\0" .. tostring(scope_key)
end

local function _dispatch_with_event_role(callback, data, bind_client_role)
  if not bind_client_role then
    callback(data)
    return
  end
  local role = data and data.role or nil
  if role ~= nil then
    runtime.with_client_role(role, callback, data)
    return
  end
  callback(data)
end

local function _resolve_click_nodes(cache, name, scope_key)
  local key = _cache_key(name, scope_key)
  local nodes = cache[key] or cache[name]
  if nodes then
    return nodes
  end
  local ok, result = pcall(runtime.query_nodes, name)
  if not ok then
    _report_register_node_click_failure(name)
    return nil
  end
  cache[key] = result
  cache[name] = result
  return result
end

local function _attach_click_listeners(nodes, callback, listeners, bind_client_role)
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      _dispatch_with_event_role(callback, data, bind_client_role)
    end)
    table.insert(listeners, listener)
  end
end

local function _assert_register_node_click_args(name, callback, registered, listeners)
  assert(name ~= nil, "missing node name")
  assert(type(callback) == "function", "missing callback")
  assert(registered ~= nil, "missing registered map")
  assert(listeners ~= nil, "missing listeners list")
end

local function _should_bind_client_role(opts)
  return opts == nil or opts.bind_client_role ~= false
end

local function _has_click_nodes(nodes)
  return nodes and nodes[1] ~= nil
end

function bindings.register_node_click(cache, name, callback, registered, listeners, opts)
  _assert_register_node_click_args(name, callback, registered, listeners)
  local bind_client_role = _should_bind_client_role(opts)
  local scope_key = GLOBAL_ROLE_SCOPE
  if _is_registered(registered, name, scope_key) then return end
  local nodes = _resolve_click_nodes(cache, name, scope_key)
  if not _has_click_nodes(nodes) then
    _report_register_node_click_failure(name)
    return
  end
  _mark_registered(registered, name, scope_key)
  _attach_click_listeners(nodes, callback, listeners, bind_client_role)
end

local function _set_node_touch_enabled_fallback(node, enabled)
  if not node then
    return
  end
  node.disabled = not enabled
end

local function _cached_nodes(cache, name)
  return cache and cache[name] or nil
end

local function _has_nodes(nodes)
  return nodes ~= nil and nodes[1] ~= nil
end

local function _query_target_nodes(cache, name)
  local nodes = _cached_nodes(cache, name)
  if _has_nodes(nodes) then
    return nodes
  end
  local ok, result = pcall(runtime.query_nodes, name)
  if not ok then
    return nil
  end
  return result
end

local function _enable_target_nodes(name, nodes)
  if not nodes or not nodes[1] then
    return
  end
  for _, node in ipairs(nodes) do
    pcall(_set_node_touch_enabled_fallback, node, true)
  end
end

local function _enable_action_log_targets(cache, targets)
  for _, name in ipairs(targets) do
    _enable_target_nodes(name, _query_target_nodes(cache, name))
  end
end

local function _try_enable_via_touch_policy(ui)
  if not (ui and ui.set_touch_enabled) then
    return false
  end
  local ok = pcall(ui_touch_policy.set_action_log_toggle_touch, ui, true)
  return ok
end

function bindings.enable_action_log_toggle_touch(cache, ui)
  local targets = base_contract.action_log.toggle_targets or {}
  local main_path_ok = _try_enable_via_touch_policy(ui)

  if not main_path_ok then
    _enable_action_log_targets(cache, targets)
  end

  pcall(runtime.set_client_role, nil)
end

function bindings.register_missing_button_tip(cache, registered, listeners)
  for _, entry in pairs(ui_manager_nodes) do
    if type(entry) == "table" then
      local name = entry[1]
      local kind = entry[2]
      if kind == "EButton" and not registered[name] then
        bindings.register_node_click(cache, name, function()
          _show_missing_button_tip(name)
        end, registered, listeners)
      end
    end
  end
end

return bindings

--[[ mutate4lua-manifest
version=4
projectHash=ee9631e1b97ee809
scope.0.id=chunk:src/ui/coord/event_bindings.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=197
scope.0.semanticHash=2514df6b785fba3b
scope.1.id=function:_show_missing_button_tip
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=25
scope.1.semanticHash=37418d5fb64f35c0
scope.2.id=function:_report_register_node_click_failure
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=31
scope.2.semanticHash=e28983cb5b06eaa9
scope.3.id=function:_is_registered
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=39
scope.3.semanticHash=c9d8502bdad7084b
scope.4.id=function:_mark_registered
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=48
scope.4.semanticHash=725a370ce24b9942
scope.5.id=function:_cache_key
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=52
scope.5.semanticHash=5f9ffb10335863b9
scope.6.id=function:_dispatch_with_event_role
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=65
scope.6.semanticHash=d885f0841b6a6c0c
scope.7.id=function:_resolve_click_nodes
scope.7.kind=function
scope.7.startLine=67
scope.7.endLine=81
scope.7.semanticHash=694da542862bd5da
scope.8.id=function:_attach_click_listeners
scope.8.kind=function
scope.8.startLine=83
scope.8.endLine=90
scope.8.semanticHash=851c307ea4929a2a
scope.9.id=function:<anonymous>
scope.9.kind=function
scope.9.startLine=85
scope.9.endLine=87
scope.9.semanticHash=11e97ffd44326f60
scope.10.id=function:_assert_register_node_click_args
scope.10.kind=function
scope.10.startLine=92
scope.10.endLine=97
scope.10.semanticHash=795749b1e0db798d
scope.11.id=function:_should_bind_client_role
scope.11.kind=function
scope.11.startLine=99
scope.11.endLine=101
scope.11.semanticHash=094f3635d2503291
scope.12.id=function:_has_click_nodes
scope.12.kind=function
scope.12.startLine=103
scope.12.endLine=105
scope.12.semanticHash=380dedd850c4d21f
scope.13.id=function:bindings.register_node_click
scope.13.kind=function
scope.13.startLine=107
scope.13.endLine=119
scope.13.semanticHash=3a59e3a7ffa89bb0
scope.14.id=function:_set_node_touch_enabled_fallback
scope.14.kind=function
scope.14.startLine=121
scope.14.endLine=126
scope.14.semanticHash=66db2bfa2a6b98cf
scope.15.id=function:_cached_nodes
scope.15.kind=function
scope.15.startLine=128
scope.15.endLine=130
scope.15.semanticHash=cd6b189045fad21d
scope.16.id=function:_has_nodes
scope.16.kind=function
scope.16.startLine=132
scope.16.endLine=134
scope.16.semanticHash=afdad5c23e6dd84b
scope.17.id=function:_query_target_nodes
scope.17.kind=function
scope.17.startLine=136
scope.17.endLine=146
scope.17.semanticHash=ac72ee87f48b3bcd
scope.18.id=function:_enable_target_nodes
scope.18.kind=function
scope.18.startLine=148
scope.18.endLine=155
scope.18.semanticHash=caf2341ddbb26457
scope.19.id=function:_enable_action_log_targets
scope.19.kind=function
scope.19.startLine=157
scope.19.endLine=161
scope.19.semanticHash=e35fcb72bdd419a8
scope.20.id=function:_try_enable_via_touch_policy
scope.20.kind=function
scope.20.startLine=163
scope.20.endLine=169
scope.20.semanticHash=20550672d51cd0cd
scope.21.id=function:bindings.enable_action_log_toggle_touch
scope.21.kind=function
scope.21.startLine=171
scope.21.endLine=180
scope.21.semanticHash=53b951776d0ddd47
scope.22.id=function:bindings.register_missing_button_tip
scope.22.kind=function
scope.22.startLine=182
scope.22.endLine=194
scope.22.semanticHash=f884b82e8d418dcb
scope.23.id=function:<anonymous>#2
scope.23.kind=function
scope.23.startLine=188
scope.23.endLine=190
scope.23.semanticHash=600a75ce96a391b3
]]
