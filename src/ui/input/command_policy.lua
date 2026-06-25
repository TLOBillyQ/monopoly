local command_policy = {}

local COMMANDS = {
  toggle_action_log = {
    reason = "toggle_action_log",
    view_command = true,
    dispatch_before_game = true,
    panel_id = "action_log",
    requires_event_actor = true,
    actor_source = "local",
    fallback_handler = "toggle_action_log",
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
    fallback_handler = "open_skin_panel",
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
    fallback_handler = "open_gallery_panel",
    port_handler = "open_gallery_panel",
  },
  skin_panel_action = {
    reason = "skin_panel_action",
    view_command = true,
    dispatch_before_game = true,
    requires_event_actor = true,
    actor_source = "local",
    fallback_handler = "skin_panel_action",
    port_handler = "skin_panel_action",
  },
  item_atlas_action = {
    reason = "item_atlas_action",
    view_command = true,
    dispatch_before_game = true,
    requires_event_actor = true,
    actor_source = "local",
    fallback_handler = "item_atlas_action",
    port_handler = "item_atlas_action",
  },
  skin_gallery_action = {
    reason = "skin_gallery_action",
    view_command = true,
    dispatch_before_game = true,
    requires_event_actor = true,
    actor_source = "local",
    fallback_handler = "skin_gallery_action",
    port_handler = "skin_gallery_action",
  },
  market_select = {
    reason = "market_select",
    view_command = true,
    fallback_handler = "market_select",
    port_handler = "market_select",
  },
  popup_confirm = {
    reason = "popup_confirm",
    view_command = true,
    fallback_handler = "popup_confirm",
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

function command_policy.fallback_handler(intent)
  return _read(intent, "fallback_handler")
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
