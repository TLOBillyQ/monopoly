require("test.bootstrap").install_package_paths()

local git_query = require("test.guards.lib.git_query")

local M = {}

-- 禁同名对结构 guard（#298 的发现式包结构过渡纪律）：禁止新增
-- foo.lua + foo/test/ 同名对——新测试一律随包(<pkg>/test/ 目录即包)。
-- 管辖 tools/ + test/support/(test/behavior 与 test/guards 不受管辖:前者
-- out of scope,后者天生跨目录无所属包)。存量同名对开白名单快照
-- (test/guards/config/same_name_pair.lua),只许减不许增,由迁移工单逐个销账。

local _SCOPE = { "tools", "test/support" }
local _WHITELIST = require("test.guards.config.same_name_pair").pairs

-- 纯策略核:给定文件路径表(字符串数组),返回违规清单(字符串数组)。
-- 同名对判定:存在形如 <dir>/<name>/test/<...> 的路径,且 <dir>/<name>.lua
-- 文件存在 → 对 (dir/name)。路径表可注入(合成语料),check 不碰 git 与文件
-- 系统——门禁的判定逻辑必须能拿合成的违规输入喂进来验证它真的会红。
function M.check(paths, whitelist)
  whitelist = whitelist or _WHITELIST
  local path_set = {}
  for _, path in ipairs(paths or {}) do
    local normalized = tostring(path):gsub("\\", "/")
    if normalized ~= "" then
      path_set[normalized] = true
    end
  end

  local violations = {}
  local seen = {}
  for path in pairs(path_set) do
    -- <dir>/<name>/test/<rest> → dir, name(rest 任意深度)
    local dir, name = path:match("^(.*)/([^/]+)/test/.+$")
    if dir ~= nil and name ~= nil and not seen[dir .. "/" .. name] then
      seen[dir .. "/" .. name] = true
      local peer = dir .. "/" .. name .. ".lua"
      if path_set[peer] and not whitelist[dir .. "/" .. name] then
        violations[#violations + 1] = "same_name_pair_guard: 同名对 "
          .. peer .. " + " .. dir .. "/" .. name .. "/test/ 违规（#298 的发现式包结构："
          .. " foo.lua + foo/test/ 同名对废除,新测试一律随包 <pkg>/test/;"
          .. " 存量同名对只由迁移工单销账,日常迭代禁止顺手迁)"
      end
    end
  end
  table.sort(violations)
  return violations
end

-- IO 壳:git 取管辖两棵树的 tracked + 未跟踪未忽略文件(tracked 之外还要拦
-- 未提交的新增——"人为新增同名对"验的就是这个形态),合并喂纯核。
function M.run()
  local paths = {}
  for _, scope in ipairs(_SCOPE) do
    local lines, err = git_query.list_files(scope)
    if lines == nil then
      return { ok = false, error = "same_name_pair_guard error: " .. tostring(err) }
    end
    for _, line in ipairs(lines) do
      paths[#paths + 1] = line
    end
  end

  local violations = M.check(paths, _WHITELIST)
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end
  return { ok = true, message = "same_name_pair_guard ok" }
end

return M
