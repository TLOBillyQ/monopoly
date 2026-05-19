local common = require("shared.lib.common")
local json = require("acceptance.json")
local table_shape = require("acceptance.table_shape")

local generator = {}

local function _lua_literal(value, indent, key_hint)
  local value_type = type(value)
  if value == nil then
    return "nil"
  end
  if value_type == "string" then
    return string.format("%q", value)
  end
  if value_type == "boolean" or value_type == "number" then
    return tostring(value)
  end
  if value_type ~= "table" then
    return string.format("%q", tostring(value))
  end

  local next_indent = indent + 2
  local pad = string.rep(" ", indent)
  local child_pad = string.rep(" ", next_indent)

  if table_shape.is_array(value, key_hint) then
    if next(value) == nil then
      return "{}"
    end
    local parts = {}
    for _, item in ipairs(value) do
      parts[#parts + 1] = child_pad .. _lua_literal(item, next_indent) .. ","
    end
    return "{\n" .. table.concat(parts, "\n") .. "\n" .. pad .. "}"
  end

  local keys = table_shape.sorted_keys(value)
  if #keys == 0 then
    return "{}"
  end

  local fields = {}
  for _, key in ipairs(keys) do
    fields[#fields + 1] = child_pad
      .. "["
      .. string.format("%q", key)
      .. "] = "
      .. _lua_literal(value[key], next_indent, key)
      .. ","
  end
  return "{\n" .. table.concat(fields, "\n") .. "\n" .. pad .. "}"
end

function generator.generate(ir)
  return table.concat({
    "-- luacheck: globals describe it",
    'local runtime = require("acceptance.runtime")',
    'local steps = require("acceptance.steps")',
    "",
    "local ir = " .. _lua_literal(ir, 0),
    "",
    "describe(\"Acceptance: \" .. tostring(ir.name), function()",
    "  runtime.define_busted_specs(ir, steps.handlers(), it)",
    "end)",
    "",
  }, "\n")
end

function generator.write_generated(ir, output_path)
  local parent = common.parent_dir(output_path)
  local ok, err = common.ensure_dir(parent)
  if not ok then
    return nil, err
  end
  return common.write_file(output_path, generator.generate(ir))
end

function generator.generate_file(json_path, output_path)
  local content, err = common.read_file(json_path)
  if content == nil then
    return nil, err
  end

  local ok, ir_or_err = pcall(json.decode, content)
  if not ok then
    return nil, ir_or_err
  end
  return generator.write_generated(ir_or_err, output_path)
end

return generator
