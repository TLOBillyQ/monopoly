local event_kinds = require("src.config.gameplay.event_kinds")

local M = {}

M[event_kinds.dice_roll] = { tip = false }
M[event_kinds.rent_paid] = { tip = true }
M[event_kinds.tax_paid] = { tip = true }
M[event_kinds.medical_fee] = { tip = true }
M[event_kinds.hospital_stay] = { tip = true }
M[event_kinds.mountain_stay] = { tip = true }
M[event_kinds.land_purchase] = { tip = true }
M[event_kinds.land_upgrade] = { tip = true }
M[event_kinds.transit] = { tip = false }
M[event_kinds.move_completed] = { tip = false }
M[event_kinds.roadblock_placed] = { tip = false }
M[event_kinds.roadblock_triggered] = { tip = false }
M[event_kinds.mine_placed] = { tip = false }
M[event_kinds.bankruptcy] = { tip = false }
M[event_kinds.victory] = { tip = false }
M[event_kinds.remote_dice] = { tip = false }

M[event_kinds.rent_multiplier_breakdown] = { tip = true }
M[event_kinds.afk_auto_enabled] = { tip = true }

M[event_kinds.choice_picked] = { log = false }
M[event_kinds.choice_skipped] = { log = false }
M[event_kinds.turn_start] = { log = false }
M[event_kinds.turn_end] = { log = false }

return M

--[[ mutate4lua-manifest
version=4
projectHash=430699cd6ba512dc
scope.0.id=chunk:src/config/tip_policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=ae3ef943efeea695
]]
