local AdapterLayer = require("Manager.Adapter.Core.AdapterLayer")

local MainController = {}

local NEXT_TURN_COOLDOWN = 0.4

local function get_timestamp_seconds()
  if not (GameAPI and GameAPI.get_timestamp) then
    return nil
  end
  local ts = GameAPI.get_timestamp()
  if type(ts) ~= "number" then
    return nil
  end
  if ts > 10000000000 then
    return ts / 1000
  end
  return ts
end

function MainController.dispatch_action(layer, action)
  if not action then
    return
  end
  if action.type == "ui_button" then
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = tonumber(slot_index)
      local choice = layer.pending_choice
      if not (choice and choice.kind == "item_phase_choice") then
        return
      end
      local item_ids = layer.ui and layer.ui.item_slot_item_ids or nil
      local item_id = item_ids and item_ids[slot_index] or nil
      if not item_id then
        return
      end
      local options = choice.options or {}
      local option_ok = false
      for _, opt in ipairs(options) do
        local opt_id = opt.id or opt
        if opt_id == item_id then
          option_ok = true
          break
        end
      end
      if not option_ok then
        return
      end
      layer:dispatch_action({ type = "choice_select", choice_id = choice.id, option_id = item_id })
      return
    end
    if action.id == "next" then
      print("[debug] dispatch ui_button next")
      local phase = nil
      local store = layer.game and layer.game.store
      if store and store.get then
        phase = store:get({ "turn", "phase" })
      end
      local now = get_timestamp_seconds()
      if layer.next_turn_locked then
        local allow = false
        if layer.next_turn_lock_phase and phase and phase ~= layer.next_turn_lock_phase then
          allow = true
        elseif now and layer.next_turn_last_click
            and (now - layer.next_turn_last_click) >= NEXT_TURN_COOLDOWN then
          allow = true
        end
        if not allow then
          return
        end
      end
      layer.next_turn_locked = true
      layer.next_turn_last_click = now
      layer.next_turn_lock_phase = phase
      layer:step_turn()
    elseif action.id == "auto" then
      layer.ui.auto_play = not layer.ui.auto_play
      layer.auto_runner:set_enabled(layer.ui.auto_play)
      layer.auto_runner:reset_timer()
    elseif action.id == "restart" then
      local was_auto = layer.ui.auto_play
      layer:set_game(layer:new_game())
      layer.auto_runner:set_enabled(was_auto)
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    AdapterLayer.clear_choice(layer, {
      on_close_choice = function(ctx)
        ctx:_close_choice_modal()
      end,
    })
    if layer.game then
      layer.game:dispatch_action(action)
    end
  end
end

return MainController
