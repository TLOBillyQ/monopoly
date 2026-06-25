local busted_lane_args = {}

function busted_lane_args.usage()
  return "usage: lua tools/quality/busted_lane.lua --profile <name> [--busted-bin <path>] [--verbose]\n"
end

function busted_lane_args.parse(args)
  local options = { verbose = false }
  local i = 1
  while i <= #(args or {}) do
    local token = args[i]
    if token == "--profile" then
      options.profile = args[i + 1]
      i = i + 2
    elseif token == "--busted-bin" then
      options.busted_bin = args[i + 1]
      i = i + 2
    elseif token == "--verbose" then
      options.verbose = true
      i = i + 1
    elseif token == "--help" or token == "-h" then
      options.help = true
      i = i + 1
    else
      return nil, "unknown option: " .. tostring(token)
    end
  end
  if not options.help and (not options.profile or options.profile == "") then
    return nil, "missing --profile"
  end
  return options
end

return busted_lane_args
