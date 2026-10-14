-- packages/uml_quality/cli.lua —— uml 子命令(#93):邻接 uml-viewer 质量入口的原生 Windows 调用面。
--
-- 统一接口形态(#300 决议):
--   M.main(args, env) -> 退出码
--   M.usage()         -> 完整 usage 文本
--
-- 质量算法、派发优先级(operations > standardTools > Clojure alias)与 validResult
-- 判定全在 .uml-viewer/uml-viewer/scripts/uml-command.ps1;本包只做两件事:
--   1. 预检:Lua 模块只从项目 .toolcache/luarocks 解析(不借全局 %APPDATA%\luarocks
--      tree)、PowerShell 7、uml-viewer 检出、uml-quality.json(用 uml-viewer 自己的
--      读取器校验)、crapper/mutator 的 Python 3.11+ venv。任一不过退 1,先删陈旧的
--      .uml-viewer/quality-result.json,不起工具。
--   2. 派发:在钉死 LUA_PATH/LUA_CPATH/PATH 的 cmd 批处理里跑 uml-command.ps1,
--      退出码原样回传(crap 0/2、mutate 0/3 是有效结果,不改写成 0/1)。
-- 预检失败退 1 而不是 3:3 是 mutate 的有效结果码(存活突变),不能复用为「不可用」。
local M = {}

local runtime = require("packages.uml_quality.runtime")
local bootstrap = require("foundation.bootstrap")
local proc = require("foundation.proc")
local fs = require("foundation.fs")
local env_lib = require("foundation.env")
local path_lib = require("foundation.path")

local _TOOLS = { check = { "crapper", "mutator" }, crap = { "crapper" }, mutate = { "mutator" } }

-- 必需 rock 与 bootstrap 中的钉版本一一对应;lcov reporter 依赖 luacov,自带前置。
local _ROCKS = {
  { "busted", "ensure_busted_tree" },
  { "luassert", "ensure_luassert_tree" },
  { "luacov", "ensure_luacov_tree" },
  { "luacov-reporter-lcov", "ensure_luacov_reporter_lcov_tree" },
}

local _PYTHON_PROBE = {
  crapper = "import sys, crapper, crapper.languages.treesitter; "
    .. "print('.'.join(map(str, sys.version_info[:3]))); print(crapper.__file__)",
  mutator = "import sys, mutator; from mutator.crapper_link import ensure_crapper; c = ensure_crapper(); "
    .. "print('.'.join(map(str, sys.version_info[:3]))); print(mutator.__file__); print(c.__file__)",
}

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua uml <check|crap|mutate> [args...]",
    "",
    "check   只做预检:项目缓存 Lua 模块来源、PowerShell 7、uml-viewer 检出、",
    "        uml-quality.json、crapper/mutator Python 3.11+ venv。0 = 全过 / 1 = 有缺失。",
    "crap    预检后经 uml-command.ps1 跑 crapper(standardTools,--full-tree)。",
    "        退出码原样回传:0/2 有效结果,其余失败。",
    "mutate  预检后经 uml-command.ps1 跑 mutator;args 原样转发(目标文件或 --changed)。",
    "        退出码原样回传:0/3 有效结果,其余失败。",
    "",
    "预检失败退 1,并删除陈旧的 .uml-viewer/quality-result.json。",
    "Python venv 搭建见 tools/specs/uml_quality.prompt。",
    "",
  }, "\n") .. "\n"
end

local function _absolute_root(repo_root)
  return path_lib.resolve_path(env_lib.current_dir(), repo_root or ".")
end

local function _report(state, ok, message)
  io.write((ok and "ok   " or "FAIL ") .. message .. "\n")
  if not ok then state.ok = false end
end

-- crapper 用 shutil.which("lua") 找解释器;钉 lua.exe 所在目录而不是 lua.cmd 垫片目录。
local function _lua_exe(state)
  local ok, lua_bin = pcall(require("foundation.lua54").lua54_bin)
  if not ok then
    _report(state, false, "lua 5.4: " .. tostring(lua_bin))
    return nil
  end
  local result = proc.run_command({ lua_bin, "-e", "io.write(arg[0])" })
  local exe = path_lib.normalize_path(tostring(result.output or ""))
  if result.ok ~= true or not fs.path_exists(exe) then
    _report(state, false, "lua 5.4: cannot resolve native interpreter behind " .. tostring(lua_bin))
    return nil
  end
  _report(state, true, "lua 5.4: " .. exe)
  return exe
end

local function _ensure_rocks(state, root)
  for _, rock in ipairs(_ROCKS) do
    local ok, err = bootstrap[rock[2]](root)
    _report(state, ok == true, "project cache rock " .. rock[1] .. (ok == true and "" or (": " .. tostring(err))))
  end
end

local function _run_batch(root, env_list, argv, output_path)
  local batch = env_lib.make_temp_path("uml_quality", ".cmd")
  fs.write_file(batch, runtime.batch_text(root, env_list, argv, output_path))
  local ok, kind, code = os.execute('cmd.exe /d /v:off /c ""' .. batch:gsub("/", "\\") .. '""')
  fs.remove_path(batch)
  return require("foundation.shell").exit_status(ok, kind, code)
