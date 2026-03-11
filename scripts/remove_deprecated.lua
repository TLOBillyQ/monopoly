local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir(script_path)
  local normalized = _normalize_path(script_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local _raw_script_path = arg and arg[0] or "scripts/remove_deprecated.lua"
local _entry_script_dir = _script_dir(_raw_script_path)
local _entry_parent_dir = _entry_script_dir:match("^(.*)/[^/]+$") or "."
package.path = _entry_script_dir .. "/?.lua;"
  .. _entry_script_dir .. "/?/?.lua;"
  .. _entry_parent_dir .. "/?.lua;"
  .. _entry_parent_dir .. "/?/?.lua;"
  .. package.path

local bootstrap = require("bootstrap")
local env = bootstrap.install(_raw_script_path)
local common = require("lib.common")

local function _fail(message)
  io.stderr:write(tostring(message), "\n")
  os.exit(1)
end

local function _split_lines_keepends(text)
  local lines = {}
  local cursor = 1
  local source = tostring(text or "")
  local source_length = #source
  if source_length == 0 then
    return lines
  end

  while cursor <= source_length do
    local newline_index = source:find("\n", cursor, true)
    if newline_index == nil then
      lines[#lines + 1] = source:sub(cursor)
      break
    end
    lines[#lines + 1] = source:sub(cursor, newline_index)
    cursor = newline_index + 1
  end

  return lines
end

local function remove_deprecated_api(lines)
  local output = {}
  local buffer = {}
  local deprecated_in_buffer = false

  for _, line in ipairs(lines or {}) do
    local stripped = line:gsub("^%s*", "")
    local is_doc = stripped:sub(1, 3) == "---"
    if is_doc then
      buffer[#buffer + 1] = line
      if line:find("@deprecated", 1, true) ~= nil then
        deprecated_in_buffer = true
      end
    else
      if deprecated_in_buffer then
        if line:match("^%s*$") ~= nil then
        else
          buffer = {}
          deprecated_in_buffer = false
        end
      else
        if #buffer > 0 then
          for _, buffered_line in ipairs(buffer) do
            output[#output + 1] = buffered_line
          end
          buffer = {}
        end
        output[#output + 1] = line
      end
    end
  end

  if not deprecated_in_buffer and #buffer > 0 then
    for _, buffered_line in ipairs(buffer) do
      output[#output + 1] = buffered_line
    end
  end

  return output
end

local function _parse_args(args)
  local options = {
    path = common.join_path(env.repo_root, "EggyAPI.lua"),
    backup_suffix = ".bak",
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--backup-suffix" then
      options.backup_suffix = args[index + 1] or ""
      index = index + 2
    elseif token:sub(1, 2) == "--" then
      _fail("unknown flag: " .. tostring(token))
    else
      if options.path ~= common.join_path(env.repo_root, "EggyAPI.lua") then
        _fail("unexpected extra positional argument: " .. tostring(token))
      end
      options.path = token
      index = index + 1
    end
  end

  return options
end

local function main(args)
  local options = _parse_args(args or {})
  local target_path = common.resolve_path(common.current_dir(), options.path)
  if not common.path_exists(target_path) then
    _fail("目标文件不存在: " .. target_path)
  end

  local original, read_err = common.read_file(target_path)
  if original == nil then
    _fail(read_err)
  end

  local updated = table.concat(remove_deprecated_api(_split_lines_keepends(original)))

  if options.backup_suffix ~= "" then
    local backup_path = target_path .. options.backup_suffix
    local backup_ok, backup_err = common.write_file(backup_path, original)
    if not backup_ok then
      _fail(backup_err)
    end
  end

  local write_ok, write_err = common.write_file(target_path, updated)
  if not write_ok then
    _fail(write_err)
  end
end

main(arg or {})
