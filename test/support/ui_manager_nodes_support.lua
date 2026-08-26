-- ui.manager 节点适配器(ENode/EButton/EImage/EProgressbar)的 spec 共享底座。
-- 这些适配器在 load 时捕获 context.allroles / context.event_handlers 的表引用,
-- 故 fake 角色只能就地写入同一张表,并在每例后清空,避免泄漏到别的 spec。
local context = require("src.ui.manager.context")

local M = {}

-- 适配器会调用的宿主角色方法全集(dot 调用,首参为 eui node id)。
local ROLE_METHODS = {
  "set_node_visible",
  "set_node_touch_enabled",
  "set_button_enabled",
  "set_button_text",
  "set_button_text_color",
  "set_button_font_size",
  "set_image_color",
  "set_image_texture_by_key_with_auto_resize",
  "set_progressbar_transition",
  "set_progressbar_max",
  "set_progressbar_min",
}

-- 记录每次宿主调用: { method = name, args = { ... } }
---@param roleid integer
function M.make_role(roleid)
  local role = { roleid = roleid, calls = {} }
  role.get_roleid = function()
    return roleid
  end
  for _, name in ipairs(ROLE_METHODS) do
    role[name] = function(...)
      role.calls[#role.calls + 1] = { method = name, args = table.pack(...) }
    end
  end
  return role
end

---@return table[] 该角色上某个宿主方法的全部调用记录
function M.calls_of(role, method)
  local found = {}
  for _, call in ipairs(role.calls) do
    if call.method == method then
      found[#found + 1] = call
    end
  end
  return found
end

function M.clear_roles()
  for i = #context.allroles, 1, -1 do
    table.remove(context.allroles, i)
  end
end

function M.install_roles(roles)
  M.clear_roles()
  for _, role in ipairs(roles) do
    context.allroles[#context.allroles + 1] = role
  end
end

-- Eggy 宿主的 math.tofixed 在测试进程里不存在,而 EButton/EImage/ELabel 的
-- __set_* 直接调它(不像 src/ui/render 那样带 guard)。整套 behavior 一起跑时,
-- 别的 spec(tick_clock_spec / test_env.install_defaults)会先把恒等桩装进 math
-- 并且不还原,于是这几个 spec 靠泄漏活着——单独跑(mutate 只跑相关子集)就
-- 「attempt to call a nil value (field 'tofixed')」全红,整个 manager 簇没法做变异测试。
-- 故底座自带装/还原,让每个 manager spec 不依赖目录顺序。
local _original_tofixed
local _tofixed_installed = false

-- 同理自备共享运行时端口基线(runtime ports / 付费网关 / tips):#217 的
-- runtime_baseline_guard 在 mutate 车道 after_case 逐项核对,窄 suite 子集里没有任何
-- 别的 spec 先装基线时,第一个用例就被判失败,整个 manager 簇的变异车道被堵死。
-- 只在缺失时补装(守卫同款 restore),全量车道基线已在位时是 no-op,不重置别的
-- suite 装好的运行时上下文——直接 env_runtime.refresh() 会把它们踩掉。
do
  local baseline_guard = require("test.support.runtime_baseline_guard")
  if #baseline_guard.missing_ports() > 0 then
    baseline_guard.restore()
  end
end

function M.install_host_math()
  if _tofixed_installed then return end
  _original_tofixed = math.tofixed
  math.tofixed = function(value)
    return value
  end
  _tofixed_installed = true
end

function M.restore_host_math()
  if not _tofixed_installed then return end
  math.tofixed = _original_tofixed
  _tofixed_installed = false
end

function M.clear_context()
  for k in pairs(context.nodes_list) do
    context.nodes_list[k] = nil
  end
  for k in pairs(context.event_handlers) do
    context.event_handlers[k] = nil
  end
  for k in pairs(context.name_node_mapping) do
    context.name_node_mapping[k] = nil
  end
  context.client_role = nil
  M.clear_roles()
end

return M
