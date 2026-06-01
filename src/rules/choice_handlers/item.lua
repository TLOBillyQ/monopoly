local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local inventory = require("src.rules.items.inventory")
local intent_output_port = require("src.rules.ports.intent_output")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local demolish = require("src.rules.items.demolish")
local item_use_broadcast = require("src.rules.items.use_broadcast")
local logger = require("src.foundation.log")
local roadblock = require("src.rules.items.roadblock")
local remote_dice = require("src.rules.items.remote_dice")

local copy_table = availability.copy_table
local normalize_integer_field = availability.normalize_integer_field

local normalize = {}

normalize.copy_table = copy_table
normalize.normalize_integer_field = normalize_integer_field

function normalize.choice_action_option_id(choice_kind, action)
  local normalized_action = copy_table(action)
  normalize_integer_field(normalized_action, "option_id", choice_kind, "action", true)
  return normalized_action
end

function normalize.validate_item_player(game, choice_kind, meta)
  return assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
end

function normalize.consume_if_needed(player, item_id, already_consumed)
  if not item_id or already_consumed == true then
    return
  end
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
end

function normalize.is_repeatable_phase_meta(meta)
  return type(meta) == "table" and item_phase.is_repeatable(meta.phase)
end

function normalize.finish_item_phase_by_name(game, phase)
  if type(phase) ~= "string" or phase == "" then
    return
  end
  item_phase.finish(game, phase)
end

function normalize.merge_after_action_anim(result, final_res)
  if type(result) == "table" and type(result.after_action_anim) == "table" then
    final_res.after_action_anim = result.after_action_anim
  end
  return final_res
end

function normalize.owner_meta(choice_kind, meta, choice_spec)
  local normalized_meta = copy_table(meta)
  normalize_integer_field(normalized_meta, "player_id", choice_kind)
  choice_spec.owner_role_id = choice_spec.owner_role_id or normalized_meta.player_id
  return normalized_meta
end

function normalize.item_phase_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  assert(type(normalized_meta.phase) == "string" and normalized_meta.phase ~= "",
    tostring(choice_spec.kind) .. " requires string meta.phase")
  return normalized_meta
end

function normalize.validate_item_phase_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
  assert(item_phase.is_enabled(meta.phase), tostring(choice_spec.kind) .. " requires enabled meta.phase")
end

function normalize.validate_item_owner_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
end

function normalize.item_target_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "item_id", choice_spec.kind)
  return normalized_meta
end

function normalize.remote_dice_meta(_, meta, choice_spec)
  local normalized_meta = normalize.item_target_meta(nil, meta, choice_spec)
  normalize_integer_field(normalized_meta, "dice_count", choice_spec.kind)
  return normalized_meta
end

function normalize.validate_remote_dice_meta(game, meta, choice_spec)
  normalize.validate_item_owner_meta(game, meta, choice_spec)
  if meta.dice_count ~= nil then
    assert(meta.dice_count >= 1, tostring(choice_spec.kind) .. " requires positive meta.dice_count")
  end
end

local completions = {}

function completions.build(helpers)
  local finish_choice = helpers.finish_choice

  local function _finish_followup_choice(game)
    helpers.finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function _resume_pre_action_phase(game, player, meta)
    if not item_phase.reopen_or_finish(game, player, meta) then
      return finish_choice(game, false)
    end
    if game.turn.action_anim then
      return {
        after_action_anim = {
          next_state = "wait_choice",
          next_args = item_phase.build_wait_choice_args(meta),
        },
      }
    end
    return { stay = true }
  end

  local function _resolve_phase_completion(game, player, meta, result)
    if not normalize.is_repeatable_phase_meta(meta) then
      normalize.finish_item_phase_by_name(game, meta and meta.phase or nil)
      return normalize.merge_after_action_anim(result, finish_choice(game, false))
    end
    if meta.phase == "post_action" then
      return normalize.merge_after_action_anim(result, finish_choice(game, false))
    end
    local resumed = _resume_pre_action_phase(game, player, meta)
    if resumed.stay then
      return resumed
    end
    return normalize.merge_after_action_anim(result, resumed)
  end

  local function _resolve_followup_completion(game, choice, player, result)
    local meta = choice.meta or {}
    if meta.passive_origin and meta.item_id then
      availability.mark_effect_group_used(game, meta.item_id)
    end
    if normalize.is_repeatable_phase_meta(meta) then
      return _resolve_phase_completion(game, player, meta, result)
    end
    return normalize.merge_after_action_anim(result, _finish_followup_choice(game))
  end

  local function _resolve_followup_cancel(game, choice)
    local meta = choice and choice.meta or nil
    if normalize.is_repeatable_phase_meta(meta) then
      if meta.phase == "pre_action" then
        local player = normalize.validate_item_player(game, choice.kind, meta)
        if item_phase.reopen_or_finish(game, player, meta) then
          return { stay = true }
        end
      end
      return nil
    end
    local phase = game.turn.item_phase_active
    if phase and phase ~= "" then
      item_phase.finish(game, phase)
    end
    return nil
  end

  return {
    phase_completion = _resolve_phase_completion,
    followup_completion = _resolve_followup_completion,
    followup_cancel = _resolve_followup_cancel,
  }
end

function completions.item_target_handler(kind, execute_fn, complete, opts)
  opts = opts or {}
  return {
    required_meta = { "player_id", "item_id" },
    cancel = {
      resolve = function(game, choice)
        return complete.followup_cancel(game, choice)
      end,
    },
    normalize_meta = opts.normalize_meta or normalize.item_target_meta,
    meta_validator = opts.meta_validator or normalize.validate_item_owner_meta,
    normalize_action = function(_, _, action)
      return normalize.choice_action_option_id(kind, action)
    end,
    execute = execute_fn,
  }
