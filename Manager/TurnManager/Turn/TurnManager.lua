local Flow = require("Components.Flow")
local Logger = require("Library.Monopoly.Logger")
local Agent = require("Manager.GameManager.Agent")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local Tile = require("Components.Tile")
local SERVICE_KEY = require("Globals.ServiceKeys")
require "Library.ClassUtils"

---@class TurnManager
---@field game Game
---@field phases table
---@field flow Flow?
---@field pending_action table?
---回合循环管理器，控制游戏状态机和流程
local TurnManager = Class("TurnManager")
TurnManager.__class_new = TurnManager.new

local function build_turn_log_line(game, turn_count)
  local player = game:current_player()
  local next_count = turn_count + 1
  if player.eliminated then
    next_count = turn_count
  end
  local line = "回合" .. tostring(next_count) .. ": "
  if player.eliminated then
    line = line .. tostring(player.name) .. " (已出局)"
    return line
  end

  local tile_state = Tile.get_state
  local status = player.status
  local status_parts = {}
  local stay_turns = status.stay_turns
  if stay_turns ~= 0 then
    table.insert(status_parts, "stay_turns=" .. tostring(stay_turns))
  end
  local deity = status.deity
  if deity then
    table.insert(status_parts, "deity=" .. tostring(deity.type) .. ":" .. tostring(deity.remaining))
  end
  local items = {}
  for _, it in ipairs(Inventory.items(player)) do
    local id = it.id
    local name = Inventory.item_name(id)
    table.insert(items, name .. "(" .. tostring(id) .. ")")
  end
  line = line
    .. tostring(player.name)
    .. " 金币=" .. tostring(player.cash)
  if #status_parts > 0 then
    line = line .. " 状态: " .. table.concat(status_parts, ", ")
  end
  if #items > 0 then
    line = line .. " 背包: " .. table.concat(items, ", ")
  end
  local properties = {}
  local ids = {}
  for tile_id in pairs(player.properties) do
    table.insert(ids, tile_id)
  end
  table.sort(ids, function(a, b)
    if type(a) == "number" and type(b) == "number" then
      return a < b
    end
    return tostring(a) < tostring(b)
  end)
  for _, tile_id in ipairs(ids) do
    local tile = game.board:get_tile_by_id(tile_id)
    local name = tile.name
    local level = 0
    local ok, st = pcall(tile_state, game, tile)
    if ok and type(st) == "table" then
      level = st.level
    end
    table.insert(properties, name .. "(Lv" .. tostring(level) .. ")")
  end
  if #properties > 0 then
    line = line .. " 地产: " .. table.concat(properties, ", ")
  end
  return line
end

local function get_choice(game)
  return game.store:get({ "turn", "pending_choice" })
end

