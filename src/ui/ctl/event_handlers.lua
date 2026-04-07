local monopoly_event = require("src.core.events")
local runtime_ports = require("src.core.ports.runtime_ports")
local host_runtime_ports = require("src.ui.host_bridge")
local board_feedback = require("src.ui.render.board_feedback_service")
local landing_visual_hold = require("src.ui.landing_visual_hold")

local event_handlers = {}
local context = { installed = false, logger = nil, state = nil, handlers_by_event = {} }
local MARKET_BUY_FAILED_MIN_TIP_SECONDS = 3.0

local function _enqueue_tip(intent)
  return host_runtime_ports.enqueue_tip(intent)
end

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

  local movement_log_events = {
    monopoly_event.movement.moved,
    monopoly_event.movement.passed_start,
    monopoly_event.movement.roadblock_hit,
    monopoly_event.movement.market_interrupt,
    monopoly_event.movement.steal_interrupt,
  }

  local log_events = {
    monopoly_event.land.rent_skipped_mountain,
    monopoly_event.land.strong_card_used,
    monopoly_event.land.free_rent_used,
    monopoly_event.land.rent_paid,
    monopoly_event.land.rent_bankrupt,
    monopoly_event.land.tax_free,
    monopoly_event.land.tax_paid,
    monopoly_event.market.bought_item,
    monopoly_event.market.bought_vehicle,
    monopoly_event.market.auto_skip,
    monopoly_event.chance.applied,
  }

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
  local deferred = landing_visual_hold.run_or_defer(current_state, nil, "runtime_event", function()
    result = handler(data)
  end)
  if deferred == true then
    return result
  end
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

  for _, event_name in ipairs(log_events) do
    _register_handler(event_name, function(data)
      local event_data = _event_data(data)
      local log = context.logger
      if log and event_data and event_data.text then
        log.event(event_data.text)
      end
    end)
  end

  for _, event_name in ipairs(movement_log_events) do
    _register_handler(event_name, function(data)
      local event_data = _event_data(data)
      local log = context.logger
      if log and event_data and event_data.text then
        log.event(event_data.text)
      end
    end)
  end

  local ok, action_anim = pcall(require, "src.ui.render.action_anim")

  _register_handler(monopoly_event.movement.roadblock_hit, function(data)
    return _resolve_tile_index_from_payload(_event_data(data))
  end)

  _register_handler(monopoly_event.land.mine_hit, function(data)
    return _resolve_tile_index_from_payload(_event_data(data))
  end)

  _register_handler(monopoly_event.land.rent_paid, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local owner = event_data and event_data.owner or nil
    if ctx and owner and owner.id ~= nil then
      board_feedback.play_player_cue(ctx, "cash_burst", owner.id, event_data)
    end
  end)

  _register_handler(monopoly_event.land.rent_bankrupt, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local owner = event_data and event_data.owner or nil
    if ctx and owner and owner.id ~= nil then
      board_feedback.play_player_cue(ctx, "cash_burst", owner.id, event_data)
    end
  end)

  _register_handler(monopoly_event.land.tax_paid, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player = event_data and event_data.player or nil
    if ctx and player and player.id ~= nil then
      board_feedback.play_player_cue(ctx, "tax_wave", player.id, event_data)
    end
  end)

  _register_handler(monopoly_event.chance.applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player = event_data and event_data.player or nil
    local card = event_data and event_data.card or nil
    if ctx and player and player.id ~= nil and card and card.negative == true then
      board_feedback.play_player_cue(ctx, "generic_negative", player.id, event_data)
    end
  end)

  _register_handler(monopoly_event.feedback.turn_started, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = event_data and (event_data.player_id or (event_data.player and event_data.player.id)) or nil
    if ctx and player_id ~= nil then
      board_feedback.play_player_cue(ctx, "turn_started", player_id, event_data)
    end
  end)

  _register_handler(monopoly_event.feedback.status_applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local cue_name = event_data and event_data.cue_name or nil
    local player_id = event_data and (event_data.player_id or (event_data.player and event_data.player.id)) or nil
    local tile_index = event_data and event_data.tile_index or nil
    if ctx and cue_name and tile_index ~= nil then
      board_feedback.play_tile_cue(ctx, cue_name, tile_index, event_data)
      return
    end
    if ctx and cue_name and player_id ~= nil then
      board_feedback.play_player_cue(ctx, cue_name, player_id, event_data)
    end
  end)

  _register_handler(monopoly_event.feedback.deity_applied, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local deity_type = event_data and event_data.deity_type or nil
    local player_id = event_data and (event_data.player_id or (event_data.player and event_data.player.id)) or nil
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

  _register_handler(monopoly_event.feedback.bankruptcy, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player_id = event_data and (event_data.player_id or (event_data.player and event_data.player.id)) or nil
    if ctx and player_id ~= nil then
      board_feedback.play_player_cue(ctx, "bankruptcy_slam", player_id, event_data)
    end
  end)

  _register_handler(monopoly_event.market.buy_failed, function(data)
    local event_data = _event_data(data)
    local tip_text = _resolve_market_buy_failed_tip(event_data)
    _enqueue_tip({
      text = tip_text,
      duration = MARKET_BUY_FAILED_MIN_TIP_SECONDS,
      dedupe_key = "market_buy_failed:" .. tostring(tip_text),
      blocks_inter_turn = false,
      source = "market.buy_failed",
    })
  end)

  _register_handler(monopoly_event.market.bought_item, function(data)
    local event_data = _event_data(data)
    local ctx = context.state
    local player = event_data and event_data.player or nil
    if ctx and player and player.id ~= nil then
      board_feedback.play_player_cue(ctx, "cash_burst", player.id, event_data)
    end
  end)

  _register_handler(monopoly_event.game.finished, function(data)
    local event_data = _event_data(data)
    _apply_game_result_panels(event_data)
  end)
end

return event_handlers
