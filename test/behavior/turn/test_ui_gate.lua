local lu = require("luaunit")
local ui_gate = require("src.turn.policies.ui_gate")

-- 这个接缝是 validator_gate 与 auto_context 共用的：ui_sync 端口在无头车道
-- （以及 no-UI gameplay guard）下不存在，两边都必须退化为「没有 gate」。
TestUiGate = {}

function TestUiGate:test_asks_the_port_for_the_gate_when_one_is_installed()
  local seen_state = nil
  local gate = ui_gate.resolve({ tag = "state" }, {
    resolve_ui_gate = function(state)
      seen_state = state
      return { blocked = true }
    end,
  })
  lu.assertEquals(gate, { blocked = true })
  lu.assertEquals(seen_state, { tag = "state" })
end

function TestUiGate:test_returns_nil_when_no_ui_sync_ports_are_installed()
  lu.assertNil(ui_gate.resolve({}, nil))
end

function TestUiGate:test_returns_nil_when_the_port_exists_but_has_no_resolve_ui_gate()
  lu.assertNil(ui_gate.resolve({}, {}))
end

function TestUiGate:test_returns_nil_when_resolve_ui_gate_is_not_callable()
  lu.assertNil(ui_gate.resolve({}, { resolve_ui_gate = "not a function" }))
end


return TestUiGate
