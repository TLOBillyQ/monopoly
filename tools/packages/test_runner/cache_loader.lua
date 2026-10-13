--- Load real busted and its dependencies exclusively from this project's tree.
local M = {}
local prefixes = { "busted", "luassert", "say", "cliargs", "mediator", "pl", "term", "system", "lfs", "dkjson", "datafile" }
local verified = {}
local function dependency(name)
  for _, prefix in ipairs(prefixes) do
    if name == prefix or name:sub(1, #prefix + 1) == prefix .. "." then return true end
  end
  return false
end
function M.install(root)
  local prefix = root:gsub("\\", "/"):gsub("/+$", "") .. "/.toolcache/luarocks/"
  for name, object in pairs(package.loaded) do
    if dependency(name) and object and verified[name] ~= object then
      error("unverified preloaded module: " .. name, 0)
    end
  end
  local function searcher(name)
    if not dependency(name) then return nil end
    local source = package.searchpath(name, package.path)
    local native = false
    if not source then source = package.searchpath(name, package.cpath); native = true end
    assert(source, "cache dependency missing: " .. name)
    source = source:gsub("\\", "/")
    assert(source:sub(1, #prefix) == prefix, "dependency outside project cache: " .. name .. " " .. source)
    local chunk, err
    if native then chunk, err = package.loadlib(source, "luaopen_" .. name:gsub("%.", "_"))
    else chunk, err = loadfile(source) end
    assert(chunk, err)
    return function(...)
      local object = chunk(...)
      verified[name] = object == nil and true or object
      return object
    end, source
  end
  table.insert(package.searchers, 1, searcher)
end
return M
