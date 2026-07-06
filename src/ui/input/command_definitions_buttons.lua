-- Static routing definitions for ui_button intents (per-id overrides plus
-- item-slot and generic fallbacks) consumed by command_definitions. Split out
-- of command_definitions.lua to keep each data module under the mutation-site
-- split threshold.

local UI_BUTTONS = {
  next = {
    reason = "action_button",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "turn",
  },
  auto = {
    reason = "auto_button",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "local",
  },
  cancel = {
    reason = "cancel_button",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "turn",
  },
}

local ITEM_SLOT_BUTTON = {
  reason = "item_slot",
  game_handler = "basic",
  requires_event_actor = true,
  actor_source = "turn",
  item_slot = true,
}

local GENERIC_UI_BUTTON = {
  reason = "ui_button",
  game_handler = "basic",
}

return {
  UI_BUTTONS = UI_BUTTONS,
  ITEM_SLOT_BUTTON = ITEM_SLOT_BUTTON,
  GENERIC_UI_BUTTON = GENERIC_UI_BUTTON,
}

--[[ mutate4lua-manifest
version=2
projectHash=c4ac2f86aca458c1
scope.0.id=chunk:src/ui/input/command_definitions_buttons.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=3c2561114d5842c4
]]
