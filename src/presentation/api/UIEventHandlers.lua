local monopoly_event = require("src.game.core.runtime.MonopolyEvents")

local event_handlers = {}
local context = { installed = false, logger = nil, state = nil }

local function _resolve_actor_display_name(player)
  if type(player) ~= "table" then
    return nil
  end
  local player_id = player.id
  if player_id ~= nil and GameAPI and type(GameAPI.get_role) == "function" then
    local ok_role, role = pcall(GameAPI.get_role, player_id)
    if ok_role and role and type(role.get_name) == "function" then
      local ok_name, role_name = pcall(role.get_name)
      if ok_name and role_name ~= nil and role_name ~= "" then
        return role_name
      end
    end
  end
  local player_name = player.name
  if player_name ~= nil and player_name ~= "" then
    return player_name
  end
  return nil
end

local function _build_other_action_prompt_text(event_data)
  if type(event_data) ~= "table" then
    return nil
  end
  local raw_text = event_data.prompt_text or event_data.text
  if type(raw_text) ~= "string" or raw_text == "" then
    return nil
  end
  local actor_name = _resolve_actor_display_name(event_data.player)
  if actor_name == nil or actor_name == "" then
    return raw_text
  end
  return string.gsub(raw_text, "玩家", actor_name)
end

local function _sync_other_player_action_prompt(event_data)
  local state = context.state
  if type(state) ~= "table" then
    return
  end
  local player = event_data and event_data.player or nil
  local actor_player_id = player and player.id or nil
  if actor_player_id == nil then
    return
  end
  local prompt_text = _build_other_action_prompt_text(event_data)
  if prompt_text == nil or prompt_text == "" then
    return
  end
  state.ui_other_action_prompt_pending = {
    actor_player_id = actor_player_id,
    text = prompt_text,
  }
  state.ui_dirty = true
end

local function _apply_game_result_panels(event_data)
  if not (GameAPI and type(GameAPI.get_role) == "function") then
    return
  end
  local state = context.state
  local game = state and state.game or nil
  local players = game and game.players or nil
  if type(players) ~= "table" then
    return
  end
  local winner_ids = event_data and event_data.winner_ids or {}
  for _, player in ipairs(players) do
    local ok_role, role = pcall(GameAPI.get_role, player.id)
    if ok_role and role then
      if winner_ids[player.id] then
        if role.game_win_and_show_result_panel then
          role.game_win_and_show_result_panel()
        end
      else
        if role.lose then
          role.lose()
        end
      end
    end
  end
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

  for _, event_name in ipairs(log_events) do
    RegisterCustomEvent(event_name, function(_, _, data)
      local event_data = _event_data(data)
      local log = context.logger
      if log and event_data and event_data.text then
        log.event(event_data.text)
      end
    end)
  end

  for _, event_name in ipairs(movement_log_events) do
    RegisterCustomEvent(event_name, function(_, _, data)
      local event_data = _event_data(data)
      local log = context.logger
      if log and event_data and event_data.text then
        log.event(event_data.text)
      end
      _sync_other_player_action_prompt(event_data)
    end)
  end

  local ok, action_anim = pcall(require, "src.presentation.render.ActionAnim")

  local function _resolve_tile_index(payload)
    if type(payload) ~= "table" then
      return nil
    end
    if payload.tile_index then
      return payload.tile_index
    end
    local tile_id = nil
    if payload.tile and payload.tile.id then
      tile_id = payload.tile.id
    elseif payload.tile_id then
      tile_id = payload.tile_id
    end
    local ctx = context.state
    if tile_id and ctx and ctx.game and ctx.game.board and ctx.game.board.index_of_tile_id then
      return ctx.game.board:index_of_tile_id(tile_id)
    end
    return nil
  end

  RegisterCustomEvent(monopoly_event.movement.roadblock_hit, function(_, _, data)
    local idx = _resolve_tile_index(data)
    local ctx = context.state
    if ok and action_anim and idx and ctx then
      action_anim.clear_overlay(ctx, "roadblock", idx)
    end
  end)

  RegisterCustomEvent(monopoly_event.land.mine_hit, function(_, _, data)
    local idx = _resolve_tile_index(data)
    local ctx = context.state
    if ok and action_anim and idx and ctx then
      action_anim.clear_overlay(ctx, "mine", idx)
    end
  end)

  RegisterCustomEvent(monopoly_event.market.buy_failed, function(_, _, data)
    local event_data = _event_data(data)
    local popup = event_data and event_data.popup or nil
    local ctx = context.state
    if popup and ctx and ctx.push_popup then
      ctx:push_popup(popup)
    end
  end)

  RegisterCustomEvent(monopoly_event.game.finished, function(_, _, data)
    local event_data = _event_data(data)
    _apply_game_result_panels(event_data)
  end)
end

return event_handlers
