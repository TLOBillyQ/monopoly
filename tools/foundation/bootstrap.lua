local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/foundation/bootstrap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/foundation"
end

local runtime_paths = dofile(_module_dir() .. "/runtime_paths.lua")
-- 与 runtime_paths 同样按相对路径 dofile:本文件在 install 装好 package.path 之前就被加载。
local availability = dofile(_module_dir() .. "/tool_availability.lua")

local bootstrap = {}

function bootstrap.resolve(script_path, opts)
  opts = opts or {}
  return runtime_paths.resolve({
    source_path = script_path or opts.source_path or (debug.getinfo(2, "S") and debug.getinfo(2, "S").source) or "",
    cwd = opts.cwd or runtime_paths.current_dir(),
  })
end

function bootstrap.install(script_path, opts)
  local env = bootstrap.resolve(script_path, opts)
  local helper_path = runtime_paths.join_path(env.tools_dir, "foundation/package_path_helper.lua")
  local helper = dofile(helper_path)
  helper.install_eggy_package_paths({
    repo_root = env.repo_root,
  })
  helper.install_luarocks_tree_paths({
    repo_root = env.repo_root,
  })
  return env
end

local function _luarocks_tree_dir(repo_root)
  return runtime_paths.join_path(repo_root, ".toolcache/luarocks")
end

-- 解释器解析与全仓同源:LUA54_BIN 覆写 + 候选表 + `<candidate> -v` 版本验证全在
-- packages.test_runner.lua54 一处表达;这里不再自造第二套规则(旧实现读 arg[-1],
-- 而 `-e` 形态下 arg[-1] 恒为 nil,等于沉默退回 PATH 猜测)。调用点均已装好
-- package.path(install / script_bootstrap 在前)。
local function _selected_interpreter()
  return require("foundation.lua54").lua54_bin()
end

