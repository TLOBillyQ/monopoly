local path_planner = require("src.computer.agent.path")
local action_selector = require("src.computer.agent.action")
local decision_engine = require("src.computer.agent.decision")

local agent = {}

agent.is_auto_player = path_planner.is_auto_player
agent.pick_remote_dice_value = path_planner.pick_remote_dice_value
agent.pick_target_player = action_selector.pick_target_player
agent.pick_roadblock_target = action_selector.pick_roadblock_target
agent.pick_demolish_target = action_selector.pick_demolish_target
agent.auto_action_for_choice = decision_engine.build(agent)

return agent

--[[ mutate4lua-manifest
version=2
projectHash=72c1f3e928302aa8
scope.0.id=chunk:src/computer/agent/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=15
scope.0.semanticHash=c543d5ed385f4a8c
scope.0.lastMutatedAt=2026-07-07T03:18:25Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
]]
