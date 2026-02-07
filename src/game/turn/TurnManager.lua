local flow = require("src.core.Flow")
local logger = require("src.core.Logger")
local agent = require("src.game.game.Agent")
local inventory = require("src.game.item.ItemInventory")
local choice_manager = require("src.game.choice.ChoiceManager")
local gameplay_rules = require("Config.GameplayRules")
local store_paths = require("src.core.StorePaths")
require "vendor.third_party.ClassUtils"


local turn_manager = Class("TurnManager")

local phase_path = store_paths.turn.phase
local pending_choice_path = store_paths.turn.pending_choice
local turn_count_path = store_paths.turn.turn_count
local player_index_path = store_paths.turn.current_player_index
local action_anim_path = store_paths.turn.action_anim
local anim_path_by_key = {
  move_anim = store_paths.turn.move_anim,
  action_anim = store_paths.turn.action_anim,
}

local wait_states = {
  wait_choice = true,
  wait_move_anim = true,
  wait_action_anim = true,
}

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
  local store = game.store
  local store_get = store and store.get
  local props = {}
  for _, tile_id in ipairs(ids) do
    local tile = game.board:get_tile_by_id(tile_id)
    local level = 0
    if store_get then
      local st = store_get(store, store_paths.board.tile(tile_id))
      if type(st) == "table" and st.level then
        level = st.level
      end
    end
    props[#props + 1] = tile.name .. "(Lv" .. tostring(level) .. ")"
  end
  return props
end

local function _build_turn_log_line(game, turn_count)
  local player = game:current_player()
  local next_count = player.eliminated and turn_count or (turn_count + 1)
  local line = "回合" .. tostring(next_count) .. ": "
  if player.eliminated then
    return line .. tostring(player.name) .. " (已出局)"
  end

  line = line .. tostring(player.name) .. " 金币=" .. tostring(game:player_balance(player, "金币"))
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

local function _get_choice(game)
  return game.store:get(pending_choice_path)
end


local function _decide_choice_action(game, choice, pending_action)
  if pending_action then
    return pending_action
  end

  local min_visible = gameplay_rules.auto_choice_min_visible_seconds or 0
  if min_visible > 0 then
    local meta = choice and choice.meta or {}
    local actor = nil
    if meta.player_id and game.players and game.players[meta.player_id] then
      actor = game.players[meta.player_id]
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


local function _resolve_choice(game, choice, action)
  return choice_manager.resolve(game, choice, action) or {}
end


function turn_manager:init(game, phases)
  self.game = game
  self.phases = phases
  self.flow = nil
  self.pending_action = nil
end


function turn_manager:dispatch(action)
  self.pending_action = action

  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end


local function _make_anim_wait(turn_mgr, state_name, store_key, done_action_type)
  local anim_path = assert(anim_path_by_key[store_key], "missing anim path: " .. tostring(store_key))
  return function(args)
    turn_mgr.game.store:set(phase_path, state_name)
    local anim = turn_mgr.game.store:get(anim_path)
    assert(anim ~= nil, "missing " .. store_key)

    local action = turn_mgr.pending_action
    turn_mgr.pending_action = nil
    if not action or action.type ~= done_action_type then
      return state_name, args
    end
    if action.seq and anim.seq and action.seq ~= anim.seq then
      return state_name, args
    end
    turn_mgr.game.store:set(anim_path, nil)
    return args.resume_state, args.resume_args
  end
end


function turn_manager:_build_flow()
  assert(self.phases, "TurnManager requires phases")
  local states = {}
  for name, fn in pairs(self.phases) do
    states[name] = function(args)
      if name == "start" then
        local tc = self.game.store:get(turn_count_path)
        logger.info(_build_turn_log_line(self.game, tc))
      end
      self.game.store:set(phase_path, name)
      return fn(self, args)
    end
  end

  states.wait_choice = function(args)
    self.game.store:set(phase_path, "wait_choice")
    local choice = _get_choice(self.game)
    if not choice then
      self.pending_action = nil
      return args.resume_state, args.resume_args
    end

    self.pending_action = _decide_choice_action(self.game, choice, self.pending_action)

    if not self.pending_action then
      return "wait_choice", args
    end
    local action = self.pending_action
    self.pending_action = nil

    if action.type == "choice_select" or action.type == "choice_cancel" then
      if not action.choice_id or not choice.id or action.choice_id ~= choice.id then
        logger.warn(
          "choice action mismatch:",
          tostring(action.type),
          "action_choice_id=" .. tostring(action.choice_id),
          "pending_choice_id=" .. tostring(choice.id)
        )
        return "wait_choice", args
      end
    end
    local res = _resolve_choice(self.game, choice, action)
    if res.stay then
      return "wait_choice", args
    end
    local aa = self.game.store:get(action_anim_path)
    if aa then
      return "wait_action_anim", args
    end
    return args.resume_state, args.resume_args
  end

  states.wait_move_anim = _make_anim_wait(self, "wait_move_anim", "move_anim", "move_anim_done")
  states.wait_action_anim = _make_anim_wait(self, "wait_action_anim", "action_anim", "action_anim_done")

  return flow:new({ start = "start", states = states })
end


function turn_manager:next_player()
  local count = #self.game.players
  local current = self.game.store:get(player_index_path)
  local next_index = current % count + 1
  self.game.store:set(player_index_path, next_index)
  local tc = self.game.store:get(turn_count_path)
  logger.info(
    "[Eggy]",
    "切换玩家:",
    "回合",
    tostring(tc),
    "current_index",
    tostring(current),
    "next_index",
    tostring(next_index)
  )
end


function turn_manager:run_until_wait()
  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  while self.flow.current do
    local current = self.flow.current
    self.flow:step()
    if wait_states[self.flow.current] and self.flow.current == current and not self.pending_action then
      self.game.store:set(phase_path, self.flow.current)
      return self.flow.current
    end
  end

  self.flow = nil
  return nil
end


function turn_manager:run_turn()
  return self:run_until_wait()
end

return turn_manager
