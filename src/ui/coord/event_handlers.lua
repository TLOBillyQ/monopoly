local monopoly_event = require("src.foundation.events")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local host_runtime_ports = require("src.ui.host_bridge")
local board_feedback = require("src.ui.render.board_feedback.service")
local panel_interrupt = require("src.ui.coord.panel_interrupt")
local landing_visual_hold = require("src.ui.visual_hold")

local event_handlers = {}
local context = { installed = false, logger = nil, state = nil, handlers_by_event = {} }
local MARKET_TIP_MIN_SECONDS = 3.0

local _enqueue_tip = host_runtime_ports.enqueue_tip

local function _resolve_market_buy_failed_tip(event_data)
  local popup = event_data and event_data.popup or nil
  local body = popup and popup.body or nil
  if type(body) == "string" and body ~= "" then
    return body
  end
  return "黑市购买失败"
end

local function _apply_game_result_panels(event_data)
  local state = context.state
  local game = state and state.game or nil
  local players = game and game.players or nil
  if type(players) ~= "table" then
    return
  end
  local winner_ids = event_data and event_data.winner_ids or {}
  for _, player in ipairs(players) do
    local role = runtime_ports.resolve_role(player.id)
    local is_winner = winner_ids[player.id] == true
    if is_winner and role and role.game_win_and_show_result_panel then
      role.game_win_and_show_result_panel()
    end
    if not is_winner and role and role.lose then
      role.lose()
    end
  end
end

local function _resolve_tile_id(payload)
  if type(payload) ~= "table" then
    return nil
  end
  if payload.tile and payload.tile.id then
    return payload.tile.id
  end
  return payload.tile_id
end

local function _index_of_tile_id_from_context(tile_id)
  local ctx = context.state
  local board = ctx and ctx.game and ctx.game.board or nil
  if tile_id == nil or type(board and board.index_of_tile_id) ~= "function" then
    return nil
  end
  return board:index_of_tile_id(tile_id)
end

local function _resolve_tile_index_from_payload(payload)
  if type(payload) ~= "table" then
    return nil
  end
  if payload.tile_index ~= nil then
    return payload.tile_index
  end
  return _index_of_tile_id_from_context(_resolve_tile_id(payload))
end

