-- base_screen step-handler support: render-state, intent, and completion flow.
--
-- Behavior-preserving split of base_screen.lua's support layer. This module
-- owns the render-state construction, ui-model build, panel refresh, route
-- intent construction, action / end-button triggering, optional-action
-- completion, and end-button assertions. It builds on the lower-level
-- role / game / state helpers owned by base_screen/context.lua (required
-- here as `context`) plus direct Eggy / host requires, so the support layer
-- stays acyclic: context.lua never requires this module.

local ui_state = require("src.ui.coord.ui_state")
local panel_presenter = require("src.ui.render.widgets.presenter")
local route_base = require("src.ui.input.route_base")
local optional_action_completion = require("src.turn.optional_action_completion")

local context = require("acceptance.steps.base_screen.context")
local base_nodes = context.base_nodes
local panel_slice = context.panel_slice

local render_flow_context = {}

function render_flow_context.make_runtime(role_id)
  local role = { id = role_id }
  return {
    set_client_role = function() end,
    resolve_role_id = function(target_role)
      return target_role and target_role.id or nil
    end,
    for_each_role_or_global = function(callback)
      callback(role)
    end,
    query_node = function()
      return {}
    end,
    set_node_texture_native_size = function() end,
  }
end

function render_flow_context.make_render_state(world)
  local state = { ui = ui_state.build_ui_state() }
  state.ui_refs = { images = { Empty = "EMPTY" } }
  state.ui.labels = {}
  state.ui.buttons = {}
  state.ui.visibility = {}
  state.ui.touch = {}
  state.ui.input_blocked = world and world.base_screen_input_blocked == true or false
  state.ui.popup_active = world and world.base_screen_buy_property_open == true or false
  state.ui.set_label = function(self, name, text)
    self.labels[name] = text
  end
  state.ui.set_button = function(self, name, text)
    self.buttons[name] = text
  end
  state.ui.set_visible = function(self, name, value)
    self.visibility[name] = value
  end
  state.ui.set_touch_enabled = function(self, name, enabled)
    self.touch[name] = enabled
  end
  state.ui.query_node = function()
    return {}
  end
  return state
end

function render_flow_context.build_ui_model(world)
  local game = context.make_game()
  local action_role_id = context.current_action_role_id(world)
  local panel_role_id = action_role_id or context.role_id(world)
  local auto_enabled_by_player = context.make_auto_enabled_by_player(world)
  local item_slots_by_player = {}
  if world.base_screen_viewer_is_spectator ~= true then
    item_slots_by_player[context.role_id(world)] = {}
  end
  if action_role_id ~= nil then
    item_slots_by_player[action_role_id] = {}
  end
  return {
    current_player_id = action_role_id,
    auto_enabled_by_player = auto_enabled_by_player,
    board = { players = game.players },
    item_slots_by_player = item_slots_by_player,
    choice = context.optional_choice_for_world(world, action_role_id),
    panel = panel_slice.build(
      game,
      { game = { board = {} } },
      { turn_count = 1, countdown_seconds = 0 },
      panel_role_id,
      auto_enabled_by_player
    ),
  }
end

function render_flow_context.refresh_base_screen_for_player(world)
  world.base_screen_render_state = render_flow_context.make_render_state(world)
  world.base_screen_ui_model = render_flow_context.build_ui_model(world)
  world.base_screen_render_state.ui_runtime = {
    ui_model = world.base_screen_ui_model,
  }
  panel_presenter.refresh(world.base_screen_render_state, world.base_screen_ui_model, {
    runtime = render_flow_context.make_runtime(context.role_id(world)),
    refresh_item_slots = function() end,
  })
  return world.base_screen_render_state
end

function render_flow_context.find_base_route(state, node_name)
  for _, spec in ipairs(route_base.build(state)) do
    if spec.name == node_name then
      return spec
    end
  end
  return nil
end

function render_flow_context.build_base_intent(world, node_name)
  if world.base_screen_render_state == nil then
    render_flow_context.refresh_base_screen_for_player(world)
  end
  local spec = render_flow_context.find_base_route(world.base_screen_render_state, node_name)
  if spec == nil or type(spec.build_intent) ~= "function" then
    return nil
  end
  return spec.build_intent()
