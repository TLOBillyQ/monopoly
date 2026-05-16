local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../shared/bootstrap.lua")
bootstrap.install(debug.getinfo(1, "S").source)

local mutator = require("acceptance.mutator")

local function _usage()
  return table.concat({
    "usage: gherkin-mutator [options]",
    "  --feature <path>   default: features/a-feature.feature",
    "  --work-dir <path>  default: build/acceptance-mutation",
    "  --workers <count>",
    "  --timeout <duration>",
    "  --json",
  }, "\n")
end

local function _parse_duration(value)
  if value == nil then
    return nil
  end
  local amount, unit = tostring(value):match("^(%d+)([smh]?)$")
  if amount == nil then
    return nil
  end
  local seconds = tonumber(amount)
  if unit == "m" then
    seconds = seconds * 60
  elseif unit == "h" then
    seconds = seconds * 3600
  end
  return seconds
end

local function _parse_args(args)
  local options = {
    feature = "features/a-feature.feature",
    work_dir = "build/acceptance-mutation",
    workers = 1,
    json = false,
  }

  local index = 1
  while index <= #(args or {}) do
    local value = args[index]
    if value == "--feature" then
      options.feature = args[index + 1]
      index = index + 2
    elseif value == "--work-dir" then
      options.work_dir = args[index + 1]
      index = index + 2
    elseif value == "--workers" then
      options.workers = tonumber(args[index + 1])
      index = index + 2
    elseif value == "--timeout" then
      options.timeout_seconds = _parse_duration(args[index + 1])
      if options.timeout_seconds == nil then
        return nil, "invalid timeout: " .. tostring(args[index + 1])
      end
      index = index + 2
    elseif value == "--json" then
      options.json = true
      index = index + 1
    elseif value == "--help" or value == "-h" then
      options.help = true
      index = index + 1
    else
      return nil, "unknown option: " .. tostring(value)
    end
  end

  if options.feature == nil or options.work_dir == nil then
    return nil, "missing option value"
  end
  return options
end

local options, err = _parse_args(arg)
if options == nil then
  io.stderr:write(_usage() .. "\n" .. tostring(err) .. "\n")
  os.exit(2)
end
if options.help then
  io.write(_usage() .. "\n")
  os.exit(0)
end

local report
report, err = mutator.run(options)
if report == nil then
  io.stderr:write(tostring(err) .. "\n")
  os.exit(1)
end

if options.json then
  io.write(mutator.format_json_report(report))
else
  io.write(mutator.format_text_report(report))
end

if report.summary.survived > 0 or report.summary.errors > 0 then
  os.exit(1)
end
os.exit(0)
