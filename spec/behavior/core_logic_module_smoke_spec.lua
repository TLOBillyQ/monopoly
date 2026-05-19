-- Re-requires key core_logic modules inside it() bodies so the debug hook
-- captures function-definition lines that otherwise fire before any hook.
describe("core_logic module-level coverage (re-require sweep)", function()
  it("state.runtime — fires all function definitions under hook", function()
    package.loaded["src.state.runtime"] = nil
    local m = require("src.state.runtime")
    assert(type(m) == "table", "expected table")
  end)

  it("state.visual_hold — fires all function definitions under hook", function()
    package.loaded["src.state.visual_hold"] = nil
    local m = require("src.state.visual_hold")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.items.post_effects — fires all function definitions under hook", function()
    package.loaded["src.rules.items.post_effects"] = nil
    local m = require("src.rules.items.post_effects")
    assert(type(m) == "table", "expected table")
  end)

  it("turn.waits.timeout — fires all function definitions under hook", function()
    package.loaded["src.turn.waits.timeout"] = nil
    local m = require("src.turn.waits.timeout")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.choice_handlers.item — fires all function definitions under hook", function()
    package.loaded["src.rules.choice_handlers.item"] = nil
    local m = require("src.rules.choice_handlers.item")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.items.phase — fires all function definitions under hook", function()
    package.loaded["src.rules.items.phase"] = nil
    local m = require("src.rules.items.phase")
    assert(type(m) == "table", "expected table")
  end)

  it("turn.phases.land — fires all function definitions under hook", function()
    package.loaded["src.turn.phases.land"] = nil
    local m = require("src.turn.phases.land")
    assert(type(m) == "table", "expected table")
  end)

  it("turn.deadlines — fires all function definitions under hook", function()
    package.loaded["src.turn.deadlines"] = nil
    local m = require("src.turn.deadlines")
    assert(type(m) == "table", "expected table")
  end)

  it("turn.loop.ports — fires module-level base_ports construction", function()
    package.loaded["src.turn.loop.ports"] = nil
    local m = require("src.turn.loop.ports")
    assert(type(m) == "table", "expected table")
  end)

  it("foundation.log — fires all function definitions under hook", function()
    package.loaded["src.foundation.log"] = nil
    local m = require("src.foundation.log")
    assert(type(m) == "table", "expected table")
    -- restore test_mode since the harness expects it
    if type(m.set_test_mode) == "function" then
      m.set_test_mode(true)
    end
  end)

  it("turn.loop (init) — fires module-level setup under hook", function()
    package.loaded["src.turn.loop"] = nil
    local m = require("src.turn.loop")
    assert(type(m) == "table", "expected table")
  end)

  it("app.roster — fires all function definitions under hook", function()
    package.loaded["src.app.roster"] = nil
    local m = require("src.app.roster")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.items.availability — fires all function definitions under hook", function()
    package.loaded["src.rules.items.availability"] = nil
    local m = require("src.rules.items.availability")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.land.landing_rules — fires all function definitions under hook", function()
    package.loaded["src.rules.land.landing_rules"] = nil
    local m = require("src.rules.land.landing_rules")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.land.effect_base — fires all function definitions under hook", function()
    package.loaded["src.rules.land.effect_base"] = nil
    local m = require("src.rules.land.effect_base")
    assert(type(m) == "table", "expected table")
  end)

  it("rules.board.direction — fires all function definitions under hook", function()
    package.loaded["src.rules.board.direction"] = nil
    local m = require("src.rules.board.direction")
    assert(type(m) == "table", "expected table")
  end)
end)
