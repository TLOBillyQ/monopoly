local timing = require("src.config.gameplay.timing")
local auto_play_port = require("src.rules.ports.auto_play")
local strategy = require("src.rules.items.strategy")
local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")
local intent_output_port = require("src.rules.ports.intent_output")
local item_config = require("src.rules.items.config")
local dirty_tracker = require("src.state.dirty_tracker")
local chain_args = require("src.foundation.chain_args")

local phase_module = {}

local cfg_by_id = item_config.cfg_by_id

local phase_titles = {
  pre_action = "出牌时间！",
  pre_move = "出牌时间！",
  post_action = "出牌时间！",
}

local phase_confirm_titles = {
  pre_action = "行动前",
  pre_move = "掷骰后",
  post_action = "行动后",
}

local repeatable_phases = {
  pre_action = true,
  pre_move = true,
  post_action = true,
}

local function _resolve_after_action_anim(args, res)
  return chain_args.resolve_after_action_anim(args, res, "move_followup")
end

local function _result_after_action_anim(result)
  return type(result) == "table" and result.after_action_anim or nil
end

function phase_module.is_enabled(phase)
  local queue = timing.item_phase_queue
  assert(type(queue) == "table", "invalid item_phase_queue")
  for _, name in ipairs(queue) do
    if name == phase then
      return true
    end
  end
  return false
end

function phase_module.is_repeatable(phase)
  return repeatable_phases[phase] == true
end

local function _build_options(game, player, phase)
  local options = {}
  local body_lines = {}
  local seen_item_ids = {}
  for _, it in ipairs(inventory.items(player)) do
    local cfg = cfg_by_id[it.id]
    if cfg and not seen_item_ids[it.id] and availability.can_offer_in_phase(game, player, it.id, phase) then
      seen_item_ids[it.id] = true
      table.insert(options, {
        id = it.id,
        label = cfg.name,
        confirm_title = phase_confirm_titles[phase] or "本回合",
        confirm_body = "将使用：" .. cfg.name,
      })
      local line = cfg.name
      if cfg.usage and #cfg.usage > 0 then
        line = line .. "：" .. cfg.usage
      end
      table.insert(body_lines, line)
    end
  end
  return body_lines, options
end

function phase_module.finish(game, phase)
  if type(phase) ~= "string" or phase == "" then
    game.turn.item_phase_active = ""
    return
  end
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = { done = true }
  local active = game.turn.item_phase_active
  if active == phase then
    game.turn.item_phase_active = ""
  end
  dirty_tracker.mark(game.dirty, "turn")
end

local function _require_resume_next_state(meta)
  return assert(meta and meta.resume_next_state, "missing meta.resume_next_state")
end

function phase_module.build_wait_choice_args(meta)
  return {
    next_state = _require_resume_next_state(meta),
    next_args = meta and meta.resume_next_args or nil,
  }
end

local function _clear_finished_phase(game, phase)
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = nil
  dirty_tracker.mark(game.dirty, "turn")
end

local function _resolve_finished_phase(game, phase_state, phase)
  if not (phase_state and phase_state.done) then
    return false
  end
  _clear_finished_phase(game, phase)
  return true
end

local function _mark_waiting_phase(game, phase)
  game.turn.item_phase_active = phase
  dirty_tracker.mark_turn(game)
end

function phase_module.mark_active(game, phase)
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = { active = true }
  _mark_waiting_phase(game, phase)
end

function phase_module.decorate_followup_choice_spec(choice_spec, meta)
  if type(choice_spec) ~= "table" or type(meta) ~= "table" then
    return choice_spec
  end
  choice_spec.meta = choice_spec.meta or {}
  choice_spec.meta.phase = meta.phase
  choice_spec.meta.resume_next_state = meta.resume_next_state
  choice_spec.meta.resume_next_args = meta.resume_next_args
  if phase_module.is_repeatable(meta.phase) then
    choice_spec.allow_cancel = true
    choice_spec.cancel_label = choice_spec.cancel_label or "返回"
  end
  return choice_spec
end

function phase_module.reopen_or_finish(game, player, meta, opts)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  assert(type(meta) == "table", "missing phase meta")
  opts = opts or {}
  local spec = phase_module.build_passive_choice_spec(game, player, meta.phase, {
    next_state = meta.resume_next_state,
    next_args = meta.resume_next_args,
  })
  if spec == nil then
    phase_module.finish(game, meta.phase)
    return false
  end
  local open_opts = nil
  if opts.elapsed_seconds ~= nil then
    open_opts = { elapsed_seconds = opts.elapsed_seconds }
  end
  intent_output_port.open_choice(game, spec, open_opts)
  phase_module.mark_active(game, meta.phase)
  return true
