local definitions = require("src.ui.input.command_definitions")

local command_policy = {}

local COMMANDS = definitions.COMMANDS
local UI_BUTTONS = definitions.UI_BUTTONS
local ITEM_SLOT_BUTTON = definitions.ITEM_SLOT_BUTTON
local GENERIC_UI_BUTTON = definitions.GENERIC_UI_BUTTON

local function _is_item_slot_id(action_id)
  return type(action_id) == "string" and string.match(action_id, "^item_slot_%d+$") ~= nil
end

local function _describe_ui_button(intent)
  local action_id = intent and intent.id
  if UI_BUTTONS[action_id] ~= nil then
    return UI_BUTTONS[action_id]
  end
  if _is_item_slot_id(action_id) then
    return ITEM_SLOT_BUTTON
  end
  return GENERIC_UI_BUTTON
end

function command_policy.describe(intent)
  if type(intent) ~= "table" then
    return nil
  end
  if intent.type == "ui_button" then
    return _describe_ui_button(intent)
  end
  return COMMANDS[intent.type]
end

local function _read(intent, key)
  local command = command_policy.describe(intent)
  return command and command[key] or nil
end

function command_policy.reason(intent)
  return _read(intent, "reason")
end

function command_policy.is_view_command(intent)
  return _read(intent, "view_command") == true
end

function command_policy.dispatches_before_game(intent)
  return _read(intent, "dispatch_before_game") == true
end

function command_policy.panel_id(intent)
  return _read(intent, "panel_id")
end

function command_policy.requires_event_actor(intent)
  return _read(intent, "requires_event_actor") == true
end

function command_policy.uses_local_actor(intent)
  return _read(intent, "actor_source") == "local"
end

function command_policy.is_optional_event_actor(intent)
  return _read(intent, "optional_event_actor") == true
end

function command_policy.port_handler(intent)
  return _read(intent, "port_handler")
end

function command_policy.game_handler(intent)
  return _read(intent, "game_handler")
end

function command_policy.is_item_slot_command(intent)
  return _read(intent, "item_slot") == true
end

return command_policy

--[[ mutate4lua-manifest
version=2
projectHash=329ba815138e1cc6
scope.0.id=chunk:src/ui/input/command_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=01cbdd269d32a426
scope.1.id=function:_is_item_slot_id:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=2da4f54737cb85bc
scope.2.id=function:_describe_ui_button:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=23
scope.2.semanticHash=efcad8c736d0b25a
scope.3.id=function:command_policy.describe:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=33
scope.3.semanticHash=bbbb0361deecf767
scope.4.id=function:_read:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=38
scope.4.semanticHash=01d675ba58c80000
scope.5.id=function:command_policy.reason:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=42
scope.5.semanticHash=050cbc707571053b
scope.6.id=function:command_policy.is_view_command:44
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=46
scope.6.semanticHash=2d6c6c06c7089248
scope.7.id=function:command_policy.dispatches_before_game:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=50
scope.7.semanticHash=5e9290ca4eaacd37
scope.8.id=function:command_policy.panel_id:52
scope.8.kind=function
scope.8.startLine=52
scope.8.endLine=54
scope.8.semanticHash=49599835f603b2f3
scope.9.id=function:command_policy.requires_event_actor:56
scope.9.kind=function
scope.9.startLine=56
scope.9.endLine=58
scope.9.semanticHash=9548669ac626500b
scope.10.id=function:command_policy.uses_local_actor:60
scope.10.kind=function
scope.10.startLine=60
scope.10.endLine=62
scope.10.semanticHash=5fc840ac207b6e6d
scope.11.id=function:command_policy.is_optional_event_actor:64
scope.11.kind=function
scope.11.startLine=64
scope.11.endLine=66
scope.11.semanticHash=6f913880403724ec
scope.12.id=function:command_policy.fallback_handler:68
scope.12.kind=function
scope.12.startLine=68
scope.12.endLine=70
scope.12.semanticHash=f8f1c9bbfe76c68d
scope.13.id=function:command_policy.port_handler:72
scope.13.kind=function
scope.13.startLine=72
scope.13.endLine=74
scope.13.semanticHash=e9152f2dd64e1aa7
scope.14.id=function:command_policy.game_handler:76
scope.14.kind=function
scope.14.startLine=76
scope.14.endLine=78
scope.14.semanticHash=f467ef71d5fe3d05
scope.15.id=function:command_policy.is_item_slot_command:80
scope.15.kind=function
scope.15.startLine=80
scope.15.endLine=82
scope.15.semanticHash=3df955cb458a5dd8
]]
