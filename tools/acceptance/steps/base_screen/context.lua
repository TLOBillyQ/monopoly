-- Shared context for base_screen step handlers.
--
-- This module owns the reusable support (requires, lookup tables, and pure
-- helper functions) that the behavior-preserving split of base_screen.lua
-- produced. Each handler sub-module requires this context and contributes its
-- own Gherkin step keys; the thin aggregator in base_screen.lua merges them
-- back into the same 1:1 handler set, so the public `base_screen_steps.handlers()`
-- API is unchanged.
--
-- Kept side-effect free at module scope: tables and functions only. All mutable
-- state continues to live on the per-scenario `world` passed into each handler.

local number_utils = require("src.foundation.number")
local panel_slice = require("src.ui.view.panel_slice")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local ui_runtime = require("src.ui.coord.ui_runtime")
local base_nodes = require("src.ui.schema.base")
local state_tables = require("acceptance.steps.base_screen.state_tables")

local context = {}

context.base_nodes = base_nodes
context.number_utils = number_utils
context.panel_slice = panel_slice
context.choice_auto_policy = choice_auto_policy
context.ui_runtime = ui_runtime

context.SKIN_ENTRY_NODES = state_tables.SKIN_ENTRY_NODES
context.AUXILIARY_ENTRY_NODES = state_tables.AUXILIARY_ENTRY_NODES
context.OPTIONAL_ACTION_KIND_BY_NAME = state_tables.OPTIONAL_ACTION_KIND_BY_NAME
context.FOLLOWUP_BY_OPTIONAL_ACTION = state_tables.FOLLOWUP_BY_OPTIONAL_ACTION
context.BLOCKING_STATE_BY_NAME = state_tables.BLOCKING_STATE_BY_NAME
context.STAGE_STATE_BY_NAME = state_tables.STAGE_STATE_BY_NAME

function context.role_id(world)
  return number_utils.to_integer(world.ui_role_id) or 1
end

function context.parse_auto_state(value)
  local text = tostring(value or "")
  if text == "开启" then
    return true
  end
  if text == "关闭" then
    return false
  end
  return nil, "unknown auto state: " .. text
end

function context.make_game()
  local players = {}
  for role_id = 1, 4 do
    players[role_id] = {
      id = role_id,
      name = "P" .. tostring(role_id),
      cash = 1000,
      properties = {},
    }
  end
  return {
    players = players,
    auto_play_port = {
      is_auto_player = function()
        return false
      end,
      auto_action_for_choice = function()
        return nil
      end,
    },
  }
end

function context.make_auto_enabled_by_player(world)
  return {
    [context.role_id(world)] = world.base_screen_auto_enabled == true,
  }
end

function context.current_action_role_id(world)
  if world.base_screen_action_role_unset == true then
    return nil
  end
  return number_utils.to_integer(world.base_screen_action_role_id) or context.role_id(world)
end

function context.valid_role_id(role_id)
  return role_id ~= nil and role_id >= 1 and role_id <= 4
end

function context.set_role_id(world, value)
  local role_id = number_utils.to_integer(value)
  if not context.valid_role_id(role_id) then
    return nil, "invalid role_id: " .. tostring(value)
  end
  world.ui_role_id = role_id
  return true
end

function context.set_current_action_role(world, example, key_name)
  local role_id = number_utils.to_integer(example[key_name])
  if not context.valid_role_id(role_id) then
    return nil, "invalid action role_id: " .. tostring(example[key_name])
  end
  world.base_screen_action_role_id = role_id
  world.base_screen_action_role_unset = false
  return true
end

function context.resolve_followup_flow(world)
  local action_name = tostring(world.base_screen_optional_action or "")
  return context.FOLLOWUP_BY_OPTIONAL_ACTION[action_name] or "必经流程"
end

