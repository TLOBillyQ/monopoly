local function build_paths(extra)
  local paths = {
    "src/?.lua",
    "src/?/init.lua",
  }
  for _, p in ipairs(extra or {}) do
    paths[#paths + 1] = p
  end
  paths[#paths + 1] = "?.lua"
  return table.concat(paths, ";") .. ";" .. package.path
end

local function bootstrap(extra)
  package.path = build_paths(extra)
end

return bootstrap