end

local function _build_phase_handlers(helpers)
  local complete = completions.build(helpers)
  local use_item = helpers.use_item

  local function _decorate_repeatable_followup(choice_spec, meta, item_id, player, phase)
    choice_spec.meta = choice_spec.meta or {}
    choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
    choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
    item_phase.decorate_followup_choice_spec(choice_spec, meta)
  end

  local function _decorate_non_repeatable_followup(choice_spec, player, item_id)
    assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
    item_preconsume_policy.decorate_followup_choice_spec(choice_spec, {
      item_id = item_id,
      player_id = player.id,
    })
  end

  local function _handle_waiting_result(game, result, meta, player, item_id, phase)
    local intent = result.intent or {}
    local choice_spec = intent.choice_spec
    if type(choice_spec) == "table" then
      if item_phase.is_repeatable(phase) then
        _decorate_repeatable_followup(choice_spec, meta, item_id, player, phase)
      else
        _decorate_non_repeatable_followup(choice_spec, player, item_id)
      end
    end
    intent_output_port.dispatch(game, intent)
    return { stay = true }
  end

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local phase = meta.phase
    local item_id = action.option_id

    local result = use_item(game, player, item_id)
    if type(result) == "table" and result.waiting then
      return _handle_waiting_result(game, result, meta, player, item_id, phase)
    end
    return complete.phase_completion(game, player, meta, result)
  end

  local function _decorate_passive_followup(choice_spec, meta, item_id, player)
    choice_spec.meta = choice_spec.meta or {}
    choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
    choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
    choice_spec.meta.passive_origin = true
    item_phase.decorate_followup_choice_spec(choice_spec, meta)
  end

  local function _handle_passive_waiting_result(game, result, meta, player, item_id)
    local intent = result.intent or {}
    local choice_spec = intent.choice_spec
    if type(choice_spec) == "table" then
      _decorate_passive_followup(choice_spec, meta, item_id, player)
    end
    intent_output_port.dispatch(game, intent)
    return { stay = true }
  end

  local function _handle_item_phase_passive(game, choice, action)
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = action.option_id

    local result = use_item(game, player, item_id)
    assert(result ~= nil, "missing use_item result")
    if type(result) == "table" and result.waiting then
      return _handle_passive_waiting_result(game, result, meta, player, item_id)
    end

    availability.mark_effect_group_used(game, item_id)
    local reopened = item_phase.reopen_or_finish(game, player, meta)
    return reopened and { stay = true } or nil
  end

  local function _item_phase_handler(kind, execute_fn)
    return {
      required_meta = { "player_id", "phase" },
      cancel = {
        resolve = function(game, choice)
          item_phase.finish(game, choice.meta and choice.meta.phase or nil)
        end,
      },
      normalize_meta = normalize.item_phase_meta,
      meta_validator = normalize.validate_item_phase_meta,
      normalize_action = function(_, _, action)
        return normalize.choice_action_option_id(kind, action)
      end,
      execute = execute_fn,
    }
  end

  return {
    item_phase_choice = _item_phase_handler("item_phase_choice", _handle_item_phase_choice),
    item_phase_passive = _item_phase_handler("item_phase_passive", _handle_item_phase_passive),
  }
end

local function _build_demolish_handlers(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = demolish.apply(game, player, index, {
      injure = meta.injure,
      title = meta.title,
      item_id = meta.item_id,
    })
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    local intent = result.intent or {}
    intent_output_port.dispatch(game, intent)
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    demolish_target = completions.item_target_handler("demolish_target", _handle, complete),
  }
end

local function _build_roadblock_handlers(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local index = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    if not roadblock.is_ui_candidate(game, player, index) then
      logger.warn(player.name .. " 选择了无效的路障位置: " .. tostring(index))
      return { stay = true }
    end
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = roadblock.apply(game, player, index)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
      intent_output_port.dispatch(game, result)
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    roadblock_target = completions.item_target_handler("roadblock_target", _handle, complete),
  }
end

local function _build_target_player_handlers(helpers)
  local complete = completions.build(helpers)
  local use_item = helpers.use_item

  local function _handle(game, choice, action)
    local target_id = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local item_id = meta.item_id
    local result = use_item(game, player, item_id, {
      target_id = target_id,
      item_preconsumed = meta.item_preconsumed == true,
    })
    assert(result ~= nil, "missing use_item result")
    if result.waiting then
      return { stay = true }
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    item_target_player = completions.item_target_handler("item_target_player", _handle, complete),
  }
end

local function _build_remote_dice_handlers(helpers)
  local complete = completions.build(helpers)

  local function _handle(game, choice, action)
    local value = action.option_id
    local meta = choice.meta
    local player = normalize.validate_item_player(game, choice.kind, meta)
    local dice_count = meta.dice_count or game:player_dice_count(player)
    normalize.consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = remote_dice.apply(game, player, dice_count, value)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    return complete.followup_completion(game, choice, player, result)
  end

  return {
    remote_dice_value = completions.item_target_handler("remote_dice_value", _handle, complete, {
      normalize_meta = normalize.remote_dice_meta,
      meta_validator = normalize.validate_remote_dice_meta,
    }),
  }
end

local M = {}

local _handler_builders = {
  _build_phase_handlers,
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
