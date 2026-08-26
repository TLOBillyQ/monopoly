require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local git_query = require("test.guards.lib.git_query")

local M = {}

-- 宿主解析链返回值禁用 type(x) == "table" 把门(#376):
-- runtime_ports.resolve_role / GameAPI.get_role / role_resolver.resolve_role_with
-- 等返回宿主 Role 对象,是 userdata(CampRole)而非 Lua table——type() 返回宿主
-- 类名,这道门恒假,功能静默退化(#266 / #375 两次踩坑)。复数解析(resolve_roles /
-- get_all_valid_roles)返回的是真 Lua 数组容器,type == "table" 是安全判断,不拦。
--
-- 静态判定:函数级变量追踪。`local X = <ns>.resolve_role(...)` / `X = ...` /
-- `local ok, X = pcall(<ns>.get_role, ...)` 之后,X 被标记为「宿主 Role 对象」;
-- X 再被任意赋值即失效(变量复用不得误报);函数定义行清空追踪(跨函数同名不得
-- 误报)。命中规则:`type(X) == "table"` / `~= "table"`(含镜像 "table" == 形态)
-- 出现在已标记变量上。字段访问(如 type(X.method))不匹配裸标识符,鸭子判定放行。

local _HOST_ROLE_METHODS = {
  resolve_role = true,
  resolve_role_with = true,
  get_role = true,
}

local _FUNC_HEADER_PATTERNS = {
  "^(%s*)local%s+function%s+",
  "^(%s*)function%s+",
  "^(%s*)[%w_][%w_%.]*%s*=%s*function%s*%(",
}

-- pcall 双返回形态:`local ok, X = pcall(<ns>.<method>, ...)`,X 是第二个
-- 返回值(宿主 Role)。注意实参是函数引用,方法名后**没有** `(`(直接调用才有)。
-- pcall 包装复数解析(get_all_valid_roles)时 method 不在集合,不追踪。
local _PCALL_ASSIGN = "^%s*local%s+[%w_]+,%s*([%w_]+)%s*=%s*pcall%s*%(%s*([%w_]+)%.([%w_]+)"
local _LOCAL_METHOD_CALL = "^%s*local%s+([%w_]+)%s*=%s*([%w_]+)%.([%w_]+)%s*%("
local _PLAIN_METHOD_CALL = "^%s*([%w_]+)%s*=%s*([%w_]+)%.([%w_]+)%s*%("
local _LOCAL_REASSIGN = "^%s*local%s+([%w_]+)%s*="
local _PLAIN_REASSIGN = "^%s*([%w_]+)%s*="

local _TYPE_GATE = "type%s*%(%s*[%w_]+%s*%)"
local _IDENT_IN_GATE = "type%s*%(%s*([%w_]+)%s*%)"

local function _is_func_header(code)
  for _, pattern in ipairs(_FUNC_HEADER_PATTERNS) do
    if code:match(pattern) then
      return true
    end
  end
  return false
end

local function _is_host_role_method(method)
  return _HOST_ROLE_METHODS[method] == true
end

-- 纯策略核:给定文件路径表与 read(path) -> content|nil,返回违规列表。
-- 不碰 git、不碰文件系统——spec 喂合成的「#375 旧写法」验证它真的会红,
-- 喂盘点确认的正确模式(鸭子判定/容器判断/内部数据防御/#375 新写法)验证零误报。
-- 门禁的价值全在能对合成违规输入变红。
function M.check(paths, read)
  local violations = {}

  for _, path in ipairs(paths) do
    local content = read(path)
    if content == nil then
      violations[#violations + 1] = "host_role_type_guard: 读不到 " .. tostring(path)
    else
      local tracked = {}
      local line_no = 0
      for line in (content .. "\n"):gmatch("(.-)\n") do
        line_no = line_no + 1
        -- 先剥行内注释再判定:注释里的 type(role) == "table"(如 #266 教训注释)不算违规。
        local code = line:gsub("%-%-.*$", "")

        if _is_func_header(code) then
          tracked = {}
        end

        local pcall_var, _, pcall_method = code:match(_PCALL_ASSIGN)
        if pcall_var then
          tracked[pcall_var] = _is_host_role_method(pcall_method) and true or nil
        else
          -- ⚠️ 不能用 match(a) or match(b) 合并:or 是表达式,多返回值会被截断成单值,
          -- method 捕获丢失导致追踪恒置 nil。必须拆开两次匹配。
          local var, _, method = code:match(_LOCAL_METHOD_CALL)
          if not var then
            var, _, method = code:match(_PLAIN_METHOD_CALL)
          end
          if var then
            tracked[var] = _is_host_role_method(method) and true or nil
          else
            -- 其他赋值(任意来源)都会让同名追踪失效:变量被重用时守卫不得误报。
            local reassigned = code:match(_LOCAL_REASSIGN) or code:match(_PLAIN_REASSIGN)
            if reassigned then
              tracked[reassigned] = nil
            end
          end
        end

        -- for 头循环变量在循环体内遮蔽外层同名变量(迭代值是容器元素,非宿主
        -- 解析结果),须从追踪清掉,否则 for 内 type(role) == "table" 容器判断被误报。
        local numeric_var = code:match("^%s*for%s+([%w_]+)%s*=%s*")
        if numeric_var then
          tracked[numeric_var] = nil
        end
        local for_list = code:match("^%s*for%s+([%w_,%s]+)%s*in%s+")
        if for_list then
          -- 列表尾部可能带空格,用 %s*, 容忍逗号前空白(`_, role ,`)。
          for name in (for_list .. ","):gmatch("([%w_]+)%s*,") do
            tracked[name] = nil
          end
        end

        -- type(X) 把门检测:X 必须是宿主 Role 追踪中的裸标识符,且与 "table" 比较。
        -- 字段访问(role.show_map_share_panel 等)不是裸标识符,不匹配,鸭子判定放行。
        local search_from = 1
        while true do
          local start_pos, end_pos = code:find(_TYPE_GATE, search_from)
          if start_pos == nil then
            break
          end
          local ident = code:sub(start_pos, end_pos):match(_IDENT_IN_GATE)
          search_from = end_pos + 1
          if tracked[ident] then
            local before = code:sub(1, start_pos - 1)
            local after = code:sub(end_pos + 1)
            if after:match("^%s*[~=]=%s*[\"']table[\"']")
              or before:match("[\"']table[\"']%s*[~=]=%s*$") then
              violations[#violations + 1] = "host_role_type_guard: " .. path .. ":" .. line_no
                .. " 宿主解析返回值被 type(" .. ident .. ") 与 \"table\" 比较把门(#376):"
                .. " 宿主 Role 是 userdata(CampRole),type() 返回宿主类名,这道门恒假静默退化;"
                .. " 改 nil 守卫 + 方法存在性检查(见 #375 / init_runtime._show_tips_of)"
            end
          end
        end
      end
    end
  end

  return violations
end

-- IO 壳:取 src/ 下 tracked + 未跟踪未忽略的 lua 文件(tracked 之外还要拦未提交
-- 新增——"人为新增违规"验的就是这个形态),把真实 reader 交给纯核。
function M.run()
  local paths, err = git_query.list_files("src")
  if paths == nil then
    return { ok = false, error = "host_role_type_guard error: " .. tostring(err) }
  end
  local violations = M.check(paths, fs_lib.read_file)
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end
  return { ok = true, message = "host_role_type_guard ok" }
end

return M
