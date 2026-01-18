local Inventory = require("src.gameplay.item_inventory")
local Demolish = require("src.gameplay.item_demolish")
local Steal = require("src.gameplay.item_steal")
local Roadblock = require("src.gameplay.item_roadblock")
local logger = require("src.util.logger")
local IntentDispatcher = require("src.util.intent_dispatcher")
local Convert = require("src.util.convert")
local RemoteDice = require("src.gameplay.item_remote_dice")

local ItemChoiceHandler = {}

function ItemChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local clear_choice = helpers.clear_choice
  local use_item = helpers.use_item
  local finish_item_phase = helpers.finish_item_phase
  local finish_active_item_phase = helpers.finish_active_item_phase

  local function finish_and_clear(game)
    finish_active_item_phase(game)
    clear_choice(game)
    return { stay = false }
  end

  local function open_steal_item_choice(game, stealer, target)
    local lines = {}
    local options = {}
    for i, it in ipairs(target.inventory.items) do
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
        meta = { stealer_id = stealer.id, target_id = target.id },
      },
    })
  end

  local function handle_demolish_target(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = Convert.to_number(action.option_id)
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
    if idx and player then
      if meta.item_id then
        Inventory.consume(player, meta.item_id)
      end
      local res = Demolish.apply(game, player, idx, {
        services = game and game.get_services and game:get_services(),
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
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
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
    local meta = choice.meta or {}
    local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
    local target = meta.target_id and game.players[meta.target_id]
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
      clear_choice(game)
      return { stay = false }
    end
    local meta = choice.meta or {}
    local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
    local target = meta.target_id and game.players[meta.target_id]
    if not stealer or not target or target.eliminated then
      clear_choice(game)
      return { stay = false }
    end

    if action and action.option_id == "use" then
      if target.inventory:count() <= 0 then
        if Inventory.consume(stealer, 2007) then
          local res = Steal.steal_item_at_index(game, stealer, target, 1)
          if res and res.intent then
            IntentDispatcher.dispatch(game, res.intent)
          end
        end
        clear_choice(game)
        return { stay = false }
      end
      if target.inventory:count() <= 1 then
        local res = Steal.steal_item_at_index(game, stealer, target, 1)
        if res and res.intent then
          IntentDispatcher.dispatch(game, res.intent)
        end
        clear_choice(game)
        return { stay = false }
      end
      open_steal_item_choice(game, stealer, target)
      return { stay = true }
    end

    local next_index = (meta.index or 1) + 1
    local queue = meta.queue or {}
    if Inventory.find_index(stealer, 2007) and queue[next_index] then
      local spec = Steal.build_prompt_spec(game, stealer, queue, next_index)
      if spec then
        IntentDispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
        return { stay = true }
      end
    end

    clear_choice(game)
    return { stay = false }
  end

  local function handle_item_target_player(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local target_id = Convert.to_number(action.option_id)
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
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
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
    local dice_count = meta.dice_count or (player and player.dice_count and player:dice_count()) or 1
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
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
    local phase = meta.phase
    if is_cancel(action) then
      finish_item_phase(game, phase)
      clear_choice(game)
      return { stay = false }
    end
    if not player then
      clear_choice(game)
      return { stay = false }
    end
    local item_id = Convert.to_number(action.option_id)
    if not item_id then
      clear_choice(game)
      return { stay = false }
    end

    local res = use_item(game, player, item_id)
    if type(res) == "table" and res.waiting then
      if res.intent then
        IntentDispatcher.dispatch(game, res.intent)
      end
      return { stay = true }
    end
    finish_item_phase(game, phase)
    clear_choice(game)
    return { stay = false }
  end

  return {
    item_phase_choice = handle_item_phase_choice,
    demolish_target = handle_demolish_target,
    roadblock_target = handle_roadblock_target,
    steal_item = handle_steal_item,
    steal_prompt = handle_steal_prompt,
    item_target_player = handle_item_target_player,
    remote_dice_value = handle_remote_dice_value,
  }
end

return ItemChoiceHandler
