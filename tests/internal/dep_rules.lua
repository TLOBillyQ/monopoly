package.path = package.path .. ";./tests/?.lua"

local guard_support = require("internal.guard_support")

local rules = {
  {
    roots = { "src/presentation" },
    forbidden = { "shared.UINodes" },
    description = "no module may depend on retired shared.UINodes",
  },
  {
    roots = { "src/presentation" },
    forbidden = { "intent_builders" },
    description = "no module may depend on retired intent_builders",
  },
  {
    roots = { "src/game/core/runtime" },
    forbidden = { "TurnFlow" },
    description = "runtime must not depend on retired TurnFlow",
  },
  {
    roots = { "src/presentation/view/canvas/base" },
    forbidden = {
      "canvas.always_show", "canvas.market", "canvas.secondary_confirm",
      "canvas.remote_choice", "canvas.player_choice", "canvas.popup",
      "canvas.target_choice",
    },
    description = "base canvas must not import other canvas modules",
  },
  {
    roots = { "src/game/core" },
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
    roots = { "src/core" },
    forbidden_patterns = {
      "%f[%w_]GameAPI%f[^%w_]",
      "%f[%w_]GlobalAPI%f[^%w_]",
      "%f[%w_]SetTimeOut%f[^%w_]",
      "%f[%w_]RegisterTriggerEvent%f[^%w_]",
      "%f[%w_]RegisterCustomEvent%f[^%w_]",
    },
    description = "core utility layer must not use host runtime globals directly",
  },
  {
    roots = { "src/game/core", "src/app", "src/presentation", "tests" },
    forbidden_patterns = {
      "require%(\"src%.core%.runtime_compat\"%)",
      "require%('src%.core%.runtime_compat'%)",
    },
    description = "runtime_compat bridge path is retired; use runtime ports or injected context",
  },
  {
    roots = { "src", "tests" },
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.TurnEngine\"%)",
      "require%('src%.game%.core%.runtime%.TurnEngine'%)",
      "require%(\"src%.game%.core%.runtime%.PhaseRegistry\"%)",
      "require%('src%.game%.core%.runtime%.PhaseRegistry'%)",
    },
    description = "TurnEngine/PhaseRegistry proxy modules are retired",
  },
  {
    roots = { "src", "tests" },
    forbidden_patterns = {
      "require%(\"src%.game%.core%.runtime%.MonopolyEvents\"%)",
      "require%('src%.game%.core%.runtime%.MonopolyEvents'%)",
    },
    description = "MonopolyEvents proxy module is retired",
  },
  {
    roots = { "src" },
    forbidden_patterns = {
      "clock%.now%(",
      "clock%.diff_seconds%(",
    },
    description = "source must not use retired clock.now/diff_seconds aliases",
  },
  {
    roots = { "src/game/systems" },
    forbidden_patterns = {
      "ui_port%.wait_action_anim",
      "game%.ui_port%.wait_action_anim",
    },
    description = "systems layer must use ActionAnimPort instead of direct ui_port.wait_action_anim checks",
  },
  {
    roots = { "src/game/systems" },
    forbidden_patterns = {
      "game%.gameplay_loop_ports",
      "self%.gameplay_loop_ports",
      "require%(%\"src%.game%.flow%.turn%.loop_ports%\"%)",
      "require%(%'src%.game%.flow%.turn%.loop_ports'%)",
    },
    description = "systems layer must not read gameplay loop runtime object fields directly or depend on loop_ports",
  },
  {
    roots = { "src/game/flow/turn" },
    forbidden_patterns = {
      "state%.ui%.",
      "state%.ui_[A-Za-z0-9_]+%s*=",
    },
    description = "turn flow must route UI reads and writes through output/ui_sync ports",
  },
  {
    roots = { "src/game/systems/market/application" },
    forbidden_patterns = {
      "%f[%w_]GameAPI%f[^%w_]",
      "%f[%w_]RegisterTriggerEvent%f[^%w_]",
      "%f[%w_]EVENT%f[^%w_]",
    },
    description = "market service layer must not call host purchase globals directly",
  },
  {
    roots = { "src/presentation/runtime/ports" },
    forbidden_patterns = {
      "game%.ui_port",
      "ui_port%.get_board_scene",
      "ui_port%.board_scene",
    },
    description = "presentation ports must consume narrow board_scene_port instead of retired ui_port fallbacks",
  },
  {
    roots = { "src/game", "src/presentation" },
    forbidden_patterns = {
      "%f[%w_]all_roles%f[^%w_]",
      "%f[%w_]ALLROLES%f[^%w_]",
      "%f[%w_]vehicle_helper%f[^%w_]",
      "%f[%w_]camera_helper%f[^%w_]",
    },
    description = "game/presentation layers must not read legacy runtime globals directly",
  },
  {
    roots = { "src", "tests" },
    forbidden_patterns = {
      "context_policy%s*=%s*\"legacy\"",
      "context_policy%s*=%s*'legacy'",
      "enable_legacy_helper_fallback%s*=%s*true",
    },
    description = "legacy runtime context fallback flags are retired",
  },
}

