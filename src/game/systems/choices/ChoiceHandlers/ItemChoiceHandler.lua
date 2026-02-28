local inventory = require("src.game.systems.items.ItemInventory")
local demolish = require("src.game.systems.items.ItemDemolish")
local steal = require("src.game.systems.items.ItemSteal")
local roadblock = require("src.game.systems.items.ItemRoadblock")
local logger = require("src.core.Logger")
local remote_dice = require("src.game.systems.items.ItemRemoteDice")
local item_phase = require("src.game.systems.items.ItemPhase")
local gameplay_rules = require("Config.GameplayRules")
local number_utils = require("src.core.NumberUtils")
local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")

local item_choice_handler = {}
local item_ids = gameplay_rules.item_ids

function item_choice_handler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice
  local use_item = helpers.use_item
  local finish_item_phase = helpers.finish_item_phase
  local finish_active_item_phase = helpers.finish_active_item_phase

  local function _finish_and_clear(game)
    finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function _open_steal_item_choice(game, stealer, target)
    local lines = {}
    local options = {}
    for i, it in ipairs(inventory.items(target)) do
      local label = inventory.item_name(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    intent_dispatcher.dispatch(game, {
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

  local function _reopen_item_phase(game, player, phase)
    local spec = item_phase.build_choice_spec(game, player, phase)
    if spec == nil then
      finish_item_phase(game, phase)
      return nil
    end
    intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
    return { stay = true }
  end

  local function _handle_demolish_target(game, choice, action)
    if is_cancel(action) then
      return _finish_and_clear(game)
    end
    local idx = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(idx ~= nil, "missing demolish index")
    if meta.item_id then
      inventory.consume(player, meta.item_id)
    end
    local res = demolish.apply(game, player, idx, {
      injure = meta.injure,
      title = meta.title
    })
    local intent = res.intent or {}
    intent_dispatcher.dispatch(game, intent)
    return _finish_and_clear(game)
  end

  local function _handle_roadblock_target(game, choice, action)
    if is_cancel(action) then
      return _finish_and_clear(game)
    end
    local idx = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(idx ~= nil, "missing roadblock index")
    if meta.item_id then
      inventory.consume(player, meta.item_id)
    end
    local res = roadblock.apply(game, player, idx)
    if res then
      intent_dispatcher.dispatch(game, res)
    end
    return _finish_and_clear(game)
  end

  local function _handle_steal_item(game, choice, action)
    if is_cancel(action) then
      return _finish_and_clear(game)
    end
    local idx = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local stealer = assert(game:find_player_by_id(meta.player_id), "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game:find_player_by_id(meta.target_id), "missing target: " .. tostring(meta.target_id))
    assert(idx ~= nil, "missing steal index")
    local res = steal.steal_item_at_index(game, stealer, target, idx)
    logger.event("Steal choice result (multi)", res)
    assert(res ~= nil, "missing steal result")
    intent_dispatcher.dispatch(game, res.intent or {})
    return _finish_and_clear(game)
  end

  local function _handle_steal_prompt(game, choice, action)
    if is_cancel(action) then
      return finish_choice(game, false)
    end
    local meta = choice.meta
    local stealer = assert(game:find_player_by_id(meta.player_id), "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game:find_player_by_id(meta.target_id), "missing target: " .. tostring(meta.target_id))
    if target.eliminated then
      return finish_choice(game, false)
    end

    assert(action ~= nil, "missing action")
    if action.option_id == "use" then
      if inventory.count(target) <= 1 then
        local res = steal.steal_item_at_index(game, stealer, target, 1)
        if res then
          intent_dispatcher.dispatch(game, res.intent or {})
        end
        return finish_choice(game, false)
      end
      _open_steal_item_choice(game, stealer, target)
      return { stay = true }
    end

    local next_index = meta.index + 1
    local queue = meta.queue
    if inventory.find_index(stealer, item_ids.steal) and queue[next_index] then
      local spec = steal.build_prompt_spec(game, stealer, queue, next_index)
      assert(spec ~= nil, "missing steal prompt spec")
      intent_dispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })
      return { stay = true }
    end

    return finish_choice(game, false)
  end

  local function _handle_item_target_player(game, choice, action)
    if is_cancel(action) then
      return _finish_and_clear(game)
    end
    local target_id = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local item_id = assert(meta.item_id, "missing item_id")
    assert(target_id ~= nil, "missing target_id")
    local res = use_item(game, player, item_id, { target_id = target_id })
    assert(res ~= nil, "missing use_item result")
    if res.waiting then return { stay = true } end
    return _finish_and_clear(game)
  end

  local function _handle_remote_dice_value(game, choice, action)
    if is_cancel(action) then
      return _finish_and_clear(game)
    end
    local value = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(value ~= nil, "missing dice value")
    local dice_count = meta.dice_count or game:player_dice_count(player)
    if meta.item_id then
      inventory.consume(player, meta.item_id)
    end
    remote_dice.apply(game, player, dice_count, value)
    return _finish_and_clear(game)
  end

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local phase = meta.phase
    if is_cancel(action) then
      finish_item_phase(game, phase)
      return finish_choice(game, false)
    end
    local item_id = number_utils.to_integer(action.option_id)
    assert(item_id ~= nil, "missing item_id")

    local res = use_item(game, player, item_id)
    if type(res) == "table" and res.waiting then
      intent_dispatcher.dispatch(game, res.intent or {})
      return { stay = true }
    end
    finish_item_phase(game, phase)
    return finish_choice(game, false)
  end

  return {
    item_phase_choice = _handle_item_phase_choice,
    demolish_target = _handle_demolish_target,
    roadblock_target = _handle_roadblock_target,
    steal_item = _handle_steal_item,
    steal_prompt = _handle_steal_prompt,
    item_target_player = _handle_item_target_player,
    remote_dice_value = _handle_remote_dice_value,
  }
end

return item_choice_handler
