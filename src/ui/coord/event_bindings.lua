local runtime = require("src.ui.render.runtime_ui")
local base_contract = require("src.ui.schema.base_contract")
local ui_touch_policy = require("src.ui.input.touch")
local host_runtime_ports = require("src.ui.host_bridge")
local ui_manager_nodes = require("Data.UIManagerNodes")

local bindings = {}

local missing_button_tips = {}
local GLOBAL_ROLE_SCOPE = "__global"

local function _show_missing_button_tip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  host_runtime_ports.enqueue_tip({
    text = "UI 节点未适配: " .. tostring(name),
    duration = 2.0,
    dedupe_key = "ui_missing_button:" .. tostring(name),
    blocks_inter_turn = false,
    source = "ui.missing_button",
  })
end

local function _report_register_node_click_failure(name)
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

local function _query_target_nodes(cache, name)
  local nodes = cache and cache[name] or nil
  if nodes and nodes[1] then
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

function bindings.enable_action_log_toggle_touch(cache, ui)
  local targets = base_contract.action_log.toggle_targets or {}
  local main_path_ok = false

  if ui and ui.set_touch_enabled then
    local ok = pcall(ui_touch_policy.set_action_log_toggle_touch, ui, true)
    if ok then
      main_path_ok = true
    end
  end

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
version=2
projectHash=fe10b8dc70234298
scope.0.id=chunk:src/ui/coord/event_bindings.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=185
scope.0.semanticHash=14daca9f7123d420
scope.0.lastMutatedAt=2026-05-29T07:52:18Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=27
scope.0.lastMutationKilled=27
scope.1.id=function:_show_missing_button_tip:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=24
scope.1.semanticHash=a6d01cbecd5be59c
scope.1.lastMutatedAt=2026-05-29T07:44:51Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_report_register_node_click_failure:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=0731e9a74195b308
scope.2.lastMutatedAt=2026-05-29T07:44:51Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_is_registered:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=36
scope.3.semanticHash=df16ad59ca3811b8
scope.3.lastMutatedAt=2026-05-29T07:44:51Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=9
scope.3.lastMutationKilled=9
scope.4.id=function:_mark_registered:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=45
scope.4.semanticHash=227106d11114d98e
scope.4.lastMutatedAt=2026-05-29T07:44:51Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
scope.5.id=function:_cache_key:47
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=49
scope.5.semanticHash=d206dabe10b07002
scope.5.lastMutatedAt=2026-05-29T07:44:51Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_dispatch_with_event_role:51
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=62
scope.6.semanticHash=de0b63c87e33adfd
scope.6.lastMutatedAt=2026-05-29T07:44:51Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:_resolve_click_nodes:64
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=78
scope.7.semanticHash=472b4601a3f6823a
scope.7.lastMutatedAt=2026-05-29T07:52:18Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:anonymous@82:82
scope.8.kind=function
scope.8.startLine=82
scope.8.endLine=84
scope.8.semanticHash=2949e4aeffaf4a29
scope.8.lastMutatedAt=2026-05-29T07:44:51Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=no_sites
scope.8.lastMutationSites=0
scope.8.lastMutationKilled=0
scope.9.id=function:_assert_register_node_click_args:89
scope.9.kind=function
scope.9.startLine=89
scope.9.endLine=94
scope.9.semanticHash=dfa9d348546edefe
scope.9.lastMutatedAt=2026-05-29T07:52:18Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=4
scope.9.lastMutationKilled=4
scope.10.id=function:_should_bind_client_role:96
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=98
scope.10.semanticHash=4721cce78fabdf92
scope.10.lastMutatedAt=2026-05-29T07:52:18Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=4
scope.10.lastMutationKilled=4
scope.11.id=function:_has_click_nodes:100
scope.11.kind=function
scope.11.startLine=100
scope.11.endLine=102
scope.11.semanticHash=480a8b0a511c036e
scope.11.lastMutatedAt=2026-05-29T07:52:18Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=3
scope.11.lastMutationKilled=3
scope.12.id=function:bindings.register_node_click:104
scope.12.kind=function
scope.12.startLine=104
scope.12.endLine=116
scope.12.semanticHash=270ca8e9afc2b36d
scope.12.lastMutatedAt=2026-05-29T07:52:18Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=9
scope.12.lastMutationKilled=9
scope.13.id=function:_set_node_touch_enabled_fallback:118
scope.13.kind=function
scope.13.startLine=118
scope.13.endLine=123
scope.13.semanticHash=8d85a56c56453ee0
scope.13.lastMutatedAt=2026-05-29T07:52:18Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=2
scope.13.lastMutationKilled=2
scope.14.id=function:_query_target_nodes:125
scope.14.kind=function
scope.14.startLine=125
scope.14.endLine=135
scope.14.semanticHash=366fa22de2b01d75
scope.14.lastMutatedAt=2026-05-29T07:52:18Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=6
scope.14.lastMutationKilled=6
scope.15.id=function:bindings.enable_action_log_toggle_touch:152
scope.15.kind=function
scope.15.startLine=152
scope.15.endLine=168
scope.15.semanticHash=54db8633f488f55d
scope.15.lastMutatedAt=2026-05-29T07:52:18Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=8
scope.15.lastMutationKilled=8
scope.16.id=function:anonymous@176:176
scope.16.kind=function
scope.16.startLine=176
scope.16.endLine=178
scope.16.semanticHash=d13bc5be9502ff89
scope.16.lastMutatedAt=2026-05-29T07:52:18Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=no_sites
scope.16.lastMutationSites=0
scope.16.lastMutationKilled=0
]]
