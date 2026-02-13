local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local ui_nodes = require("src.presentation.shared.UINodes")

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
      if name == ui_nodes.debug.toggle_image then
        logger.info("[调试屏] 图片_82注册失败: query_nodes异常")
      end
      return
    end
    nodes = result
    cache[name] = nodes
  end
  if not nodes or not nodes[1] then
    _show_missing_button_tip(name)
    if name == ui_nodes.debug.toggle_image then
      logger.info("[调试屏] 图片_82注册失败: 未找到节点")
    end
    return
  end
  if name == ui_nodes.debug.toggle_image then
    logger.info("[调试屏] 图片_82注册成功", "nodes=" .. tostring(#nodes))
  end
  registered[name] = true
  for _, node in ipairs(nodes) do
    local listener = node:listen(UIManager.EVENT.CLICK, function(data)
      callback(data)
    end)
    table.insert(listeners, listener)
  end
end

function bindings.enable_debug_toggle_touch(cache)
  local nodes = cache and cache[ui_nodes.debug.toggle_image] or nil
  if not nodes or not nodes[1] then
    local ok, result = pcall(runtime.query_nodes, ui_nodes.debug.toggle_image)
    if not ok then
      logger.info("[调试屏] 图片_82触控启用失败: query_nodes异常")
      return
    end
    nodes = result
  end
  if not nodes or not nodes[1] then
    logger.info("[调试屏] 图片_82触控启用失败: 未找到节点")
    return
  end
  runtime.for_each_role_or_global(function()
    for _, node in ipairs(nodes) do
      node.disabled = false
    end
  end)
  runtime.set_client_role(nil)
  logger.info("[调试屏] 图片_82触控已启用", "nodes=" .. tostring(#nodes))
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
