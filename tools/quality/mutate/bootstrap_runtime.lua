local util = require("mutate4lua.util")
local manifest = require("mutate4lua.internal.manifest")
local scanner = require("mutate4lua.internal.scanner")
local project = require("mutate4lua.driver.project")
local command = require("quality.mutate.command")

local M = {}

local function _list_src_lua_files()
  local out = command.read("git ls-files -- 'src/*.lua'")
  if out == nil then return {} end
  local files = {}
  for line in out:gmatch("([^\n]+)") do
    if line:match("%.lua$") and line:sub(1, 4) == "src/" then
      files[#files + 1] = line
    end
  end
  table.sort(files)
  return files
end

local function _read_source(path)
  local f = io.open(path, "r")
  if not f then return nil, "cannot open " .. path end
  local body = f:read("*a")
  f:close()
  return body
end

local function _read_manifest(path)
  local ok, data = pcall(manifest.read, path)
  if not ok then return nil end
  return data
end

local function _scan_file(bootstrap_env, path)
  local source, read_err = _read_source(path)
  if source == nil then return nil, read_err end
  local stripped = manifest.strip(source)
  local abs = util.absolute_path(util.join_path(bootstrap_env.repo_root, path))
  local relative = project.relative_file(bootstrap_env.repo_root, abs)
  local ok, data = pcall(scanner.analyze, abs, relative, stripped)
  if not ok then return nil, tostring(data) end
  data._abs = abs
  data._stripped = stripped
  return data
end

local function _write_manifest(bootstrap_env, _, data)
  local proj_hash = project.project_hash(
    project.find_root(bootstrap_env.repo_root, data._abs),
    data._abs,
    data._stripped
  )
  manifest.write(data._abs, data._stripped, {
    version = 2,
    project_hash = proj_hash,
    scopes = data.scopes,
  })
end

function M.build(bootstrap_env)
  return {
    list_src_lua_files = _list_src_lua_files,
    read_source = _read_source,
    read_manifest = _read_manifest,
    scan_file = function(path) return _scan_file(bootstrap_env, path) end,
    write_manifest = function(path, data) return _write_manifest(bootstrap_env, path, data) end,
    out_write = function(s) io.stdout:write(s) end,
    err_write = function(s) io.stderr:write(s) end,
  }
end

return M
