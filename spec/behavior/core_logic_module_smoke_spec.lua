-- Re-requires key core_logic modules inside it() bodies so the debug hook
-- captures function-definition lines that otherwise fire before any hook.
-- The original package.loaded entry is restored after each re-require so the
-- new (hook-captured) table does not leak to other specs that hold lexically
-- captured references to the original module.
local function _refire(name)
  local saved = package.loaded[name]
  package.loaded[name] = nil
  local m = require(name)
  package.loaded[name] = saved
  assert(type(m) == "table", "expected table for " .. name)
  return m
end

-- Each entry is { module_path[, override_label] }. The default label is
-- "<rel> — fires all function definitions under hook" where <rel> is the
-- module path with the "src." prefix stripped. Two cases use override labels
-- to keep wording the coder fix established.
local _DEFAULT_HOOK_SUBJECT = "fires all function definitions under hook"
local _CASES = {
  { "src.state.runtime" },
  { "src.state.visual_hold" },
  { "src.rules.items.post_effects" },
  { "src.turn.waits.timeout" },
  { "src.rules.choice_handlers.item" },
  { "src.rules.items.phase" },
  { "src.turn.phases.land" },
  { "src.turn.deadlines" },
  { "src.turn.loop.ports", "turn.loop.ports — fires module-level base_ports construction" },
  { "src.foundation.log" },
  { "src.turn.loop", "turn.loop (init) — fires module-level setup under hook" },
  { "src.app.roster" },
  { "src.rules.items.availability" },
  { "src.rules.land.landing_rules" },
  { "src.rules.land.effect_base" },
  { "src.rules.board.direction" },
}

local function _label(case)
  if case[2] then return case[2] end
  local rel = case[1]:gsub("^src%.", "")
  return rel .. " — " .. _DEFAULT_HOOK_SUBJECT
end

describe("core_logic module-level coverage (re-require sweep)", function()
  for _, case in ipairs(_CASES) do
    it(_label(case), function()
      _refire(case[1])
    end)
  end
end)
