local inventory = require("src.game.systems.items.item_inventory")
local demolish = require("src.game.systems.items.item_demolish")
local steal = require("src.game.systems.items.item_steal")
local roadblock = require("src.game.systems.items.item_roadblock")
local logger = require("src.core.utils.logger")
local remote_dice = require("src.game.systems.items.item_remote_dice")
local item_phase = require("src.game.systems.items.item_phase")
local gameplay_rules = require("src.core.config.gameplay_rules")
local number_utils = require("src.core.utils.number_utils")
local intent_output_port = require("src.game.ports.intent_output_port")
local item_use_broadcast = require("src.game.systems.items.item_use_broadcast")

local item_choice_handler = {}
local item_ids = gameplay_rules.item_ids

local function _finish_item_target_choice(helpers, game)
  helpers.finish_active_item_phase(game)
  return helpers.finish_choice(game, false)
end

function item_choice_handler.build(helpers)
  local finish_choice = helpers.finish_choice
  local use_item = helpers.use_item
  local finish_item_phase = helpers.finish_item_phase

  local function _consume_if_needed(player, item_id, already_consumed)
    if not item_id or already_consumed == true then
      return
    end
    assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
  end

  local function _open_steal_item_choice(game, stealer, target)
    local lines = {}
    local options = {}
    for index, item in ipairs(inventory.items(target)) do
      local label = inventory.item_name(item.id)
      table.insert(lines, index .. ". " .. label)
      table.insert(options, { id = index, label = label })
    end
    intent_output_port.open_choice(game, {
      kind = "steal_item",
      owner_role_id = stealer.id,
      title = "选择要偷的道具",
      body_lines = lines,
      options = options,
      allow_cancel = true,
      cancel_label = "取消",
      meta = { player_id = stealer.id, target_id = target.id },
    })
  end

  local function _handle_demolish_target(game, choice, action)
    local index = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(index ~= nil, "missing demolish index")
    _consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = demolish.apply(game, player, index, {
      injure = meta.injure,
      title = meta.title,
    })
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    local intent = result.intent or {}
    intent_output_port.dispatch(game, intent)
    return _finish_item_target_choice(helpers, game)
  end

  local function _handle_roadblock_target(game, choice, action)
    local index = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(index ~= nil, "missing roadblock index")
    if not roadblock.is_ui_candidate(game, player, index) then
      logger.warn(player.name .. " 选择了无效的路障位置: " .. tostring(index))
      return { stay = true }
    end
    _consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = roadblock.apply(game, player, index)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
      intent_output_port.dispatch(game, result)
    end
    return _finish_item_target_choice(helpers, game)
  end

  local function _handle_steal_item(game, choice, action)
    local index = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local stealer = assert(game:find_player_by_id(meta.player_id), "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game:find_player_by_id(meta.target_id), "missing target: " .. tostring(meta.target_id))
    assert(index ~= nil, "missing steal index")
    local result = steal.steal_item_at_index(game, stealer, target, index)
    assert(result ~= nil, "missing steal result")
    intent_output_port.dispatch(game, result.intent or {})
    return _finish_item_target_choice(helpers, game)
  end

  local function _handle_steal_prompt(game, choice, action)
    local meta = choice.meta
    local stealer = assert(game:find_player_by_id(meta.player_id), "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game:find_player_by_id(meta.target_id), "missing target: " .. tostring(meta.target_id))
    if target.eliminated then
      return finish_choice(game, false)
    end

    if action.option_id == "use" then
      if inventory.count(target) <= 1 then
        local result = steal.steal_item_at_index(game, stealer, target, 1)
        if result then
          intent_output_port.dispatch(game, result.intent or {})
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
      intent_output_port.open_choice(game, spec)
      return { stay = true }
    end

    return finish_choice(game, false)
  end

  local function _handle_item_target_player(game, choice, action)
    local target_id = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local item_id = assert(meta.item_id, "missing item_id")
    assert(target_id ~= nil, "missing target_id")
    local result = use_item(game, player, item_id, {
      target_id = target_id,
      item_preconsumed = meta.item_preconsumed == true,
    })
    assert(result ~= nil, "missing use_item result")
    if result.waiting then
      return { stay = true }
    end
    return _finish_item_target_choice(helpers, game)
  end

  local function _handle_remote_dice_value(game, choice, action)
    local value = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(value ~= nil, "missing dice value")
    local dice_count = meta.dice_count or game:player_dice_count(player)
    _consume_if_needed(player, meta.item_id, meta.item_preconsumed)
    local result = remote_dice.apply(game, player, dice_count, value)
    if result then
      item_use_broadcast.dispatch(game, player, meta.item_id)
    end
    return _finish_item_target_choice(helpers, game)
  end

  local function _handle_item_phase_choice(game, choice, action)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local phase = meta.phase
    local item_id = number_utils.to_integer(action.option_id)
    assert(item_id ~= nil, "missing item_id")

    local result = use_item(game, player, item_id)
    if type(result) == "table" and result.waiting then
      assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
      local intent = result.intent or {}
      local choice_spec = intent.choice_spec
      if type(choice_spec) == "table" then
        choice_spec.allow_cancel = false
        choice_spec.cancel_label = nil
        choice_spec.meta = choice_spec.meta or {}
        choice_spec.meta.item_preconsumed = true
        choice_spec.meta.item_id = choice_spec.meta.item_id or item_id
        choice_spec.meta.player_id = choice_spec.meta.player_id or player.id
      end
      intent_output_port.dispatch(game, intent)
      return { stay = true }
    end
    finish_item_phase(game, phase)
    return finish_choice(game, false)
  end

  return {
    item_phase_choice = {
      cancel = { mode = "finish_item_phase" },
      execute = _handle_item_phase_choice,
    },
    demolish_target = {
      cancel = { mode = "finish_active_item_phase" },
      execute = _handle_demolish_target,
    },
    roadblock_target = {
      cancel = { mode = "finish_active_item_phase" },
      execute = _handle_roadblock_target,
    },
    steal_item = {
      cancel = { mode = "finish_active_item_phase" },
      execute = _handle_steal_item,
    },
    steal_prompt = {
      execute = _handle_steal_prompt,
    },
    item_target_player = {
      cancel = { mode = "finish_active_item_phase" },
      execute = _handle_item_target_player,
    },
    remote_dice_value = {
      cancel = { mode = "finish_active_item_phase" },
      execute = _handle_remote_dice_value,
    },
  }
end

return item_choice_handler