end

-- Deep-module completion entry: handles repeatable/non-repeatable phases,
-- reopen-or-finish, action-anim continuation, and elapsed preservation.
-- Callers no longer branch by phase.
-- Returns a normalized result: { status = "resolved/waiting", stay = bool, ... }.
function phase_module.resolve_completion(game, player, meta, result, _opts)
  result = result or {}
  local phase = meta and meta.phase
  local after_action_anim = _result_after_action_anim(result)
  if type(phase) ~= "string" or phase == "" then
    return { status = "resolved", stay = false, after_action_anim = after_action_anim }
  end
  if not phase_module.is_repeatable(phase) then
    phase_module.finish(game, phase)
    return { status = "resolved", stay = false, after_action_anim = after_action_anim }
  end

  local open_opts = {
    elapsed_seconds = game.turn.choice_elapsed_seconds or 0,
  }
  local reopened = phase_module.reopen_or_finish(game, player, meta, open_opts)
  if not reopened then
    return { status = "resolved", stay = false, after_action_anim = after_action_anim }
  end

  if game.turn.action_anim then
    return {
      status = "resolved",
      stay = false,
      after_action_anim = {
        next_state = "wait_choice",
        next_args = phase_module.build_wait_choice_args(meta),
      },
    }
  end

  return { status = "waiting", stay = true }
end


local function _resolve_auto_phase_wait(game, phase, args, pre)
  if not (pre and pre.waiting) then
    return nil
  end
  _mark_waiting_phase(game, phase)
  return { waiting = true, next_state = args.next_state, next_args = args.next_args }
end

local function _resolve_auto_phase_action_anim(game, phase, args, pre, should_finish)
  if not game.turn.action_anim then
    return nil
  end
  local next_state, next_args = _resolve_after_action_anim(args, pre)
  if should_finish ~= false then
    phase_module.finish(game, phase)
  end
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
    dirty_tracker.mark(game.dirty, "turn")
  end
  return { waiting = true, wait_action_anim = true, next_state = next_state, next_args = next_args }
end

local function _try_dispatch_animation(game, phase, args, pre, repeatable)
  if type(pre) == "table" and type(pre.after_action_anim) == "table" then
    return _resolve_auto_phase_action_anim(game, phase, args, pre, phase ~= "post_action"), false
  end
  if game.turn.action_anim then
    if not repeatable then
      return _resolve_auto_phase_action_anim(game, phase, args, pre, true), false
    end
    return nil, true
  end
  if not repeatable then
    phase_module.finish(game, phase)
    return nil, false
  end
  return nil, false
end

local function _run_auto_phase(game, player, phase, args)
  local repeatable = phase_module.is_repeatable(phase)
  local saw_action_anim = false
  while true do
    local pre = strategy.auto_pre_action(game, player, phase)
    if pre then
      intent_output_port.dispatch(game, pre)
    end
    local wait_res = _resolve_auto_phase_wait(game, phase, args, pre)
    if wait_res ~= nil then
      return wait_res
    end
    if pre == nil then
      break
    end
    local dispatch_result, saw_anim = _try_dispatch_animation(game, phase, args, pre, repeatable)
    if dispatch_result ~= nil then
      return dispatch_result
    end
    if saw_anim then
      saw_action_anim = true
    end
  end
  phase_module.finish(game, phase)
  if saw_action_anim and game.turn.action_anim then
    local next_state, next_args = _resolve_after_action_anim(args, {})
    return { waiting = true, wait_action_anim = true, next_state = next_state, next_args = next_args }
  end
  return nil
end

