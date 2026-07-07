-- Static routing table for view/game commands (non-button intents) consumed
-- by command_definitions. Split out of command_definitions.lua to keep each
-- data module under the mutation-site split threshold.

local COMMANDS = {
  toggle_action_log = {
    reason = "toggle_action_log",
    view_command = true,
    dispatch_before_game = true,
    panel_id = "action_log",
    requires_event_actor = true,
    actor_source = "local",
    port_handler = "toggle_action_log",
  },
  open_skin_panel = {
    reason = "open_skin_panel",
    view_command = true,
    dispatch_before_game = true,
    panel_id = "skin",
    requires_event_actor = true,
    actor_source = "local",
    optional_event_actor = true,
    port_handler = "open_skin_panel",
  },
  open_gallery_panel = {
    reason = "open_gallery_panel",
    view_command = true,
    dispatch_before_game = true,
    panel_id = "gallery",
    requires_event_actor = true,
    actor_source = "local",
    optional_event_actor = true,
    port_handler = "open_gallery_panel",
  },
  skin_panel_action = {
    reason = "skin_panel_action",
    view_command = true,
    dispatch_before_game = true,
    requires_event_actor = true,
    actor_source = "local",
    port_handler = "skin_panel_action",
  },
  item_atlas_action = {
    reason = "item_atlas_action",
    view_command = true,
    dispatch_before_game = true,
    requires_event_actor = true,
    actor_source = "local",
    port_handler = "item_atlas_action",
  },
  skin_gallery_action = {
    reason = "skin_gallery_action",
    view_command = true,
    dispatch_before_game = true,
    requires_event_actor = true,
    actor_source = "local",
    port_handler = "skin_gallery_action",
  },
  market_select = {
    reason = "market_select",
    view_command = true,
    port_handler = "market_select",
  },
  popup_confirm = {
    reason = "popup_confirm",
    view_command = true,
    port_handler = "popup_confirm",
  },
  choice_select = {
    reason = "choice_select",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "turn",
  },
  choice_cancel = {
    reason = "choice_cancel",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "turn",
  },
  complete_optional_action_phase = {
    reason = "complete_optional_action_phase",
    game_handler = "basic",
    requires_event_actor = true,
    actor_source = "turn",
  },
  market_confirm = {
    reason = "market_confirm",
    game_handler = "market_confirm",
    requires_event_actor = true,
    actor_source = "turn",
  },
  market_page_prev = {
    reason = "market_page_prev",
    game_handler = "market_page_prev",
    requires_event_actor = true,
    actor_source = "turn",
  },
  market_page_next = {
    reason = "market_page_next",
    game_handler = "market_page_next",
    requires_event_actor = true,
    actor_source = "turn",
  },
  market_tab_select = {
    reason = "market_tab_select",
    game_handler = "market_tab_select",
    requires_event_actor = true,
    actor_source = "turn",
  },
}

return COMMANDS

--[[ mutate4lua-manifest
version=2
projectHash=3ab3fb5fc81c1790
scope.0.id=chunk:src/ui/input/command_definitions_commands.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=122
scope.0.semanticHash=be4c4f7791d1008b
]]
