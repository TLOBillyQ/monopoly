local items_cfg = require("Config.Generated.Items")
local gameplay_rules = require("src.core.config.GameplayRules")
local agent = require("src.game.core.runtime.Agent")
local strategy = require("src.game.systems.items.ItemStrategy")
local inventory = require("src.game.systems.items.ItemInventory")
local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")

local item_phase = {}

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

function item_phase.is_enabled(phase)
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

function item_phase.finish(game, phase)
  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = { done = true }
  local active = game.turn.item_phase_active
  if active == phase then
    game.turn.item_phase_active = ""
  end
  game.dirty.turn = true
  game.dirty.any = true
end

function item_phase.run(turn_mgr, phase, args)
  local game = turn_mgr.game
  local player = args.player
  assert(player ~= nil, "missing player")
  if not item_phase.is_enabled(phase) then
    return nil
  end

  local item_phases = game.turn.item_phase
  local phase_state = item_phases and item_phases[phase]
  if phase_state and phase_state.done then
    game.turn.item_phase = game.turn.item_phase or {}
    game.turn.item_phase[phase] = nil
    game.dirty.turn = true
    game.dirty.any = true
    return nil
  end

  if agent.is_auto_player(player) then
    local pre = strategy.auto_pre_action(game, player, phase)
    if pre then
      intent_dispatcher.dispatch(game, pre)
    end
    if pre and pre.waiting then
      game.turn.item_phase_active = phase
      game.dirty.turn = true
      game.dirty.any = true
      return { waiting = true, next_state = args.next_state, next_args = args.next_args }
    end
    if game.turn.action_anim then
      item_phase.finish(game, phase)
      return { waiting = true, wait_action_anim = true, next_state = args.next_state, next_args = args.next_args }
    end
    item_phase.finish(game, phase)
    return nil
  end

  local spec = item_phase.build_choice_spec(game, player, phase)
  if spec == nil then
    item_phase.finish(game, phase)
    return nil
  end

  intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })

  game.turn.item_phase = game.turn.item_phase or {}
  game.turn.item_phase[phase] = { active = true }
  game.turn.item_phase_active = phase
  game.dirty.turn = true
  game.dirty.any = true

  return { waiting = true, next_state = args.next_state, next_args = args.next_args }
end

function item_phase.build_choice_spec(game, player, phase)
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

return item_phase