function event_handlers.install(_, logger, state)
  context.logger = logger
  context.state = state

  if context.installed then
    return
  end
  context.installed = true

  local function _event_data(data)
    if type(data) == "table" then
      return data
    end
    return nil
  end

  local function _dispatch_or_defer(data, handler)
    local current_state = context.state
    if current_state == nil then
      return handler(data)
    end
    local result = nil
    landing_visual_hold.run_or_defer(current_state, nil, "runtime_event", function()
      result = handler(data)
    end)
    return result
  end

  local function _register_handler(event_name, handler)
    local list = context.handlers_by_event[event_name]
    if type(list) ~= "table" then
      list = {}
      context.handlers_by_event[event_name] = list
    end
    list[#list + 1] = handler
    host_runtime_ports.register_custom_event(event_name, function(_, _, data)
      return _dispatch_or_defer(data, handler)
    end)
  end

  pcall(require, "src.ui.render.anim")

  _register_handler(monopoly_event.movement.roadblock_hit, function(data)
    return _resolve_tile_index_from_payload(_event_data(data))
  end)

  _register_handler(monopoly_event.land.mine_hit, function(data)
    return _resolve_tile_index_from_payload(_event_data(data))
  end)

  local function _player_cue_from_subject(cue_name, subject_key)
    return function(data)
      local event_data = _event_data(data)
      local ctx = context.state
      local subject = event_data and event_data[subject_key] or nil
      if ctx and subject and subject.id ~= nil then
        board_feedback.play_player_cue(ctx, cue_name, subject.id, event_data)
      end
    end
  end

  local _handle_rent_cue = _player_cue_from_subject("cash_burst", "owner")
  _register_handler(monopoly_event.land.rent_paid, _handle_rent_cue)
  _register_handler(monopoly_event.land.rent_bankrupt, _handle_rent_cue)

  _register_handler(monopoly_event.land.tax_paid, _player_cue_from_subject("tax_wave", "player"))

  _register_handler(monopoly_event.chance.applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player = event_data and event_data.player or nil
    local card = event_data and event_data.card or nil
    if ctx and player and player.id ~= nil and card and card.negative == true then
      board_feedback.play_player_cue(ctx, "generic_negative", player.id, event_data)
    end
  end)

  local function _event_player_id(event_data)
    return event_data and (event_data.player_id or (event_data.player and event_data.player.id)) or nil
  end

  local function _player_cue_from_player_id(cue_name)
    return function(data)
      local event_data = _event_data(data)
      local ctx = context.state
      local player_id = _event_player_id(event_data)
      if ctx and player_id ~= nil then
        board_feedback.play_player_cue(ctx, cue_name, player_id, event_data)
      end
    end
  end

  _register_handler(monopoly_event.feedback.turn_started, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = _event_player_id(event_data)
    if ctx and player_id ~= nil then
      board_feedback.play_player_cue(ctx, "turn_started", player_id, event_data)
      panel_interrupt.begin_player_action(ctx, player_id)
    end
  end)

  _register_handler(monopoly_event.feedback.status_applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local cue_name = event_data and event_data.cue_name or nil
    local tile_index = event_data and event_data.tile_index or nil
    if ctx and cue_name and tile_index ~= nil then
      board_feedback.play_tile_cue(ctx, cue_name, tile_index, event_data)
      return
    end
    local player_id = _event_player_id(event_data)
    if ctx and cue_name and player_id ~= nil then
      board_feedback.play_player_cue(ctx, cue_name, player_id, event_data)
    end
  end)

  _register_handler(monopoly_event.feedback.deity_applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local deity_type = event_data and event_data.deity_type or nil
    local player_id = _event_player_id(event_data)
    local cue_name = nil
    if deity_type == "rich" then
      cue_name = "rich_deity"
    elseif deity_type == "angel" then
      cue_name = "angel_deity"
    end
    if ctx and cue_name and player_id ~= nil then
      board_feedback.play_player_cue(ctx, cue_name, player_id, event_data)
    end
  end)

  _register_handler(monopoly_event.feedback.angel_immune_blocked, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = _event_player_id(event_data)
    local tile_index = event_data and event_data.tile_index or nil
    if ctx and tile_index ~= nil then
      board_feedback.play_tile_cue(ctx, "angel_deity", tile_index, event_data)
      return
    end
    if ctx and player_id ~= nil then
      board_feedback.play_player_cue(ctx, "angel_deity", player_id, event_data)
    end
  end)

  _register_handler(monopoly_event.feedback.bankruptcy, _player_cue_from_player_id("bankruptcy_slam"))

  _register_handler(monopoly_event.market.buy_failed, function(data)
    local event_data = _event_data(data)
    local tip_text = _resolve_market_buy_failed_tip(event_data)
    _enqueue_tip({
      text = tip_text,
      duration = MARKET_TIP_MIN_SECONDS,
      dedupe_key = "market_buy_failed:" .. tostring(tip_text),
      blocks_inter_turn = false,
      source = "market.buy_failed",
    })
  end)

  _register_handler(monopoly_event.market.inventory_full, function(data)
    local event_data = _event_data(data)
    local tip_text = (event_data and event_data.body) or "卡槽已满，无法继续购买"
    _enqueue_tip({
      text = tip_text,
      duration = MARKET_TIP_MIN_SECONDS,
      dedupe_key = "market_inventory_full",
      blocks_inter_turn = false,
      source = "market.inventory_full",
    })
  end)

  _register_handler(monopoly_event.market.bought_item, _player_cue_from_subject("cash_burst", "player"))

  _register_handler(monopoly_event.game.finished, function(data)
    local event_data = _event_data(data)
    _apply_game_result_panels(event_data)
  end)
end

return event_handlers

--[[ mutate4lua-manifest
version=2
projectHash=36b80b1d938abade
scope.0.id=chunk:src/ui/coord/event_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=245
scope.0.semanticHash=90c869c5ce9461a8
scope.1.id=function:_resolve_market_buy_failed_tip:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=20
scope.1.semanticHash=0acce0c4af5aec3b
scope.2.id=function:_resolve_tile_id:42
scope.2.kind=function
scope.2.startLine=42
scope.2.endLine=50
scope.2.semanticHash=3327aacc9dddcdd7
scope.3.id=function:_index_of_tile_id_from_context:52
scope.3.kind=function
scope.3.startLine=52
scope.3.endLine=59
scope.3.semanticHash=867bb046b2a656a8
scope.4.id=function:_resolve_tile_index_from_payload:61
scope.4.kind=function
scope.4.startLine=61
scope.4.endLine=69
scope.4.semanticHash=8c19398f41e0ee62
scope.5.id=function:_event_data:80
scope.5.kind=function
scope.5.startLine=80
scope.5.endLine=85
scope.5.semanticHash=73f52fe608bda032
scope.6.id=function:anonymous@93:93
scope.6.kind=function
scope.6.startLine=93
scope.6.endLine=95
scope.6.semanticHash=e9a5908cae6527c6
scope.7.id=function:_dispatch_or_defer:87
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=97
scope.7.semanticHash=a8dfdee35b6fc668
scope.8.id=function:anonymous@106:106
scope.8.kind=function
scope.8.startLine=106
scope.8.endLine=108
scope.8.semanticHash=a64f461204463346
scope.9.id=function:_register_handler:99
scope.9.kind=function
scope.9.startLine=99
scope.9.endLine=109
scope.9.semanticHash=84bc9f29b72fbfd1
scope.10.id=function:anonymous@113:113
scope.10.kind=function
scope.10.startLine=113
scope.10.endLine=115
scope.10.semanticHash=fe87554277d74f80
scope.11.id=function:anonymous@117:117
scope.11.kind=function
scope.11.startLine=117
scope.11.endLine=119
scope.11.semanticHash=fe87554277d74f80
scope.12.id=function:anonymous@122:122
scope.12.kind=function
scope.12.startLine=122
scope.12.endLine=129
scope.12.semanticHash=6f2bb9f8197b235f
scope.13.id=function:_player_cue_from_subject:121
scope.13.kind=function
scope.13.startLine=121
scope.13.endLine=130
scope.13.semanticHash=91053fca375b3bda
scope.14.id=function:anonymous@138:138
scope.14.kind=function
scope.14.startLine=138
scope.14.endLine=146
scope.14.semanticHash=2310046bf89406dc
scope.15.id=function:_event_player_id:148
scope.15.kind=function
scope.15.startLine=148
scope.15.endLine=150
scope.15.semanticHash=c530988a11ae8ca2
scope.16.id=function:anonymous@153:153
scope.16.kind=function
scope.16.startLine=153
scope.16.endLine=160
scope.16.semanticHash=9adc1e3a44df0045
scope.17.id=function:_player_cue_from_player_id:152
scope.17.kind=function
scope.17.startLine=152
scope.17.endLine=161
scope.17.semanticHash=cc39a23b94bff883
scope.18.id=function:anonymous@165:165
scope.18.kind=function
scope.18.startLine=165
scope.18.endLine=178
scope.18.semanticHash=2837912e308f4ff9
scope.19.id=function:anonymous@180:180
scope.19.kind=function
scope.19.startLine=180
scope.19.endLine=194
scope.19.semanticHash=533bf5dbdbe7e618
scope.20.id=function:anonymous@196:196
scope.20.kind=function
scope.20.startLine=196
scope.20.endLine=208
scope.20.semanticHash=aed9073ee3bdac5c
scope.21.id=function:anonymous@212:212
scope.21.kind=function
scope.21.startLine=212
scope.21.endLine=222
scope.21.semanticHash=8ee078ef4d1da802
scope.22.id=function:anonymous@224:224
scope.22.kind=function
scope.22.startLine=224
scope.22.endLine=234
scope.22.semanticHash=dac1c0da6883dde9
scope.23.id=function:anonymous@238:238
scope.23.kind=function
scope.23.startLine=238
scope.23.endLine=241
scope.23.semanticHash=9e4f6403c4204525
scope.24.id=function:event_handlers.install:71
scope.24.kind=function
scope.24.startLine=71
scope.24.endLine=242
scope.24.semanticHash=fb0017083227f519
]]
