local defaults = {
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
}

local constants = {}

local function _apply_defaults(target)
  for key, value in pairs(defaults) do
    target[key] = value
  end
end

local function _reset(target)
  for key in pairs(target) do
    target[key] = nil
  end
  _apply_defaults(target)
end

_apply_defaults(constants)

local methods = {
  reset = function()
    _reset(constants)
  end,
}

setmetatable(constants, { __index = methods })

return constants

--[[ mutate4lua-manifest
version=2
projectHash=3d16f7255f22cce5
scope.0.id=chunk:src/config/content/constants.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=f9be789f7af8b643
scope.1.id=function:anonymous@32:32
scope.1.kind=function
scope.1.startLine=32
scope.1.endLine=34
scope.1.semanticHash=4ee118a174818efd
]]
