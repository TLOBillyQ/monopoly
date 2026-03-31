local debug_helpers = require("src.turn.waits.await.debug_helpers")
local move_anim_wait = require("src.turn.waits.await.move_anim_wait")
local action_anim_wait = require("src.turn.waits.await.action_anim_wait")
local choice_wait = require("src.turn.waits.await.choice_wait")
local seconds_wait = require("src.turn.waits.await.seconds_wait")
local simple_waits = require("src.turn.waits.await.simple_waits")

local await = {}

local function _next(args)
  args = args or {}
  return args.next_state, args.next_args
end

local function _mark_dirty(game)
  if game and game.dirty then
    game.dirty.turn = true
    game.dirty.any = true
  end
end

local function _await_anim_done(session, args, opts)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  assert(opts ~= nil and opts.state_name ~= nil, "missing wait state_name")
  assert(opts.anim_key ~= nil, "missing wait anim_key")
  assert(opts.done_action_type ~= nil, "missing wait done_action_type")
  local game = session.game
  session:mark_phase(opts.state_name)
  local anim = game.turn[opts.anim_key]
  assert(anim ~= nil, "missing " .. tostring(opts.anim_key))
  local action = session:take_pending_action()
  if not action or action.type ~= opts.done_action_type then
    return { wait = true }
  end
  if action.seq and anim.seq and action.seq ~= anim.seq then
    return { wait = true }
  end
  game.turn[opts.anim_key] = nil
  _mark_dirty(game)
  local next_state, next_args = _next(args)
  return { next_state = next_state, next_args = next_args }
end

function await.choice(session, args)
  return choice_wait.choice(session, args)
end

function await.move_anim(session, args, opts)
  if debug_helpers.should_log() then
    move_anim_wait.log_move_anim_wait(session, opts)
  end
  return _await_anim_done(session, args, move_anim_wait.resolve_wait_anim_opts(opts))
end

function await.action_anim(session, args)
  return action_anim_wait.action_anim(session, args)
end

function await.landing_visual(session, args)
  return simple_waits.landing_visual(session, args)
end

function await.detained(session, args)
  return simple_waits.detained(session, args)
end

function await.inter_turn(session, args)
  return simple_waits.inter_turn(session, args)
end

function await.seconds(session, sec, opts)
  return seconds_wait.seconds(session, sec, opts)
end

function await.action(session, args)
  return simple_waits.action(session, args)
end

return await
