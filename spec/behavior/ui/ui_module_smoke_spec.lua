-- Re-requires key ui_surface modules inside it() bodies so the debug hook
-- captures function-definition lines that otherwise fire before any hook.
describe("ui_surface module-level coverage (re-require sweep)", function()
  it("ui.state.runtime — fires all function definitions under hook", function()
    package.loaded["src.ui.state.runtime"] = nil
    local m = require("src.ui.state.runtime")
    assert(type(m) == "table", "expected table")
  end)

  it("ui.render.move_anim.stop — fires all function definitions under hook", function()
    package.loaded["src.ui.render.move_anim.stop"] = nil
    local m = require("src.ui.render.move_anim.stop")
    assert(type(m) == "table", "expected table")
  end)

  it("ui.coord.skin_panel — fires all function definitions under hook", function()
    package.loaded["src.ui.coord.skin_panel"] = nil
    local m = require("src.ui.coord.skin_panel")
    assert(type(m) == "table", "expected table")
  end)

  it("ui.input.dispatch.view_command — fires all function definitions under hook", function()
    package.loaded["src.ui.input.view_command"] = nil
    local m = require("src.ui.input.view_command")
    assert(type(m) == "table", "expected table")
  end)

  it("ui.render.board_feedback.service — fires all function definitions under hook", function()
    package.loaded["src.ui.render.board_feedback.service"] = nil
    local m = require("src.ui.render.board_feedback.service")
    assert(type(m) == "table", "expected table")
  end)
end)
