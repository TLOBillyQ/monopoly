local logger = require("src.core.utils.logger")
local inventory = require("src.game.systems.items.inventory")
local gameplay_rules = require("src.core.config.gameplay_rules")
local number_utils = require("src.core.utils.number_utils")
local choice_auto_policy = require("src.game.flow.turn.choice_auto_policy")

local turn_decision = {}

local function _format_status(player)
  local parts = {}
  local stay_turns = player.status.stay_turns
  if stay_turns ~= 0 then
    parts[#parts + 1] = "stay_turns=" .. tostring(stay_turns)
  end
  local deity = player.status.deity
  if deity then
    parts[#parts + 1] = "deity=" .. tostring(deity.type) .. ":" .. tostring(deity.remaining)
  end
  return parts
end

local function _format_items(player)
  local list = {}
  local item_name = inventory.item_name
  for _, it in ipairs(inventory.items(player)) do
    list[#list + 1] = item_name(it.id) .. "(" .. tostring(it.id) .. ")"
  end
  return list
end

local function _format_properties(game, player)
  if next(player.properties) == nil then
    return {}
  end
  local ids = {}
  for tile_id in pairs(player.properties) do
    ids[#ids + 1] = tile_id
  end
  table.sort(ids, function(a, b)
    local ai = number_utils.to_integer(a)
    local bi = number_utils.to_integer(b)
    if ai ~= nil and bi ~= nil then
      return ai < bi
    end
    return tostring(a) < tostring(b)
  end)
  local props = {}
  for _, tile_id in ipairs(ids) do
    local tile = game.board:get_tile_by_id(tile_id)
    local level = tile.level or 0
    props[#props + 1] = tile.name .. "(Lv" .. tostring(level) .. ")"
  end
  return props
end

function turn_decision.build_turn_log_line(game)
  local player = game:current_player()
  local line = "玩家 " .. tostring(player.name)
  if player.eliminated then
    return line .. " (已出局)"
  end

  line = line .. " 金币=" .. number_utils.format_integer_part(game:player_balance(player, "金币"))
  local status_parts = _format_status(player)
  if #status_parts > 0 then
    line = line .. " 状态: " .. table.concat(status_parts, ", ")
  end
  local items_list = _format_items(player)
  if #items_list > 0 then
    line = line .. " 背包: " .. table.concat(items_list, ", ")
  end
  local properties = _format_properties(game, player)
  if #properties > 0 then
    line = line .. " 地产: " .. table.concat(properties, ", ")
  end
  return line
end

function turn_decision.decide_choice_action(game, choice, pending_action, opts)
  opts = opts or {}
  local min_visible = gameplay_rules.auto_choice_min_visible_seconds or 0
  local elapsed = opts.elapsed_seconds or 0
  local action = choice_auto_policy.decide(game, nil, choice, {
    mode = "wait_choice",
    pending_action = pending_action,
    min_visible_seconds = min_visible,
    elapsed_seconds = elapsed,
  })
  if action then
    return action
  end
  return nil
end

function turn_decision.resolve_choice(game, choice, action)
  return require("src.game.systems.choices.resolver").resolve(game, choice, action) or {}
end

function turn_decision.log_turn_start(game)
  local turn_count = game and game.turn and game.turn.turn_count or 0
  local next_turn_count = number_utils.format_integer_part((turn_count or 0) + 1)
  logger.event_no_tips("第" .. next_turn_count .. "回合开始：" .. turn_decision.build_turn_log_line(game))
end

return turn_decision
