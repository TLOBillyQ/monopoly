local effect_track = require("src.ui.render.support.effect_track")

local landing_visual_hold = {}

local function _landing_visual_hold()
return require("src.state.landing_visual_hold")
end

_landing_visual_hold().set_post_release_hook(function()
  effect_track.await_all()
end)

function landing_visual_hold.start(game)
  return _landing_visual_hold().start(game)
end

function landing_visual_hold.hold_state_for_game(game, opts)
  return _landing_visual_hold().hold_state_for_game(game, opts)
end

function landing_visual_hold.is_active_game(game)
  return _landing_visual_hold().is_active_game(game)
end

function landing_visual_hold.is_release_pending_game(game)
  return _landing_visual_hold().is_release_pending_game(game)
end

function landing_visual_hold.mark_release_pending(game)
  return _landing_visual_hold().mark_release_pending(game)
end

function landing_visual_hold.clear_game(game)
  return _landing_visual_hold().clear_game(game)
end

function landing_visual_hold.is_active_state(state)
  return _landing_visual_hold().is_active_state(state)
end

function landing_visual_hold.is_flushing_state(state)
  return _landing_visual_hold().is_flushing_state(state)
end

function landing_visual_hold.sync_state_from_game(state, game)
  return _landing_visual_hold().sync_state_from_game(state, game)
end

function landing_visual_hold.should_defer(state, game)
  return _landing_visual_hold().should_defer(state, game)
end

function landing_visual_hold.capture_frozen_ui_model(state)
  return _landing_visual_hold().capture_frozen_ui_model(state)
end

function landing_visual_hold.freeze_active_ui(state)
  return _landing_visual_hold().freeze_active_ui(state)
end

function landing_visual_hold.defer_dirty(state, dirty)
  return _landing_visual_hold().defer_dirty(state, dirty)
end

function landing_visual_hold.register_release_callback(state, key, fn, opts)
  return _landing_visual_hold().register_release_callback(state, key, fn, opts)
end

function landing_visual_hold.run_or_defer(state, game, key, fn, opts)
  return _landing_visual_hold().run_or_defer(state, game, key, fn, opts)
end

function landing_visual_hold.defer_popup(state, payload, opts, replay)
  return _landing_visual_hold().defer_popup(state, payload, opts, replay)
end

function landing_visual_hold.defer_runtime_event(state, event_name, payload, replay)
  return _landing_visual_hold().defer_runtime_event(state, event_name, payload, replay)
end

function landing_visual_hold.defer_board_visual_sync(state, payload, replay)
  return _landing_visual_hold().defer_board_visual_sync(state, payload, replay)
end

function landing_visual_hold.defer_tile_update(state, tile_id, level, replay)
  return _landing_visual_hold().defer_tile_update(state, tile_id, level, replay)
end

function landing_visual_hold.defer_owner_change(state, tile_id, owner_id, replay)
  return _landing_visual_hold().defer_owner_change(state, tile_id, owner_id, replay)
end

function landing_visual_hold.defer_bankruptcy_clear(state, game, player, owned_tile_ids, replay)
  return _landing_visual_hold().defer_bankruptcy_clear(state, game, player, owned_tile_ids, replay)
end

function landing_visual_hold.with_flushing(state, fn)
  return _landing_visual_hold().with_flushing(state, fn)
end

function landing_visual_hold.merge_dirty(target, dirty)
  return _landing_visual_hold().merge_dirty(target, dirty)
end

function landing_visual_hold.release(state, opts)
  return _landing_visual_hold().release(state, opts)
end

function landing_visual_hold.reset_state(state)
  return _landing_visual_hold().reset_state(state)
end

function landing_visual_hold.set_post_release_hook(fn)
  return _landing_visual_hold().set_post_release_hook(fn)
end

return landing_visual_hold
