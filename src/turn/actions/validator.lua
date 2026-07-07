local actor = require("src.turn.actions.validator_actor")
local gate = require("src.turn.actions.validator_gate")
local item_phase = require("src.turn.actions.validator_item_phase")
local item_slot = require("src.turn.actions.validator_item_slot")

local validator = {}

validator.validate_actor_role = actor.validate_actor_role
validator.validate_choice_actor = actor.validate_choice_actor
validator.validate_choice_id = actor.validate_choice_id
validator.validate_choice_action = actor.validate_choice_action

validator.resolve_gate_state = gate.resolve_gate_state
validator.should_block_action = gate.should_block_action

validator.resolve_item_slot_action = item_slot.resolve_item_slot_action
validator._resolve_item_slot_resolution = item_slot.resolve_item_slot_resolution
validator._validate_item_slot_action = item_phase.validate_item_slot_action

return validator

--[[ mutate4lua-manifest
version=2
projectHash=307a3c9248d742ea
scope.0.id=chunk:src/turn/actions/validator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=fa3539d365f67759
]]
