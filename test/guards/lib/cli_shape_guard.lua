require("test.bootstrap").install_package_paths()

local git_query = require("test.guards.lib.git_query")

local M = {}

-- 包内 cli.lua 形态契约结构 guard(#316 / #300 Q4 决议):tools/packages/
-- 下每个包内 cli.lua 必须满足统一接口形态(#300 决议,骨架约定见
-- tools/cli.lua 头部注释)——require 返回 table 且 main 为 function。
-- 与 cli_command_table_guard 同族:那条管「表 ↔ 目录」,这条管「模块形态」。

local _CLI_GLOB = "tools/packages/*/cli.lua"

-- 纯核:断言单个包 cli 模块形态,违规返回字符串,干净返回 nil。
function M.check_module(pkg, module)
  if type(module) ~= "table" then
    return "cli_shape_guard: packages." .. pkg .. ".cli 未返回 table(实际 "
      .. type(module) .. ";统一接口形态要求 return { main = function, ... })"
  end
  if type(module.main) ~= "function" then
    return "cli_shape_guard: packages." .. pkg .. ".cli.main 不是 function(实际 "
      .. type(module.main) .. ";顶层 cli.lua 依赖 cli.main(args, env) 契约)"
  end
  return nil
end

-- 纯策略核:loader 可注入(合成语料喂红/绿),默认 pcall require。
function M.check(pkgs, loader)
  loader = loader or function(module_name)
    return pcall(require, module_name)
  end

  local violations = {}
  for _, pkg in ipairs(pkgs or {}) do
    local module_name = "packages." .. tostring(pkg) .. ".cli"
    local ok, module = loader(module_name)
    if not ok then
      violations[#violations + 1] = "cli_shape_guard: " .. module_name
        .. " 加载失败: " .. tostring(module)
    else
      local violation = M.check_module(pkg, module)
      if violation ~= nil then
        violations[#violations + 1] = violation
      end
    end
  end
  table.sort(violations)
  return violations
end

-- IO 壳:git 枚举 tools/packages/*/cli.lua(tracked + 未跟踪未忽略,新增未提交
-- 的包内 cli 也要被验),逐个 require 断言形态。
function M.run()
  local lines, err = git_query.list_files(_CLI_GLOB)
  if lines == nil then
    return { ok = false, error = "cli_shape_guard error: " .. tostring(err) }
  end

  local pkg_set = {}
  for _, line in ipairs(lines) do
    local pkg = line:match("^tools/packages/([^/]+)/cli%.lua$")
    if pkg ~= nil then
      pkg_set[pkg] = true
    end
  end

  local pkgs = {}
  for pkg in pairs(pkg_set) do
    pkgs[#pkgs + 1] = pkg
  end
  table.sort(pkgs)

  local violations = M.check(pkgs)
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end
  return { ok = true, message = "cli_shape_guard ok" }
end

return M