---判断选择行动（自动/玩家/超时）
---@param game Game 游戏实例
---@param choice table 待选项表
---@param pending_action table? 玩家待定行动
---@return table? 决议行动
local function decide_choice_action(game, choice, pending_action)
  if pending_action then
    return pending_action
  end

  local auto_action = Agent.auto_action_for_choice(game, choice)
  if auto_action then
    return auto_action
  end

  if game.ui_port == nil then
    local first = choice.options and choice.options[1]
    if first then
      return { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
    end
    if choice.allow_cancel ~= false then
      return { type = "choice_cancel", choice_id = choice.id }
    end
  end

  return nil
end

---处理选择项的决议
---@param game Game 游戏实例
---@param choice table 待选项表
---@param action table? 行动对象
---@return table 决议结果
local function resolve_choice(game, choice, action)
  local service = game:get_service(SERVICE_KEY.choice)
  return service.resolve(game, choice, action) or {}
end


---创建新回合管理器
---@param game Game 游戏实例
---@param phases table 回合阶段函数表
function TurnManager:init(game, phases)
  self.game = game
  self.phases = phases
  self.flow = nil
  self.pending_action = nil
end

---创建新回合管理器
---@param game Game 游戏实例
---@param phases table 回合阶段函数表
---@return TurnManager 新TurnManager对象
function TurnManager.new(game, phases)
  return TurnManager.__class_new(TurnManager, game, phases)
end

---分发玩家行动到流程
---@param self TurnManager
---@param action table? 行动对象
---@return table? 决议结果
function TurnManager:dispatch(action)
  self.pending_action = action

  local choice = get_choice(self.game)
  if choice and action == nil and (not self.flow or not self.flow.current) then
    return nil
  end
  if choice and (not self.flow or not self.flow.current) then
    local res = resolve_choice(self.game, choice, action)
    self.pending_action = nil
    return res
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end

---构建回合流程的状态机
---@param self TurnManager
---@return Flow 新的Flow对象
function TurnManager:_build_flow()
  assert(self.phases, "TurnManager requires phases")
  local states = {}
  for name, fn in pairs(self.phases) do
    states[name] = function(args)
      if name == "start" then
        local turn_count = self.game.store:get({ "turn", "turn_count" })
        Logger.info(build_turn_log_line(self.game, turn_count))
      end
      self.game.store:set({ "turn", "phase" }, name)
      return fn(self, args)
    end
  end

  states.wait_choice = function(args)
    self.game.store:set({ "turn", "phase" }, "wait_choice")
    local choice = get_choice(self.game)
    if not choice then
      self.pending_action = nil
      return args.resume_state, args.resume_args
    end

    self.pending_action = decide_choice_action(self.game, choice, self.pending_action)

    if not self.pending_action then
      return "wait_choice", args
    end
    local action = self.pending_action
    self.pending_action = nil


    if action.choice_id and choice.id and action.choice_id ~= choice.id then
      return "wait_choice", args
    end
    local res = resolve_choice(self.game, choice, action)
    if res.stay then
      return "wait_choice", args
    end
    local action_anim = self.game.store:get({ "turn", "action_anim" })
    if action_anim then
      return "wait_action_anim", args
    end
    return args.resume_state, args.resume_args
  end

  states.wait_move_anim = function(args)
    self.game.store:set({ "turn", "phase" }, "wait_move_anim")
    local anim = self.game.store:get({ "turn", "move_anim" })
    if not anim then
      self.pending_action = nil
      return args.resume_state, args.resume_args
    end

    local action = self.pending_action
    self.pending_action = nil
    if not action or action.type ~= "move_anim_done" then
      return "wait_move_anim", args
    end
    if action.seq and anim.seq and action.seq ~= anim.seq then
      return "wait_move_anim", args
    end
    self.game.store:set({ "turn", "move_anim" }, nil)
    return args.resume_state, args.resume_args
  end

  states.wait_action_anim = function(args)
    self.game.store:set({ "turn", "phase" }, "wait_action_anim")
    local anim = self.game.store:get({ "turn", "action_anim" })
    if not anim then
      self.pending_action = nil
      return args.resume_state, args.resume_args
    end

    local action = self.pending_action
    self.pending_action = nil
    if not action or action.type ~= "action_anim_done" then
      return "wait_action_anim", args
    end
    if action.seq and anim.seq and action.seq ~= anim.seq then
      return "wait_action_anim", args
    end
    self.game.store:set({ "turn", "action_anim" }, nil)
    return args.resume_state, args.resume_args
  end

  return Flow.new({ start = "start", states = states })
end

---推进到下一个玩家
---@param self TurnManager
function TurnManager:next_player()
  local count = #self.game.players
  local current = self.game.store:get({ "turn", "current_player_index" })
  local next_index = current % count + 1
  self.game.store:set({ "turn", "current_player_index" }, next_index)
end

---持续运行流程直到遇到等待点
---@param self TurnManager
---@return string? 等待状态名，或nil表示完成
function TurnManager:run_until_wait()
  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  while self.flow.current do
    if self.flow.current == "wait_choice" then
      self.flow:step()
      if self.flow.current == "wait_choice" and not self.pending_action then
        self.game.store:set({ "turn", "phase" }, "wait_choice")
        return "wait_choice"
      end
    elseif self.flow.current == "wait_move_anim" then
      self.flow:step()
      if self.flow.current == "wait_move_anim" and not self.pending_action then
        self.game.store:set({ "turn", "phase" }, "wait_move_anim")
        return "wait_move_anim"
      end
    elseif self.flow.current == "wait_action_anim" then
      self.flow:step()
      if self.flow.current == "wait_action_anim" and not self.pending_action then
        self.game.store:set({ "turn", "phase" }, "wait_action_anim")
        return "wait_action_anim"
      end
    else
      self.flow:step()
    end
  end

  self.flow = nil
  return nil
end

---运行一个完整回合
---@param self TurnManager
---@return string? 等待状态名
function TurnManager:run_turn()
  print("[debug] turn_manager: run_turn")
  return self:run_until_wait()
end

return TurnManager
