local logger = require("src.core.utils.logger")
local runtime = require("src.ui.render.runtime_ui")
local base_nodes = require("src.ui.schema.base")
local base_contract = require("src.ui.schema.base_contract")
local ui_touch_policy = require("src.ui.input.touch_policy")
local host_runtime_ports = require("src.ui.host_bridge")

local bindings = {}

local missing_button_tips = {}

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

local function _report_register_node_click_failure(name, reason)
  _show_missing_button_tip(name)
  if name == base_nodes.action_log_button then
    logger.info("[调试屏] 行动日志按钮注册失败: " .. tostring(reason))
  end
end

function bindings.register_node_click(cache, name, callback, registered, listeners)
  assert(name ~= nil, "missing node name")
  assert(type(callback) == "function", "missing callback")
  assert(registered ~= nil, "missing registered map")
  assert(listeners ~= nil, "missing listeners list")
  if registered[name] then
    return
  end
  local nodes = cache[name]
  if not nodes then
    local ok, result = pcall(runtime.query_nodes, name)
    if not ok then
      _report_register_node_click_failure(name, "query_nodes异常")
      return
    end
    nodes = result
    cache[name] = nodes
  end
  if not nodes or not nodes[1] then
    _report_register_node_click_failure(name, "未找到节点")
    return
  end
  registered[name] = true
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    table.insert(listeners, listener)
  end
end

local function _set_node_touch_enabled_fallback(node, enabled)
  if not node then
    return false
  end
  node.disabled = not enabled
  return true
end

local function _query_target_nodes(cache, name)
  local nodes = cache and cache[name] or nil
  if nodes and nodes[1] then
    return nodes
  end
  local ok, result = pcall(runtime.query_nodes, name)
  if not ok then
    logger.info(
      "[调试屏] 行动日志触控启用失败: query_nodes异常",
      "node=" .. tostring(name),
      "err=" .. tostring(result)
    )
    return nil
  end
  return result
end

local function _enable_target_nodes(name, nodes)
  if not nodes or not nodes[1] then
    logger.info("[调试屏] 行动日志触控启用失败: 未找到节点", "node=" .. tostring(name))
    return 0
  end
  local enabled_count = 0
  for index, node in ipairs(nodes) do
    local ok, err = pcall(_set_node_touch_enabled_fallback, node, true)
    if ok then
      enabled_count = enabled_count + 1
    else
      logger.info(
        "[调试屏] 行动日志触控启用失败: 节点触控设置异常",
        "node=" .. tostring(name),
        "index=" .. tostring(index),
        "err=" .. tostring(err)
      )
    end
  end
  return enabled_count
end

local function _enable_action_log_targets(cache, targets)
  local enabled_count = 0
  for _, name in ipairs(targets) do
    enabled_count = enabled_count + _enable_target_nodes(name, _query_target_nodes(cache, name))
  end
  return enabled_count
end

function bindings.enable_action_log_toggle_touch(cache, ui)
  local targets = base_contract.action_log.toggle_targets or {}
  local main_path_ok = false

  if ui and ui.set_touch_enabled then
    local ok, err = pcall(ui_touch_policy.set_action_log_toggle_touch, ui, true)
    if ok then
      main_path_ok = true
    else
      for _, name in ipairs(targets) do
        logger.info(
          "[调试屏] 行动日志触控启用失败: 按名称设置异常",
          "node=" .. tostring(name),
          "err=" .. tostring(err)
        )
      end
    end
  end

  if not main_path_ok then
    _enable_action_log_targets(cache, targets)
  end

  pcall(runtime.set_client_role, nil)
end

function bindings.register_missing_button_tip(cache, registered, listeners)
  local nodes = require("Data.UIManagerNodes")
  for _, entry in pairs(nodes) do
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

function bindings.show_missing_button_tip(name)
  _show_missing_button_tip(name)
end

return bindings
