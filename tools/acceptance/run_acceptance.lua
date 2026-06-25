local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../shared/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
assert(bootstrap.ensure_tool("acceptance4lua", env))

local common = require("shared.lib.common")
local generator = require("acceptance4lua.generator")
local gherkin_parser = require("acceptance4lua.gherkin_parser")
local runner = require("acceptance4lua.runner")

local run_acceptance = {}

local function _usage()
  return "usage: lua tools/acceptance/run_acceptance.lua [--feature <path>] [--json <path>] [--generated <path>]"
end

local function _parse_args(args)
  local options = {
    feature = "features/a-feature.feature",
    json = "build/acceptance/a-feature.json",
    generated = "acceptance/generated/a-feature_acceptance_spec.lua",
  }

  local index = 1
  while index <= #(args or {}) do
    local arg_value = args[index]
    if arg_value == "--feature" then
      options.feature = args[index + 1]
      index = index + 2
    elseif arg_value == "--json" then
      options.json = args[index + 1]
      index = index + 2
    elseif arg_value == "--generated" then
      options.generated = args[index + 1]
      index = index + 2
    elseif arg_value == "--help" or arg_value == "-h" then
      options.help = true
      index = index + 1
    else
      return nil, "unknown option: " .. tostring(arg_value)
    end
  end

  if options.feature == nil or options.json == nil or options.generated == nil then
    return nil, "missing option value"
  end
  return options
end

function run_acceptance.run(options)
  options = options or {}
  local ok, err = common.ensure_dir(common.parent_dir(options.json))
  if not ok then
    return nil, err
  end
  ok, err = common.ensure_dir(common.parent_dir(options.generated))
  if not ok then
    return nil, err
  end

  ok, err = gherkin_parser.write_json_file(options.feature, options.json)
  if not ok then
    return nil, err
  end

  ok, err = generator.generate_file(options.json, options.generated)
  if not ok then
    return nil, err
  end

  local result = runner.run_generated(options.generated, { cwd = env.repo_root })
  if result.error ~= "" then
    return nil, result.error
  end
  if result.passed ~= true then
    return nil, result.output
  end

  return true, result.output
end

local function _compress_tap(output)
  local passed, failed = 0, 0
  local kept = {}
  for line in (tostring(output or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^ok%s+%d") then
      passed = passed + 1
    elseif line:match("^not ok%s+%d") then
      failed = failed + 1
      kept[#kept + 1] = line
    elseif not line:match("^%d+%.%.%d+%s*$") then
      kept[#kept + 1] = line
    end
  end
  if failed == 0 then
    return string.format("%d passed\n", passed)
  end
  kept[#kept + 1] = string.format("%d passed, %d failed", passed, failed)
  return table.concat(kept, "\n") .. "\n"
end

function run_acceptance.main(args)
  local options, err = _parse_args(args)
  if options == nil then
    io.stderr:write(_usage() .. "\n" .. tostring(err) .. "\n")
    return 2
  end
  if options.help then
    io.write(_usage() .. "\n")
    return 0
  end

  local ok, output = run_acceptance.run(options)
  if not ok then
    io.stderr:write(_compress_tap(output))
    return 1
  end
  io.write(_compress_tap(output))
  return 0
end

if arg ~= nil and tostring(arg[0] or ""):match("tools/acceptance/run_acceptance%.lua$") then
  os.exit(run_acceptance.main(arg))
end

return run_acceptance
