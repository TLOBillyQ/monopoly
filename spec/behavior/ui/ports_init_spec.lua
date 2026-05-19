describe("src.ui.ports (module-level coverage)", function()
  it("loads all sub-port modules under debug hook", function()
    package.loaded["src.ui.ports.init"] = nil
    local ports = require("src.ui.ports.init")
    assert(type(ports) == "table", "expected table")
  end)
end)
