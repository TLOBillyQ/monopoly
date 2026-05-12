local debug_helpers = require("src.turn.waits.await.debug")
local move_anim_wait = require("src.turn.waits.await.move_anim")
local action_anim_wait = require("src.turn.waits.await.action_anim")
local choice_wait = require("src.turn.waits.await.choice")
local seconds_wait = require("src.turn.waits.await.seconds")
local simple_waits = require("src.turn.waits.await.simple")

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

await.choice = choice_wait.choice

function await.move_anim(session, args, opts)
  if debug_helpers.should_log() then
    move_anim_wait.log_move_anim_wait(session, opts)
  end
  return _await_anim_done(session, args, move_anim_wait.resolve_wait_anim_opts(opts))
end

await.action_anim = action_anim_wait.action_anim
await.landing_visual = simple_waits.landing_visual
await.detained = simple_waits.detained
await.inter_turn = simple_waits.inter_turn
await.seconds = seconds_wait.seconds
await.action = simple_waits.action

return await