function context.optional_choice_for_world(world, action_role_id)
  if world.base_screen_target_choice ~= nil then
    return world.base_screen_target_choice
  end
  if world.base_screen_empty_optional_phase == true or world.base_screen_optional_action == nil then
    return nil
  end
  local action_name = tostring(world.base_screen_optional_action)
  local kind = context.OPTIONAL_ACTION_KIND_BY_NAME[action_name]
  if kind == nil then
    return nil
  end
  return {
    id = 9001,
    kind = kind,
    route_key = kind == "item_phase_passive" and "item_phase_passive" or "base_inline",
    allow_cancel = true,
    owner_role_id = action_role_id,
    options = { { id = "optional", label = action_name } },
    meta = {
      optional_action = action_name,
      followup_flow = context.resolve_followup_flow(world),
    },
  }
end

function context.enter_item_target_selection(world, item_name)
  local action_role_id = context.current_action_role_id(world)
  world.base_screen_target_choice = {
    id = 9002,
    kind = "item_phase_passive",
    route_key = "item_phase_passive",
    allow_cancel = true,
    owner_role_id = action_role_id,
    meta = {
      passive_origin = true,
      item_name = item_name,
    },
  }
  return true
end

function context.set_optional_action_phase(world, action_name)
  local text = tostring(action_name or "")
  if context.OPTIONAL_ACTION_KIND_BY_NAME[text] == nil then
    return nil, "unknown optional action: " .. text
  end
  world.base_screen_optional_action = text
  world.base_screen_empty_optional_phase = false
  return true
end

function context.set_blocking_state(world, state_name)
  local text = tostring(state_name or "")
  if context.BLOCKING_STATE_BY_NAME[text] ~= true then
    return nil, "unknown blocking state: " .. text
  end
  world.base_screen_blocking_state = text
  world.base_screen_input_blocked = true
  return true
end

function context.set_stage_state(world, stage_name)
  local text = tostring(stage_name or "")
  if context.STAGE_STATE_BY_NAME[text] ~= true then
    return nil, "unknown stage state: " .. text
  end
  world.base_screen_stage_state = text
  world.base_screen_optional_action = nil
  world.base_screen_empty_optional_phase = text == "空可选行动阶段"
  if text ~= "空可选行动阶段" then
    world.base_screen_input_blocked = true
  end
  return true
end

function context.auxiliary_entry_node(name)
  return context.AUXILIARY_ENTRY_NODES[tostring(name or "")]
end

function context.give_item(world, item_name)
  world.base_screen_inventory = world.base_screen_inventory or {}
  world.base_screen_inventory[item_name] = (world.base_screen_inventory[item_name] or 0) + 1
  return true
end

function context.has_item(world, item_name)
  return (world.base_screen_inventory or {})[item_name] or 0
end

function context.set_item_phase(world, item_name, phase)
  world.base_screen_item_phases = world.base_screen_item_phases or {}
  world.base_screen_item_phases[item_name] = phase
  if phase == "post_action" then
    world.base_screen_optional_action = "落地选择"
    world.base_screen_empty_optional_phase = false
  end
  return true
end

function context.item_phase(world, item_name)
  return (world.base_screen_item_phases or {})[item_name]
end

function context.set_dice_rolled_and_moved(world)
  world.base_screen_dice_rolled = true
  world.base_screen_move_completed = true
  world.base_screen_stage_state = "移动完成"
  return true
end

function context.set_landed_buyable_property(world)
  world.base_screen_landed_property = {
    buyable = true,
    owner_role_id = nil,
  }
  return true
end

function context.show_buy_property_choice(world)
  world.base_screen_buy_property_open = true
  return context.set_blocking_state(world, "选择弹窗")
end

function context.resolve_forced_landing_choices(world)
  world.base_screen_forced_landing_resolved = true
  world.base_screen_buy_property_open = false
  world.base_screen_blocking_state = nil
  world.base_screen_input_blocked = false
  if world.base_screen_optional_action == nil then
    world.base_screen_optional_action = "落地选择"
    world.base_screen_empty_optional_phase = false
  end
  return true
end

function context.set_countdown_timeout(world)
  world.base_screen_countdown_timeout = true
  return true
end

return context