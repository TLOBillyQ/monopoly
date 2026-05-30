local runtime_state = require("src.state.runtime")
local deferred_dirty = require("src.state.visual_hold.deferred_dirty")
local release_scheduler = require("src.state.visual_hold.release_scheduler")
local event_log = require("src.state.event_log")
local dirty_tracker = require("src.state.dirty_tracker")

local landing_visual_hold = {}

local post_release_hook = nil

local function _ensure_hold(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local hold = turn_runtime.landing_visual_hold
  if type(hold) ~= "table" then
    hold = {
      active = false,
      release_pending = false,
      flushing = false,
      frozen_ui_model = nil,
      deferred_dirty = deferred_dirty.new_bucket(),
      release_callbacks = {},
    }
    turn_runtime.landing_visual_hold = hold
  end
  deferred_dirty.ensure_inventory_ids(hold)
  release_scheduler.ensure_buffers(hold)
  return hold
end

local _mark_turn_dirty = dirty_tracker.mark_turn

local function _ensure_event_log_for_game(game)
  if type(game) ~= "table" then
    return nil
  end
  game.state = game.state or {}
  game.state.event_log = game.state.event_log or event_log.new()
  return game.state.event_log
end

local function _reset_deferred_buffers(hold)
  deferred_dirty.reset(hold)
  release_scheduler.reset(hold)
end

local function _game_turn(game)
  return game and game.turn or nil
end

local function _game_turn_bool(field)
  return function(game)
    local turn = _game_turn(game)
    return turn and turn[field] == true or false
  end
end

local _game_turn_active = _game_turn_bool("landing_visual_hold_active")
local _game_turn_release_pending = _game_turn_bool("landing_visual_release_pending")

local function _project_hold_to_game(game, hold)
  local turn = _game_turn(game)
  if turn == nil then
    return
  end
  turn.landing_visual_hold_active = hold.active == true
  turn.landing_visual_release_pending = hold.release_pending == true
end

local function _hold_is_state_source(hold)
  return hold.source == "state"
end

local function _set_hold_state(state, active, release_pending, source)
  runtime_state.set_landing_visual_hold_active(state, active)
  runtime_state.set_landing_visual_release_pending(state, release_pending)
  runtime_state.set_landing_visual_hold_source(state, source)
  return _ensure_hold(state)
end

function landing_visual_hold.start(game, opts)
  local _ = opts
  if not (game and game.turn) then
    return false
  end
  local state = game.landing_visual_hold_state
  if landing_visual_hold.is_active_game(game) == true then
    if type(state) == "table" then
      local hold = _ensure_hold(state)
      local was_active = hold.active == true
      hold = _set_hold_state(state, true, false, "state")
      _project_hold_to_game(game, hold)
      if was_active ~= true then
        _ensure_event_log_for_game(game)
        event_log.push_buffer(game.state.event_log, hold)
      end
    end
    return false
  end
  if type(state) == "table" then
    local hold = _set_hold_state(state, true, false, "state")
    _project_hold_to_game(game, hold)
    _ensure_event_log_for_game(game)
    event_log.push_buffer(game.state.event_log, hold)
  else
    game.turn.landing_visual_hold_active = true
    game.turn.landing_visual_release_pending = false
  end
  _mark_turn_dirty(game)
  return true
end

landing_visual_hold.hold_state_for_game = landing_visual_hold.start

local function _hold_field_or_game_fallback(game, field, fallback)
  local state = game and game.landing_visual_hold_state or nil
  if type(state) == "table" then
    local hold = _ensure_hold(state)
    if _hold_is_state_source(hold) then
      return hold[field] == true
    end
  end
  return fallback(game)
end

function landing_visual_hold.is_active_game(game)
  return _hold_field_or_game_fallback(game, "active", _game_turn_active)
end

function landing_visual_hold.is_release_pending_game(game)
  return _hold_field_or_game_fallback(game, "release_pending", _game_turn_release_pending)
end

function landing_visual_hold.mark_release_pending(game)
  if not (game and game.turn) then
    return false
  end
  if landing_visual_hold.is_active_game(game) ~= true then
    return false
  end
  local state = game.landing_visual_hold_state
  if type(state) == "table" then
    local hold = _set_hold_state(state, true, true, "state")
    _project_hold_to_game(game, hold)
  else
    game.turn.landing_visual_release_pending = true
  end
  _mark_turn_dirty(game)
  return true
end

function landing_visual_hold.clear_game(game)
  if not (game and game.turn) then
    return false
  end
  local changed = landing_visual_hold.is_active_game(game) == true
    or landing_visual_hold.is_release_pending_game(game) == true
  local state = game.landing_visual_hold_state
  if type(state) == "table" then
    local hold = _set_hold_state(state, false, false, "state")
    _project_hold_to_game(game, hold)
  else
    game.turn.landing_visual_hold_active = false
    game.turn.landing_visual_release_pending = false
  end
  if changed then
    _mark_turn_dirty(game)
  end
  return changed
end

landing_visual_hold.is_active_state = runtime_state.get_landing_visual_hold_active

function landing_visual_hold.is_flushing_state(state)
  local hold = _ensure_hold(state)
  return hold.flushing == true
end

function landing_visual_hold.sync_state_from_game(state, game)
  local hold = _ensure_hold(state)
  local was_active = hold.active == true
  if _hold_is_state_source(hold) then
    _project_hold_to_game(game, hold)
    if hold.active == true and was_active ~= true then
      _ensure_event_log_for_game(game)
      event_log.push_buffer(game.state.event_log, hold)
    end
    return hold
  end
  runtime_state.set_landing_visual_hold_active(state, _game_turn_active(game))
  runtime_state.set_landing_visual_release_pending(state, _game_turn_release_pending(game))
  runtime_state.set_landing_visual_hold_source(state, "game")
  if hold.active == true and was_active ~= true then
    _ensure_event_log_for_game(game)
    event_log.push_buffer(game.state.event_log, hold)
  end
  return hold
end

function landing_visual_hold.should_defer(state, game)
  if state == nil then
    return false
  end
  if game ~= nil then
    landing_visual_hold.sync_state_from_game(state, game)
  end
  return landing_visual_hold.is_active_state(state) and not landing_visual_hold.is_flushing_state(state)
end

function landing_visual_hold.capture_frozen_ui_model(state)
  local hold = _ensure_hold(state)
  if hold.frozen_ui_model ~= nil then
    return hold.frozen_ui_model
  end
  hold.frozen_ui_model = runtime_state.get_ui_model(state)
  return hold.frozen_ui_model
end

function landing_visual_hold.freeze_active_ui(state)
  local hold = _ensure_hold(state)
  if hold.active ~= true then
    return nil
  end
  return landing_visual_hold.capture_frozen_ui_model(state)
end

function landing_visual_hold.defer_dirty(state, dirty)
  local hold = _ensure_hold(state)
  return deferred_dirty.defer(hold, dirty)
end

function landing_visual_hold.register_release_callback(state, key, fn, opts)
  local hold = _ensure_hold(state)
  return release_scheduler.register(hold, key, fn, opts)
end

function landing_visual_hold.run_or_defer(state, game, key, fn, opts)
  if landing_visual_hold.should_defer(state, game) then
    landing_visual_hold.register_release_callback(state, key, fn, opts)
    return true
  end
  return fn()
end

local function _defer_replay(state, bucket, replay, ...)
  return release_scheduler.register_deferred_replay(_ensure_hold(state), bucket, replay, ...)
end

function landing_visual_hold.defer_popup(state, payload, opts, replay)
  return _defer_replay(state, "popup", replay, payload, opts)
end

function landing_visual_hold.defer_runtime_event(state, _, payload, replay)
  return _defer_replay(state, "runtime_event", replay, payload)
end

function landing_visual_hold.defer_board_visual_sync(state, payload, replay)
  return _defer_replay(state, "board_visual_sync", replay, payload)
end

function landing_visual_hold.defer_tile_update(state, tile_id, level, replay)
  return _defer_replay(state, "tile_update", replay, tile_id, level)
end

function landing_visual_hold.defer_owner_change(state, tile_id, owner_id, replay)
  return _defer_replay(state, "owner_change", replay, tile_id, owner_id)
end

function landing_visual_hold.defer_bankruptcy_clear(state, game, player, owned_tile_ids, replay)
  return _defer_replay(state, "bankruptcy_clear", replay, game, player, owned_tile_ids)
end

function landing_visual_hold.with_flushing(state, fn)
  local hold = _ensure_hold(state)
  local previous = hold.flushing == true
  hold.flushing = true
  local ok, result_or_err = xpcall(fn, debug and debug.traceback or function(err)
    return err
  end)
  hold.flushing = previous
  if not ok then
    error(result_or_err)
  end
  return result_or_err
end

function landing_visual_hold.set_post_release_hook(fn)
  post_release_hook = fn
end

function landing_visual_hold.release(state, game)
  if game == nil and state and state.turn then
    return landing_visual_hold.clear_game(state)
  end
  if state and game then
    landing_visual_hold.sync_state_from_game(state, game)
  end
  local hold = _ensure_hold(state)
  if hold.release_pending ~= true then
    return false
  end

  hold.release_pending = false
  hold.active = false

  if game and game.dirty then
    deferred_dirty.merge_into(game.dirty, hold.deferred_dirty)
  end

  landing_visual_hold.with_flushing(state, function()
    release_scheduler.replay(hold)
  end)
  hold.frozen_ui_model = nil
  _reset_deferred_buffers(hold)

  if type(post_release_hook) == "function" then
    post_release_hook()
  end

  runtime_state.set_ui_dirty(state, true)
  landing_visual_hold.clear_game(game)
  return true
end

function landing_visual_hold.reset_state(state)
  local hold = _ensure_hold(state)
  event_log.pop_buffer(hold)
  hold.active = false
  hold.release_pending = false
  hold.flushing = false
  hold.frozen_ui_model = nil
  hold.source = nil
  _reset_deferred_buffers(hold)
  return hold
end

function landing_visual_hold.merge_dirty(target, dirty)
  return deferred_dirty.merge_into(target, dirty)
end

return landing_visual_hold

--[[ mutate4lua-manifest
version=2
projectHash=219a538513a8a96f
scope.0.id=chunk:src/state/visual_hold/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=341
scope.0.semanticHash=bc02cbd4f6f10c90
scope.1.id=function:_ensure_hold:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=28
scope.1.semanticHash=ff330682e1a05747
scope.2.id=function:_ensure_event_log_for_game:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=39
scope.2.semanticHash=bf49b587d9b31dd1
scope.3.id=function:_reset_deferred_buffers:41
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=44
scope.3.semanticHash=9fa9aff3bf179afb
scope.4.id=function:_game_turn:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=48
scope.4.semanticHash=061fcbbefd74727e
scope.5.id=function:anonymous@51:51
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=54
scope.5.semanticHash=44550c10fb581749
scope.6.id=function:_game_turn_bool:50
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=55
scope.6.semanticHash=0e93be9245aa2bf1
scope.7.id=function:_project_hold_to_game:60
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=67
scope.7.semanticHash=0e1ec79c5c67cfaf
scope.8.id=function:_hold_is_state_source:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=71
scope.8.semanticHash=877c0518e42368fc
scope.9.id=function:_set_hold_state:73
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=78
scope.9.semanticHash=8f49c14fcb44baaa
scope.10.id=function:landing_visual_hold.start:80
scope.10.kind=function
scope.10.startLine=80
scope.10.endLine=110
scope.10.semanticHash=ccbab2804b86293d
scope.11.id=function:_hold_field_or_game_fallback:114
scope.11.kind=function
scope.11.startLine=114
scope.11.endLine=123
scope.11.semanticHash=cf8a6dc00f50b3bd
scope.12.id=function:landing_visual_hold.is_active_game:125
scope.12.kind=function
scope.12.startLine=125
scope.12.endLine=127
scope.12.semanticHash=cd31b0f0c3d40d81
scope.13.id=function:landing_visual_hold.is_release_pending_game:129
scope.13.kind=function
scope.13.startLine=129
scope.13.endLine=131
scope.13.semanticHash=12f9586ef8f28d02
scope.14.id=function:landing_visual_hold.mark_release_pending:133
scope.14.kind=function
scope.14.startLine=133
scope.14.endLine=149
scope.14.semanticHash=a976c854ff581653
scope.15.id=function:landing_visual_hold.clear_game:151
scope.15.kind=function
scope.15.startLine=151
scope.15.endLine=169
scope.15.semanticHash=c88cd819661901fa
scope.16.id=function:landing_visual_hold.is_flushing_state:173
scope.16.kind=function
scope.16.startLine=173
scope.16.endLine=176
scope.16.semanticHash=3fbcc3ab9e56e04c
scope.17.id=function:landing_visual_hold.sync_state_from_game:178
scope.17.kind=function
scope.17.startLine=178
scope.17.endLine=197
scope.17.semanticHash=db8d194ea9652022
scope.18.id=function:landing_visual_hold.should_defer:199
scope.18.kind=function
scope.18.startLine=199
scope.18.endLine=207
scope.18.semanticHash=8c9f01d8f31ffbd2
scope.19.id=function:landing_visual_hold.capture_frozen_ui_model:209
scope.19.kind=function
scope.19.startLine=209
scope.19.endLine=216
scope.19.semanticHash=75dd2ec89c60fa3f
scope.20.id=function:landing_visual_hold.freeze_active_ui:218
scope.20.kind=function
scope.20.startLine=218
scope.20.endLine=224
scope.20.semanticHash=594b3a9d47ec654b
scope.21.id=function:landing_visual_hold.defer_dirty:226
scope.21.kind=function
scope.21.startLine=226
scope.21.endLine=229
scope.21.semanticHash=d80f3043d35abfa3
scope.22.id=function:landing_visual_hold.register_release_callback:231
scope.22.kind=function
scope.22.startLine=231
scope.22.endLine=234
scope.22.semanticHash=c1eba34a2fde332d
scope.23.id=function:landing_visual_hold.run_or_defer:236
scope.23.kind=function
scope.23.startLine=236
scope.23.endLine=242
scope.23.semanticHash=a514d20c16545343
scope.24.id=function:_defer_replay:244
scope.24.kind=function
scope.24.startLine=244
scope.24.endLine=246
scope.24.semanticHash=99db5aa652fc3faf
scope.25.id=function:landing_visual_hold.defer_popup:248
scope.25.kind=function
scope.25.startLine=248
scope.25.endLine=250
scope.25.semanticHash=c85c71e40d780218
scope.26.id=function:landing_visual_hold.defer_runtime_event:252
scope.26.kind=function
scope.26.startLine=252
scope.26.endLine=254
scope.26.semanticHash=51ae9f228391473f
scope.27.id=function:landing_visual_hold.defer_board_visual_sync:256
scope.27.kind=function
scope.27.startLine=256
scope.27.endLine=258
scope.27.semanticHash=0ebb7f5127ab1844
scope.28.id=function:landing_visual_hold.defer_tile_update:260
scope.28.kind=function
scope.28.startLine=260
scope.28.endLine=262
scope.28.semanticHash=54bdca939f1a69da
scope.29.id=function:landing_visual_hold.defer_owner_change:264
scope.29.kind=function
scope.29.startLine=264
scope.29.endLine=266
scope.29.semanticHash=1e1626fbde62c8e4
scope.30.id=function:landing_visual_hold.defer_bankruptcy_clear:268
scope.30.kind=function
scope.30.startLine=268
scope.30.endLine=270
scope.30.semanticHash=f424e3ea1bee42bc
scope.31.id=function:anonymous@276:276
scope.31.kind=function
scope.31.startLine=276
scope.31.endLine=278
scope.31.semanticHash=749d6143526735c7
scope.32.id=function:landing_visual_hold.with_flushing:272
scope.32.kind=function
scope.32.startLine=272
scope.32.endLine=284
scope.32.semanticHash=ab6091bc578de061
scope.33.id=function:landing_visual_hold.set_post_release_hook:286
scope.33.kind=function
scope.33.startLine=286
scope.33.endLine=288
scope.33.semanticHash=e5b8c61756687935
scope.34.id=function:anonymous@309:309
scope.34.kind=function
scope.34.startLine=309
scope.34.endLine=311
scope.34.semanticHash=401b641a06dcb899
scope.35.id=function:landing_visual_hold.release:290
scope.35.kind=function
scope.35.startLine=290
scope.35.endLine=322
scope.35.semanticHash=5bbd287b292852a2
scope.36.id=function:landing_visual_hold.reset_state:324
scope.36.kind=function
scope.36.startLine=324
scope.36.endLine=334
scope.36.semanticHash=715acf4415e6f831
scope.37.id=function:landing_visual_hold.merge_dirty:336
scope.37.kind=function
scope.37.startLine=336
scope.37.endLine=338
scope.37.semanticHash=e2ab30ae623a4de4
]]
