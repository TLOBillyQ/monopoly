-- 棋盘反馈 cue 事件处理器(自 event_handlers.lua 拆分,行为保持):租金/税务/
-- 机会卡/回合开始/状态/神明/破产等事件的 player/tile 级 cue 与打断;
-- 踩雷/地块命中索引定位在 tile_index_handlers。
local board_feedback = require("src.ui.render.board_feedback.service")
local panel_interrupt = require("src.ui.state.panel_interrupt")

local board_feedback_handlers = {}
local context = { state = nil }

local function _event_data(data)
  if type(data) == "table" then
    return data
  end
  return nil
end

local function _event_field(event_data, key)
  return event_data and event_data[key] or nil
end

local function _cue_subject(event_data, subject_key)
  return event_data and event_data[subject_key] or nil
end

local function _player_cue_from_subject(cue_name, subject_key)
  return function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local subject = _cue_subject(event_data, subject_key)
    if ctx and subject and subject.id ~= nil then
      board_feedback.play_player_cue(ctx, cue_name, subject.id, event_data)
    end
  end
end

local function _player_id(player)
  return player and player.id or nil
end

local function _negative_card_ready(ctx, player_id, card)
  return ctx and player_id ~= nil and card and card.negative == true
end

-- 负向卡(negative=true)对持有者播一次 generic_negative cue;条件不齐
-- (ctx/player/card 缺省或非负卡)时静默。
local function _play_negative_card_cue(ctx, player, card, event_data)
  local player_id = _player_id(player)
  if _negative_card_ready(ctx, player_id, card) then
    board_feedback.play_player_cue(ctx, "generic_negative", player_id, event_data)
  end
end

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

-- 播 tile 级 cue;命中(条件齐)时返回 true 供调用方跳过 player 级兜底。
local function _play_tile_cue(ctx, cue_name, tile_index, event_data)
  if ctx and cue_name and tile_index ~= nil then
    board_feedback.play_tile_cue(ctx, cue_name, tile_index, event_data)
    return true
  end
  return false
end

local function _deity_cue_name(deity_type)
  if deity_type == "rich" then
    return "rich_deity"
  end
  if deity_type == "angel" then
    return "angel_deity"
  end
  return nil
end

function board_feedback_handlers.set_context(state)
  context.state = state
end

function board_feedback_handlers.install(register_handler, monopoly_event)
  local _handle_rent_cue = _player_cue_from_subject("cash_burst", "owner")
  register_handler(monopoly_event.land.rent_paid, _handle_rent_cue)
  register_handler(monopoly_event.land.rent_bankrupt, _handle_rent_cue)

  register_handler(monopoly_event.land.tax_paid, _player_cue_from_subject("tax_wave", "player"))

  register_handler(monopoly_event.chance.applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player = _event_field(event_data, "player")
    local card = _event_field(event_data, "card")
    _play_negative_card_cue(ctx, player, card, event_data)
  end)

  register_handler(monopoly_event.feedback.turn_started, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = _event_player_id(event_data)
    if ctx and player_id ~= nil then
      board_feedback.play_player_cue(ctx, "turn_started", player_id, event_data)
      panel_interrupt.begin_player_action(ctx, player_id)
    end
  end)

  register_handler(monopoly_event.feedback.status_applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local cue_name = _event_field(event_data, "cue_name")
    local tile_index = _event_field(event_data, "tile_index")
    if not _play_tile_cue(ctx, cue_name, tile_index, event_data) then
      local player_id = _event_player_id(event_data)
      if ctx and cue_name and player_id ~= nil then
        board_feedback.play_player_cue(ctx, cue_name, player_id, event_data)
      end
    end
  end)

  register_handler(monopoly_event.feedback.deity_applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = _event_player_id(event_data)
    local cue_name = _deity_cue_name(_event_field(event_data, "deity_type"))
    if ctx and cue_name and player_id ~= nil then
      board_feedback.play_player_cue(ctx, cue_name, player_id, event_data)
    end
  end)

  register_handler(monopoly_event.feedback.angel_immune_blocked, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = _event_player_id(event_data)
    if not _play_tile_cue(ctx, "angel_deity", _event_field(event_data, "tile_index"), event_data) then
      if ctx and player_id ~= nil then
        board_feedback.play_player_cue(ctx, "angel_deity", player_id, event_data)
      end
    end
  end)

  register_handler(monopoly_event.feedback.bankruptcy, _player_cue_from_player_id("bankruptcy_slam"))

  register_handler(monopoly_event.market.bought_item, _player_cue_from_subject("cash_burst", "player"))
