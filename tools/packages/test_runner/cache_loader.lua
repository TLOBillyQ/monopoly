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
function M.verified_module(name)
  for dependency_name, object in pairs(verified) do
    assert(package.loaded[dependency_name] == object, "verified module identity changed: " .. dependency_name)
  end
  return verified[name]
end
local function cache_prefix(root)
  return root:gsub("\\", "/"):gsub("/+$", "") .. "/.toolcache/luarocks/"
end
-- Stock busted.runner (uml crap / mutate via .busted, #99) loads these before any
-- project code runs. Adopt them only inside the pinned uml environment: every
-- search template lies under the repo root (no user tree, no ;; default), and
-- every preloaded dependency resolves inside the project cache.
function M.adopt_preloaded(root)
  local repo = root:gsub("\\", "/"):gsub("/+$", "") .. "/"
  local prefix = cache_prefix(root)
  for template in (package.path .. ";" .. package.cpath):gmatch("[^;]+") do
    local normalized = template:gsub("\\", "/")
    assert(normalized:sub(1, #repo) == repo, "search path outside repo root: " .. template)
  end
  for name, object in pairs(package.loaded) do
    if dependency(name) and object and verified[name] ~= object then
      local source = package.searchpath(name, package.path) or package.searchpath(name, package.cpath)
      source = tostring(source):gsub("\\", "/")
      assert(source:sub(1, #prefix) == prefix, "dependency outside project cache: " .. name .. " " .. source)
      verified[name] = object
    end
  end
end
function M.install(root)
  local prefix = cache_prefix(root)
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
