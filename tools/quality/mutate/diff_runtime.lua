local common = require("shared.lib.common")
local util = require("mutate4lua.util")
local command = require("quality.mutate.command")

local M = {}

local function _diff_name_status(base)
  local cmd = "git diff --name-status " .. common.shell_quote(base .. "...HEAD")
  return command.read(cmd)
end

local function _make_buffer_writer()
  local chunks = {}
  local writer = {}
  function writer:write(...)
    for i = 1, select("#", ...) do
      chunks[#chunks + 1] = tostring((select(i, ...)))
    end
    return self
  end
  function writer.text()
    return table.concat(chunks)
  end
  return writer
end

local _mutate_module
local _mutate_cli

local function _ensure_mutate_loaded()
  if _mutate_module ~= nil then
    return
  end
  _mutate_module = require("quality.mutate")
  _mutate_cli = require("mutate4lua.cli")
end

local function _mutate_file(file)
  _ensure_mutate_loaded()
  local stdout = _make_buffer_writer()
  local stderr = _make_buffer_writer()

  if not _mutate_module.check_bootstrap_only(file, function(t) stderr:write(t) end) then
    return { exit_code = 1, json = nil, stderr = stderr.text() }
  end

  local call_env = {}
  for k, v in pairs(_mutate_module.env) do
    call_env[k] = v
  end
  call_env.stdout = stdout
  call_env.stderr = stderr

  local ok, exit_or_err = pcall(_mutate_cli.run, { file, "--json" }, call_env)
  local exit_code
  if ok then
    exit_code = tonumber(exit_or_err) or 0
  else
    exit_code = 1
    stderr:write(tostring(exit_or_err), "\n")
  end

  local json_ok, json_value = pcall(util.decode_json, stdout.text())
  return {
    exit_code = exit_code,
    json = json_ok and type(json_value) == "table" and json_value or nil,
    stderr = stderr.text(),
  }
end

function M.build()
  return {
    diff_name_status = _diff_name_status,
    mutate_file = _mutate_file,
    out_write = function(s) io.stdout:write(s) end,
    err_write = function(s) io.stderr:write(s) end,
  }
end

return M
