local logger = require("src.util.logger")
local Choice = require("src.gameplay.app.choice")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")
local Inventory = require("src.gameplay.domain.item_inventory")
local Strategy = require("src.gameplay.domain.item_strategy")
local Executor = require("src.gameplay.domain.item_executor")

local function phase_start(tm)
  local player = tm.game:current_player()
  local tc = (tm.game.store and tm.game.store:get({ "turn", "turn_count" })) or 0
  tc = tc + 1
  if tm.game.store then
    tm.game.store:set({ "turn", "turn_count" }, tc)
  end
  tm.game.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  if player.eliminated then
    tm.game.last_turn.note = "已出局，跳过"
    tm.game.last_turn.skipped = true
    return "end_turn", { player = player }
  end
  if player.status.stay_turns and player.status.stay_turns > 0 then
    tm.game:set_player_status(player, "stay_turns", player.status.stay_turns - 1)
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    tm.game.last_turn.note = "被扣留"
    tm.game.last_turn.skipped = true
    tm.game.last_turn.stay_turns = player.status.stay_turns
    return "end_turn", { player = player }
  end

  local pre = Strategy.auto_pre_action(tm.game, player, {
    inventory = Inventory,
    find_monster_target = Executor.find_monster_target,
    find_missile_target = Executor.find_missile_target,
    use_item = function(g, p, id, ctx)
      ctx = ctx or { by_ai = true }
      ctx.services = g.services
      return Executor.use_item(g, p, id, ctx, { inventory = Inventory, strategy = Strategy })
    end,
  })

  if pre then
    IntentDispatcher.dispatch(tm.game, pre)
  end
  if pre and pre.waiting then
    return "wait_choice", { resume_state = "roll", resume_args = { player = player } }
  end
  return "roll", { player = player }
end

return phase_start
