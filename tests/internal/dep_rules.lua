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
      "require%(\"src%.core%.RuntimeCompat\"%)",
      "require%('src%.core%.RuntimeCompat'%)",
    },
    description = "game core must not depend on retired runtime bridge path src.core.RuntimeCompat; use RuntimePorts/context-injected ports",
  },
  {
    root = "src/app",
    forbidden_patterns = {
      "require%(\"src%.core%.RuntimeCompat\"%)",
      "require%('src%.core%.RuntimeCompat'%)",
    },
    description = "app layer must not depend on retired runtime bridge path src.core.RuntimeCompat; use RuntimePorts/context",
  },
  {
    root = "src/presentation",
    forbidden_patterns = {
      "require%(\"src%.core%.RuntimeCompat\"%)",
      "require%('src%.core%.RuntimeCompat'%)",
    },
    description = "presentation layer must not depend on retired runtime bridge path src.core.RuntimeCompat; use RuntimePorts/context",
  },
  {
    root = "tests",
    forbidden_patterns = {
      "require%(\"src%.core%.RuntimeCompat\"%)",
      "require%('src%.core%.RuntimeCompat'%)",
    },
    description = "tests must not depend on retired runtime bridge path src.core.RuntimeCompat; validate RuntimePorts/RuntimeContext contracts directly",
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
    description = "source must not depend on MonopolyEvents retired bridge path",
  },
  {
    root = "tests",
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.MonopolyEvents\"%)",
      "require%('src%.game%.core%.runtime%.MonopolyEvents'%)",
    },
    description = "tests must not depend on MonopolyEvents retired bridge path",
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
  {
    root = "src/game/flow/turn",
    forbidden_patterns = {
      "state%.ui%."
    },
    description = "turn flow must use ui_sync.resolve_ui_gate/ui_sync ports instead of direct state.ui reads",
  },
  {
    root = "src/game/systems/market/service",
    forbidden_patterns = {
      "%f[%w_]GameAPI%f[^%w_]",
      "%f[%w_]RegisterTriggerEvent%f[^%w_]",
      "%f[%w_]EVENT%f[^%w_]",
    },
    description = "market service layer must not call host purchase globals directly; move Eggy payment details to outer adapters",
  },
  {
    root = "src/presentation/api/presentation_ports",
    forbidden_patterns = {
      "game%.ui_port",
      "ui_port%.get_board_scene",
      "ui_port%.board_scene",
    },
    description = "presentation ports must consume narrow board_scene_port instead of retired ui_port fallbacks",
  },
  {
    root = "src/app",
    forbidden_patterns = {
      "%f[%w_]all_roles%f[^%w_]",
      "%f[%w_]ALLROLES%f[^%w_]",
      "%f[%w_]vehicle_helper%f[^%w_]",
      "%f[%w_]camera_helper%f[^%w_]",
    },
    description = "app layer must not read legacy runtime globals directly; use RuntimePorts/context",
  },
  {
    root = "src/game",
    forbidden_patterns = {
      "%f[%w_]all_roles%f[^%w_]",
      "%f[%w_]ALLROLES%f[^%w_]",
      "%f[%w_]vehicle_helper%f[^%w_]",
      "%f[%w_]camera_helper%f[^%w_]",
    },
    description = "game layer must not read legacy runtime globals directly; use RuntimePorts/context",
  },
  {
    root = "src/presentation",
    forbidden_patterns = {
      "%f[%w_]all_roles%f[^%w_]",
      "%f[%w_]ALLROLES%f[^%w_]",
      "%f[%w_]vehicle_helper%f[^%w_]",
      "%f[%w_]camera_helper%f[^%w_]",
    },
    description = "presentation layer must not read legacy runtime globals directly; use RuntimePorts/context",
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

local growth_budget_rules = {
  {
    description = "src/core host runtime global touch points are frozen until stage 3 runtime extraction",
    roots = { "src/core" },
    patterns = {
      "%f[%w_]GameAPI%f[^%w_]",
      "%f[%w_]GlobalAPI%f[^%w_]",
      "%f[%w_]SetTimeOut%f[^%w_]",
      "%f[%w_]RegisterTriggerEvent%f[^%w_]",
      "%f[%w_]RegisterCustomEvent%f[^%w_]",
    },
    budget = {
      ["src/core/Logger.lua"] = 0,
      ["src/core/RuntimeContext.lua"] = 0,
      ["src/core/RuntimeEditorExports.lua"] = 0,
      ["src/core/RuntimeEnvBindings.lua"] = 0,
      ["src/core/runtime_ports/DefaultPorts.lua"] = 0,
    },
  },
  {
    description = "gameplay/runtime modules must not add new game.ui_port dependency points before stage 2 port extraction",
    roots = { "src/game", "src/core" },
    patterns = {
      "game%.ui_port",
      "self%.ui_port",
      "ui_port%.wait_action_anim",
      "ui_port%.wait_move_anim",
      "ui_port:push_popup",
      "ui_port%.push_popup",
      "ui_port%.state",
    },
    budget = {
      ["src/core/ActionAnimPort.lua"] = 0,
      ["src/game/core/runtime/Bankruptcy.lua"] = 0,
      ["src/game/core/runtime/GameStateTiles.lua"] = 0,
      ["src/game/flow/intent/IntentDispatcher.lua"] = 0,
      ["src/game/flow/turn/GameplayLoop.lua"] = 0,
      ["src/game/flow/turn/TurnDecision.lua"] = 0,
      ["src/game/flow/turn/TurnMove.lua"] = 0,
      ["src/game/flow/turn/TurnRoll.lua"] = 0,
      ["src/game/systems/items/ItemInventory.lua"] = 0,
      ["src/game/systems/items/ItemPhase.lua"] = 0,
      ["src/game/systems/items/ItemUseBroadcast.lua"] = 0,
      ["src/game/systems/land/LandingPresenter.lua"] = 0,
      ["src/game/systems/land/landing_effects/BaseLandEffects.lua"] = 0,
    },
  },
  {
    description = "turn flow must not add new state.ui_* writes before stage 1 output-port extraction",
    roots = { "src/game/flow" },
    patterns = {
      "state%.ui_[A-Za-z0-9_]+%s*=",
    },
    budget = {},
  },
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

local function _to_repo_relpath(path)
  local normalized = _normalize_path(path)
  return normalized:match(".*(src/.+)") or normalized:match(".*(tests/.+)") or normalized
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

local function _scan_legacy_policy_usages()
  local roots = { "src", "tests" }
  for _, root in ipairs(roots) do
    local files, err = _collect_lua_files(root)
    if not files then
      if not tostring(err):find("no lua files found under", 1, true) then
        return nil, err
      end
    else
      for _, path in ipairs(files) do
        local normalized = _normalize_path(path)
        local relpath = normalized:match(".*(src/.+)") or normalized:match(".*(tests/.+)") or normalized
        if not relpath:match("tests/internal/dep_rules.lua$") then
          local file = io.open(path, "r")
          if not file then
            return nil, "cannot open: " .. tostring(path)
          end
          local lineno = 0
          for line in file:lines() do
            lineno = lineno + 1
            if line:find("context_policy%s*=%s*\"legacy\"")
              or line:find("context_policy%s*=%s*'legacy'") then
              file:close()
              return {
                path = relpath,
                line = lineno,
                token = "context_policy = legacy",
                text = line,
                description = "legacy context_policy is retired",
              }
            end
            if line:find("enable_legacy_helper_fallback%s*=%s*true") then
              file:close()
              return {
                path = relpath,
                line = lineno,
                token = "enable_legacy_helper_fallback = true",
                text = line,
                description = "legacy helper fallback opt-in is retired",
              }
            end
          end
          file:close()
        end
      end
    end
  end
  return nil
end

local function _count_pattern_hits(line, patterns)
  local total = 0
  for _, pattern in ipairs(patterns or {}) do
    local _, count = line:gsub(pattern, "")
    total = total + count
  end
  return total
end

local function _scan_growth_budget_rule(rule)
  local observed = {}
  for _, root in ipairs(rule.roots or {}) do
    local files, err = _collect_lua_files(root)
    if not files then
      if not tostring(err):find("no lua files found under", 1, true) then
        return nil, err
      end
    else
      for _, path in ipairs(files) do
        local relpath = _to_repo_relpath(path)
        local file = io.open(path, "r")
        if not file then
          return nil, "cannot open: " .. tostring(path)
        end
        local hits = 0
        for line in file:lines() do
          hits = hits + _count_pattern_hits(line, rule.patterns)
        end
        file:close()
        if hits > 0 then
          observed[relpath] = hits
          local budget = rule.budget[relpath] or 0
          if hits > budget then
            return {
              path = relpath,
              line = 1,
              token = "growth_budget",
              text = "observed=" .. tostring(hits) .. " budget=" .. tostring(budget),
              description = rule.description,
            }
          end
          if budget == 0 then
            return {
              path = relpath,
              line = 1,
              token = "growth_budget",
              text = "observed=" .. tostring(hits) .. " budget=0",
              description = rule.description,
            }
          end
        end
      end
    end
  end

  for relpath, budget in pairs(rule.budget or {}) do
    local hits = observed[relpath] or 0
    if hits ~= budget then
      return {
        path = relpath,
        line = 1,
        token = "growth_budget_stale",
        text = "observed=" .. tostring(hits) .. " budget=" .. tostring(budget),
        description = rule.description .. " (update budget after debt shrinks)",
      }
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

local legacy_usage_hit, legacy_usage_err = _scan_legacy_policy_usages()
if legacy_usage_err and not tostring(legacy_usage_err):find("no lua files found under", 1, true) then
  io.stderr:write("dep_rules error: ", legacy_usage_err, "\n")
  os.exit(1)
end
if legacy_usage_hit then
  io.stderr:write("dep_rules violation: ", legacy_usage_hit.path, ":", legacy_usage_hit.line, " contains ", legacy_usage_hit.token, "\n")
  io.stderr:write("rule: ", legacy_usage_hit.description, "\n")
  io.stderr:write(legacy_usage_hit.text, "\n")
  os.exit(1)
end

for _, rule in ipairs(growth_budget_rules) do
  local hit, err = _scan_growth_budget_rule(rule)
  if err and not tostring(err):find("no lua files found under", 1, true) then
    io.stderr:write("dep_rules error: ", err, "\n")
    os.exit(1)
  end
  if hit then
    io.stderr:write("dep_rules violation: ", hit.path, ":", hit.line, " contains ", hit.token, "\n")
    io.stderr:write("rule: ", hit.description, "\n")
    io.stderr:write(hit.text, "\n")
    os.exit(1)
  end
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
