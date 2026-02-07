local function _run(path)
  print("Running " .. path)
  dofile(path)
end

_run(".agents/tests/regression.lua")
_run(".agents/tests/contracts/intent_dispatcher.lua")
_run(".agents/tests/contracts/turn_choice_protocol.lua")
_run(".agents/tests/contracts/ui_router_resilience.lua")
_run(".agents/tests/contracts/bankruptcy_idempotent.lua")
_run(".agents/tests/contracts/board_determinism.lua")
_run(".agents/tests/contracts/runtime_context_boot.lua")

print("All tests passed")
