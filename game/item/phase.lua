local items_cfg = require("cfg.Generated.Items")
local gameplay_rules = require("cfg.GameplayRules")
local agent = require("game.rule.agent")
local strategy = require("game.item.strategy")
local inventory = require("game.item.inventory")
local intent_dispatcher = require("turn.intent")

local phase = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local phase_titles = {
  pre_action = "行动前：使用道具？",
  pre_move = "投骰后：使用道具？",
  post_action = "行动后：使用道具？",
}

function phase.is_enabled(phase_name)
  local queue = gameplay_rules.item_phase_queue
  assert(type(queue) == "table", "invalid item_phase_queue")
  for _, name in ipairs(queue) do
    if name == phase_name then
      return true
    end
  end
  return false
end

local function _build_options(player, phase_name)
  local options = {}
  local body_lines = {}
  for _, it in ipairs(inventory.items(player)) do
    local cfg = cfg_by_id[it.id]
    local timing = cfg.timing
    if strategy.timing_allowed(phase_name, timing, false) then
      table.insert(options, { id = it.id, label = cfg.name })
      local line = cfg.name
      if cfg.usage and #cfg.usage > 0 then
        line = line .. "：" .. cfg.usage
      end
      table.insert(body_lines, line)
    end
  end
  return body_lines, options
end

function phase.finish(game, phase_name)
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase_name] = { done = true }
  local active = game.turn.item_phase_active
  if active == phase_name then
    game.turn.item_phase_active = ""
  end
  game.dirty.turn = true
  game.dirty.any = true
end

function phase.run(turn_mgr, phase_name, args)
  local game = turn_mgr.game
  local player = args.player
  assert(player ~= nil, "missing player")
  if not phase.is_enabled(phase_name) then
    return nil
  end

  local item_phases = game.turn.item_phase
  local phase_state = item_phases and item_phases[phase_name]
  if phase_state and phase_state.done then
    game.turn.item_phase = game.turn.item_phase or {}
    game.turn.item_phase[phase_name] = nil
    game.dirty.turn = true
    game.dirty.any = true
    return nil
  end

  if agent.is_auto_player(player) then
    local pre = strategy.auto_pre_action(game, player, phase_name)
    if pre then
      intent_dispatcher.dispatch(game, pre)
    end
    if pre and pre.waiting then
      game.turn.item_phase_active = phase_name
      game.dirty.turn = true
      game.dirty.any = true
      return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    if game.turn.action_anim then
      phase.finish(game, phase_name)
      return { waiting = true, wait_action_anim = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    phase.finish(game, phase_name)
    return nil
  end

  assert(game.ui_port ~= nil, "missing ui_port")

  local spec = phase.build_choice_spec(player, phase_name)
  if spec == nil then
    phase.finish(game, phase_name)
    return nil
  end

  intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })

  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase_name] = { active = true }
  game.turn.item_phase_active = phase_name
  game.dirty.turn = true
  game.dirty.any = true

  return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
end

function phase.build_choice_spec(player, phase_name)
  local body_lines, options = _build_options(player, phase_name)
  if #options == 0 then
    return nil
  end
  return {
    kind = "item_phase_choice",
    title = phase_titles[phase_name],
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "结束阶段",
    meta = { player_id = player.id, phase = phase_name },
  }
end

return phase
