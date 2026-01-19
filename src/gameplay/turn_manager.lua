local Flow = require("src.core.flow")
local Logger = require("src.util.logger")
local Agent = require("src.gameplay.agent")

local TurnManager = {}
TurnManager.__index = TurnManager

local function get_choice(game)
  if not (game and game.store) then
    return nil
  end
  return game.store:get({ "turn", "pending_choice" })
end

local function decide_choice_action(game, choice, pending_action)
  if pending_action then
    return pending_action
  end

  local auto_action = Agent.auto_action_for_choice(game, choice)
  if auto_action then
    return auto_action
  end

  local auto_play = game
    and game.ui_port
    and game.ui_port.ui
    and game.ui_port.ui.auto_play
  if game.ui_port == nil or auto_play then
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

local function resolve_choice(game, choice, action)
  local service = game and game.get_service and game:get_service("choice")
  assert(service and service.resolve, "Missing ChoiceService (game.services.choice)")
  return service.resolve(game, choice, action) or {}
end


function TurnManager.new(game, phases)
  local tm = {
    game = game,
    phases = phases,
    flow = nil,
    pending_action = nil,
  }
  return setmetatable(tm, TurnManager)
end

function TurnManager:dispatch(action)
  self.pending_action = action

  local choice = get_choice(self.game)
  if choice and action == nil and (not self.flow or not self.flow.current) then
    return nil
  end
  if choice and (not self.flow or not self.flow.current) then
    ---@type any
    local res = resolve_choice(self.game, choice, action)
    self.pending_action = nil
    return res
  end

  if self.flow and self.flow.current then
    self:run_until_wait()
  end
end

function TurnManager:_build_flow()
  assert(self.phases, "TurnManager requires phases")
  local states = {}
  for name, fn in pairs(self.phases) do
    states[name] = function(args)
      if name == "start" then
        local p_idx = self.game.store:get({ "turn", "current_player_index" })
        local turn_count = self.game.store:get({ "turn", "turn_count" }) or 0
        Logger.info("回合: " .. (turn_count + 1) .. " [Player " .. tostring(p_idx) .. "]")
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
      return (args and args.resume_state) or "end_turn", (args and args.resume_args) or {}
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
    ---@type any
    local res = resolve_choice(self.game, choice, action)
    if res.stay then
      return "wait_choice", args
    end
    return args and args.resume_state, args and args.resume_args
  end

  return Flow.new({ start = "start", states = states })
end

function TurnManager:next_player()
  local count = #self.game.players
  local current = self.game.store:get({ "turn", "current_player_index" }) or 1
  local next_index = current % count + 1
  self.game.store:set({ "turn", "current_player_index" }, next_index)
end

function TurnManager:run_until_wait()
  if not self.flow or not self.flow.current then
    self.flow = self:_build_flow()
  end

  while self.flow.current do
    if self.flow.current == "wait_choice" then
      -- 执行一次 wait_choice 状态以获取自动决策
      self.flow:step()
      -- 如果仍在 wait_choice 且无待处理行动，则等待
      if self.flow.current == "wait_choice" and not self.pending_action then
        self.game.store:set({ "turn", "phase" }, "wait_choice")
        return "wait_choice"
      end
    else
      self.flow:step()
    end
  end

  self.flow = nil
  return nil
end

function TurnManager:run_turn()
  return self:run_until_wait()
end

return TurnManager
