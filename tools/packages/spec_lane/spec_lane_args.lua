local spec_lane_args = {}

function spec_lane_args.usage()
  return table.concat({
    "用法: lua tools/cli.lua spec-lane --profile <name> [--verbose]",
    "",
    "--profile 选车道:behavior(七层 + foundation 全量)/ tooling(工具模块单测,不在 verify 管线内);",
    "--profile 也可直接给存在的目录（如 test/behavior/turn）按需点跑，按 behavior 默认构造临时 profile；其余语义见 `lua tools/cli.lua verify --help`。",
    "--busted-bin / BUSTED_BIN 已删除，PATH 无 busted。",
  }, "\n") .. "\n"
end

function spec_lane_args.parse(args)
  local options = { verbose = false }
  local i = 1
  while i <= #(args or {}) do
    local token = args[i]
    if token == "--profile" then
      options.profile = args[i + 1]
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

return spec_lane_args
