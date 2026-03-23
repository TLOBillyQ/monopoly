local contract_helper = require("src.rules.ports.contract_helper")

local tip_output = {}

function tip_output.enqueue(game, intent)
  return contract_helper.call_optional_method(game, "tip_output_port", "enqueue", {
    default_result = false,
  }, game, intent)
end

return tip_output
