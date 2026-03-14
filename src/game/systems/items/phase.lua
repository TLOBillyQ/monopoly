local items_cfg = require("src.config.content.items")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local auto_play_port = require("src.game.ports.auto_play_port")
local strategy = require("src.game.systems.items.strategy")
local inventory = require("src.game.systems.items.inventory")
local intent_output_port = require("src.game.ports.intent_output_port")

local phase_module = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local phase_titles = {
  pre_action = "行动前：使用道具？",
  pre_move = "投骰后：使用道具？",
  post_action = "行动后：使用道具？",
}

local phase_confirm_titles = {
  pre_action = "行动前",
  pre_move = "投骰后",
  post_action = "行动后",
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
  local queue = gameplay_rules.item_phase_queue
  assert(type(queue) == "table", "invalid item_phase_queue")
  for _, name in ipairs(queue) do
    if name == phase then
      return true
    end
  end
  return false
end

local function _build_options(game, player, phase)
  local options = {}
  local body_lines = {}
  for _, it in ipairs(inventory.items(player)) do
    local cfg = cfg_by_id[it.id]
    if cfg and strategy.can_offer_in_phase(game, player, it.id, phase) then
      table.insert(options, { id = it.id, label = cfg.name })
      options[#options].confirm_title = phase_confirm_titles[phase] or "本回合"
      options[#options].confirm_body = "将使用：" .. cfg.name
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
  game.dirty.turn = true
  game.dirty.any = true
end

local function _clear_finished_phase(game, phase)
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = nil
  game.dirty.turn = true
  game.dirty.any = true
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
  game.dirty.turn = true
  game.dirty.any = true
end

local function _resolve_auto_phase_wait(game, phase, args, pre)
  if not (pre and pre.waiting) then
    return nil
  end
  _mark_waiting_phase(game, phase)
  return { waiting = true, next_state = args.next_state, next_args = args.next_args }
end

local function _resolve_auto_phase_action_anim(game, phase, args, pre)
  if not game.turn.action_anim then
    return nil
  end
  local next_state, next_args = _resolve_after_action_anim(args, pre)
  phase_module.finish(game, phase)
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
    game.dirty.turn = true
    game.dirty.any = true
  end
  return { waiting = true, wait_action_anim = true, next_state = next_state, next_args = next_args }
end

local function _run_auto_phase(game, player, phase, args)
  local pre = strategy.auto_pre_action(game, player, phase)
  if pre then
    intent_output_port.dispatch(game, pre)
  end
  local wait_res = _resolve_auto_phase_wait(game, phase, args, pre)
  if wait_res ~= nil then
    return wait_res
  end
  local anim_res = _resolve_auto_phase_action_anim(game, phase, args, pre)
  if anim_res ~= nil then
    return anim_res
  end
  phase_module.finish(game, phase)
  return nil
end

local function _mark_player_choice_phase(game, phase)
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = { active = true }
  game.turn.item_phase_active = phase
  game.dirty.turn = true
  game.dirty.any = true
end

local function _run_player_phase(game, player, phase, args)
  local spec = phase_module.build_choice_spec(game, player, phase)
  if spec == nil then
    phase_module.finish(game, phase)
    return nil
  end
  intent_output_port.open_choice(game, spec)
  _mark_player_choice_phase(game, phase)
  return { waiting = true, next_state = args.next_state, next_args = args.next_args }
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

function phase_module.build_choice_spec(game, player, phase)
  assert(game ~= nil, "missing game")
  assert(player ~= nil, "missing player")
  local body_lines, options = _build_options(game, player, phase)
  if #options == 0 then
    return nil
  end
  local option_labels = {}
  for _, option in ipairs(options) do
    if option.label and option.label ~= "" then
      option_labels[#option_labels + 1] = option.label
    end
  end
  return {
    kind = "item_phase_choice",
    route_key = "base_inline",
    owner_role_id = player.id,
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    title = phase_titles[phase],
    body_lines = body_lines,
    options = options,
    confirm_title = phase_confirm_titles[phase] or "本回合",
    confirm_body = #option_labels > 0 and ("可用道具：" .. table.concat(option_labels, "、")) or "请再确认一次",
    allow_cancel = true,
    cancel_label = "结束阶段",
    meta = { player_id = player.id, phase = phase },
  }
end

return phase_module
