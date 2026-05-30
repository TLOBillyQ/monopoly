local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq

describe("ui.schema.debug", function()
  it("uses event-log screen node names", function()
    package.loaded["src.ui.schema.debug"] = nil
    local debug_nodes = require("src.ui.schema.debug")
    _assert_eq(debug_nodes.canvas, "日志屏", "canvas node should use event-log label")
    _assert_eq(debug_nodes.log_text, "日志", "log text node should stay stable")
  end)
end)
