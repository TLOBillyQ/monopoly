local rules = {
  {
    root = "src/presentation/interaction",
    forbidden = { "src.game." },
    description = "interaction layer must not require src.game.* directly",
  },
  {
    root = "src/presentation",
    forbidden = { "shared.UINodes" },
    description = "no module may depend on retired shared.UINodes",
  },
  {
    root = "src/presentation",
    forbidden = { "intent_builders" },
    description = "no module may depend on retired intent_builders",
  },
  {
    root = "src/game/core/runtime",
    forbidden = { "TurnFlow" },
    description = "runtime must not depend on retired TurnFlow",
  },
  {
    root = "src/presentation/canvas/base",
    forbidden = {
      "canvas.always_show", "canvas.market", "canvas.secondary_confirm",
      "canvas.remote_choice", "canvas.player_choice", "canvas.popup",
      "canvas.target_choice",
    },
    description = "base canvas must not import other canvas modules",
  },
  {
    root = "src/game/core",
    forbidden_patterns = {
      "%f[%w_]GameAPI%f[^%w_]",
      "%f[%w_]GlobalAPI%f[^%w_]",
      "%f[%w_]SetTimeOut%f[^%w_]",
      "%f[%w_]RegisterTriggerEvent%f[^%w_]",
      "%f[%w_]RegisterCustomEvent%f[^%w_]",
    },
    description = "game core must not use runtime global APIs directly",
  },
  {
    root = "src/game/core",
    forbidden_patterns = {
      "require%(\"src%.game%.flow%..-\"%)",
      "require%('src%.game%.flow%..-'%)",
    },
    description = "game core must not depend on src.game.flow.* directly",
  },
  {
    root = "src",
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.TurnEngine\"%)",
      "require%('src%.game%.core%.runtime%.TurnEngine'%)",
      "require%(\"src%.game%.core%.runtime%.PhaseRegistry\"%)",
      "require%('src%.game%.core%.runtime%.PhaseRegistry'%)",
    },
    description = "source must not depend on retired core runtime proxy modules",
  },
  {
    root = "tests",
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.TurnEngine\"%)",
      "require%('src%.game%.core%.runtime%.TurnEngine'%)",
      "require%(\"src%.game%.core%.runtime%.PhaseRegistry\"%)",
      "require%('src%.game%.core%.runtime%.PhaseRegistry'%)",
    },
    description = "tests must not depend on retired core runtime proxy modules",
  },
  {
    root = "src",
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.MonopolyEvents\"%)",
      "require%('src%.game%.core%.runtime%.MonopolyEvents'%)",
    },
    description = "source must not depend on MonopolyEvents compatibility bridge path",
  },
  {
    root = "tests",
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.MonopolyEvents\"%)",
      "require%('src%.game%.core%.runtime%.MonopolyEvents'%)",
    },
    description = "tests must not depend on MonopolyEvents compatibility bridge path",
  },
  {
    root = "src",
    forbidden_patterns = {
      "clock%.now%(",
      "clock%.diff_seconds%(",
    },
    description = "source must not use retired clock.now/diff_seconds aliases",
  },
  {
    root = "src/game/systems",
    forbidden_patterns = {
      "ui_port%.wait_action_anim",
      "game%.ui_port%.wait_action_anim",
    },
    description = "systems layer must use ActionAnimPort instead of direct ui_port.wait_action_anim checks",
  },
}

-- Keep this whitelist minimal and only for temporary migration bridges.
-- Entries that are no longer observed will fail the rule check to enforce decay.
local presentation_game_systems_whitelist = {
  -- ["src/presentation/example.lua"] = {
  --   ["src.game.systems.some.Module"] = true,
  -- },
}

local forbidden_files = {
  "src/game/core/runtime/TurnEngine.lua",
  "src/game/core/runtime/PhaseRegistry.lua",
  "src/game/core/runtime/MonopolyEvents.lua",
}

local function _is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function _build_list_command(root)
  if _is_windows() then
    local win_root = root:gsub("/", "\\")
    return 'dir /b /s /a-d "' .. win_root .. '\\*.lua" 2>nul'
  end
  return 'find "' .. root .. '" -type f -name "*.lua" 2>/dev/null'
end

