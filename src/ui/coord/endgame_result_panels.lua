-- 终局结算面板链(自 event_handlers.lua 拆分,行为保持):game.finished 事件的
-- 胜/败者面板触发,宿主对象调用「跳过必留痕」(ADR 0046),禁止静默。
local runtime_ports = require("src.foundation.ports.runtime_ports")

local endgame_result_panels = {}
local context = { logger = nil, state = nil }

-- 宿主对象调用「跳过必留痕」(ADR 0046):logger 缺位时(测试桩)静默可接受,
-- 生产路径 logger 恒在。
local function _warn(...)
  local logger = context.logger
  if logger and type(logger.warn) == "function" then
    logger.warn(...)
  end
end

local function _player_tag(player)
  return tostring(player and player.id or "?")
end

-- 终局结算面板走宿主「显示界面」方法(与 EggyAPI 注解对齐):胜利
-- game_win_and_show_result_panel / 失败 game_lose_and_show_result_panel(#334);
-- 方法缺失时跳过且留痕,不静默。
local function _show_winner_panel(role, player)
  if type(role.game_win_and_show_result_panel) ~= "function" then
    _warn("endgame result panel skip: role", _player_tag(player), "lacks game_win_and_show_result_panel")
    return
  end
  role.game_win_and_show_result_panel()
end

local function _show_loser_panel(role, player)
  if type(role.game_lose_and_show_result_panel) ~= "function" then
    _warn("endgame result panel skip: role", _player_tag(player), "lacks game_lose_and_show_result_panel")
    return
  end
  role.game_lose_and_show_result_panel()
end

local function _notify_player_result(role, player, is_winner)
  if role == nil then
    _warn("endgame result panel skip: role not resolved for player", _player_tag(player))
    return
  end
  if is_winner then
    _show_winner_panel(role, player)
  else
    _show_loser_panel(role, player)
  end
end

local function _game_players(game)
  local players = game and game.players or nil
  if type(players) ~= "table" then
    return nil
  end
  return players
end

local function _current_players()
  local state = context.state
  return _game_players(state and state.game or nil)
end

local function _apply_game_result_panels(event_data)
  local players = _current_players()
  if players == nil then
    _warn("endgame result panel skip: no current players")
    return
  end
  local winner_ids = event_data and event_data.winner_ids or {}
  for _, player in ipairs(players) do
    local role = runtime_ports.resolve_role(player.id)
    _notify_player_result(role, player, winner_ids[player.id] == true)
  end
end

function endgame_result_panels.set_context(logger, state)
  context.logger = logger
  context.state = state
end

function endgame_result_panels.install(register_handler, monopoly_event)
  register_handler(monopoly_event.game.finished, function(data)
    _apply_game_result_panels(data)
  end)
end

return endgame_result_panels

--[[ mutate4lua-manifest
version=4
projectHash=a7c03b9e916d6e27
scope.0.id=chunk:src/ui/coord/endgame_result_panels.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=e29b9ba2c2ff167d
scope.1.id=function:_warn
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=38961a0b2c68bf4e
scope.2.id=function:_player_tag
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=7d072b025ad9bbab
scope.3.id=function:_show_winner_panel
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=30
scope.3.semanticHash=6cb44b137f278677
scope.4.id=function:_show_loser_panel
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=38
scope.4.semanticHash=6cb44b137f278677
scope.5.id=function:_notify_player_result
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=50
scope.5.semanticHash=750b2f1b711639f3
scope.6.id=function:_game_players
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=58
scope.6.semanticHash=7ecf9f077756bf6c
scope.7.id=function:_current_players
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=63
scope.7.semanticHash=275c1bf841de2dc9
scope.8.id=function:_apply_game_result_panels
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=76
scope.8.semanticHash=100f84b8568880c1
scope.9.id=function:endgame_result_panels.set_context
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=81
scope.9.semanticHash=10c5c24adc1f4b32
scope.10.id=function:endgame_result_panels.install
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=87
scope.10.semanticHash=c3c02a023052b3ea
scope.11.id=function:<anonymous>
scope.11.kind=function
scope.11.startLine=84
scope.11.endLine=86
scope.11.semanticHash=c772a22f8680e278
]]
