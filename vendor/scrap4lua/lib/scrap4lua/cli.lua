local common = require("shared.lib.common")
local json_writer = require("shared.lib.json_writer")
local config_loader = require("scrap4lua.config")
local indexer = require("scrap4lua.indexer")
local json_reader = require("scrap4lua.json_reader")
local query = require("scrap4lua.query")

local cli = {}

local function _asset_root()
  local source = debug.getinfo(1, "S").source or "@vendor/scrap4lua/lib/scrap4lua/cli.lua"
  local normalized = common.normalize_path(source):gsub("^@", "")
  local root = normalized:match("^(.*)/lib/scrap4lua/[^/]+$")
  return common.join_path(root or "vendor/scrap4lua", "viewer")
end

local function _help_text(command_name)
  return table.concat({
    "用法:",
    "  lua " .. tostring(command_name) .. " index --config FILE --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " find --config FILE --query TEXT [--limit N] [--project-root DIR] [--out FILE]",
    "  lua " .. tostring(command_name) .. " clusters --config FILE [--limit N] [--project-root DIR] [--out FILE]",
    "  lua " .. tostring(command_name) .. " viewer --config FILE [--in-json FILE] --out-dir DIR [--project-root DIR] [--open]",
    "",
    "Usage:",
    "  lua " .. tostring(command_name) .. " index --config FILE --out FILE [--project-root DIR]",
    "  lua " .. tostring(command_name) .. " find --config FILE --query TEXT [--limit N] [--project-root DIR] [--out FILE]",
    "  lua " .. tostring(command_name) .. " clusters --config FILE [--limit N] [--project-root DIR] [--out FILE]",
    "  lua " .. tostring(command_name) .. " viewer --config FILE [--in-json FILE] --out-dir DIR [--project-root DIR] [--open]",
  }, "\n") .. "\n"
end

local function _write_json(path, payload)
  local ok, err = common.write_file(path, json_writer.encode(payload))
  if not ok then
    return nil, err
  end
  return true
end

local function _write_data_script(path, global_name, payload)
  local script = "window." .. tostring(global_name) .. " = " .. json_writer.encode(payload) .. ";\n"
  local ok, err = common.write_file(path, script)
  if not ok then
    return nil, err
  end
  return true
end

local function _copy_viewer_assets(out_dir)
  local asset_root = _asset_root()
  local ok, err = common.copy_tree(asset_root, out_dir)
  if not ok then
    return nil, err
  end
  return true
end

local function _parse_args(args)
  local options = {
    command = args[1],
    config = nil,
    out = nil,
    out_dir = nil,
    in_json = nil,
    project_root = nil,
    query = nil,
    limit = 10,
    help = false,
    open = false,
  }

  local index = 2
  while index <= #args do
    local token = args[index]
    if token == "--help" or token == "-h" then
      options.help = true
    elseif token == "--config" then
      index = index + 1
      options.config = args[index]
    elseif token == "--out" then
      index = index + 1
      options.out = args[index]
    elseif token == "--out-dir" then
      index = index + 1
      options.out_dir = args[index]
    elseif token == "--in-json" then
      index = index + 1
      options.in_json = args[index]
    elseif token == "--project-root" then
      index = index + 1
      options.project_root = args[index]
    elseif token == "--query" then
      index = index + 1
      options.query = args[index]
    elseif token == "--limit" then
      index = index + 1
      options.limit = common.to_integer(args[index]) or 10
    elseif token == "--open" then
      options.open = true
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  return options
end

function cli.run(args, env)
  local stdout = env and env.stdout or io.stdout
  local stderr = env and env.stderr or io.stderr
  local command_name = env and env.command_name or "vendor/scrap4lua/bin/scrap4lua"
  local open_path = env and env.open_path or common.open_path
  local options = _parse_args(args or {})

  if options.help or options.command == nil then
    stdout:write(_help_text(command_name))
    return 0
  end

  if options.config == nil or options.config == "" then
    stderr:write("missing --config\n")
    return 1
  end

  local config = config_loader.load(options.config)

  if options.command == "index" then
    local built_index = indexer.build_index(config, {
      project_root = options.project_root,
    })
    if options.out == nil or options.out == "" then
      stderr:write("index requires --out FILE\n")
      return 1
    end
    local ok, err = _write_json(options.out, built_index)
    if not ok then
      stderr:write(tostring(err) .. "\n")
      return 1
    end
    stdout:write(options.out .. "\n")
    return 0
  end

  if options.command == "find" then
    local built_index = indexer.build_index(config, {
      project_root = options.project_root,
    })
    if options.query == nil or options.query == "" then
      stderr:write("find requires --query TEXT\n")
      return 1
    end
    local payload = query.find(built_index, config, options.query, {
      limit = options.limit,
    })
    if options.out ~= nil and options.out ~= "" then
      local ok, err = _write_json(options.out, payload)
      if not ok then
        stderr:write(tostring(err) .. "\n")
        return 1
      end
      stdout:write(options.out .. "\n")
    else
      stdout:write(json_writer.encode(payload) .. "\n")
    end
    return 0
  end

  if options.command == "clusters" then
    local built_index = indexer.build_index(config, {
      project_root = options.project_root,
    })
    local payload = {
      metadata = built_index.metadata,
      themes = {},
    }
    for index_value = 1, math.min(options.limit or 10, #(built_index.themes or {})) do
      payload.themes[#payload.themes + 1] = built_index.themes[index_value]
    end
    if options.out ~= nil and options.out ~= "" then
      local ok, err = _write_json(options.out, payload)
      if not ok then
        stderr:write(tostring(err) .. "\n")
        return 1
      end
      stdout:write(options.out .. "\n")
    else
      stdout:write(json_writer.encode(payload) .. "\n")
    end
    return 0
  end

  if options.command == "viewer" then
    if options.out_dir == nil or options.out_dir == "" then
      stderr:write("viewer requires --out-dir DIR\n")
      return 1
    end

    local built_index = nil
    if options.in_json ~= nil and options.in_json ~= "" then
      local content, err = common.read_file(options.in_json)
      if content == nil then
        stderr:write(tostring(err) .. "\n")
        return 1
      end
      built_index = json_reader.decode(content)
    else
      built_index = indexer.build_index(config, {
        project_root = options.project_root,
      })
    end

    local ok, err = _copy_viewer_assets(options.out_dir)
    if not ok then
      stderr:write(tostring(err) .. "\n")
      return 1
    end

    local index_json_path = common.join_path(options.out_dir, "scrap_index.json")
    ok, err = _write_json(index_json_path, built_index)
    if not ok then
      stderr:write(tostring(err) .. "\n")
      return 1
    end

    ok, err = _write_data_script(common.join_path(options.out_dir, "scrap_data.js"), "SCRAP4LUA_DATA", built_index)
    if not ok then
      stderr:write(tostring(err) .. "\n")
      return 1
    end

    stdout:write("scrap4lua viewer ok / scrap4lua 视图已生成: " .. tostring(options.out_dir) .. "\n")
    if options.open then
      local open_ok, open_err = open_path(common.join_path(options.out_dir, "index.html"))
      if not open_ok then
        stderr:write(tostring(open_err) .. "\n")
        return 1
      end
    end
    return 0
  end

  stderr:write("unknown command: " .. tostring(options.command) .. "\n")
  return 1
end

function cli.main(args)
  local command_name = arg and arg[0] or "vendor/scrap4lua/bin/scrap4lua"
  return cli.run(args or {}, {
    command_name = command_name,
  })
end

return cli
