require("tests.bootstrap")

local resolver = require("src.app.bootstrap.testing.test_profile_resolver")

local function _is_array(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for key in pairs(value) do
    if math.tointeger(key) == nil then
      return false
    end
    count = count + 1
  end
  for index = 1, count do
    if value[index] == nil then
      return false
    end
  end
  return true
end

local function _sorted_keys(value)
  local keys = {}
  for key in pairs(value or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    if type(left) == type(right) then
      return left < right
    end
    return tostring(left) < tostring(right)
  end)
  return keys
end

local function _quote_string(value)
  return string.format("%q", value)
end

local function _serialize(value, depth)
  depth = depth or 0
  local indent = string.rep("  ", depth)
  local child_indent = string.rep("  ", depth + 1)
  local value_type = type(value)

  if value_type == "nil" then
    return "nil"
  end
  if value_type == "boolean" or value_type == "number" then
    return tostring(value)
  end
  if value_type == "string" then
    return _quote_string(value)
  end
  assert(value_type == "table", "unsupported startup profile value type: " .. tostring(value_type))

  local lines = { "{" }
  if _is_array(value) then
    for _, entry in ipairs(value) do
      lines[#lines + 1] = child_indent .. _serialize(entry, depth + 1) .. ","
    end
  else
    for _, key in ipairs(_sorted_keys(value)) do
      local rendered_key
      if type(key) == "string" and key:match("^[%a_][%w_]*$") then
        rendered_key = key
      else
        rendered_key = "[" .. _serialize(key, depth + 1) .. "]"
      end
      lines[#lines + 1] = child_indent .. rendered_key .. " = " .. _serialize(value[key], depth + 1) .. ","
    end
  end
  lines[#lines + 1] = indent .. "}"
  return table.concat(lines, "\n")
end

local function _write_file(path, content)
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
end

local function main(args)
  local profile_name = args[1]
  local output_path = args[2]
  assert(type(profile_name) == "string" and profile_name ~= "", "missing profile name")
  assert(type(output_path) == "string" and output_path ~= "", "missing output path")

  local payload = {
    profile_name = profile_name,
    bootstrap = resolver.resolve_bootstrap(profile_name),
  }
  local content = "return " .. _serialize(payload) .. "\n"
  _write_file(output_path, content)
end

main(arg or {})
