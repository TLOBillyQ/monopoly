local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/mutate.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local REPO_ROOT = bootstrap_env.repo_root
require("shared.mutate4lua_paths").activate(bootstrap_env.vendor_dir)

local _env = {
  cwd = REPO_ROOT, command_name = "tools/quality/mutate.lua",
  default_driver = "tools/quality/mutate/driver.lua",
  busted_driver = "tools/quality/mutate/busted_adapter.lua",
  busted_discover = function(lane)
    return require("quality.mutate.busted_adapter").discover_specs(lane)
  end,
}

local _BYPASS_FLAGS = {
  ["--help"] = true, ["-h"] = true,
  ["--scan"] = true, ["--update-manifest"] = true, ["--index-suites"] = true,
  ["--dry-run"] = true, ["--mutate-all"] = true, ["--lines"] = true,
}
local _VALUE_FLAGS = {
  ["--lane"] = true, ["--runner"] = true, ["--max-workers"] = true,
  ["--poll-interval"] = true,
  ["--timeout-factor"] = true, ["--test-command"] = true, ["--mutation-warning"] = true,
}

local function _preflight_target(args)
  if args == nil then return nil end
  for _, token in ipairs(args) do
    if _BYPASS_FLAGS[token] then return nil end
  end
  local skip_next = false
  for _, token in ipairs(args) do
    if skip_next then
      skip_next = false
    elseif _VALUE_FLAGS[token] then
      skip_next = true
    elseif token:sub(1, 2) ~= "--" then
      return token
    end
  end
  return nil
end

local function _bootstrap_only_message(target)
  return string.format(
    "[mutate] %s manifest is bootstrap-only — every scope is missing last_mutation_status.\n" ..
    "  Run `lua tools/quality/mutate.lua %s --mutate-all` first to prove coverage,\n" ..
    "  or pass --lines / --update-manifest to bypass differential mode.\n",
    target, target
  )
end

local function _default_stderr_writer(text)
  io.stderr:write(text)
end

local function _check_bootstrap_only(target, stderr_writer)
  if target == nil or target:sub(-4) ~= ".lua" then return true end
  local manifest_mod = require("mutate4lua.internal.manifest")
  local ok, data = pcall(manifest_mod.read, target)
  if not ok or data == nil then return true end
  local bootstrap_mod = require("quality.mutate_bootstrap")
  if not bootstrap_mod.is_bootstrap_only(data) then return true end
  (stderr_writer or _default_stderr_writer)(_bootstrap_only_message(target))
  return false
end

if ... == "quality.mutate" then
  return {
    env = _env,
    preflight_target = _preflight_target,
    check_bootstrap_only = _check_bootstrap_only,
    run = function(args, env)
      local m = {} for k, v in pairs(_env) do m[k] = v end for k, v in pairs(env or {}) do m[k] = v end
      return require("mutate4lua.cli").run(args, m)
    end,
  }
end

local _target = _preflight_target(arg)
if _target ~= nil and not _check_bootstrap_only(_target) then
  os.exit(1)
end
os.exit(require("mutate4lua.cli").run(arg or {}, _env))