end

function render_flow_context.trigger_action_button(world)
  local intent = render_flow_context.build_base_intent(world, base_nodes.action_button)
  world.base_screen_action_button_triggered = true
  world.base_screen_action_button_intent = intent
  if intent and intent.type == "ui_button" and intent.id == "next" then
    world.base_screen_required_flow_started = true
    world.base_screen_dice_rolled = true
    world.base_screen_move_completed = true
  end
  return intent
end

function render_flow_context.mark_optional_completed(world, intent)
  world.base_screen_optional_completed = true
  world.base_screen_pending_choice_cleared = true
  world.base_screen_followup_flow = context.resolve_followup_flow(world)
  world.base_screen_end_button_intent = intent or world.base_screen_end_button_intent
  if world.base_screen_ui_model then
    world.base_screen_ui_model.choice = nil
  end
  local ui_model = world.base_screen_render_state
    and world.base_screen_render_state.ui_runtime
    and world.base_screen_render_state.ui_runtime.ui_model
  if ui_model then
    ui_model.choice = nil
  end
end

function render_flow_context.make_completion_game(world)
  local game = context.make_game()
  local current_role_id = context.current_action_role_id(world) or context.role_id(world)
  game.turn = {
    current_player_index = current_role_id,
    pending_choice = world.base_screen_ui_model and world.base_screen_ui_model.choice or nil,
  }
  game.current_player = function(self)
    return self.players[self.turn.current_player_index]
  end
  return game
end

function render_flow_context.complete_optional_action(world, intent, input_source)
  local state = world.base_screen_render_state
  local game = render_flow_context.make_completion_game(world)
  local result = optional_action_completion.complete_optional_action_phase(game, context.role_id(world), state, {
    input_source = input_source,
    dispatch_choice_action = function(action)
      world.base_screen_completion_action = action
      return { status = "applied" }
    end,
  })
  world.base_screen_completion_result = result
  if result.ok == true then
    render_flow_context.mark_optional_completed(world, intent)
  end
  return result
end

function render_flow_context.cancel_optional_action(world, intent, input_source)
  local state = world.base_screen_render_state
  local game = render_flow_context.make_completion_game(world)
  local result = optional_action_completion.complete_optional_action_phase(game, context.role_id(world), state, {
    input_source = input_source,
    choice = world.base_screen_ui_model and world.base_screen_ui_model.choice,
    dispatch_choice_action = function(action)
      world.base_screen_cancel_action = action
      return { status = "applied" }
    end,
  })
  world.base_screen_cancel_result = result
  if result.ok == true then
    world.base_screen_target_choice = nil
    if world.base_screen_ui_model then
      world.base_screen_ui_model.choice = nil
    end
    local ui_model = world.base_screen_render_state
      and world.base_screen_render_state.ui_runtime
      and world.base_screen_render_state.ui_runtime.ui_model
    if ui_model then
      ui_model.choice = nil
    end
  end
  return result
end

function render_flow_context.trigger_end_button(world)
  local intent = render_flow_context.build_base_intent(world, base_nodes.end_button)
  world.base_screen_end_button_intent = intent
  if intent and intent.type == "complete_optional_action_phase" then
    local result = render_flow_context.complete_optional_action(world, intent, "user")
    if result.ok == true then
      world.base_screen_turn_ended = true
      world.base_screen_next_player = true
    end
  end
  return intent
end

function render_flow_context.assert_end_button_hidden(world)
  local state = world.base_screen_render_state
  local actual = state and state.ui and state.ui.visibility and state.ui.visibility[base_nodes.end_button]
  if actual ~= false then
    return nil, "expected end button hidden, got " .. tostring(actual)
  end
  return true
end

function render_flow_context.assert_end_button_not_touchable(world)
  local state = world.base_screen_render_state
  local actual = state and state.ui and state.ui.touch and state.ui.touch[base_nodes.end_button]
  if actual == true then
    return nil, "expected end button not touchable"
  end
  return true
end

return render_flow_context