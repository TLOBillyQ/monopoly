-- packages/acceptance/provision.lua —— APS PATH 三件的幂等 provision 命令面(工单 #606)
--
-- 背景:任务卡「配置蛋仔lua swarm-forge环境」把 APS 三件(gherkin-parser /
-- ir-dry-checker / gherkin-mutator)从 Babashka 版 Acceptance-Pipeline-Specification
-- 迁到本仓 `tools/tools.lock` 跟随的 Lua rock `acceptance4lua`(bb 版读不了本仓
-- `# language: zh-CN` 的 feature,直接 `missing feature declaration`)。供给形态是
-- `<swarm-root>/.swarmforge/bin/` 里三个 bash→Lua 转发器(launcher 把该目录放 PATH 最前)。
--
-- 缺口正是 `.swarmforge/` 属 gitignored 运行时状态、`distclean` 连它一起删:转发器丢了
-- 没有版本化的重建入口,只能照 constitution 里的配方手抄 bash。本文件就是那份配方的
-- 版本化真源的执行端——正文在 packages.acceptance.aps_forwarders,根解析在
-- packages.acceptance.swarm_root,本文件只做「幂等落盘 + 命令面」这段有副作用的事。
--
-- 三条口径与既有车道一致:
--   1. 目标 bin 目录跟着 launcher 的 PATH 走 = SwarmForge 项目根(持 `.swarmforge/roles.tsv`
--      的目录;worktree 场景下即 `git --git-common-dir` 的父目录),与
--      `swarm_tool.sh require` 的解析口径同构——否则 provision 与 probe 各说各话;
--   2. 解释器探测式复用 packages.luaunit_runner.lua54(探不到 lua5.4 退回 PATH 上的
--      "lua"),并烘进正文:PATH 上的 `lua` 可能是 5.5,不是本仓钉定的 5.4;
--   3. rock 装载复用 foundation.bootstrap.ensure_tool,落 `<swarm-root>/.toolcache/luarocks`
--      ——与转发器实际 exec 的那份入口同一个根,不然装完入口仍找不到 rock。
local _self = debug.getinfo(1, "S").source or "@tools/packages/acceptance/provision.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local _, bootstrap = _sb.install("tools/packages/acceptance", _self)

local forwarders = require("packages.acceptance.aps_forwarders")
local swarm_root = require("packages.acceptance.swarm_root")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local lua54 = require("packages.luaunit_runner.lua54")

local M = {}

local _APS_ROCK = "acceptance4lua"

function M.detect_lua_bin()
  return lua54.lua54_bin()
end

-- 幂等落盘:内容一致不动;缺失或漂移才写并 chmod 755。options.lua_bin 缺省走探测,
-- options.tools 给子集时只碰子集。失败返回 (nil, err),已写部分不回滚——正文可重入。
function M.provision(options)
  options = options or {}
  local bin_dir = options.bin_dir
  if bin_dir == nil or bin_dir == "" then
    return nil, "provision: 缺少 bin_dir"
  end

  -- 没给解释器(含纯空白这种「看着像有值」的假值)就走探测口径——报告里的 lua_bin
  -- 必须等于真正烘进正文的那个词,否则下次排障就被报告带偏。
  local lua_bin = tostring(options.lua_bin or "")
  if forwarders.is_blank_launcher(lua_bin) then
    lua_bin = M.detect_lua_bin()
  end
  local desired = forwarders.desired_bodies(lua_bin)

  local ok, err = fs_lib.ensure_dir(bin_dir)
  if not ok then
    return nil, err
  end

  local written = {}
  local unchanged = {}
  for _, tool in ipairs(options.tools or forwarders.TOOLS) do
    local body = desired[tool.name]
    if body == nil then
      return nil, "provision: 未登记的 APS 工具 " .. tostring(tool.name)
    end
    local path = path_lib.join_path(bin_dir, tool.name)
    if fs_lib.read_raw(path) == body then
      unchanged[#unchanged + 1] = tool.name
    else
      local wrote, write_err = fs_lib.write_file(path, body)
      if not wrote then
        return nil, write_err
      end
      local chmod = proc_lib.run_command({ "chmod", "755", path })
      if not chmod.ok then
        return nil, "chmod 755 失败: " .. path
      end
      written[#written + 1] = tool.name
    end
  end

  return {
    bin_dir = bin_dir,
    lua_bin = lua_bin,
    written = written,
    unchanged = unchanged,
  }
end

-- 报告正文(纯演算):命令面只负责把它逐行写出去,断言报告形状不必起子进程。
function M.report_lines(report, rock_url)
  return {
    string.format("APS 转发器根目录: %s", report.bin_dir),
    string.format("解释器: %s", report.lua_bin),
    string.format("rock: %s", tostring(rock_url)),
    string.format("重建 %d 件: %s", #report.written, table.concat(report.written, ", ")),
    string.format("保留 %d 件: %s", #report.unchanged, table.concat(report.unchanged, ", ")),
  }
end

function M.usage()
  return table.concat({
    "用法: lua tools/packages/acceptance/provision.lua",
    "",
    "幂等重建 SwarmForge 的 APS PATH 三件——<swarm-root>/.swarmforge/bin/ 里的",
    "gherkin-parser / ir-dry-checker / gherkin-mutator bash→Lua 转发器。入口是本仓",
    "tools/tools.lock 跟随的 acceptance4lua rock 的 Lua 面;launcher 把该 bin 目录放 PATH",
    "最前,所以这三份文件就是「下次启动可用」的载体。",
    "",
    "语义:",
    "  1. 确保 acceptance4lua rock 在 <swarm-root>/.toolcache/luarocks(foundation.bootstrap)。",
    "  2. 内容一致则不写;缺失或漂移才重写并 chmod 755——可反复跑,distclean / 新克隆后跑它。",
    "  3. 解释器探测 packages.luaunit_runner.lua54,探不到 lua5.4 退回 PATH 上的 lua。",
    "",
    "探测用 `swarm_tool.sh require <aps-tool>`;不要 `swarm_tool.sh ensure <aps-tool>`——",
    "ensure 会把转发器换成 Babashka 包装器,并把上游 Clojure 克隆拖回 .swarmforge/tools/。",
    "真源:swarmforge/constitution/articles/local-engineering.prompt、tools/specs/acceptance4lua.prompt。",
    "",
  }, "\n") .. "\n"
end

-- 命令面退出码与 tools/cli.lua 同一约定(#300 Q2):0 成功 / 1 业务失败 / 2 用法错误。
function M.main(args)
  local tokens = args or {}
  for _, value in ipairs(tokens) do
    if value == "--help" or value == "-h" then
      io.write(M.usage())
      return 0
    end
  end
  if #tokens > 0 then
    io.write(M.usage())
    io.write("provision 不接受参数: " .. table.concat(tokens, " ") .. "\n")
    return 2
  end

  local root, root_err = swarm_root.resolve()
  if root == nil then
    io.write("provision 失败: " .. tostring(root_err) .. "\n")
    return 1
  end

  local rock, rock_err = bootstrap.ensure_tool(_APS_ROCK, { repo_root = root })
  if rock == nil then
    io.write("provision 失败: " .. tostring(rock_err) .. "\n")
    return 1
  end

  local report, err = M.provision({ bin_dir = forwarders.bin_dir(root) })
  if report == nil then
    io.write("provision 失败: " .. tostring(err) .. "\n")
    return 1
  end

  for _, line in ipairs(M.report_lines(report, rock.url)) do
    io.write(line .. "\n")
  end
  return 0
end

if ... == "packages.acceptance.provision" then
  return M
end

os.exit(M.main(arg or {}))
