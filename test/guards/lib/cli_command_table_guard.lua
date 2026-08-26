require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local git_query = require("test.guards.lib.git_query")

local M = {}

-- cli 子命令表 ↔ packages/ 一致性结构 guard(#316 / #300 Q4 决议):tools/cli.lua
-- tools/cli.lua 顶层静态路由表（封闭命令集）与 tools/packages/ 目录必须
-- 一一对应——路由到不存在的包(错名/遗漏)、存在但未路由也未豁免的包(多余)
-- 都报错。非路由包开白名单快照(test/guards/config/cli_command_table.lua),
-- 条目随包迁/新包同步维护,stale 条目(包已消失或已路由)同样报错要求销账。

local _CLI_ENTRY = "tools/cli.lua"
local _PACKAGES_ROOT = "tools/packages"
local _NON_ROUTED = require("test.guards.config.cli_command_table").non_routed_packages

-- 纯核:从 cli.lua 源码解析 commands 路由表条目({ name, pkg } 数组)。
-- 解析不到任何条目视为失败——表被改名/搬走后静默全绿比红更危险。
function M.parse_commands(source)
  local commands = {}
  for name, pkg in tostring(source or ""):gmatch('{%s*name%s*=%s*"([^"]+)"%s*,%s*pkg%s*=%s*"([^"]+)"') do
    commands[#commands + 1] = { name = name, pkg = pkg }
  end
  if #commands == 0 then
    return nil, "未能从 " .. _CLI_ENTRY .. " 解析出 commands 表条目(表结构变更需同步本 guard)"
  end
  return commands
end

-- 纯策略核:给定 commands 条目、packages/ 目录清单、非路由白名单,返回违规
-- 清单(字符串数组)。三份输入都可注入(合成语料),check 不碰 git 与文件系统。
function M.check(commands, package_dirs, non_routed)
  local dir_set = {}
  for _, dir in ipairs(package_dirs or {}) do
    dir_set[dir] = true
  end
  local exempt = {}
  for _, dir in ipairs(non_routed or {}) do
    exempt[dir] = true
  end

  local violations = {}
  local routed = {}
  local seen_names = {}
  for _, entry in ipairs(commands or {}) do
    if seen_names[entry.name] then
      violations[#violations + 1] = "cli_command_table_guard: 子命令 "
        .. entry.name .. " 在 commands 表重复登记(封闭命令集一名一entry)"
    end
    seen_names[entry.name] = true
    if routed[entry.pkg] == nil then
      routed[entry.pkg] = true
      if not dir_set[entry.pkg] then
        violations[#violations + 1] = "cli_command_table_guard: 子命令 "
          .. entry.name .. " 路由到不存在的包 tools/packages/" .. entry.pkg
          .. "(错名或目录遗漏;新包先落目录,改名同步修 commands 表)"
      end
      if exempt[entry.pkg] then
        violations[#violations + 1] = "cli_command_table_guard: 包 "
          .. entry.pkg .. " 已挂路由却仍在非路由白名单(从 "
          .. "test/guards/config/cli_command_table.lua 销账)"
      end
    end
  end

  for dir in pairs(dir_set) do
    if not routed[dir] and not exempt[dir] then
      violations[#violations + 1] = "cli_command_table_guard: 包 tools/packages/"
        .. dir .. " 未挂路由也不在非路由白名单(多余;挂进 commands 表或在 "
        .. "test/guards/config/cli_command_table.lua 登记豁免理由)"
    end
  end

  for dir in pairs(exempt) do
    if not dir_set[dir] then
      violations[#violations + 1] = "cli_command_table_guard: 非路由白名单条目 "
        .. dir .. " 对应的 tools/packages/" .. dir .. " 已不存在(stale,销账)"
    end
  end

  table.sort(violations)
  return violations
end

-- IO 壳:读 tools/cli.lua 源码解析路由表;git 取 packages/ 下 tracked +
-- 未跟踪未忽略文件推导目录清单(新增未提交包也要被拦),合并喂纯核。
function M.run()
  local source, read_err = fs_lib.read_file(_CLI_ENTRY)
  if source == nil then
    return { ok = false, error = "cli_command_table_guard error: " .. tostring(read_err) }
  end

  local commands, parse_err = M.parse_commands(source)
  if commands == nil then
    return { ok = false, error = "cli_command_table_guard error: " .. tostring(parse_err) }
  end

  local lines, err = git_query.list_files(_PACKAGES_ROOT)
  if lines == nil then
    return { ok = false, error = "cli_command_table_guard error: " .. tostring(err) }
  end

  local dir_set = {}
  for _, line in ipairs(lines) do
    local dir = line:match("^tools/packages/([^/]+)/")
    if dir ~= nil then
      dir_set[dir] = true
    end
  end

  local dirs = {}
  for dir in pairs(dir_set) do
    dirs[#dirs + 1] = dir
  end

  local violations = M.check(commands, dirs, _NON_ROUTED)
  if #violations > 0 then
    return { ok = false, error = table.concat(violations, "\n") }
  end
  return { ok = true, message = "cli_command_table_guard ok" }
end

return M
