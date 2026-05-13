local common = require("shared.lib.common")
local json_writer = require("shared.lib.json_writer")

local loc_scan = {}
local _engine_binary_cache = {
  resolved = false,
  path = nil,
  err = nil,
}

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/shared/lib/loc_scan.lua"
  local normalized = common.normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/shared/lib"
end

local bootstrap = dofile(_module_dir() .. "/../bootstrap.lua")
local bootstrap_env = bootstrap.install(debug.getinfo(1, "S").source)
local REPO_ROOT = bootstrap_env.repo_root
local LOC_ENGINE_ROOT = common.join_path(REPO_ROOT, "tools/loc_engine")
local LOC_TOOLCHAIN_ROOT = common.join_path(REPO_ROOT, ".loc/toolchain/current")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _binary_name()
  if common.is_windows() then
    return "monopoly-loc.exe"
  end
  return "monopoly-loc"
end

local function _binary_path()
  return common.join_path(LOC_TOOLCHAIN_ROOT, _binary_name())
end

local function _copy_array(values)
  local copied = {}
  for index, value in ipairs(values or {}) do
    copied[index] = value
  end
  return copied
end

local function _run_command(command, options, env)
  if env ~= nil and type(env.run_command) == "function" then
    return env.run_command(command, options)
  end
  return common.run_command(command, options)
end

local function _write_json_file(path, payload)
  local ok, err = common.write_file(path, json_writer.encode(payload))
  if not ok then
    return nil, err
  end
  return true
end

local function _parse_json_response(text)
  local ok, decoded = pcall(require("shared.lib.json_reader").decode, text)
  if not ok then
    return nil, tostring(decoded)
  end
  if type(decoded) ~= "table" then
    return nil, _text("LOC 引擎返回的 JSON 不是对象", "LOC engine returned non-object JSON")
  end
  return decoded, nil
end

local function _run_go_engine(command_name, payload, env)
  local binary_path, build_err = loc_scan.ensure_binary(env)
  if binary_path == nil then
    return nil, build_err
  end

  local request_path = common.make_temp_path("loc_engine_request", ".json")
  local ok, write_err = _write_json_file(request_path, payload)
  if not ok then
    return nil, write_err
  end

  local result = _run_command({
    binary_path,
    command_name,
    "--request-json",
    request_path,
  }, {
    cwd = REPO_ROOT,
  }, env)
  common.remove_path(request_path)
  if result.ok ~= true then
    return nil, result.output
  end

  return _parse_json_response(result.output), nil
end

function loc_scan.ensure_binary(env)
  env = env or {}
  local binary_path = _binary_path()
  if type(env.ensure_binary) == "function" then
    return env.ensure_binary(binary_path)
  end
  if _engine_binary_cache.resolved then
    return _engine_binary_cache.path, _engine_binary_cache.err
  end
  if common.path_exists(binary_path) == true then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.path = binary_path
    return binary_path, nil
  end
  if common.command_exists("go") ~= true then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.err = _text("未找到 go 命令", "go command not found")
    return nil, _engine_binary_cache.err
  end

  local ok, err = common.ensure_parent_dir(binary_path)
  if not ok then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.err = err
    return nil, err
  end

  local result = _run_command({ "go", "build", "-o", binary_path, "./cmd/monopoly-loc" }, {
    cwd = LOC_ENGINE_ROOT,
  }, env)
  if result.ok ~= true then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.err = _trim(result.output)
    return nil, _engine_binary_cache.err
  end

  _engine_binary_cache.resolved = true
  _engine_binary_cache.path = binary_path
  _engine_binary_cache.err = nil
  return binary_path, nil
end

function loc_scan.count_worktree(request, env)
  env = env or request.env or {}
  local normalized_request = {
    project_root = common.normalize_path(request.project_root or REPO_ROOT),
    directories = _copy_array(request.directories),
    files = _copy_array(request.files),
  }

  local go_result, go_err = _run_go_engine("worktree", normalized_request, env)
  if go_result == nil then
    return nil, go_err
  end
  return go_result
end

function loc_scan.count_history(request, env)
  env = env or request.env or {}
  local normalized_request = {
    git_root = common.normalize_path(request.git_root or request.project_root or REPO_ROOT),
    since = request.since or "3 days ago",
  }

  local go_result, go_err = _run_go_engine("history", normalized_request, env)
  if go_result == nil then
    return nil, go_err
  end
  return go_result
end

function loc_scan.reset_caches()
  _engine_binary_cache = {
    resolved = false,
    path = nil,
    err = nil,
  }
end

return loc_scan
