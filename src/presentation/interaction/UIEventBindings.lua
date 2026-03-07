local logger = require("src.core.utils.Logger")
local runtime = require("src.presentation.adapter.UIRuntimePort")
local always_show_nodes = require("src.presentation.canvas.always_show.nodes")
local always_show_contract = require("src.presentation.canvas.always_show.contract")
local ui_touch_policy = require("src.presentation.interaction.UITouchPolicy")
local host_runtime = require("src.presentation.adapter.HostRuntimePort")

local bindings = {}

local missing_button_tips = {}

local function _show_missing_button_tip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  host_runtime.show_tips("UI 节点未适配: " .. tostring(name), 2.0)
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
      _show_missing_button_tip(name)
      if name == always_show_nodes.action_log_button then
        logger.info("[调试屏] 行动日志按钮注册失败: query_nodes异常")
      end
      return
    end
    nodes = result
    cache[name] = nodes
  end
  if not nodes or not nodes[1] then
      _show_missing_button_tip(name)
      if name == always_show_nodes.action_log_button then
        logger.info("[调试屏] 行动日志按钮注册失败: 未找到节点")
      end
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

function bindings.enable_action_log_toggle_touch(cache, ui)
  local targets = always_show_contract.action_log.toggle_targets or {}
  local enabled_count = 0
  local main_path_ok = false

  if ui and ui.set_touch_enabled then
    local ok, err = pcall(ui_touch_policy.set_action_log_toggle_touch, ui, true)
    if ok then
      main_path_ok = true
      enabled_count = #targets
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
    for _, name in ipairs(targets) do
      local nodes = cache and cache[name] or nil
      if not nodes or not nodes[1] then
        local ok, result = pcall(runtime.query_nodes, name)
        if not ok then
          logger.info(
            "[调试屏] 行动日志触控启用失败: query_nodes异常",
            "node=" .. tostring(name),
            "err=" .. tostring(result)
          )
        else
          nodes = result
        end
      end
      if nodes and nodes[1] then
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
      else
        logger.info("[调试屏] 行动日志触控启用失败: 未找到节点", "node=" .. tostring(name))
      end
    end
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