local function _collect_lua_files(root)
  local cmd = _build_list_command(root)
  local p = io.popen(cmd)
  if not p then
    return nil, "cannot run list command: " .. cmd
  end

  local files = {}
  for line in p:lines() do
    if line and line ~= "" then
      files[#files + 1] = line
    end
  end

  local ok = p:close()
  if ok == nil or ok == false then
    return nil, "list command failed: " .. tostring(cmd)
  end
  if #files == 0 then
    return nil, "no lua files found under: " .. tostring(root)
  end
  return files
end

local function _scan_file(path, forbidden, forbidden_patterns)
  local file = io.open(path, "r")
  if not file then
    return nil, "cannot open: " .. tostring(path)
  end
  local lineno = 0
  for line in file:lines() do
    lineno = lineno + 1
    for _, prefix in ipairs(forbidden or {}) do
      if line:find(prefix, 1, true) then
        file:close()
        return {
          path = path,
          line = lineno,
          token = prefix,
          text = line,
        }
      end
    end
    for _, pattern in ipairs(forbidden_patterns or {}) do
      if line:find(pattern) then
        file:close()
        return {
          path = path,
          line = lineno,
          token = pattern,
          text = line,
        }
      end
    end
  end
  file:close()
  return nil
end

local function _scan_tree(rule)
  local files, files_err = _collect_lua_files(rule.root)
  if not files then
    return nil, files_err
  end
  for _, path in ipairs(files) do
    local hit, scan_err = _scan_file(path, rule.forbidden, rule.forbidden_patterns)
    if hit then
      return hit
    end
    if scan_err then
      return nil, scan_err
    end
  end
  return nil
end

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _to_presentation_relpath(path)
  local normalized = _normalize_path(path)
  local rel = normalized:match(".*(src/presentation/.+)")
  return rel or normalized
end

local function _scan_presentation_system_requires()
  local files, err = _collect_lua_files("src/presentation")
  if not files then
    return nil, err
  end

  local observed = {}

  for _, path in ipairs(files) do
    local relpath = _to_presentation_relpath(path)
    local file = io.open(path, "r")
    if not file then
      return nil, "cannot open: " .. tostring(path)
    end
    local lineno = 0
    for line in file:lines() do
      lineno = lineno + 1
      local dep = line:match("require%(%s*\"(src%.game%.systems%.[^\"]+)\"%s*%)")
      if dep == nil then
        dep = line:match("require%(%s*'(src%.game%.systems%.[^']+)'%s*%)")
      end
      if dep ~= nil then
        if observed[relpath] == nil then
          observed[relpath] = {}
        end
        observed[relpath][dep] = true
        local allow_by_file = presentation_game_systems_whitelist[relpath]
        local is_allowed = allow_by_file ~= nil and allow_by_file[dep] == true
        if not is_allowed then
          file:close()
          return {
            path = relpath,
            line = lineno,
            token = dep,
            text = line,
            description = "presentation must not require src.game.systems.* directly (whitelist only allows temporary migration entries)",
          }
        end
      end
    end
    file:close()
  end

  for relpath, deps in pairs(presentation_game_systems_whitelist) do
    for dep in pairs(deps) do
      local has_dep = observed[relpath] and observed[relpath][dep] == true
      if not has_dep then
        return {
          path = relpath,
          line = 1,
          token = dep,
          text = "stale whitelist entry",
          description = "presentation->game/systems whitelist must only keep active dependencies (decay-only governance)",
        }
      end
    end
  end

  return nil
end

for _, rule in ipairs(rules) do
  local hit, err = _scan_tree(rule)
  if err and not tostring(err):find("no lua files found under", 1, true) then
    io.stderr:write("dep_rules error: ", err, "\n")
    os.exit(1)
  end
  if hit then
    io.stderr:write("dep_rules violation: ", hit.path, ":", hit.line, " contains ", hit.token, "\n")
    io.stderr:write("rule: ", rule.description, "\n")
    io.stderr:write(hit.text, "\n")
    os.exit(1)
  end
end

local presentation_hit, presentation_err = _scan_presentation_system_requires()
if presentation_err and not tostring(presentation_err):find("no lua files found under", 1, true) then
  io.stderr:write("dep_rules error: ", presentation_err, "\n")
  os.exit(1)
end
if presentation_hit then
  io.stderr:write("dep_rules violation: ", presentation_hit.path, ":", presentation_hit.line, " contains ", presentation_hit.token, "\n")
  io.stderr:write("rule: ", presentation_hit.description, "\n")
  io.stderr:write(presentation_hit.text, "\n")
  os.exit(1)
end

for _, path in ipairs(forbidden_files) do
  local file = io.open(path, "r")
  if file then
    file:close()
    io.stderr:write("dep_rules violation: forbidden file exists: ", path, "\n")
    os.exit(1)
  end
end

print("dep_rules ok")
