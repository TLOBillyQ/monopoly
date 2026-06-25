local completions = require("src.rules.choice_handlers.item_completions")
local normalize = require("src.rules.choice_handlers.item_normalize")
local phase_handlers = require("src.rules.choice_handlers.item_phase_handlers")

local function _handle_flow_choice(game, choice, action, complete, resolve_item_use_choice, context)
  local result = resolve_item_use_choice(game, choice, action, context)
  local player = result.actor or normalize.validate_item_player(game, choice.kind, choice.meta)
  if result.ok ~= true then
    return { stay = true, reason = result.reason }
  end
  if result.waiting then
    return { stay = true }
  end
  return complete.followup_completion(game, choice, player, result)
end

local function _build_flow_handlers(helpers, kind, handler_opts)
  local complete = completions.build(helpers)
  local resolve_item_use_choice = helpers.resolve_item_use_choice

  local function _handle(game, choice, action)
    return _handle_flow_choice(game, choice, action, complete, resolve_item_use_choice)
  end

  return {
    [kind] = completions.item_target_handler(kind, _handle, complete, handler_opts),
  }
end

local function _build_demolish_handlers(helpers)
  return _build_flow_handlers(helpers, "demolish_target")
end

local function _build_roadblock_handlers(helpers)
  return _build_flow_handlers(helpers, "roadblock_target")
end

local function _build_target_player_handlers(helpers)
  return _build_flow_handlers(helpers, "item_target_player")
end

local function _build_remote_dice_handlers(helpers)
  return _build_flow_handlers(helpers, "remote_dice_value", {
    normalize_meta = normalize.remote_dice_meta,
    meta_validator = normalize.validate_remote_dice_meta,
  })
end

local M = {}

local _handler_builders = {
  phase_handlers.build,
  _build_demolish_handlers,
  _build_roadblock_handlers,
  _build_target_player_handlers,
  _build_remote_dice_handlers,
}