-- 裸命令名 → Lua 安装前缀(luarocks `--lua-dir` 的实参)。
-- where.exe 可能先给出 lua.cmd / lua.bat 这类 wrapper(用户 shell 垫片),它们的
-- 目录不是 Lua 安装前缀,拿错会让 C 扩展找不到 include/lib;故优先取真实 .exe
-- 所在的 bin/ 目录,只在没有 .exe 时退回第一个 bin/ 前一节。
local function _install_prefix(selected)
  local proc = require("foundation.proc")
  local candidates = {}
  local normalized = runtime_paths.normalize_path(selected)
  if normalized:find("/") ~= nil then
    candidates[#candidates + 1] = normalized
  else
    local found = proc.run_command({ "where.exe", selected })
    if found.ok == true then
      for line in tostring(found.output or ""):gmatch("[^\r\n]+") do
        candidates[#candidates + 1] = runtime_paths.normalize_path(line)
      end
    end
  end
  local fallback
  for _, candidate in ipairs(candidates) do
    local prefix = candidate:match("^(.*)/bin/[^/]+$")
    if prefix ~= nil then
      if candidate:lower():match("%.exe$") ~= nil then
        return prefix
      end
      fallback = fallback or prefix
    end
  end
  return fallback
end

local function _luarocks_command(tree)
  local selected = _selected_interpreter()
  local prefix = _install_prefix(selected)
  assert(prefix ~= nil, "cannot resolve selected Lua install prefix: " .. tostring(selected))
  local found = require("foundation.proc").run_command({ "where.exe", "luarocks.exe" })
  local rocks = found.ok and tostring(found.output):match("[^\r\n]+") or nil
  rocks = rocks or runtime_paths.join_path(os.getenv("LOCALAPPDATA") or "", "Programs/LuaRocks/bin/luarocks.exe")
  assert(require("foundation.fs").path_exists(rocks), "native LuaRocks executable missing: " .. rocks)
  return { rocks, "--tree", tree, "--lua-version", "5.4", "--lua-dir", prefix }
end

local function _rocks_run(tree, args, opts)
  local command = _luarocks_command(tree)
  for _, value in ipairs(args) do command[#command + 1] = value end
  return require("foundation.proc").run_command(command, opts)
end

local function _luarocks_list(tree, name)
  -- 调用方已确保 foundation 可用(package.path 已装好)。
  return _rocks_run(tree, { "list", name, "--porcelain" })
end

local function _installed_version(tree, name)
  local result = _luarocks_list(tree, name)
  if result.ok ~= true then
    return nil
  end
  local pattern = "^" .. name:gsub("%-", "%%-") .. "%s+(%S+)%s+installed"
  local best = nil
  for line in tostring(result.output or ""):gmatch("[^\r\n]+") do
    local version = line:match(pattern)
    if version ~= nil then
      best = version
    end
  end
  return best
end

local function _is_tool_present(tree, name)
  return _installed_version(tree, name) ~= nil
end

local function _tool_source_dir(repo_root, name)
  return runtime_paths.join_path(repo_root, ".toolcache/src/" .. name)
end

-- 浅克隆上游主干到 .toolcache/src/<name>,返回实测 HEAD commit。
local function _fetch_tool_source(repo_url, src_dir)
  local fs_lib = require("foundation.fs")
  local proc_lib = require("foundation.proc")
  local remote = tostring(repo_url):gsub("/+$", "")
  if remote:match("%.git$") == nil then
    remote = remote .. ".git"
  end
  fs_lib.remove_path(src_dir)
  local ok, ensure_err = fs_lib.ensure_parent_dir(src_dir)
  if not ok then
    return nil, ensure_err
  end
  local result = proc_lib.run_command({ "git", "clone", "--depth", "1", "--quiet", remote, src_dir })
  if result.ok ~= true then
    return nil, "git clone failed for " .. remote .. ": " .. tostring(result.output)
  end
  local rev = proc_lib.run_command({ "git", "-C", src_dir, "rev-parse", "HEAD" })
  if rev.ok ~= true then
    return nil, "git rev-parse failed in " .. src_dir .. ": " .. tostring(rev.output)
  end
  return (tostring(rev.output or ""):match("^(%x+)"))
end

-- 从克隆的工作树构建安装。仓库根的 rockspec 是构建清单与依赖声明
-- (luacheck/luacov 由它带入),luarocks make 自动拾取。
-- 先 remove 兜底:同版本号重复 make 会报 already installed。
local function _luarocks_make(tree, name, src_dir)
  _rocks_run(tree, { "remove", name })
  return _rocks_run(tree, { "make", "--deps-mode", "one" }, { cwd = src_dir })
end

-- 用 luarocks 往 tree 里装一个工具/库,装好(或已装)返回 true。marker 判据
-- 各不相同,由调用方给出 marker 相对子路径;name/version 是 `luarocks install`
-- 的实参。依赖 luacov 的 rock(如 luacov-reporter-lcov)用 before_install 钩子
-- 表达,装前先确保依赖。
local function _ensure_rock_installed(repo_root, name, version, marker_rel, before_install)
  local path_lib = require("foundation.path")
  local fs_lib = require("foundation.fs")
  local tree = _luarocks_tree_dir(repo_root)
  local marker = path_lib.join_path(tree, marker_rel)
  if fs_lib.path_exists(marker) == true then
    return true
  end

  local ok, err = fs_lib.ensure_dir(tree)
  if not ok then
    return nil, err
  end

  if before_install ~= nil then
    local dep_ok, dep_err, dep_unavailable = before_install()
    if dep_ok ~= true then
      return nil, dep_err, dep_unavailable
    end
  end

  local result = _rocks_run(tree, { "install", name, version, "--deps-mode", "one" })
  if result.ok ~= true then
    local install_err = "luarocks install failed for " .. name .. ": " .. tostring(result.output)
    return nil, install_err, availability.classify(name, "install", install_err)
  end

  if fs_lib.path_exists(marker) ~= true then
    return nil, name .. " not found in luarocks tree after install"
  end

  return true
end

function bootstrap.ensure_luacheck_tree(repo_root)
  return _ensure_rock_installed(repo_root, "luacheck", "1.2.0-1", "share/lua/5.4/luacheck/main.lua")
end

-- luassert(断言层迁移期,#74):终态 busted 的断言库,迁移期先由
-- test/support/luassert_loader.lua 从同一 tree 局部加载。marker 取 init.lua;
-- say 是 luassert 的 rockspec 依赖,由 luarocks 依赖解析一并带进同一 tree,
-- 不单独 ensure(单独钉 say 版本会与 luassert 的依赖声明漂移)。
function bootstrap.ensure_luassert_tree(repo_root)
  return _ensure_rock_installed(repo_root, "luassert", "1.9.0-1", "share/lua/5.4/luassert/init.lua")
end

function bootstrap.ensure_busted_tree(repo_root)
  return _ensure_rock_installed(repo_root, "busted", "2.3.0-1", "share/lua/5.4/busted/runner.lua")
end

-- 覆盖率引擎 luacov:uml crap(crapper)的 Lua 覆盖率路径 require("luacov.runner"),
-- 只从项目 tree 落地(#93/#94)。钉 0.17.0-1。
function bootstrap.ensure_luacov_tree(repo_root)
  return _ensure_rock_installed(repo_root, "luacov", "0.17.0-1", "share/lua/5.4/luacov/runner.lua")
end

-- luacov-reporter-lcov(#93):crapper 的 Lua 覆盖率路径 require("luacov.reporter.lcov")
-- 产 lcov.info。钉 0.2-0;rockspec 依赖 luacov,先确保 base engine 在项目 tree,
-- 不借用户全局 %APPDATA%\luarocks tree(那里同名 rock 会造成假绿)。
function bootstrap.ensure_luacov_reporter_lcov_tree(repo_root)
  return _ensure_rock_installed(repo_root, "luacov-reporter-lcov", "0.2-0",
    "share/lua/5.4/luacov/reporter/lcov.lua",
    function()
      return bootstrap.ensure_luacov_tree(repo_root)
    end)
end

function bootstrap.ensure_tool(name, env_or_opts)
  local env = env_or_opts
  if env == nil or env.repo_root == nil then
    env = bootstrap.resolve(nil, env_or_opts or {})
  end

  local lockfile = require("foundation.tool_lockfile")
  local lock, lock_err = lockfile.read_lock(env)
  if lock == nil then
    return nil, lock_err
  end

  local entry = lock.tools[name]
  if entry == nil then
    return nil, "tool missing from lockfile: " .. tostring(name)
  end

  local fs_lib = require("foundation.fs")
  local resolver = require("foundation.tool_resolver")
  local tree = _luarocks_tree_dir(env.repo_root)
  local ok, ensure_err = fs_lib.ensure_dir(tree)
  if not ok then
    return nil, ensure_err
  end

  -- 新鲜度 = 上游 HEAD commit。解析失败(网络不通且无缓存)时,
  -- tree 里已装任意版本则降级继续用,否则报错。#112:网络/下载类失败带第三
  -- 返回值(不可用记录,标出工具与步骤),调用方退 3 而不是把断网报成失败;
  -- 其余原因(仓库不存在、编译错误)无第三值,照旧是真实失败。
  local resolved, resolve_err = resolver.resolve(name, entry.url, env)
  if resolved == nil then
    if _is_tool_present(tree, name) then
      return { name = name, root = tree, version = _installed_version(tree, name), stale = true }
    end
    return nil, resolve_err, availability.classify(name, "resolve", resolve_err)
  end

  if resolved.installed == resolved.commit and _is_tool_present(tree, name) then
    return { name = name, root = tree, commit = resolved.commit, version = _installed_version(tree, name) }
  end

  local src_dir = _tool_source_dir(env.repo_root, name)
  local sha, fetch_err = _fetch_tool_source(entry.url, src_dir)
  if sha == nil then
    if _is_tool_present(tree, name) then
      return { name = name, root = tree, commit = resolved.installed,
        version = _installed_version(tree, name), stale = true }
    end
    return nil, fetch_err, availability.classify(name, "fetch", fetch_err)
  end

  local result = _luarocks_make(tree, name, src_dir)
  if result.ok ~= true then
    local make_err = "luarocks make failed for " .. tostring(name) .. ": " .. tostring(result.output)
    return nil, make_err, availability.classify(name, "build", make_err)
  end
  local installed_version = _installed_version(tree, name)
  if installed_version == nil then
    return nil, tostring(name) .. " not found in luarocks tree after make"
  end

  resolver.mark_installed(env, name, sha)
  return { name = name, root = tree, commit = sha, version = installed_version }
end

return bootstrap
