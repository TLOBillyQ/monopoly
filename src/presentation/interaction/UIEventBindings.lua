local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local ui_nodes = require("src.presentation.shared.UINodes")
local ui_touch_policy = require("src.presentation.interaction.UITouchPolicy")

local bindings = {}

local missing_button_tips = {}

local function _show_missing_button_tip(name)
  if missing_button_tips[name] then
    return
  end
  missing_button_tips[name] = true
  GlobalAPI.show_tips("UI 节点未适配: " .. tostring(name), 2.0)
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
      if name == ui_nodes.action_log.toggle_image then
        logger.info("[调试屏] 倒计时时钟注册失败: query_nodes异常")
      elseif name == ui_nodes.action_log.toggle_button then
        logger.info("[调试屏] 行动日志按钮注册失败: query_nodes异常")
      end
      return
    end
    nodes = result
    cache[name] = nodes
  end
  if not nodes or not nodes[1] then
    _show_missing_button_tip(name)
    if name == ui_nodes.action_log.toggle_image then
      logger.info("[调试屏] 倒计时时钟注册失败: 未找到节点")
    elseif name == ui_nodes.action_log.toggle_button then
      logger.info("[调试屏] 行动日志按钮注册失败: 未找到节点")
    end
    return
  end
  if name == ui_nodes.action_log.toggle_image then
    logger.info("[调试屏] 倒计时时钟注册成功", "nodes=" .. tostring(#nodes))
  elseif name == ui_nodes.action_log.toggle_button then
    logger.info("[调试屏] 行动日志按钮注册成功", "nodes=" .. tostring(#nodes))
  end
  registered[name] = true
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    table.insert(listeners, listener)
  end
end

function bindings.enable_action_log_toggle_touch(cache)
  local targets = ui_nodes.action_log.toggle_targets or {}
  local enabled_count = 0
  for _, name in ipairs(targets) do
    local nodes = cache and cache[name] or nil
    if not nodes or not nodes[1] then
      local ok, result = pcall(runtime.query_nodes, name)
      if not ok then
        logger.info("[调试屏] 行动日志触控启用失败: query_nodes异常", "node=" .. tostring(name))
      else
        nodes = result
      end
    end
    if nodes and nodes[1] then
      runtime.for_each_role_or_global(function()
        ui_touch_policy.set_runtime_nodes_touch_enabled(nodes, true)
      end)
      enabled_count = enabled_count + #nodes
    else
      logger.info("[调试屏] 行动日志触控启用失败: 未找到节点", "node=" .. tostring(name))
    end
  end
  runtime.set_client_role(nil)
  logger.info("[调试屏] 行动日志触控已启用", "nodes=" .. tostring(enabled_count))
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
