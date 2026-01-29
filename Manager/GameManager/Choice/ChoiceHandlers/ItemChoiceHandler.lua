local Inventory = require("Manager.GameManager.Item.ItemInventory")
local Demolish = require("Manager.GameManager.Item.ItemDemolish")
local Steal = require("Manager.GameManager.Item.ItemSteal")
local Roadblock = require("Manager.GameManager.Item.ItemRoadblock")
local logger = require("Library.Monopoly.Logger")
local IntentDispatcher = require("Library.Monopoly.IntentDispatcher")
local Convert = require("Library.Monopoly.Convert")
local RemoteDice = require("Manager.GameManager.Item.ItemRemoteDice")
local ItemPhase = require("Manager.GameManager.Item.ItemPhase")
local gameplay_constants = require("Manager.GameManager.System.Constants")

local ItemChoiceHandler = {}
local ITEM_IDS = gameplay_constants.item_ids

function ItemChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice
  local use_item = helpers.use_item
  local finish_item_phase = helpers.finish_item_phase
  local finish_active_item_phase = helpers.finish_active_item_phase

  local function finish_and_clear(game)
    finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function open_steal_item_choice(game, stealer, target)
    local lines = {}
    local options = {}
    for i, it in ipairs(Inventory.items(target)) do
      local label = Inventory.item_name(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    IntentDispatcher.dispatch(game, {
      kind = "need_choice",
      choice_spec = {
        kind = "steal_item",
        title = "选择要偷的道具",
        body_lines = lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { player_id = stealer.id, target_id = target.id },
      },
    })
  end

  local function open_discard_item_choice(game, player, phase)
    local lines = {}
    local options = {}
    for i, it in ipairs(Inventory.items(player)) do
      local label = Inventory.item_name(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    IntentDispatcher.dispatch(game, {
      kind = "need_choice",
      choice_spec = {
        kind = "discard_item",
        title = "选择要丢弃的道具",
        body_lines = lines,
        options = options,
        allow_cancel = true,
        cancel_label = "返回",
        meta = { player_id = player.id, phase = phase },
      },
    })
  end

  local function reopen_item_phase(game, player, phase)
    local spec = ItemPhase.build_choice_spec(player, phase)
    if not spec then
      finish_item_phase(game, phase)
      return finish_choice(game, false)
    end
    IntentDispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
    return { stay = true }
  end

  local function handle_demolish_target(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = Convert.to_number(action.option_id)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    if idx and player then
      if meta.item_id then
        Inventory.consume(player, meta.item_id)
      end
      local res = Demolish.apply(game, player, idx, {
        services = game:get_services(),
        injure = meta.injure,
        title = meta.title
      })
      IntentDispatcher.dispatch(game, res.intent)
    end
    return finish_and_clear(game)
  end

  local function handle_roadblock_target(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = Convert.to_number(action.option_id)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    if not player or not idx then
      return finish_and_clear(game)
    end
    if meta.item_id then
      if not Inventory.consume(player, meta.item_id) then
        return finish_and_clear(game)
      end
    end
    local res = Roadblock.apply(game, player, idx)
    if res then
      IntentDispatcher.dispatch(game, res)
    end
    return finish_and_clear(game)
  end

  local function handle_steal_item(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = Convert.to_number(action.option_id)
    local meta = choice.meta
    local stealer = game.players[meta.player_id]
    local target = game.players[meta.target_id]
    if stealer and target and idx then
      local res = Steal.steal_item_at_index(game, stealer, target, idx)
      logger.event("Steal choice result (multi)", res)
      if res and res.intent then
        IntentDispatcher.dispatch(game, res.intent)
      end
    end
    return finish_and_clear(game)
  end

  local function handle_steal_prompt(game, choice, action)
    if is_cancel(action) then
      return finish_choice(game, false)
    end
    local meta = choice.meta
    local stealer = game.players[meta.player_id]
    local target = game.players[meta.target_id]
    if not stealer or not target or target.eliminated then
      return finish_choice(game, false)
    end

    if action and action.option_id == "use" then
      if Inventory.count(target) <= 0 then
        if Inventory.consume(stealer, ITEM_IDS.steal) then
          local res = Steal.steal_item_at_index(game, stealer, target, 1)
          if res and res.intent then
            IntentDispatcher.dispatch(game, res.intent)
          end
        end
        return finish_choice(game, false)
      end
      if Inventory.count(target) <= 1 then
        local res = Steal.steal_item_at_index(game, stealer, target, 1)
        if res and res.intent then
          IntentDispatcher.dispatch(game, res.intent)
        end
        return finish_choice(game, false)
      end
      open_steal_item_choice(game, stealer, target)
      return { stay = true }
    end

    local next_index = meta.index + 1
    local queue = meta.queue
    if Inventory.find_index(stealer, ITEM_IDS.steal) and queue[next_index] then
      local spec = Steal.build_prompt_spec(game, stealer, queue, next_index)
      if spec then
        IntentDispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
        return { stay = true }
      end
    end

    return finish_choice(game, false)
  end

  local function handle_item_target_player(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local target_id = Convert.to_number(action.option_id)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local item_id = meta.item_id
    if player and target_id and item_id then
      local res = use_item(game, player, item_id, { target_id = target_id })
      if res and res.waiting then return { stay = true } end
    end
    return finish_and_clear(game)
  end

  local function handle_remote_dice_value(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local value = Convert.to_number(action.option_id)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local dice_count = meta.dice_count or player:dice_count()
    if not player or not value then
      return finish_and_clear(game)
    end
    if meta.item_id then
      if not Inventory.consume(player, meta.item_id) then
        return finish_and_clear(game)
      end
    end
    RemoteDice.apply(game, player, dice_count, value)
    return finish_and_clear(game)
  end

  local function handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local phase = meta.phase
    if is_cancel(action) then
      finish_item_phase(game, phase)
      return finish_choice(game, false)
    end
    local item_id = Convert.to_number(action.option_id)
    if not item_id and action.option_id == "discard_item" then
      finish_choice(game, false)
      open_discard_item_choice(game, player, phase)
      return { stay = true }
    end
    if not item_id then
      return finish_choice(game, false)
    end

    local res = use_item(game, player, item_id)
    if type(res) == "table" and res.waiting then
      if res.intent then
        IntentDispatcher.dispatch(game, res.intent)
      end
      return { stay = true }
    end
    finish_item_phase(game, phase)
    return finish_choice(game, false)
  end

  local function handle_discard_item(game, choice, action)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local phase = meta.phase
    if is_cancel(action) then
      finish_choice(game, false)
      return reopen_item_phase(game, player, phase)
    end
    local idx = Convert.to_number(action.option_id)
    if not idx then
      finish_choice(game, false)
      return reopen_item_phase(game, player, phase)
    end
    local dropped = Inventory.remove_by_index(player, idx)
    if dropped then
      logger.event(player.name .. " 丢弃道具 " .. Inventory.item_name(dropped.id))
    end
    finish_choice(game, false)
    return reopen_item_phase(game, player, phase)
  end

  return {
    item_phase_choice = handle_item_phase_choice,
    demolish_target = handle_demolish_target,
    roadblock_target = handle_roadblock_target,
    steal_item = handle_steal_item,
    steal_prompt = handle_steal_prompt,
    item_target_player = handle_item_target_player,
    remote_dice_value = handle_remote_dice_value,
    discard_item = handle_discard_item,
  }
end

return ItemChoiceHandler
