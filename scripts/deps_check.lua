-- Dependency rules self-check (run with: lua scripts/deps_check.lua)
-- Rules:
-- 1) src/gameplay/** must not require src/visual/**
-- 2) src/gameplay/app/services/** must not require other services via require("src.gameplay.app.services.*")
--    (use game.services.* instead). Infrastructure like logger should live outside services (e.g. src/util/logger.lua).

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

local function check_file(path, src)
  local errors = {}

  local is_gameplay = starts_with(path, "src/gameplay/")
  local is_service = starts_with(path, "src/gameplay/app/services/")

  for _, mod in ipairs(extract_requires(src)) do
    if is_gameplay and starts_with(mod, "src.visual") then
      table.insert(errors, "gameplay must not require visual: require(\"" .. mod .. "\")")
    end

    if is_service and starts_with(mod, "src.gameplay.app.services.") then
      table.insert(errors, "services must not require each other directly: require(\"" .. mod .. "\")")
    end
  end

  return errors
end

local files = git_ls_files()
local violations = {}

for _, path in ipairs(files) do
  if is_lua_file(path) and (starts_with(path, "src/gameplay/") or starts_with(path, "src/visual/") or starts_with(path, "src/core/") or starts_with(path, "src/config/") or path == "src/app.lua") then
    local src = read_all(path)
    if src then
      local errs = check_file(path, src)
      if #errs > 0 then
        for _, e in ipairs(errs) do
          table.insert(violations, path .. ": " .. e)
        end
      end
    end
  end
end

if #violations > 0 then
  io.stderr:write("Dependency rule violations (" .. #violations .. "):\n")
  for _, v in ipairs(violations) do
    io.stderr:write("- " .. v .. "\n")
  end
  os.exit(1)
end

print("Dependency self-check passed")
