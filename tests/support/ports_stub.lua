local gameplay_loop_ports = require("turn.ports")
local port_types = require("turn.types")

local ports_stub = {}

local function _copy_table(input)
  local out = {}
  for key, value in pairs(input or {}) do
    out[key] = value
  end
  return out
end

local function _resolve_grouped_override(overrides)
  if type(overrides) ~= "table" then
    return {}
  end
  local grouped = {}
  for _, group_name in ipairs(port_types.group_names) do
    if type(overrides[group_name]) == "table" then
      grouped[group_name] = _copy_table(overrides[group_name])
    else
      grouped[group_name] = {}
    end
  end
  return grouped
end

function ports_stub.new(overrides)
  local grouped = _resolve_grouped_override(overrides)
  return gameplay_loop_ports.resolve(grouped)
end

return ports_stub
