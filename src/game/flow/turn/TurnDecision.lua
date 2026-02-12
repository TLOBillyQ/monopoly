local logger = require("src.core.Logger")
local agent = require("src.game.core.runtime.Agent")
local inventory = require("src.game.systems.items.ItemInventory")
local gameplay_rules = require("Config.GameplayRules")
local number_utils = require("src.core.NumberUtils")

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
    if type(a) == "number" and type(b) == "number" then
      return a < b
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

function turn_decision.decide_choice_action(game, choice, pending_action)
  if pending_action then
    return pending_action
  end

  local min_visible = gameplay_rules.auto_choice_min_visible_seconds or 0
  if min_visible > 0 then
    local meta = choice and choice.meta or {}
    local actor = nil
    if meta.player_id and game.find_player_by_id then
      actor = game:find_player_by_id(meta.player_id)
    elseif game.current_player then
      actor = game:current_player()
    end
    if actor and agent.is_auto_player(actor) then
      local ui_port = game.ui_port
      local elapsed = ui_port and ui_port.pending_choice_elapsed or 0
      if elapsed < min_visible then
        return nil
      end
    end
  end

  local auto_action = agent.auto_action_for_choice(game, choice)
  if auto_action then
    return auto_action
  end

  assert(game.ui_port ~= nil, "missing ui_port")

  return nil
end

function turn_decision.resolve_choice(game, choice, action)
  return require("src.game.systems.choices.ChoiceResolver").resolve(game, choice, action) or {}
end

function turn_decision.log_turn_start(game)
  logger.info(turn_decision.build_turn_log_line(game))
end

return turn_decision
