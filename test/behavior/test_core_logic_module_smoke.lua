-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
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
  assert.is_table(m, "expected table for " .. name)
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
  { "src.turn.waits.choice_timeout" },
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

describe("TestCoreLogicModuleSmoke", function()
  local loaded_before_case
  before_each(function()
    loaded_before_case = {}
    for name, object in pairs(package.loaded) do
      if name:match("^src%.") then loaded_before_case[name] = object end
    end
  end)
  after_each(function()
    for name in pairs(package.loaded) do
      if name:match("^src%.") and loaded_before_case[name] == nil then package.loaded[name] = nil end
    end
    for name, object in pairs(loaded_before_case) do package.loaded[name] = object end
  end)


for _, case in ipairs(_CASES) do
  it("test_" .. _label(case), function()
    _refire(case[1])
  end)
end


end)
