local path_planner = require("src.computer.agent.path_planner")
local action_selector = require("src.computer.agent.action_selector")
local decision_engine = require("src.computer.agent.decision_engine")

local agent = {}

agent.is_auto_player = path_planner.is_auto_player
agent.pick_remote_dice_value = path_planner.pick_remote_dice_value
agent.pick_target_player = action_selector.pick_target_player
agent.pick_roadblock_target = action_selector.pick_roadblock_target
agent.pick_demolish_target = action_selector.pick_demolish_target
agent.auto_action_for_choice = decision_engine.build(agent)

return agent
