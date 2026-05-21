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

describe("core_logic module-level coverage (re-require sweep)", function()
  it("state.runtime — fires all function definitions under hook", function()
    _refire("src.state.runtime")
  end)

  it("state.visual_hold — fires all function definitions under hook", function()
    _refire("src.state.visual_hold")
  end)

  it("rules.items.post_effects — fires all function definitions under hook", function()
    _refire("src.rules.items.post_effects")
  end)

  it("turn.waits.timeout — fires all function definitions under hook", function()
    _refire("src.turn.waits.timeout")
  end)

  it("rules.choice_handlers.item — fires all function definitions under hook", function()
    _refire("src.rules.choice_handlers.item")
  end)

  it("rules.items.phase — fires all function definitions under hook", function()
    _refire("src.rules.items.phase")
  end)

  it("turn.phases.land — fires all function definitions under hook", function()
    _refire("src.turn.phases.land")
  end)

  it("turn.deadlines — fires all function definitions under hook", function()
    _refire("src.turn.deadlines")
  end)

  it("turn.loop.ports — fires module-level base_ports construction", function()
    _refire("src.turn.loop.ports")
  end)

  it("foundation.log — fires all function definitions under hook", function()
    _refire("src.foundation.log")
  end)

  it("turn.loop (init) — fires module-level setup under hook", function()
    _refire("src.turn.loop")
  end)

  it("app.roster — fires all function definitions under hook", function()
    _refire("src.app.roster")
  end)

  it("rules.items.availability — fires all function definitions under hook", function()
    _refire("src.rules.items.availability")
  end)

  it("rules.land.landing_rules — fires all function definitions under hook", function()
    _refire("src.rules.land.landing_rules")
  end)

  it("rules.land.effect_base — fires all function definitions under hook", function()
    _refire("src.rules.land.effect_base")
  end)

  it("rules.board.direction — fires all function definitions under hook", function()
    _refire("src.rules.board.direction")
  end)
end)
