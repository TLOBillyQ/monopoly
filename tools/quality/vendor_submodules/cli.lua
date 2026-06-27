local cli = {}

local function _short(hash)
  local text = tostring(hash or "")
  if text == "" then
    return "-"
  end
  return text:sub(1, 10)
end

local function _usage()
  return table.concat({
    "usage: lua tools/quality/vendor_submodules.lua [--root <path>] [--ensure]",
    "Checks swarm quality tool lockfile/cache health.",
    "--fetch is accepted as a compatibility alias for --ensure.",
  }, "\n")
end

local function _parse_args(args)
  local opts = {}
  local index = 1
  while index <= #(args or {}) do
    local value = args[index]
    if value == "--root" then
      opts.root = args[index + 1]
      if opts.root == nil then
        return nil, "missing value for --root"
      end
      index = index + 2
    elseif value == "--ensure" or value == "--fetch" then
      opts.ensure = true
      index = index + 1
    elseif value == "--help" or value == "-h" then
      opts.help = true
      index = index + 1
    else
      return nil, "unknown option: " .. tostring(value)
    end
  end
  return opts
end

function cli.main(vendor_submodules, args)
  local opts, err = _parse_args(args or {})
  if opts == nil then
    io.stderr:write(_usage() .. "\n" .. tostring(err) .. "\n")
    return 2
  end
  if opts.help then
    io.write(_usage() .. "\n")
    return 0
  end

  local result = vendor_submodules.check(opts)
  if result.ok then
    io.write(string.format("tool cache clean: %d tools\n", result.tool_count or 0))
    return 0
  end

  for _, issue in ipairs(result.issues or {}) do
    io.stderr:write(string.format(
      "tool cache issue: tool=%s path=%s expected=%s actual=%s message=%s\n",
      tostring(issue.tool or "-"),
      tostring(issue.path or "-"),
      _short(issue.expected),
      _short(issue.actual),
      tostring(issue.message or "unknown")
    ))
  end
  return 1
end

return cli