local dep_rules_whitelist = {
  ["src/game/core/runtime/composition_root.lua"] = {
    ["src.game.flow.turn.engine"] = true,
    ["src.game.flow.turn.phase_registry"] = true,
  },
}

local forbidden_files = {
  "src/game/flow/output_adapters/legacy_output_mirror.lua",
  "src/game/systems/market/service/paid_purchase_gateway.lua",
  "src/core/runtime_facade/runtime_context.lua",
  "src/core/runtime_facade/runtime_event_bridge.lua",
  "src/core/runtime_ports/default_ports.lua",
}

local function _is_whitelisted_line(relpath, line)
  local allow_by_file = dep_rules_whitelist[relpath]
  if allow_by_file == nil then
    return false
  end
  for snippet in pairs(allow_by_file) do
    if line:find(snippet, 1, true) then
      return true
    end
  end
  return false
end

local function _scan_rule(rule)
  return guard_support.find_line_violation({
    roots = rule.roots,
    find_violation = function(path, relpath, line, line_number)
      if _is_whitelisted_line(relpath, line) then
        return nil
      end

      for _, token in ipairs(rule.forbidden or {}) do
        if line:find(token, 1, true) then
          return {
            path = relpath,
            line = line_number,
            token = token,
            text = line,
            description = rule.description,
          }
        end
      end

      for _, pattern in ipairs(rule.forbidden_patterns or {}) do
        if line:find(pattern) then
          return {
            path = relpath,
            line = line_number,
            token = pattern,
            text = line,
            description = rule.description,
          }
        end
      end

      return nil
    end,
  })
end

local function _check_forbidden_files(paths)
  for _, path in ipairs(paths or {}) do
    local file = io.open(path, "r")
    if file then
      file:close()
      return {
        path = path,
        line = 1,
        token = "forbidden_file",
        text = path,
        description = "forbidden file exists",
      }
    end
  end
  return nil
end

local M = {}

function M.run(opts)
  opts = opts or {}
  local active_rules = opts.rules or rules
  for _, rule in ipairs(active_rules) do
    local hit, err = _scan_rule(rule)
    if err and not tostring(err):find("no lua files found under", 1, true) then
      return { ok = false, error = err }
    end
    if hit then
      return { ok = false, violation = hit }
    end
  end

  local forbidden_file_hit = _check_forbidden_files(opts.forbidden_files or forbidden_files)
  if forbidden_file_hit then
    return { ok = false, violation = forbidden_file_hit }
  end

  return { ok = true }
end

local function _main()
  local result = M.run()
  if result.error then
    io.stderr:write("dep_rules error: ", result.error, "\n")
    os.exit(1)
  end
  if result.violation then
    if result.violation.token == "forbidden_file" then
      io.stderr:write("dep_rules violation: forbidden file exists: ", result.violation.path, "\n")
      os.exit(1)
    end
    io.stderr:write(
      "dep_rules violation: ",
      result.violation.path,
      ":",
      tostring(result.violation.line),
      " contains ",
      result.violation.token,
      "\n"
    )
    io.stderr:write("rule: ", result.violation.description, "\n")
    io.stderr:write(result.violation.text, "\n")
    os.exit(1)
  end

  print("dep_rules ok")
end

if ... == nil then
  _main()
else
  return M
end
