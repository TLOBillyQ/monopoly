-- Dead / unused module report (static)
-- Run: lua scripts/debloat_report.lua
--
-- Notes:
-- - Conservative: only string-literal `require` calls are followed.
-- - Dynamic requires (concatenated module names) may not be detected.

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

local function git_ls_files()
  local p = io.popen("git ls-files")
  if not p then
    return {}
  end
  local out = p:read("*a")
  p:close()
  local files = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    table.insert(files, line)
  end
  return files
end

local function is_lua_file(path)
  return path:sub(-4) == ".lua"
end

local function starts_with(s, prefix)
  return s:sub(1, #prefix) == prefix
end

local function extract_requires(src)
  local reqs = {}
  if not src or src == "" then
    return reqs
  end

  -- require("mod") / require('mod')
  for mod in src:gmatch("require%s*%(%s*[%\"%']([^%\"%']+)[%\"%']%s*%)") do
    table.insert(reqs, mod)
  end

  -- require "mod" / require 'mod'
  for mod in src:gmatch("require%s+[%\"%']([^%\"%']+)[%\"%']") do
    table.insert(reqs, mod)
  end

  return reqs
end

local function module_to_paths(mod)
  local rel = mod:gsub("%.", "/")
  return { rel .. ".lua", rel .. "/init.lua" }
end

local function build_file_index(files)
  local idx = {}
  for _, path in ipairs(files) do
    if is_lua_file(path) then
      idx[path] = true
    end
  end
  return idx
end

local function resolve_module(mod, file_index)
  for _, candidate in ipairs(module_to_paths(mod)) do
    if file_index[candidate] then
      return candidate
    end
  end
  return nil
end

local files = git_ls_files()
local file_index = build_file_index(files)

local deps = {} -- file -> { required_file... }
local dynamic_require_hits = {}

for _, path in ipairs(files) do
  if is_lua_file(path) and not starts_with(path, "docs/") then
    local src = read_all(path)
    if src then
      deps[path] = deps[path] or {}
      for _, mod in ipairs(extract_requires(src)) do
        local resolved = resolve_module(mod, file_index)
        if resolved then
          table.insert(deps[path], resolved)
        end
      end

      -- Heuristic: warn if `require(` exists but we didn't see a quoted module.
      if src:match("require%s*%(") and not src:match("require%s*%(%s*[%\"%']") then
        dynamic_require_hits[path] = true
      end
    end
  end
end

local roots = { "main.lua" }

local reachable = {}
local stack = {}
for _, r in ipairs(roots) do
  if file_index[r] then
    table.insert(stack, r)
  end
end

while #stack > 0 do
  local cur = table.remove(stack)
  if not reachable[cur] then
    reachable[cur] = true
    for _, nxt in ipairs(deps[cur] or {}) do
      if not reachable[nxt] then
        table.insert(stack, nxt)
      end
    end
  end
end

local function is_in_runtime_scope(path)
  if path == "main.lua" or path == "src/app.lua" then
    return true
  end
  return starts_with(path, "src/")
end

local unused = {}
for path, _ in pairs(file_index) do
  if is_in_runtime_scope(path) and not reachable[path] then
    table.insert(unused, path)
  end
end

table.sort(unused)

print("Dead-code report (static require graph)")
print("- roots: " .. table.concat(roots, ", "))

local reachable_runtime = 0
for k, _ in pairs(reachable) do
  if is_in_runtime_scope(k) then
    reachable_runtime = reachable_runtime + 1
  end
end
print("- reachable runtime files: " .. tostring(reachable_runtime))

if next(dynamic_require_hits) then
  print("\nWARNING: possible dynamic require usage detected in:")
  local t = {}
  for k, _ in pairs(dynamic_require_hits) do
    table.insert(t, k)
  end
  table.sort(t)
  for _, p in ipairs(t) do
    print("- " .. p)
  end
end

print("\nUnused runtime-scope Lua files (conservative): " .. tostring(#unused))
for _, p in ipairs(unused) do
  print("- " .. p)
end
