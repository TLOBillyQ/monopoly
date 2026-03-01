local turn_script = require("src.game.runtime_coroutine.TurnScript")
local action_router = require("src.game.runtime_coroutine.ActionRouter")

local scheduler = {}
local SIGNAL_ACTION = "action"

local function _is_action(signal)
  return type(signal) == "table" and signal.type == SIGNAL_ACTION
end

local function _ensure_queue(session)
  if type(session.queue) ~= "table" then
    session.queue = {}
  end
  return session.queue
end

local function _ensure_script(session)
  local co = session.script
  if co and coroutine.status(co) ~= "dead" then
    return co
  end
  session:reset_turn()
  co = turn_script.create(session)
  session.script = co
  return co
end

function scheduler.dispatch(session, signal)
  assert(session ~= nil, "missing scheduler session")
  if signal == nil then
    return
  end
  local queue = _ensure_queue(session)
  queue[#queue + 1] = signal
end

function scheduler.step(session, dt)
  assert(session ~= nil, "missing scheduler session")
  local co = _ensure_script(session)
  local queue = _ensure_queue(session)
  if #queue == 0 then
    queue[#queue + 1] = action_router.tick(dt)
  end

  while #queue > 0 do
    local signal = table.remove(queue, 1)
    if _is_action(signal) then
      session:set_pending_action(signal.action)
    end
    local ok, yielded = coroutine.resume(co, signal)
    if not ok then
      error(yielded)
    end
    if coroutine.status(co) == "dead" then
      session.finished = true
      session.wait_state = nil
      return { finished = true }
    end
    if type(yielded) == "table" and yielded.kind == "wait" then
      session.wait_state = yielded.wait_state
      if #queue == 0 then
        return { wait_state = yielded.wait_state, finished = false }
      end
    else
      session.wait_state = nil
    end
  end

  return {
    wait_state = session.wait_state,
    finished = session.finished == true,
  }
end

return scheduler
