local timing = require("src.config.gameplay.timing")
local auto_play_port = require("src.rules.ports.auto_play")
local strategy = require("src.rules.items.strategy")
local availability = require("src.rules.items.availability")
local inventory = require("src.rules.items.inventory")
local intent_output_port = require("src.rules.ports.intent_output")
local item_config = require("src.rules.items.config")
local dirty_tracker = require("src.state.dirty_tracker")

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

local function _patch_move_followup_args(next_state, next_args, default_next_state, default_next_args)
  if next_state ~= "move_followup" or type(next_args) ~= "table" then
    return next_state, next_args
  end
  next_args.next_state = next_args.next_state or default_next_state
  next_args.next_args = next_args.next_args or default_next_args
  return next_state, next_args
end

local function _resolve_after_action_anim(args, res)
  local next_state = args.next_state
  local next_args = args.next_args
  local after_action_anim = type(res) == "table" and res.after_action_anim or nil
  if type(after_action_anim) ~= "table" then
    return next_state, next_args
  end
  return _patch_move_followup_args(
    after_action_anim.next_state or next_state,
    after_action_anim.next_args or next_args,
    args.next_state,
    args.next_args
  )
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
  dirty_tracker.mark(game.dirty, "turn")
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

function phase_module.reopen_or_finish(game, player, meta)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  assert(type(meta) == "table", "missing phase meta")
  local spec = phase_module.build_passive_choice_spec(game, player, meta.phase, {
    next_state = meta.resume_next_state,
    next_args = meta.resume_next_args,
  })
  if spec == nil then
    phase_module.finish(game, meta.phase)
    return false
  end
  intent_output_port.open_choice(game, spec)
  phase_module.mark_active(game, meta.phase)
  return true
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
    local item = item_slots[slot_index]
    local available = false
    local alert = false
    local alert_text = nil
    local item_id = nil
    local deny_reason = nil
    if type(item) == "table" and item.id ~= nil then
      local can_offer, dr = availability.can_offer_in_phase(game, player, item.id, phase)
      available = can_offer == true
      item_id = item.id
      deny_reason = not available and dr or nil
      local cfg = inventory.cfg(item.id)
      local item_name = cfg and cfg.name or nil
      if available then
        if cfg and cfg.prompt_style == "alert" then
          alert = true
          alert_text = (item_name or "") .. "可用！"
        end
      end
    end
    slot_states[slot_index] = {
      available = available,
      alert = alert,
      alert_text = alert_text,
      item_id = item_id,
      deny_reason = deny_reason,
    }
  end

  local sorted = {}
  for i = 1, 5 do
    if slot_states[i].item_id ~= nil and slot_states[i].available then
      sorted[#sorted + 1] = slot_states[i]
    end
  end
  for i = 1, 5 do
    if slot_states[i].item_id ~= nil and not slot_states[i].available then
      sorted[#sorted + 1] = slot_states[i]
    end
  end
  for i = 1, 5 do
    if slot_states[i].item_id == nil then
      sorted[#sorted + 1] = slot_states[i]
    end
  end
  slot_states = sorted

  local options = {}
  for _, ss in ipairs(slot_states) do
    if ss.available and ss.item_id ~= nil then
      local cfg = inventory.cfg(ss.item_id)
      local item_name = cfg and cfg.name or nil
      options[#options + 1] = {
        id = ss.item_id,
        label = item_name or tostring(ss.item_id),
        confirm_title = cfg and cfg.name or nil,
        confirm_body = cfg and cfg.description or nil,
      }
    end
  end

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
