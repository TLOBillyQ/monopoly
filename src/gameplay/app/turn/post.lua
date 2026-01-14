local UI = require("src.gameplay.ports.ui_port")
local Choice = require("src.gameplay.app.choice")
local items_cfg = require("src.config.items")

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local function eligible_for_post(cfg)
  if not cfg then
    return false
  end
  local timing = cfg.timing or "manual"
  return timing == "manual" or timing == "turn" or timing == "post_action"
end

local function build_options(player)
  local options = {}
  local body_lines = {}
  for _, it in ipairs(player.inventory.items or {}) do
    local cfg = cfg_by_id[it.id]
    if eligible_for_post(cfg) then
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

local function phase_post(tm, args)
  local player = args.player or tm.game:current_player()
  local store = tm.game and tm.game.store
  local flag = store and store:get({ "turn", "post_action" }) or nil
  if flag and flag.done then
    if store then
      store:set({ "turn", "post_action" }, nil)
    end
    return "end_turn", { player = player }
  end

  if not UI.is_available(tm.game) then
    if store then
      store:set({ "turn", "post_action" }, { done = true })
    end
    return "end_turn", { player = player }
  end

  local body_lines, options = build_options(player)
  if #options == 0 then
    if store then
      store:set({ "turn", "post_action" }, { done = true })
    end
    return "end_turn", { player = player }
  end

  Choice.open(tm.game, {
    kind = "post_action_item",
    title = "行动后：使用道具？",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "结束回合",
    meta = { player_id = player.id },
  })

  if store then
    store:set({ "turn", "post_action" }, { active = true })
  end
  return "wait_choice", { resume_state = "post_action", resume_args = { player = player } }
end

return phase_post
