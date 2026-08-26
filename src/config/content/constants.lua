local resettable_defaults = require("src.foundation.resettable_defaults")

return resettable_defaults.build({
  starting_cash = 100000,
  default_dice_count = 1,
  action_timeout_seconds = 15,
  pass_start_bonus = 2000,
  hospital_fee = 5000,
  hospital_stay_turns = 2,
  mountain_stay_turns = 2,
  tax_rate = 0.5,
  inventory_slots = 5,
  deity_duration_turns = 10,
})

--[[ mutate4lua-manifest
version=4
projectHash=4cd428256bdf6506
scope.0.id=chunk:src/config/content/constants.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=15
scope.0.semanticHash=2cb8c16f354fa053
]]
