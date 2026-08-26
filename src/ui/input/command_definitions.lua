-- Facade over the split command-routing data modules so command_policy keeps
-- a single require target. Kept as a pure data module so the policy
-- resolver/accessors stay small and testable.

local COMMANDS = require("src.ui.input.command_definitions_commands")
local buttons = require("src.ui.input.command_definitions_buttons")

return {
  COMMANDS = COMMANDS,
  UI_BUTTONS = buttons.UI_BUTTONS,
  GENERIC_UI_BUTTON = buttons.GENERIC_UI_BUTTON,
}

--[[ mutate4lua-manifest
version=4
projectHash=3368c5116f43eac6
scope.0.id=chunk:src/ui/input/command_definitions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=13
scope.0.semanticHash=eba29ec8ca01c076
]]
