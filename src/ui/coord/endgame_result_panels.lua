-- 终局结算面板链(自 event_handlers.lua 拆分,行为保持):game.finished 事件的
-- 胜/败者面板触发,宿主对象调用「跳过必留痕」(ADR 0046),禁止静默。
local runtime_ports = require("src.foundation.ports.runtime_ports")

local endgame_result_panels = {}
local context = { logger = nil, state = nil }

-- 胜/败结算面板的宿主方法名(#334 面板变体):集中文件头,grep 可达。
local _WINNER_PANEL_METHOD = "game_win_and_show_result_panel"
local _LOSER_PANEL_METHOD = "game_lose_and_show_result_panel"

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
-- 方法缺失时跳过且留痕,不静默。pcall 隔离宿主异常:面板抛错若上抛会跳过
-- 整局收尾(end_game),会话悬挂不退出——异常必须吞成 warn(#609 审查收口)。
local function _show_panel(role, player, method_name)
  local method = role[method_name]
  if type(method) ~= "function" then
    _warn("endgame result panel skip: role", _player_tag(player), "lacks " .. method_name)
    return
  end
  local ok, err = pcall(method)
  if not ok then
    _warn("endgame result panel raised: role", _player_tag(player), method_name, err)
  end
end

local function _notify_player_result(role, player, is_winner)
  if role == nil then
    _warn("endgame result panel skip: role not resolved for player", _player_tag(player))
    return
  end
  if is_winner then
    _show_panel(role, player, _WINNER_PANEL_METHOD)
  else
    _show_panel(role, player, _LOSER_PANEL_METHOD)
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
  else
    local winner_ids = event_data and event_data.winner_ids or {}
    for _, player in ipairs(players) do
      local role = runtime_ports.resolve_role(player.id)
      _notify_player_result(role, player, winner_ids[player.id] == true)
    end
  end
  -- 终局收尾:宿主要求「设置胜利或失败需要在结束之前」,故 end_game 放在全部
  -- 胜负标记(带面板)之后;面板链断裂不阻塞收尾,否则会话永久悬挂不退出。
  if runtime_ports.end_game() ~= true then
    _warn("endgame end_game not confirmed: session may stay open")
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
projectHash=071bcfb89c2c277d
scope.0.id=chunk:src/ui/coord/endgame_result_panels.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=96
scope.0.semanticHash=b6307b10581af6d8
scope.1.id=function:_warn
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=38961a0b2c68bf4e
scope.2.id=function:_player_tag
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=7d072b025ad9bbab
scope.3.id=function:_show_panel
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=39
scope.3.semanticHash=752bcaaee9ede49d
scope.4.id=function:_notify_player_result
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=51
scope.4.semanticHash=1f49a8408439351b
scope.5.id=function:_game_players
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=59
scope.5.semanticHash=7ecf9f077756bf6c
scope.6.id=function:_current_players
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=64
scope.6.semanticHash=275c1bf841de2dc9
scope.7.id=function:_apply_game_result_panels
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=82
scope.7.semanticHash=c0e104bde4b50ddd
scope.8.id=function:endgame_result_panels.set_context
scope.8.kind=function
scope.8.startLine=84
scope.8.endLine=87
scope.8.semanticHash=10c5c24adc1f4b32
scope.9.id=function:endgame_result_panels.install
scope.9.kind=function
scope.9.startLine=89
scope.9.endLine=93
scope.9.semanticHash=c3c02a023052b3ea
scope.10.id=function:<anonymous>
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=92
scope.10.semanticHash=c772a22f8680e278
]]