function M.register(registry, helpers)
  for _, builder in ipairs(_handler_builders) do
    local handlers = builder(helpers)
    for kind, handler in pairs(handlers) do
      registry[kind] = handler
    end
  end
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=c954d3f4d5ee2806
scope.0.id=chunk:src/rules/choice_handlers/item.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=394
scope.0.semanticHash=b3ea20d1c07b623e
scope.1.id=function:normalize.choice_action_option_id:20
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=24
scope.1.semanticHash=647401f28cc501e4
scope.2.id=function:normalize.validate_item_player:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=1bd909d629d6f0f0
scope.3.id=function:normalize.consume_if_needed:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=35
scope.3.semanticHash=ed52542b65af967a
scope.4.id=function:normalize.is_repeatable_phase_meta:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=2208c8e6623b88a4
scope.5.id=function:normalize.finish_item_phase_by_name:41
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=46
scope.5.semanticHash=e119c5251de086ad
scope.6.id=function:normalize.merge_after_action_anim:48
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=53
scope.6.semanticHash=d1311fb98f95161f
scope.7.id=function:normalize.owner_meta:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=60
scope.7.semanticHash=a6e31f3c465bb7a7
scope.8.id=function:normalize.item_phase_meta:62
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=67
scope.8.semanticHash=3be7cec7b753ceb8
scope.9.id=function:normalize.validate_item_phase_meta:69
scope.9.kind=function
scope.9.startLine=69
scope.9.endLine=72
scope.9.semanticHash=83fc576de21bc342
scope.10.id=function:normalize.validate_item_owner_meta:74
scope.10.kind=function
scope.10.startLine=74
scope.10.endLine=76
scope.10.semanticHash=253a7b1ac28680e8
scope.11.id=function:normalize.item_target_meta:78
scope.11.kind=function
scope.11.startLine=78
scope.11.endLine=82
scope.11.semanticHash=4a1a3c492ef3f057
scope.12.id=function:normalize.remote_dice_meta:84
scope.12.kind=function
scope.12.startLine=84
scope.12.endLine=88
scope.12.semanticHash=0db0d1132fbd305a
scope.13.id=function:normalize.validate_remote_dice_meta:90
scope.13.kind=function
scope.13.startLine=90
scope.13.endLine=95
scope.13.semanticHash=89e83fb20caa0598
scope.14.id=function:_finish_followup_choice:102
scope.14.kind=function
scope.14.startLine=102
scope.14.endLine=105
scope.14.semanticHash=431144543d69aad1
scope.15.id=function:_resume_pre_action_phase:107
scope.15.kind=function
scope.15.startLine=107
scope.15.endLine=120
scope.15.semanticHash=c939bedbafa829f4
scope.16.id=function:_resolve_phase_completion:122
scope.16.kind=function
scope.16.startLine=122
scope.16.endLine=135
scope.16.semanticHash=2fbd1c2d97e05af3
scope.17.id=function:_resolve_followup_completion:137
scope.17.kind=function
scope.17.startLine=137
scope.17.endLine=146
scope.17.semanticHash=44b5a3b4e3078ca8
scope.18.id=function:_resolve_followup_cancel:148
scope.18.kind=function
scope.18.startLine=148
scope.18.endLine=164
scope.18.semanticHash=29617bb583d0121d
scope.19.id=function:completions.build:99
scope.19.kind=function
scope.19.startLine=99
scope.19.endLine=171
scope.19.semanticHash=e3d21de0736f8834
scope.20.id=function:anonymous@178:178
scope.20.kind=function
scope.20.startLine=178
scope.20.endLine=180
scope.20.semanticHash=cb3d86778544df60
scope.21.id=function:anonymous@184:184
scope.21.kind=function
scope.21.startLine=184
scope.21.endLine=186
scope.21.semanticHash=aa5c022ffd4a4899
scope.22.id=function:completions.item_target_handler:173
scope.22.kind=function
scope.22.startLine=173
scope.22.endLine=189
scope.22.semanticHash=636d46aaee2b7d0a
scope.23.id=function:_handle_item_phase_choice:195
scope.23.kind=function
scope.23.startLine=195
scope.23.endLine=223
scope.23.semanticHash=92a2dc12de852a3f
scope.24.id=function:_handle_item_phase_passive:225
scope.24.kind=function
scope.24.startLine=225
scope.24.endLine=249
scope.24.semanticHash=1699fed38b7acbf4
scope.25.id=function:anonymous@255:255
scope.25.kind=function
scope.25.startLine=255
scope.25.endLine=257
scope.25.semanticHash=f96a923ff3d32f19
scope.26.id=function:anonymous@261:261
scope.26.kind=function
scope.26.startLine=261
scope.26.endLine=263
scope.26.semanticHash=aa5c022ffd4a4899
scope.27.id=function:_item_phase_handler:251
scope.27.kind=function
scope.27.startLine=251
scope.27.endLine=266
scope.27.semanticHash=dd28ac0d2f6cf71b
scope.28.id=function:_build_phase_handlers:191
scope.28.kind=function
scope.28.startLine=191
scope.28.endLine=272
scope.28.semanticHash=8fa0f57bfdbb3fa6
scope.29.id=function:_handle:277
scope.29.kind=function
scope.29.startLine=277
scope.29.endLine=293
scope.29.semanticHash=8b2bd9223f0d7c99
scope.30.id=function:_build_demolish_handlers:274
scope.30.kind=function
scope.30.startLine=274
scope.30.endLine=298
scope.30.semanticHash=5037b2073dc951ab
scope.31.id=function:_handle:303
scope.31.kind=function
scope.31.startLine=303
scope.31.endLine=318
scope.31.semanticHash=6d392103d91dea22
scope.32.id=function:_build_roadblock_handlers:300
scope.32.kind=function
scope.32.startLine=300
scope.32.endLine=323
scope.32.semanticHash=9641ef71a35604cc
scope.33.id=function:_handle:329
scope.33.kind=function
scope.33.startLine=329
scope.33.endLine=343
scope.33.semanticHash=b0bb06ded7a3334f
scope.34.id=function:_build_target_player_handlers:325
scope.34.kind=function
scope.34.startLine=325
scope.34.endLine=348
scope.34.semanticHash=259700acd4a98ce2
scope.35.id=function:_handle:353
scope.35.kind=function
scope.35.startLine=353
scope.35.endLine=364
scope.35.semanticHash=b5a05352d3c1bb15
scope.36.id=function:_build_remote_dice_handlers:350
scope.36.kind=function
scope.36.startLine=350
scope.36.endLine=372
scope.36.semanticHash=6a3aa0eca94e3950
]]
