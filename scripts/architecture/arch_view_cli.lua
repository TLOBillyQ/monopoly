local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir()
  local raw_path = arg and arg[0] or "scripts/architecture/arch_view_cli.lua"
  local normalized = _normalize_path(raw_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts/architecture"
end

local SCRIPT_DIR = _script_dir()
package.path = SCRIPT_DIR .. "/?.lua;" .. SCRIPT_DIR .. "/?/?.lua;" .. package.path

local common = require("arch_view.common")
local build = require("arch_view.build")
local json_writer = require("arch_view.json_writer")

local function _load_config()
  local config_path = SCRIPT_DIR .. "/monopoly_architecture.lua"
  local chunk, err = loadfile(config_path)
  if not chunk then
    error(err)
  end
  return chunk()
end

local function _usage()
  io.write("Usage:\n")
  io.write("  lua scripts/architecture/arch_view_cli.lua scan --out <file>\n")
  io.write("  lua scripts/architecture/arch_view_cli.lua check\n")
  io.write("  lua scripts/architecture/arch_view_cli.lua viewer --out-dir <dir>\n")
end

local function _parse_flag(args, flag_name)
  for index = 2, #args do
    if args[index] == flag_name then
      return args[index + 1]
    end
  end
  return nil
end

local function _write_scan_output(out_path, architecture)
  local ok, err = common.ensure_parent_dir(out_path)
  if not ok then
    error(err)
  end
  local write_ok, write_err = common.write_file(out_path, json_writer.encode(architecture))
  if not write_ok then
    error(write_err)
  end
end

local function _copy_viewer_asset(asset_name, out_dir)
  local source_path = SCRIPT_DIR .. "/viewer/" .. asset_name
  local source_text, err = common.read_file(source_path)
  if source_text == nil then
    error(err)
  end
  local target_path = out_dir .. "/" .. asset_name
  local write_ok, write_err = common.write_file(target_path, source_text)
  if not write_ok then
    error(write_err)
  end
end

local function _run_scan(args)
  local out_path = _parse_flag(args, "--out")
  if out_path == nil then
    error("scan requires --out <file>")
  end
  local architecture, err = build.analyze(_load_config())
  if architecture == nil then
    error(err)
  end
  _write_scan_output(out_path, architecture)
  print("arch_view scan ok: " .. out_path)
end

local function _run_check()
  local architecture, err = build.analyze(_load_config())
  if architecture == nil then
    error(err)
  end
  if architecture.check.ok then
    print("arch_view check ok")
    return
  end

  io.stderr:write("arch_view check failed\n")
  for _, violation in ipairs(architecture.check.violations or {}) do
    if violation.kind == "forbidden_dependency" then
      io.stderr:write("  forbidden_dependency [", tostring(violation.rule), "] ", tostring(violation.from), " -> ", tostring(violation.to), "\n")
      io.stderr:write("    ", tostring(violation.description), "\n")
    elseif violation.kind == "unclassified_module" then
      io.stderr:write("  unclassified_module ", tostring(violation.module_id), "\n")
    else
      io.stderr:write("  ", tostring(violation.kind), " ", table.concat(violation.cycle or {}, ", "), "\n")
      io.stderr:write("    ", tostring(violation.description), "\n")
    end
  end
  os.exit(1)
end

local function _run_viewer(args)
  local out_dir = _parse_flag(args, "--out-dir")
  if out_dir == nil then
    error("viewer requires --out-dir <dir>")
  end
  local architecture, err = build.analyze(_load_config())
  if architecture == nil then
    error(err)
  end
  local ok, mkdir_err = common.ensure_dir(out_dir)
  if not ok then
    error(mkdir_err)
  end

  _copy_viewer_asset("index.html", out_dir)
  _copy_viewer_asset("script.js", out_dir)
  _copy_viewer_asset("styles.css", out_dir)
  _write_scan_output(out_dir .. "/architecture.json", architecture)

  local js_payload = "window.ARCH_VIEW_DATA = " .. json_writer.encode(architecture) .. ";\n"
  local write_ok, write_err = common.write_file(out_dir .. "/architecture_data.js", js_payload)
  if not write_ok then
    error(write_err)
  end
  print("arch_view viewer ok: " .. out_dir)
end

local command = arg[1]
if command == nil or command == "--help" or command == "-h" then
  _usage()
elseif command == "scan" then
  _run_scan(arg)
elseif command == "check" then
  _run_check()
elseif command == "viewer" then
  _run_viewer(arg)
else
  _usage()
  error("unknown command: " .. tostring(command))
end