local function _collect_if(slot_states, out, pred)
  for i = 1, 5 do
    if pred(slot_states[i]) then
      out[#out + 1] = slot_states[i]
    end
  end
end

local function _sort_slot_states(slot_states)
  local sorted = {}
  _collect_if(slot_states, sorted, function(ss) return ss.item_id ~= nil and ss.available end)
  _collect_if(slot_states, sorted, function(ss) return ss.item_id ~= nil and not ss.available end)
  _collect_if(slot_states, sorted, function(ss) return ss.item_id == nil end)
  return sorted
end

local function _build_item_alert(cfg, item_id, available)
  if not available or not cfg or cfg.prompt_style ~= "alert" then
    return false, nil
  end
  return true, (cfg.name or tostring(item_id)) .. "可用！"
end

local function _build_slot_state(game, player, item, phase)
  if type(item) ~= "table" or item.id == nil then
    return { available = false, alert = false, alert_text = nil, item_id = nil, deny_reason = nil }
  end
  local can_offer, dr = availability.can_offer_in_phase(game, player, item.id, phase)
  local available = can_offer == true
  local cfg = inventory.cfg(item.id)
  local deny_reason = nil
  if not available then deny_reason = dr end
  local alert, alert_text = _build_item_alert(cfg, item.id, available)
  return {
    available = available,
    alert = alert,
    alert_text = alert_text,
    item_id = item.id,
    deny_reason = deny_reason,
  }
end

local function _build_option_from_slot(ss)
  local cfg = inventory.cfg(ss.item_id)
  local name = cfg and cfg.name
  return {
    id = ss.item_id,
    label = name or tostring(ss.item_id),
    confirm_title = name,
    confirm_body = cfg and cfg.description,
  }
end

local function _build_slot_options(slot_states)
  local options = {}
  for _, ss in ipairs(slot_states) do
    if ss.available and ss.item_id ~= nil then
      options[#options + 1] = _build_option_from_slot(ss)
    end
  end
  return options
end

local function _run_player_phase(game, player, phase, args)
  local spec = phase_module.build_passive_choice_spec(game, player, phase, args)
  if spec == nil then
    phase_module.finish(game, phase)
    return nil
  end
  intent_output_port.open_choice(game, spec)
  phase_module.mark_active(game, phase)
  return { waiting = true, next_state = args.next_state, next_args = args.next_args }
end

function phase_module.build_passive_choice_spec(game, player, phase, args)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  args = args or {}

  local slot_states = {}
  local item_slots = inventory.items(player)
  for slot_index = 1, 5 do
    slot_states[slot_index] = _build_slot_state(game, player, item_slots[slot_index], phase)
  end
  slot_states = _sort_slot_states(slot_states)

  local options = _build_slot_options(slot_states)
  if #options == 0 then
    return nil
  end

  return {
    kind = "item_phase_passive",
    route_key = "item_phase_passive",
    owner_role_id = player.id,
    uses_item_slots = true,
    pre_confirm_before_slot_pick = false,
    slot_states = slot_states,
    options = options,
    allow_cancel = true,
    cancel_label = "完成",
    meta = {
      player_id = player.id,
      phase = phase,
      resume_next_state = args.next_state,
      resume_next_args = args.next_args,
    },
  }
end

function phase_module.run(turn_mgr, phase, args)
  local game = turn_mgr.game
  local player = args.player
  assert(player ~= nil, "missing player")
  if not phase_module.is_enabled(phase) then
    return nil
  end

  local item_phases = game.turn.item_phase
  local phase_state = item_phases and item_phases[phase]
  if _resolve_finished_phase(game, phase_state, phase) then
    return nil
  end

  if auto_play_port.is_auto_player(game, player) then
    return _run_auto_phase(game, player, phase, args)
  end

  return _run_player_phase(game, player, phase, args)
end

function phase_module.build_choice_spec(game, player, phase, args)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  local body_lines, options = _build_options(game, player, phase)
  if #options == 0 then
    return nil
  end
  return {
    kind = "item_phase_choice",
    route_key = "base_inline",
    owner_role_id = player.id,
    uses_item_slots = true,
    pre_confirm_before_slot_pick = false,
    title = phase_titles[phase],
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "完成",
    meta = {
      player_id = player.id,
      phase = phase,
      resume_next_state = args and args.next_state or nil,
      resume_next_args = availability.copy_table(args and args.next_args or nil),
    },
  }
end

return phase_module

--[[ mutate4lua-manifest
version=2
projectHash=eaca072254ff01b9
scope.0.id=chunk:src/rules/items/phase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=385
scope.0.semanticHash=1d2e9e646840138e
scope.1.id=function:_resolve_after_action_anim:33
scope.1.kind=function
scope.1.startLine=33
scope.1.endLine=35
scope.1.semanticHash=ea3de58a8f0adf16
scope.2.id=function:phase_module.is_repeatable:48
scope.2.kind=function
scope.2.startLine=48
scope.2.endLine=50
scope.2.semanticHash=3be195a30467f1d5
scope.3.id=function:phase_module.finish:76
scope.3.kind=function
scope.3.startLine=76
scope.3.endLine=84
scope.3.semanticHash=1836b9be5a51fdcf
scope.4.id=function:_require_resume_next_state:86
scope.4.kind=function
scope.4.startLine=86
scope.4.endLine=88
scope.4.semanticHash=20dfff725aa91b13
scope.5.id=function:phase_module.build_wait_choice_args:90
scope.5.kind=function
scope.5.startLine=90
scope.5.endLine=95
scope.5.semanticHash=92a990eb3a6a9934
scope.6.id=function:_clear_finished_phase:97
scope.6.kind=function
scope.6.startLine=97
scope.6.endLine=101
scope.6.semanticHash=003ec24e7b79bc08
scope.7.id=function:_resolve_finished_phase:103
scope.7.kind=function
scope.7.startLine=103
scope.7.endLine=109
scope.7.semanticHash=058517e49012f5f7
scope.8.id=function:_mark_waiting_phase:111
scope.8.kind=function
scope.8.startLine=111
scope.8.endLine=114
scope.8.semanticHash=c285a4d47d3f9d72
scope.9.id=function:phase_module.mark_active:116
scope.9.kind=function
scope.9.startLine=116
scope.9.endLine=120
scope.9.semanticHash=e026eff19144a005
scope.10.id=function:phase_module.decorate_followup_choice_spec:122
scope.10.kind=function
scope.10.startLine=122
scope.10.endLine=135
scope.10.semanticHash=c79207d13ebac112
scope.11.id=function:phase_module.reopen_or_finish:137
scope.11.kind=function
scope.11.startLine=137
scope.11.endLine=152
scope.11.semanticHash=0f54f775d8b13bf3
scope.12.id=function:_resolve_auto_phase_wait:155
scope.12.kind=function
scope.12.startLine=155
scope.12.endLine=161
scope.12.semanticHash=910000d1fb1aedb1
scope.13.id=function:_resolve_auto_phase_action_anim:163
scope.13.kind=function
scope.13.startLine=163
scope.13.endLine=176
scope.13.semanticHash=f51e1b3ddffe8875
scope.14.id=function:_try_dispatch_animation:178
scope.14.kind=function
scope.14.startLine=178
scope.14.endLine=193
scope.14.semanticHash=94868842c84cfa03
scope.15.id=function:anonymous@236:236
scope.15.kind=function
scope.15.startLine=236
scope.15.endLine=236
scope.15.semanticHash=f1ac3416a584e0ea
scope.16.id=function:anonymous@237:237
scope.16.kind=function
scope.16.startLine=237
scope.16.endLine=237
scope.16.semanticHash=59de8d13fc812e75
scope.17.id=function:anonymous@238:238
scope.17.kind=function
scope.17.startLine=238
scope.17.endLine=238
scope.17.semanticHash=4ceb92001769563b
scope.18.id=function:_sort_slot_states:234
scope.18.kind=function
scope.18.startLine=234
scope.18.endLine=240
scope.18.semanticHash=3b14dfd8f2654bfe
scope.19.id=function:_build_item_alert:242
scope.19.kind=function
scope.19.startLine=242
scope.19.endLine=247
scope.19.semanticHash=49355f94952dbcd7
scope.20.id=function:_build_slot_state:249
scope.20.kind=function
scope.20.startLine=249
scope.20.endLine=266
scope.20.semanticHash=5bda3b6a72e8a1ed
scope.21.id=function:_build_option_from_slot:268
scope.21.kind=function
scope.21.startLine=268
scope.21.endLine=277
scope.21.semanticHash=e54660af80725039
scope.22.id=function:_run_player_phase:289
scope.22.kind=function
scope.22.startLine=289
scope.22.endLine=298
scope.22.semanticHash=f8eae97333d3d072
scope.23.id=function:phase_module.run:336
scope.23.kind=function
scope.23.startLine=336
scope.23.endLine=355
scope.23.semanticHash=53356a0207fc0934
scope.24.id=function:phase_module.build_choice_spec:357
scope.24.kind=function
scope.24.startLine=357
scope.24.endLine=382
scope.24.semanticHash=6f1e490462419a40
]]
