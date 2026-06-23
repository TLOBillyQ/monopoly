local timing = require("src.config.gameplay.timing")
local event_kinds = require("src.config.gameplay.event_kinds")
local panel_helpers = require("src.ui.coord.panel_helpers")
local item_atlas_view = require("src.ui.render.item_atlas")

local item_get_reveal = {}

local function _owner_role_id(anim)
  return anim and (anim.owner_role_id or anim.player_id) or nil
end

local function _is_current_reveal(state, anim)
  local current = state
    and state.game
    and state.game.turn
    and state.game.turn.action_anim
    or nil
  if current == nil or current.kind ~= event_kinds.item_get_reveal then
    return false
  end
  if anim and anim.seq ~= nil and current.seq ~= anim.seq then
    return false
  end
  return true
end

local function _hide_for_owner(state, anim)
  return panel_helpers.with_owner_role(state, _owner_role_id(anim), function()
    return item_atlas_view.hide_enlarged(state)
  end)
end

function item_get_reveal.play(state, anim, _, opts)
  local duration = timing.item_get_reveal_seconds
  panel_helpers.with_owner_role(state, _owner_role_id(anim), function()
    return item_atlas_view.show_enlarged(state, anim and anim.item_id or nil)
  end)
  local schedule = opts and opts.schedule or nil
  if type(schedule) == "function" then
    schedule(duration, function()
      if _is_current_reveal(state, anim) then
        _hide_for_owner(state, anim)
      end
    end)
  end
  return duration
end

return item_get_reveal
