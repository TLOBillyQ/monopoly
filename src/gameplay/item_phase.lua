local IntentDispatcher = require("src.util.intent_dispatcher")
local items_cfg = require("src.config.items")
local constants = require("src.config.constants")
local DecisionEngine = require("src.gameplay.decision_engine")
local Agent = require("src.gameplay.agent")

local ItemPhase = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local PHASE_TITLES = {
  pre_action = "行动前：使用道具？",
  pre_move = "投骰后：使用道具？",
  post_action = "行动后：使用道具？",
}

local PHASE_TIMING = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, manual = true, turn = true },
}

local function timing_allowed(phase, timing)
  local allowed = PHASE_TIMING[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

function ItemPhase.is_enabled(game, phase)
  local queue = constants.item_phase_queue
  if type(queue) ~= "table" then
    return true
  end
  for _, name in ipairs(queue) do
    if name == phase then
      return true
    end
  end
  return false
end

local function build_options(player, phase)
  local options = {}
  local body_lines = {}
  for _, it in ipairs(player.inventory.items or {}) do
    local cfg = cfg_by_id[it.id]
    local timing = cfg and cfg.timing or "manual"
    if timing_allowed(phase, timing) then
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

function ItemPhase.finish(game, phase)
  if game and game.store then
    game.store:set({ "turn", "item_phase", phase }, { done = true })
    local active = game.store:get({ "turn", "item_phase_active" })
    if active == phase then
      game.store:set({ "turn", "item_phase_active" }, nil)
    end
  end
end

function ItemPhase.run(tm, phase, args)
  local game = tm.game
  local player = args.player or game:current_player()
  if not ItemPhase.is_enabled(game, phase) then
    return nil
  end

  local store = game and game.store
  local phase_state = store and store:get({ "turn", "item_phase", phase }) or nil
  if phase_state and phase_state.done then
    if store then
      store:set({ "turn", "item_phase", phase }, nil)
    end
    return nil
  end

  if Agent.is_auto_player(player) then
    local pre = DecisionEngine.get_phase_action(game, player, phase)
    if pre then
      IntentDispatcher.dispatch(game, pre)
    end
    if pre and pre.waiting then
      if store then
        store:set({ "turn", "item_phase_active" }, phase)
      end
      return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    ItemPhase.finish(game, phase)
    return nil
  end

  if game.ui_port == nil then
    ItemPhase.finish(game, phase)
    return nil
  end

  local body_lines, options = build_options(player, phase)
  if #options == 0 then
    ItemPhase.finish(game, phase)
    return nil
  end

  IntentDispatcher.dispatch(game, {
    kind = "need_choice",
    choice_spec = {
      kind = "item_phase_choice",
      title = PHASE_TITLES[phase] or "使用道具？",
      body_lines = body_lines,
      options = options,
      allow_cancel = true,
      cancel_label = "结束阶段",
      meta = { player_id = player.id, phase = phase },
    },
  })

  if store then
    store:set({ "turn", "item_phase", phase }, { active = true })
    store:set({ "turn", "item_phase_active" }, phase)
  end

  return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
end

return ItemPhase
