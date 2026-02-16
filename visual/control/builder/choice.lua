local logger = require("core.logger")
local ui_event_intents = require("visual.control.intents")
local ui_nodes = require("visual.nodes")

local choice_intents = {}

function choice_intents.build_player(state)
  local specs = {}
  local player_nodes = ui_nodes.choice.player.slots
  for index, name in ipairs(player_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "player_select")
      end,
    }
  end
  return specs
end

function choice_intents.build_target(state)
  local specs = {}
  local target_nodes = ui_nodes.choice.target.slots
  for index, name in ipairs(target_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "target_select")
      end,
    }
  end
  local under_index = #target_nodes + 1
  specs[#specs + 1] = {
    name = ui_nodes.choice.target.under,
    build_intent = function()
      return ui_event_intents.choice_select_intent(state, under_index, "target_select")
    end,
  }
  return specs
end

function choice_intents.build_remote(state)
  local specs = {}
  local remote_nodes = ui_nodes.choice.remote.options
  for index, name in ipairs(remote_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice then
          logger.warn("remote_select without choice")
          return nil
        end
        local option_id = ui_event_intents.resolve_option_id(choice, { index = index }, state)
        if not option_id then
          logger.warn("remote_select missing option:", tostring(index))
          return nil
        end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end
  return specs
end

return choice_intents
