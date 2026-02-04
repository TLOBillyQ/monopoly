local monopoly_event = require("Config.MonopolyEvents")

local event_handlers = {}
local installed = false

function event_handlers.install(_, logger, state)
  if installed then
    return
  end
  installed = true

  local log_events = {
    monopoly_event.movement.moved,
    monopoly_event.movement.passed_start,
    monopoly_event.movement.roadblock_hit,
    monopoly_event.movement.market_interrupt,
    monopoly_event.movement.steal_interrupt,
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

  for _, event_name in ipairs(log_events) do
    RegisterCustomEvent(event_name, function(_, _, data)
      if data.text then
        logger.event(data.text)
      end
    end)
  end

  local ok, action_anim = pcall(require, "src.ui.ActionAnim")

  local function _resolve_tile_index(payload)
    if payload and payload.tile_index then
      return payload.tile_index
    end
    local tile_id = nil
    if payload and payload.tile and payload.tile.id then
      tile_id = payload.tile.id
    elseif payload and payload.tile_id then
      tile_id = payload.tile_id
    end
    if tile_id and state and state.game and state.game.board and state.game.board.index_of_tile_id then
      return state.game.board:index_of_tile_id(tile_id)
    end
    return nil
  end

  RegisterCustomEvent(monopoly_event.movement.roadblock_hit, function(_, _, data)
    local idx = _resolve_tile_index(data)
    if ok and action_anim and idx then
      action_anim.clear_overlay(state, "roadblock", idx)
    end
  end)

  RegisterCustomEvent(monopoly_event.land.mine_hit, function(_, _, data)
    local idx = _resolve_tile_index(data)
    if ok and action_anim and idx then
      action_anim.clear_overlay(state, "mine", idx)
    end
  end)

  RegisterCustomEvent(monopoly_event.market.buy_failed, function(_, _, data)
    local popup = data.popup
    if popup then
      state:push_popup(popup)
    end
  end)
end

return event_handlers