end

return board_feedback_handlers

--[[ mutate4lua-manifest
version=4
projectHash=d3ccbb68f95db7a5
scope.0.id=chunk:src/ui/coord/board_feedback_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=156
scope.0.semanticHash=bf06217626382bb6
scope.1.id=function:_event_data
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=e5984887eaa027c5
scope.2.id=function:_event_field
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=cd6b189045fad21d
scope.3.id=function:_cue_subject
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=cd6b189045fad21d
scope.4.id=function:_player_cue_from_subject
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=34
scope.4.semanticHash=4da353648f8ea37f
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=33
scope.5.semanticHash=f3d0197a3bd2ac95
scope.6.id=function:_player_id
scope.6.kind=function
scope.6.startLine=36
scope.6.endLine=38
scope.6.semanticHash=616a2ca60599c94f
scope.7.id=function:_negative_card_ready
scope.7.kind=function
scope.7.startLine=40
scope.7.endLine=42
scope.7.semanticHash=38c1c2f86e9bae9b
scope.8.id=function:_play_negative_card_cue
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=51
scope.8.semanticHash=48d8c92ee21c52cb
scope.9.id=function:_event_player_id
scope.9.kind=function
scope.9.startLine=53
scope.9.endLine=55
scope.9.semanticHash=62307bcab59392f6
scope.10.id=function:_player_cue_from_player_id
scope.10.kind=function
scope.10.startLine=57
scope.10.endLine=66
scope.10.semanticHash=32debb67ba0df104
scope.11.id=function:<anonymous>#2
scope.11.kind=function
scope.11.startLine=58
scope.11.endLine=65
scope.11.semanticHash=ae2c6b314d8010db
scope.12.id=function:_play_tile_cue
scope.12.kind=function
scope.12.startLine=69
scope.12.endLine=75
scope.12.semanticHash=3a971d7803e0d4aa
scope.13.id=function:_deity_cue_name
scope.13.kind=function
scope.13.startLine=77
scope.13.endLine=85
scope.13.semanticHash=3946615e64e704e6
scope.14.id=function:board_feedback_handlers.set_context
scope.14.kind=function
scope.14.startLine=87
scope.14.endLine=89
scope.14.semanticHash=a9d82726f0169db1
scope.15.id=function:board_feedback_handlers.install
scope.15.kind=function
scope.15.startLine=91
scope.15.endLine=153
scope.15.semanticHash=2d294418315caecd
scope.16.id=function:<anonymous>#3
scope.16.kind=function
scope.16.startLine=98
scope.16.endLine=104
scope.16.semanticHash=95ab2b5247e1fd36
scope.17.id=function:<anonymous>#4
scope.17.kind=function
scope.17.startLine=106
scope.17.endLine=114
scope.17.semanticHash=46b8c7094507e9d2
scope.18.id=function:<anonymous>#5
scope.18.kind=function
scope.18.startLine=116
scope.18.endLine=127
scope.18.semanticHash=c6b303238c399bb5
scope.19.id=function:<anonymous>#6
scope.19.kind=function
scope.19.startLine=129
scope.19.endLine=137
scope.19.semanticHash=8ec901e7926a0b7c
scope.20.id=function:<anonymous>#7
scope.20.kind=function
scope.20.startLine=139
scope.20.endLine=148
scope.20.semanticHash=eb2a5736444272fe
]]