end

local function _probe_lua_modules(state, root, lua_exe)
  local env_list = runtime.pinned_env(root, path_lib.parent_dir(lua_exe), os.getenv("PATH"))
  local output_path = env_lib.make_temp_path("uml_quality_probe", ".log")
  local argv = { lua_exe, root .. "/tools/packages/uml_quality/probe_lua_modules.lua" }
  for _, name in ipairs(runtime.REQUIRED_LUA_MODULES) do argv[#argv + 1] = name end
  _run_batch(root, env_list, argv, output_path)
  local output = fs.read_raw(output_path) or ""
  fs.remove_path(output_path)
  local ok, verdicts = runtime.probe_verdicts(output, root)
  for _, verdict in ipairs(verdicts) do _report(state, verdict.ok, "lua module " .. verdict.message) end
  if not ok and #verdicts == 0 then _report(state, false, "lua module probe produced no output: " .. output) end
  return env_list
end

local function _check_pwsh(state)
  local result = proc.run_command({ "pwsh", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.Major" })
  local major = tonumber(tostring(result.output or ""):match("(%d+)"))
  _report(state, result.ok == true and major ~= nil and major >= 7,
    "PowerShell 7 (pwsh): " .. (result.ok == true and ("major " .. tostring(major)) or "not runnable"))
end

local function _check_viewer(state, root)
  local scripts = root .. "/.uml-viewer/uml-viewer/scripts"
  local present = fs.path_exists(scripts .. "/uml-command.ps1")
  _report(state, present, "uml-viewer checkout: " .. scripts .. "/uml-command.ps1" .. (present and "" or " missing"))
  if not present then return nil end
  local result = proc.run_command({ "pwsh", "-NoProfile", "-File",
    root .. "/tools/packages/uml_quality/probe_config.ps1", "-Root", root, "-Scripts", scripts })
  for line in tostring(result.output or ""):gmatch("[^\r\n]+") do
    _report(state, result.ok == true, "uml-quality.json " .. line)
  end
  if result.ok ~= true and tostring(result.output or "") == "" then
    _report(state, false, "uml-quality.json probe failed (exit " .. tostring(result.code) .. ")")
  end
  return scripts
end

local function _check_python(state, root, tool)
  local python = root .. "/.uml-viewer/" .. tool .. "/.venv/Scripts/python.exe"
  if not fs.path_exists(python) then
    _report(state, false, tool .. ": " .. python .. " missing (see tools/specs/uml_quality.prompt)")
    return
  end
  local result = proc.run_command({ python, "-I", "-c", _PYTHON_PROBE[tool] }, { cwd = root })
  if result.ok ~= true then
    _report(state, false, tool .. ": import probe failed: " .. tostring(result.output))
    return
  end
  local verdict = runtime.python_verdict(tool, result.output, root)
  _report(state, verdict.ok, verdict.message)
  if tool == "mutator" then
    local version, _, linked = tostring(result.output):match("([^\r\n]+)[\r\n]+([^\r\n]+)[\r\n]+([^\r\n]+)")
    local link = runtime.python_verdict("crapper", tostring(version) .. "\n" .. tostring(linked), root)
    _report(state, link.ok, "mutator -> " .. link.message)
  end
end

local function _preflight(root, op)
  local state = { ok = true }
  local lua_exe = _lua_exe(state)
  _ensure_rocks(state, root)
  if lua_exe ~= nil then state.env_list = _probe_lua_modules(state, root, lua_exe) end
  _check_pwsh(state)
  state.scripts = _check_viewer(state, root)
  for _, tool in ipairs(_TOOLS[op]) do _check_python(state, root, tool) end
  return state
end

local function _echo_result(root)
  local text = fs.read_raw(root .. "/.uml-viewer/quality-result.json")
  if text == nil then
    io.stderr:write("uml: no .uml-viewer/quality-result.json was published\n")
  else
    io.write("uml: quality-result " .. (text:gsub("^\239\187\191", ""):gsub("%s+$", "")) .. "\n")
  end
end

function M.main(args, env)
  args = args or {}
  local op = args[1]
  if op == "--help" or op == "-h" then
    io.write(M.usage())
    return 0
  end
  if _TOOLS[op] == nil or (op == "check" and #args > 1) then
    io.stderr:write((op == nil and "缺少子命令" or ("未知参数: " .. tostring(op))) .. "\n\n" .. M.usage())
    return 2
  end

  local root = _absolute_root((env and env.repo_root) or ".")
  local state = _preflight(root, op)
  if not state.ok then
    fs.remove_path(root .. "/.uml-viewer/quality-result.json")
    io.stderr:write("uml: preflight failed; " .. (op == "check" and "environment is not ready" or (op .. " was not started")) .. "\n")
    return 1
  end
  if op == "check" then return 0 end

  local argv = { "pwsh", "-NoProfile", "-File", state.scripts .. "/uml-command.ps1", root, op }
  for index = 2, #args do argv[#argv + 1] = args[index] end
  local _, code = _run_batch(root, state.env_list, argv, nil)
  _echo_result(root)
  return code
end

return M
