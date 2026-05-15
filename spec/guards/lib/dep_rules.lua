require("spec.bootstrap").install_package_paths()

local guard_support = require("spec.support.guards.guard_support")

local rules = {
  {
    roots = { "src/ui" },
    forbidden = { "shared.UINodes" },
    description = "no module may depend on retired shared.UINodes",
  },
  {
    roots = { "src/ui", "src/app" },
    forbidden_patterns = {
      'require%("src%.state%.runtime_state"%)',
      "require%('src%.state%.runtime_state'%)",
      'require%("src%.state%.landing_visual_hold"%)',
      "require%('src%.state%.landing_visual_hold'%)",
    },
    description = "presentation modules must consume runtime state through seam adapters",
  },
  {
    roots = { "src/ui", "src/app" },
    forbidden_patterns = {
      'require%("src%.host%.eggy',
      "require%('src%.host%.eggy",
    },
    description = "presentation modules must consume host runtime through explicit adapters or bootstrap files",
  },
  {
    roots = { "src/ui" },
    forbidden = { "intent_builders" },
    description = "no module may depend on retired intent_builders",
  },
  {
    roots = { "src/state" },
    forbidden = { "TurnFlow" },
    description = "runtime must not depend on retired TurnFlow",
  },
  {
    roots = { "src/ui/schema" },
    forbidden = {
      "canvas.permanent", "canvas.market", "canvas.secondary_confirm",
      "canvas.remote_choice", "canvas.player_choice", "canvas.popup",
      "canvas.target_choice",
    },
    description = "base canvas must not import other canvas modules",
  },
  {
    roots = { "src/state", "src/player", "src/computer", "src/rules" },
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
    roots = { "src/state", "src/ui", "tests" },
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
    roots = { "src", "tests", "tools" },
    forbidden_patterns = {
      "require%(\"Config%..+\"%)",
      "require%('Config%..+'%)",
      "require%(\"Config/.+\"%)",
      "require%('Config/.+'%)",
      "require%(\"src%.core%.config%..+\"%)",
      "require%('src%.core%.config%..+'%)",
      "require%(\"src/core/config/.+\"%)",
      "require%('src/core/config/.+'%)",
    },
    description = "Config/src.core.config compatibility require paths are retired; use src.config.*",
  },
  {
    roots = { "src", "tests", "tools" },
    forbidden_patterns = {
      "require%(\"src%.rules%.choices%..+\"%)",
      "require%('src%.rules%.choices%..+'%)",
      "require%(\"src%.state%.player_state_ops%..+\"%)",
      "require%('src%.state%.player_state_ops%..+'%)",
      "require%(\"src%.state%.support%..+\"%)",
      "require%('src%.state%.support%..+'%)",
      "require%(\"src%.core%.state_access%..+\"%)",
      "require%('src%.core%.state_access%..+'%)",
      "require%(\"src%.host%.eggy%.support%.runtime_constants\"%)",
      "require%('src%.host%.eggy%.support%.runtime_constants'%)",
      "require%(\"src%.host%.eggy%.support%.runtime_editor_exports\"%)",
      "require%('src%.host%.eggy%.support%.runtime_editor_exports'%)",
      "require%(\"src%.host%.eggy%.support%.runtime_refs\"%)",
      "require%('src%.host%.eggy%.support%.runtime_refs'%)",
      "require%(\"src%.state%.compose_game\"%)",
      "require%('src%.state%.compose_game'%)",
      "require%(\"src%.state%.game_victory\"%)",
      "require%('src%.state%.game_victory'%)",
       "require%(\"src%.computer%.policies%..+\"%)",
        "require%('src%.computer%.policies%..+'%)",
      "require%(\"src%.turn%.output%.decision\"%)",
      "require%('src%.turn%.output%.decision'%)",
      "require%(\"src%.turn%.output%.logger\"%)",
      "require%('src%.turn%.output%.logger'%)",
      "require%(\"src%.turn%.output%.loop_runtime\"%)",
      "require%('src%.turn%.output%.loop_runtime'%)",
      "require%(\"src%.turn%.output%.ports\"%)",
      "require%('src%.turn%.output%.ports'%)",
      "require%(\"src%.turn%.output%.scheduler_runtime\"%)",
      "require%('src%.turn%.output%.scheduler_runtime'%)",
      "require%(\"src%.turn%.output%.session_script\"%)",
      "require%('src%.turn%.output%.session_script'%)",
      "require%(\"src%.turn%.output%.tick_flow\"%)",
      "require%('src%.turn%.output%.tick_flow'%)",
      "require%(\"src%.turn%.output%.tick_steps\"%)",
      "require%('src%.turn%.output%.tick_steps'%)",
    },
    description = "retired shim require paths are forbidden; use canonical modules directly",
  },
  {
    roots = { "src", "tests/suites/architecture" },
    forbidden_patterns = {
      "%f[%w_]invalidate_ui%f[^%w_]",
      "compatibility%s+alias",
      "compatibility%s+contract",
      "legacy%s+alias",
      "alias%s+entry",
      "alias%s+fallback",
      "shim%s+entry",
      "shim%s+fallback",
      "pre_move.-window",
      "pre_move.-窗口",
    },
    description = "business layers must not reintroduce retired invalidate_ui / alias / shim / compat wording or active-window pre_move phrasing",
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
    roots = { "src/rules" },
    forbidden_patterns = {
      "ui_port%.wait_action_anim",
      "game%.ui_port%.wait_action_anim",
    },
    description = "systems layer must use ActionAnimPort instead of direct ui_port.wait_action_anim checks",
  },
  {
    roots = { "src/rules" },
    forbidden_patterns = {
      "game%.gameplay_loop_ports",
      "self%.gameplay_loop_ports",
      "require%(%\"src%.game%.flow%.turn%.loop_ports%\"%)",
      "require%(%'src%.game%.flow%.turn%.loop_ports'%)",
    },
    description = "systems layer must not read gameplay loop runtime object fields directly or depend on loop_ports",
  },
  {
    roots = { "src/turn" },
    forbidden_patterns = {
      "state%.ui%.",
      "state%.ui_[A-Za-z0-9_]+%s*=",
    },
    description = "turn flow must route UI reads and writes through output/ui_sync ports",
  },
  {
    roots = { "src/turn/timing" },
    forbidden_patterns = {
      "require%(\"src%.game%.flow%..+\"%)",
      "require%('src%.game%.flow%..+'%)",
    },
    description = "scheduler must stay as a pure coroutine scheduler and not depend on flow modules",
  },
  {
    roots = { "src", "tests", "tools", "main.lua" },
    forbidden_patterns = {
      "require%(\"src%.entry",
      "require%('src%.entry"
    },
    description = "src.entry namespace is retired; require canonical bootstrap modules instead",
  },
  {
    roots = { "src/state" },
    forbidden_patterns = {
      "require%(\"src%.turn%.output%..+\"%)",
      "require%('src%.turn%.output%..+'%)",
    },
    description = "state must not depend on turn output adapters directly",
  },
  {
    roots = { "src/rules/market" },
    forbidden_patterns = {
      "require%(\"src%.rules%.land%.choice_specs\"%)",
      "require%('src%.rules%.land%.choice_specs'%)",
    },
    description = "market subsystem must not depend on land choice specs",
  },
  {
    roots = { "src/rules/items" },
    forbidden_patterns = {
      "require%(\"src%.rules%.land%.board_utils\"%)",
      "require%('src%.rules%.land%.board_utils'%)",
      "require%(\"src%.rules%.land%.rent_resolver\"%)",
      "require%('src%.rules%.land%.rent_resolver'%)",
    },
    description = "items subsystem must use neutral board/property helpers instead of land internals",
  },
  {
    roots = { "src/rules/market" },
    forbidden_patterns = {
      "%f[%w_]GameAPI%f[^%w_]",
      "%f[%w_]RegisterTriggerEvent%f[^%w_]",
      "%f[%w_]EVENT%f[^%w_]",
    },
    description = "market service layer must not call host purchase globals directly",
  },
  {
    roots = { "src/ui/ctl/ports" },
    forbidden_patterns = {
      "game%.ui_port",
      "ui_port%.get_board_scene",
      "ui_port%.board_scene",
    },
    description = "presentation ports must consume narrow board_scene_port instead of retired ui_port fallbacks",
  },
  {
    roots = { "src/turn", "src/ui", "src/player", "src/computer", "src/rules" },
    forbidden_patterns = {
      "%f[%w_]all_roles%f[^%w_]",
      "%f[%w_]ALLROLES%f[^%w_]",
      "%f[%w_]camera_helper%f[^%w_]",
    },
    description = "game/presentation layers must not read legacy runtime globals directly",
  },
  {
    roots = { "src/turn/actions", "src/turn/policies", "src/ui" },
    forbidden_patterns = {
      "cfg%.timing%s*==",
      "cfg%.timing%s*~=",
      "item%.timing%s*==",
      "item%.timing%s*~=",
    },
    description = "turn/ui layers must not read item timing config directly; use rules/items availability use-case",
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

local dep_rules_whitelist = {}

dep_rules_whitelist["src/ui/state/runtime.lua"] = {
  ['require("src.state.runtime")'] = true,
}

dep_rules_whitelist["src/ui/visual_hold.lua"] = {
  ['require("src.state.visual_hold")'] = true,
}

dep_rules_whitelist["src/ui/landing_visual_hold.lua"] = {
  ['require("src.state.landing_visual_hold")'] = true,
}

dep_rules_whitelist["src/ui/host_bridge.lua"] = {
  ['require("src.host")'] = true,
}

dep_rules_whitelist["src/host/global_aliases.lua"] = {
  ["bridge exception, not a business compatibility alias layer."] = true,
}

dep_rules_whitelist["src/app/ui_bootstrap.lua"] = {
  ['require("src.host.context")'] = true,
}

local forbidden_files = {
  "src/entry.lua",
  "src/turn/output/legacy_output_mirror.lua",
  "src/rules/market/service/paid_purchase_gateway.lua",
  "src/core/runtime_facade/runtime_context.lua",
  "src/core/runtime_ports/default_ports.lua",
  "src/rules/choices/handlers/optional_effect.lua",
  "src/rules/choices/registry.lua",
  "src/rules/choices/resolver.lua",
  "src/rules/choices/use_skip_choice.lua",
  "src/state/player_state_ops/balance_ops.lua",
  "src/state/player_state_ops/deity_ops.lua",
  "src/state/player_state_ops/location_ops.lua",
  "src/state/player_state_ops/status_ops.lua",
  "src/state/support/logger.lua",
  "src/state/support/number_utils.lua",
  "src/core/state_access/landing_visual_hold.lua",
  "src/core/state_access/runtime_editor_exports.lua",
  "src/core/state_access/runtime_state.lua",
  "src/core/state_access/ui_role_globals.lua",
  "src/host/support/runtime_constants.lua",
  "src/host/support/runtime_editor_exports.lua",
  "src/host/support/runtime_refs.lua",
  "src/turn/output/decision.lua",
  "src/turn/output/logger.lua",
  "src/turn/output/loop_runtime.lua",
  "src/turn/output/ports.lua",
  "src/turn/output/scheduler_runtime.lua",
  "src/turn/output/session_script.lua",
  "src/turn/output/tick_flow.lua",
  "src/turn/output/tick_steps.lua",
  "src/state/compose_game.lua",
  "src/state/game_victory.lua",
  "src/state/state_access/runtime_editor_exports.lua",
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

  return { ok = true, message = "dep_rules ok" }
end

function M.main()
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

  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
