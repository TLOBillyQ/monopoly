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

local function _notify_player_result(role, is_winner)
  if is_winner and role and role.game_win_and_show_result_panel then
    role.game_win_and_show_result_panel()
  end
  if not is_winner and role and role.lose then
    role.lose()
  end
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
    _notify_player_result(role, winner_ids[player.id] == true)
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
projectHash=b13cc80b36a7b70e
scope.0.id=chunk:src/ui/coord/event_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=257
scope.0.semanticHash=85e8d7a781034349
scope.0.lastMutatedAt=2026-06-01T12:36:30Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=19
scope.0.lastMutationKilled=19
scope.1.id=function:_resolve_market_buy_failed_tip:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=21
scope.1.semanticHash=0acce0c4af5aec3b
scope.1.lastMutatedAt=2026-06-01T12:36:30Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=11
scope.1.lastMutationKilled=10
scope.2.id=function:_notify_player_result:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=30
scope.2.semanticHash=cc68f7503d18d6e8
scope.2.lastMutatedAt=2026-06-01T12:36:30Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_resolve_tile_id:46
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=54
scope.3.semanticHash=3327aacc9dddcdd7
scope.3.lastMutatedAt=2026-06-01T12:36:30Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_index_of_tile_id_from_context:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=63
scope.4.semanticHash=867bb046b2a656a8
scope.4.lastMutatedAt=2026-06-01T12:36:30Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=9
scope.4.lastMutationKilled=9
scope.5.id=function:_resolve_tile_index_from_payload:65
scope.5.kind=function
scope.5.startLine=65
scope.5.endLine=73
scope.5.semanticHash=8c19398f41e0ee62
scope.5.lastMutatedAt=2026-06-01T12:36:30Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:_event_data:84
scope.6.kind=function
scope.6.startLine=84
scope.6.endLine=89
scope.6.semanticHash=73f52fe608bda032
scope.6.lastMutatedAt=2026-06-01T12:36:30Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:anonymous@97:97
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=99
scope.7.semanticHash=e9a5908cae6527c6
scope.7.lastMutatedAt=2026-06-01T12:36:30Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:_dispatch_or_defer:91
scope.8.kind=function
scope.8.startLine=91
scope.8.endLine=101
scope.8.semanticHash=a8dfdee35b6fc668
scope.8.lastMutatedAt=2026-06-01T12:36:30Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=survived
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=2
scope.9.id=function:anonymous@110:110
scope.9.kind=function
scope.9.startLine=110
scope.9.endLine=112
scope.9.semanticHash=a64f461204463346
scope.9.lastMutatedAt=2026-06-01T12:36:30Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=no_sites
scope.9.lastMutationSites=0
scope.9.lastMutationKilled=0
scope.10.id=function:_register_handler:103
scope.10.kind=function
scope.10.startLine=103
scope.10.endLine=113
scope.10.semanticHash=84bc9f29b72fbfd1
scope.10.lastMutatedAt=2026-06-01T12:36:30Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=survived
scope.10.lastMutationSites=6
scope.10.lastMutationKilled=2
scope.11.id=function:anonymous@117:117
scope.11.kind=function
scope.11.startLine=117
scope.11.endLine=119
scope.11.semanticHash=fe87554277d74f80
scope.12.id=function:anonymous@121:121
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=123
scope.12.semanticHash=fe87554277d74f80
scope.12.lastMutatedAt=2026-06-01T12:36:30Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=no_sites
scope.12.lastMutationSites=0
scope.12.lastMutationKilled=0
scope.13.id=function:anonymous@126:126
scope.13.kind=function
scope.13.startLine=126
scope.13.endLine=133
scope.13.semanticHash=6f2bb9f8197b235f
scope.13.lastMutatedAt=2026-06-01T12:36:30Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=7
scope.13.lastMutationKilled=7
scope.14.id=function:_player_cue_from_subject:125
scope.14.kind=function
scope.14.startLine=125
scope.14.endLine=134
scope.14.semanticHash=91053fca375b3bda
scope.14.lastMutatedAt=2026-06-01T12:36:30Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=no_sites
scope.14.lastMutationSites=0
scope.14.lastMutationKilled=0
scope.15.id=function:anonymous@142:142
scope.15.kind=function
scope.15.startLine=142
scope.15.endLine=150
scope.15.semanticHash=2310046bf89406dc
scope.15.lastMutatedAt=2026-06-01T12:36:30Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=no_sites
scope.15.lastMutationSites=0
scope.15.lastMutationKilled=0
scope.16.id=function:_event_player_id:152
scope.16.kind=function
scope.16.startLine=152
scope.16.endLine=154
scope.16.semanticHash=c530988a11ae8ca2
scope.16.lastMutatedAt=2026-06-01T12:36:30Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=4
scope.16.lastMutationKilled=4
scope.17.id=function:anonymous@157:157
scope.17.kind=function
scope.17.startLine=157
scope.17.endLine=164
scope.17.semanticHash=9adc1e3a44df0045
scope.17.lastMutatedAt=2026-06-01T12:36:30Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=survived
scope.17.lastMutationSites=5
scope.17.lastMutationKilled=4
scope.18.id=function:_player_cue_from_player_id:156
scope.18.kind=function
scope.18.startLine=156
scope.18.endLine=165
scope.18.semanticHash=cc39a23b94bff883
scope.18.lastMutatedAt=2026-06-01T12:36:30Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=no_sites
scope.18.lastMutationSites=0
scope.18.lastMutationKilled=0
scope.19.id=function:anonymous@167:167
scope.19.kind=function
scope.19.startLine=167
scope.19.endLine=175
scope.19.semanticHash=eb89a4c6c3c4fcd6
scope.19.lastMutatedAt=2026-06-01T12:36:30Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=no_sites
scope.19.lastMutationSites=0
scope.19.lastMutationKilled=0
scope.20.id=function:anonymous@177:177
scope.20.kind=function
scope.20.startLine=177
scope.20.endLine=190
scope.20.semanticHash=2837912e308f4ff9
scope.20.lastMutatedAt=2026-06-01T12:36:30Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=no_sites
scope.20.lastMutationSites=0
scope.20.lastMutationKilled=0
scope.21.id=function:anonymous@192:192
scope.21.kind=function
scope.21.startLine=192
scope.21.endLine=206
scope.21.semanticHash=533bf5dbdbe7e618
scope.21.lastMutatedAt=2026-06-01T12:36:30Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=no_sites
scope.21.lastMutationSites=0
scope.21.lastMutationKilled=0
scope.22.id=function:anonymous@208:208
scope.22.kind=function
scope.22.startLine=208
scope.22.endLine=220
scope.22.semanticHash=aed9073ee3bdac5c
scope.22.lastMutatedAt=2026-06-01T12:36:30Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=no_sites
scope.22.lastMutationSites=0
scope.22.lastMutationKilled=0
scope.23.id=function:anonymous@224:224
scope.23.kind=function
scope.23.startLine=224
scope.23.endLine=234
scope.23.semanticHash=8ee078ef4d1da802
scope.23.lastMutatedAt=2026-06-01T12:36:30Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=no_sites
scope.23.lastMutationSites=0
scope.23.lastMutationKilled=0
scope.24.id=function:anonymous@236:236
scope.24.kind=function
scope.24.startLine=236
scope.24.endLine=246
scope.24.semanticHash=dac1c0da6883dde9
scope.24.lastMutatedAt=2026-06-01T12:36:30Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=no_sites
scope.24.lastMutationSites=0
scope.24.lastMutationKilled=0
scope.25.id=function:anonymous@250:250
scope.25.kind=function
scope.25.startLine=250
scope.25.endLine=253
scope.25.semanticHash=9e4f6403c4204525
scope.25.lastMutatedAt=2026-06-01T12:36:30Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=no_sites
scope.25.lastMutationSites=0
scope.25.lastMutationKilled=0
scope.26.id=function:event_handlers.install:75
scope.26.kind=function
scope.26.startLine=75
scope.26.endLine=254
scope.26.semanticHash=6f92ad6abda14b67
scope.26.lastMutatedAt=2026-06-01T12:36:30Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=survived
scope.26.lastMutationSites=18
scope.26.lastMutationKilled=17
]]
