-- Dependency rules self-check (run with: lua tests/deps_check.lua)
--
-- === 依赖规则白名单（Allowed Dependency Directions） ===
--
-- 层级                     | 允许依赖
-- -------------------------|-------------------------------------------
-- Manager/Adapter/**       | → Manager/GameManager/**, Components/**, Config/**, Library/Monopoly/**
-- Manager/GameManager/**   | → Manager/GameManager/**, Components/**, Config/**, Library/Monopoly/**
-- Components/**            | → Config/**, Library/Monopoly/**
-- Config/**                | → (none)
-- Library/Monopoly/**      | → (none)
--
-- === 禁止规则 ===
-- 1) Manager/GameManager/** 禁止依赖 UI 适配器 (Manager/Adapter/**)
-- 2) services 之间禁止直接 require（应通过 game.services.* 注入）
-- 3) Manager/GameManager/** 禁止使用 dofile/loadfile 绕过 require 检查

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

-- Convert module name (e.g. "Manager.Adapter.Eggy.EggyRuntime") to file path (e.g. "Manager/Adapter/Eggy/EggyRuntime.lua")
local function mod_to_path(mod)
  return mod:gsub("%.", "/") .. ".lua"
end

-- Check for dofile/loadfile usage which bypasses require dependency checking
local function extract_dynamic_loads(src)
  local loads = {}
  if not src or src == "" then
    return loads
  end
  -- dofile("path") / dofile('path')
  for path in src:gmatch("dofile%s*%(%s*[%\"%']([^%\"%']+)[%\"%']%s*%)") do
    table.insert(loads, { kind = "dofile", path = path })
  end
  -- loadfile("path") / loadfile('path')
  for path in src:gmatch("loadfile%s*%(%s*[%\"%']([^%\"%']+)[%\"%']%s*%)") do
    table.insert(loads, { kind = "loadfile", path = path })
  end
  return loads
end

local function check_file(path, src)
  local errors = {}

  local is_gameplay = starts_with(path, "Manager/GameManager/")
  local is_service = path:match("Manager/GameManager/.*Service%.lua$") ~= nil

  for _, mod in ipairs(extract_requires(src)) do
    -- Convert module to path for more reliable prefix checking
    local mod_path = mod_to_path(mod)

    -- Rule 1: gameplay must not require UI adapters
    if is_gameplay and starts_with(mod_path, "Manager/Adapter/") then
      table.insert(errors, "gameplay must not require UI adapters: require(\"" .. mod .. "\")")
    end

    -- Rule 2: services must not require each other directly
    if is_service and mod_path:match("Manager/GameManager/.*Service%.lua$") then
      table.insert(errors, "services must not require each other directly: require(\"" .. mod .. "\")")
    end

    if path == "Manager/GameManager/Turn/TurnManager.lua" and mod_path:match("^Manager/GameManager/Turn") then
      table.insert(errors, "turn_manager must not require Turn* directly: require(\"" .. mod .. "\")")
    end
  end

  -- Rule 3: Check for dofile/loadfile usage in gameplay layer (bypasses require checking)
  if is_gameplay then
    for _, load in ipairs(extract_dynamic_loads(src)) do
      table.insert(errors, "gameplay must not use " .. load.kind .. " (bypasses dependency checking): " .. load.kind .. "(\"" .. load.path .. "\")")
    end
  end

  return errors
end

local function require_in_file(path, mod)
  local src = read_all(path)
  if not src then
    return false
  end
  for _, m in ipairs(extract_requires(src)) do
    if m == mod then
      return true
    end
  end
  return false
end

local files = git_ls_files()
local violations = {}
local required_phases = {
  "Manager.GameManager.Turn.TurnStart",
  "Manager.GameManager.Turn.TurnRoll",
  "Manager.GameManager.Turn.TurnMove",
  "Manager.GameManager.Turn.TurnLand",
  "Manager.GameManager.Turn.TurnPost",
  "Manager.GameManager.Turn.TurnEnd",
}

for _, mod in ipairs(required_phases) do
  if not require_in_file("Manager/GameManager/System/CompositionRoot.lua", mod) then
    table.insert(violations, "Manager/GameManager/System/CompositionRoot.lua: missing required phase module: " .. mod)
  end
end

for _, path in ipairs(files) do
  if is_lua_file(path)
    and (starts_with(path, "Manager/GameManager/")
      or starts_with(path, "Manager/Adapter/")
      or starts_with(path, "Config/")
      or path == "Manager/GameManager/System/Game.lua") then
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
