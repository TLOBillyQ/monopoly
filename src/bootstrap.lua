local function split_path(path_str)
  local out = {}
  for part in string.gmatch(path_str or "", "[^;]+") do
    out[#out + 1] = part
  end
  return out
end

local function build_paths(extra)
  local paths = {
    "src/?.lua",
    "src/?/init.lua",
  }
  for _, p in ipairs(extra or {}) do
    paths[#paths + 1] = p
  end
  paths[#paths + 1] = "?.lua"
  return paths
end

local function apply_paths(extra)
  if type(package) ~= "table" then
    return
  end
  local current = type(package.path) == "string" and package.path or ""
  local existing = split_path(current)
  local existing_set = {}
  for _, p in ipairs(existing) do
    existing_set[p] = true
  end

  local prepend = {}
  for _, p in ipairs(build_paths(extra)) do
    if not existing_set[p] then
      prepend[#prepend + 1] = p
    end
  end
  if #prepend == 0 then
    return
  end

  if current == "" then
    package.path = table.concat(prepend, ";")
  else
    package.path = table.concat(prepend, ";") .. ";" .. current
  end
end

local function resolve_extra(extra_or_opts)
  if type(extra_or_opts) ~= "table" then
    return nil
  end
  if extra_or_opts.extra ~= nil then
    return extra_or_opts.extra
  end
  return extra_or_opts
end

local function bootstrap(extra_or_opts)
  local extra = resolve_extra(extra_or_opts)
  apply_paths(extra)
end

return bootstrap
