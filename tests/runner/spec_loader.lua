local spec_loader = {}

local function _read_stdout(cmd)
  local pipe = io.popen(cmd)
  if not pipe then
    return nil
  end
  local output = pipe:read("*a") or ""
  pipe:close()
  return output
end

local function _collect_spec_paths()
  local output = _read_stdout("find tests/specs -type f -name '*_spec.lua' 2>/dev/null")
  if not output or output == "" then
    return {}
  end
  local paths = {}
  for line in string.gmatch(output, "[^\r\n]+") do
    if line ~= "" then
      paths[#paths + 1] = line
    end
  end
  table.sort(paths)
  return paths
end

local function _path_to_module(path)
  local normalized = path:gsub("\\", "/")
  if normalized:sub(1, #"tests/specs/") ~= "tests/specs/" then
    return nil
  end
  local sub = normalized:sub(#"tests/specs/" + 1)
  if sub:sub(-4) ~= ".lua" then
    return nil
  end
  sub = sub:sub(1, -5)
  return (sub:gsub("/", "."))
end

local function _load_specs_for_layers()
  local specs = {}
  for _, path in ipairs(_collect_spec_paths()) do
    local module = _path_to_module(path)
    if module then
      specs[#specs + 1] = require(module)
    end
  end
  return specs
end

function spec_loader.collect_all(opts)
  local _ = opts or {}
  return _load_specs_for_layers()
end

return spec_loader
