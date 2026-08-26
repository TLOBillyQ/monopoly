require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.host_role_type_guard")

-- #376:宿主解析链返回值(runtime_ports.resolve_role / GameAPI.get_role /
-- resolve_role_with)禁用 type(x) ==/~= "table" 把门——宿主 Role 是
-- userdata(CampRole),type() 返回宿主类名,这道门恒假导致功能静默退化
-- (#266 / #375 两次踩坑)。守卫必须能命中 #375 修复前的旧写法,且对盘点
-- 确认的全部正确模式(鸭子判定/容器判断/内部数据防御/#375 新写法)零误报。

local _PATH = "src/fake/host_gate.lua"

local function _check(files)
  local paths = {}
  for path in pairs(files) do
    paths[#paths + 1] = path
  end
  table.sort(paths)
  return guard.check(paths, function(path)
    return files[path]
  end)
end

local function _count(violations)
  local count = 0
  for _, v in ipairs(violations or {}) do
    if v:find("读不到", 1, true) == nil then
      count = count + 1
    end
  end
  return count
end

local function _lint(content)
  return _count(_check({ [_PATH] = content }))
end

TestHostRoleTypeGuard = {}

-- ── 反例:必须红 ──────────────────────────────────────────────

-- #375 修复前的旧写法:type(role) ~= "table" 出现在 runtime_ports.resolve_role
-- 的返回值上,守卫必须命中(工单验收标准第一项)。
function TestHostRoleTypeGuard:test_flags_old_375_style_gate_on_resolve_role()
  local violations = _check({
    [_PATH] = [[
local function _try_show_share_panel(actor_role_id)
  local role = runtime_ports.resolve_role(actor_role_id)
  if type(role) ~= "table" or type(role.show_map_share_panel) ~= "function" then
    return
  end
end
]],
  })
  lu.assertEquals(_count(violations), 1)
  lu.assertEvalToTrue(violations[1]:find(_PATH .. ":3", 1, true))
  lu.assertEvalToTrue(violations[1]:find("type(role)", 1, true))
end

-- GameAPI.get_role 直接赋值同样受管(工单点名的第二个入口)。
function TestHostRoleTypeGuard:test_flags_game_api_get_role_gate()
  local violations = _check({
    [_PATH] = [[
local function _role(player_id)
  local role = GameAPI.get_role(player_id)
  if type(role) == "table" then
    return role
  end
end
]],
  })
  lu.assertEquals(_count(violations), 1)
end

-- resolve_role_with 封装(role_resolver / host_roles)返回值同样受管。
function TestHostRoleTypeGuard:test_flags_resolve_role_with_gate()
  local violations = _check({
    [_PATH] = [[
local function _resolve(role_id)
  local resolved = host_roles.resolve_role_with(role_id)
  if type(resolved) ~= "table" then
    return nil
  end
  return resolved
end
]],
  })
  lu.assertEquals(_count(violations), 1)
end

-- pcall 双返回形态:GameAPI.get_role 被 pcall 包装时,第二个返回值是宿主 Role。
function TestHostRoleTypeGuard:test_flags_pcall_wrapped_get_role_gate()
  local violations = _check({
    [_PATH] = [[
local function _resolve(player_id)
  local ok, role = pcall(GameAPI.get_role, player_id)
  if ok and type(role) == "table" then
    return role
  end
end
]],
  })
  lu.assertEquals(_count(violations), 1)
end

-- 非 local 赋值形态(作用域内变量被宿主解析重新赋值)同样受管。
function TestHostRoleTypeGuard:test_flags_plain_reassignment_gate()
  local violations = _check({
    [_PATH] = [[
local role = nil
function host.resolve(player_id)
  role = runtime_ports.resolve_role(player_id)
  if type(role) ~= "table" then
    return nil
  end
  return role
end
]],
  })
  lu.assertEquals(_count(violations), 1)
end

-- 镜像比较 "table" == type(role) 同样命中。
function TestHostRoleTypeGuard:test_flags_mirrored_compare_gate()
  local violations = _check({
    [_PATH] = [[
local function _ok(role_id)
  local role = runtime_ports.resolve_role(role_id)
  return "table" == type(role)
end
]],
  })
  lu.assertEquals(_count(violations), 1)
end

-- 违规报告必须带文件与行号,且给修复方向。
function TestHostRoleTypeGuard:test_flags_report_carries_path_line_and_advice()
  local violations = _check({
    [_PATH] = [[
local role = runtime_ports.resolve_role(1)
if type(role) ~= "table" then return nil end
]],
  })
  lu.assertEquals(_count(violations), 1)
  lu.assertEvalToTrue(violations[1]:find(_PATH .. ":2", 1, true))
  lu.assertEvalToTrue(violations[1]:find("userdata", 1, true))
  lu.assertEvalToTrue(violations[1]:find("#376", 1, true))
end

-- 守卫自身红线:读不到文件必须报错而非静默跳过。
function TestHostRoleTypeGuard:test_flags_unreadable_file_instead_of_silently_skipping_it()
  local violations = guard.check({ _PATH }, function()
    return nil
  end)
  lu.assertEquals(#violations, 1)
  lu.assertEvalToTrue(violations[1]:find("读不到", 1, true))
end

-- ── 正例:盘点确认的正确模式必须全部放行 ─────────────────────

-- #375 新写法:nil 守卫 + 方法存在性检查,type() 只用在字段上(鸭子判定)。
function TestHostRoleTypeGuard:test_passes_fixed_375_style_nil_guard_plus_method_check()
  lu.assertEquals(_lint([[
local function _try_show_share_panel(actor_role_id)
  local role = runtime_ports.resolve_role(actor_role_id)
  if role == nil or type(role.show_map_share_panel) ~= "function" then
    return
  end
end
]]), 0)
end

-- 鸭子判定(init_runtime._show_tips_of / status3d/status.lua / ui_events.lua 等):
-- type() 只比较 "function"/"string",不涉及 "table"。
function TestHostRoleTypeGuard:test_passes_duck_typing_function_checks()
  lu.assertEquals(_lint([[
local function _show_tips_of(role)
  local resolved, show_tips = pcall(function()
    return role ~= nil and role.show_tips or nil
  end)
  if not resolved or type(show_tips) ~= "function" then
    return nil
  end
  return show_tips
end
]]), 0)
end

-- 容器判断:resolve_roles(复数)返回真 Lua 数组容器,type(roles) == "table" 安全。
function TestHostRoleTypeGuard:test_passes_plural_resolve_roles_container_gate()
  lu.assertEquals(_lint([[
local function _resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    return roles
  end
  return {}
end
]]), 0)
end

-- 容器判断:pcall 包装 get_all_valid_roles(复数)同样是安全容器。
function TestHostRoleTypeGuard:test_passes_pcall_plural_container_gate()
  lu.assertEquals(_lint([[
local function _query()
  local ok, roles = pcall(GameAPI.get_all_valid_roles)
  if ok and type(roles) == "table" then
    return roles
  end
  return {}
end
]]), 0)
end

-- 容器判断:roles 仅作函数参数(role_ports._find_role_by_id 等),不受管。
function TestHostRoleTypeGuard:test_passes_roles_as_plain_parameter_gate()
  lu.assertEquals(_lint([[
local function _find_role_by_id(roles, player_id)
  if type(roles) ~= "table" then
    return nil
  end
  return roles[1]
end
]]), 0)
end

-- 内部数据防御(achievement_runtime.skin_equipped / default_ports / sound.lua):
-- 变量来自配置表而非宿主解析链,type 把门安全。
function TestHostRoleTypeGuard:test_passes_internal_config_data_gate()
  lu.assertEquals(_lint([[
local function _validate_skin(skin)
  if type(skin) ~= "table" or type(skin.name) ~= "string" or skin.name == "" then
    return nil
  end
  return skin
end
]]), 0)
end

-- 变量复用:宿主解析后变量被重新赋值为本地表,type 把门合法,不得误报。
function TestHostRoleTypeGuard:test_passes_reassignment_to_local_table()
  lu.assertEquals(_lint([[
local function _f(role_id)
  local role = runtime_ports.resolve_role(role_id)
  local role = { name = "stub" }
  if type(role) == "table" then
    return role
  end
end
]]), 0)
end

-- 非 local 重赋值(作用域变量被重新赋值为本地表)走 _PLAIN_REASSIGN 分支,
-- 该分支此前无正例背书——补上,防回归。
function TestHostRoleTypeGuard:test_passes_plain_reassignment_to_local_table()
  lu.assertEquals(_lint([[
local role = nil
function host.resolve(player_id)
  role = runtime_ports.resolve_role(player_id)
  role = { name = "stub" }
  if type(role) == "table" then
    return role
  end
end
]]), 0)
end

-- for-in 循环变量复用:宿主解析后同名 role 被 for 头遮蔽为容器元素,
-- 循环体内 type(role) == "table" 是容器判断,不得误报。
function TestHostRoleTypeGuard:test_passes_for_in_loop_var_reuse()
  lu.assertEquals(_lint([[
local function _f(role_id)
  local role = runtime_ports.resolve_role(role_id)
  for _, role in ipairs(roster) do
    if type(role) == "table" then
      return role
    end
  end
end
]]), 0)
end

-- 跨函数同名:函数 B 的本地表 role 与函数 A 的宿主解析 role 互不影响。
function TestHostRoleTypeGuard:test_passes_cross_function_same_name()
  lu.assertEquals(_lint([[
local function _resolve_host(role_id)
  local role = runtime_ports.resolve_role(role_id)
  return role
end

local function _build_local()
  local role = { name = "stub" }
  if type(role) == "table" then
    return role
  end
end
]]), 0)
end

-- 非 "table" 比较(type(role) ~= "nil" 等)不是把门,放行。
function TestHostRoleTypeGuard:test_passes_non_table_type_compare()
  lu.assertEquals(_lint([[
local function _f(role_id)
  local role = runtime_ports.resolve_role(role_id)
  if type(role) ~= "nil" then
    return role
  end
end
]]), 0)
end

-- 注释里的 type(role) == "table"(#266 教训注释)不算违规。
function TestHostRoleTypeGuard:test_passes_comment_mention_of_gate()
  lu.assertEquals(_lint([[
-- 不要用 type(role) == "table" 把门:Eggy 沙盒的 type() 对宿主对象返回的是宿主
-- 类名(真机取证 #266:Role 返回 "CampRole"),这道门会恒假地把每条私人提示都打回广播。
local function _f(role_id)
  local role = runtime_ports.resolve_role(role_id)
  if role ~= nil then
    return role
  end
end
]]), 0)
end

-- 嵌套调用:_show_tips_of(resolve_role(...)) 的接收变量是方法本身,不是宿主对象,
-- 后续 type(show_tips) == "function" 鸭子判定放行。
function TestHostRoleTypeGuard:test_passes_nested_call_receiver_is_not_tracked()
  lu.assertEquals(_lint([[
local function _tips(role_id)
  local show_tips = _show_tips_of(runtime_ports.resolve_role(role_id))
  if type(show_tips) ~= "function" then
    return nil
  end
  return show_tips
end
]]), 0)
end

-- 非宿主解析的同名方法(如 get_role_data)不匹配宿主解析链,放行。
function TestHostRoleTypeGuard:test_passes_similar_method_names_are_not_tracked()
  lu.assertEquals(_lint([[
local function _f(role_id)
  local role = some_port.get_role_data(role_id)
  if type(role) == "table" then
    return role
  end
end
]]), 0)
end

-- 真实仓库现状零误报:取 #375 修复后的 action_dispatcher_handlers 关键片段。
function TestHostRoleTypeGuard:test_passes_current_real_source_fragment()
  lu.assertEquals(_lint([[
local function _try_show_share_panel(actor_role_id, player)
  local role_id = role_id_utils.normalize(actor_role_id)
  local role = runtime_ports.resolve_role(role_id)
  if role == nil or type(role.show_map_share_panel) ~= "function" then
    logger.warn("auto share panel skipped: role or show_map_share_panel missing:", tostring(role_id))
    return
  end
end
]]), 0)
end


return TestHostRoleTypeGuard
