local command = {}

function command.read(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if handle == nil then
    return nil, "popen failed"
  end
  local out = handle:read("*a")
  handle:close()
  return out or ""
end

return command
