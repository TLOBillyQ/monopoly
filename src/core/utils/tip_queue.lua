local number_utils = require("src.core.utils.number_utils")

local tip_queue = {
  pending = {},
  active_tip = nil,
  runtime = {
    presenter = nil,
    scheduler = nil,
    test_mode = false,
  },
  epoch = 0,
}

local function _normalize_duration(duration)
  if number_utils.is_numeric(duration) and duration > 0 then
    return duration
  end
  return 2.0
end

local function _normalize_text(text)
  if text == nil then
    return nil
  end
  local ok, value = pcall(tostring, text)
  if not ok then
    return nil
  end
  return value
end

local function _normalize_intent(intent)
  if type(intent) ~= "table" then
    return nil
  end

  local text = _normalize_text(intent.text)
  if text == nil then
    return nil
  end

  return {
    text = text,
    duration = _normalize_duration(intent.duration),
    dedupe_key = intent.dedupe_key,
    blocks_inter_turn = intent.blocks_inter_turn == true,
    source = intent.source,
    chain_key = intent.chain_key,
  }
end

local function _has_matching_dedupe_key(dedupe_key)
  if dedupe_key == nil then
    return false
  end
  local active_tip = tip_queue.active_tip
  if active_tip ~= nil and active_tip.dedupe_key == dedupe_key then
    return true
  end
  local pending = tip_queue.pending
  for i = 1, #pending do
    if pending[i].dedupe_key == dedupe_key then
      return true
    end
  end
  return false
end

local function _present_tip(tip)
  local presenter = tip_queue.runtime.presenter
  if type(presenter) ~= "function" then
    return false
  end
  local ok = pcall(presenter, tip.text, tip.duration, tip)
  return ok
end

local function _release_tip(epoch, tip)
  if tip_queue.epoch ~= epoch then
    return
  end
  if tip_queue.active_tip ~= tip then
    return
  end
  tip_queue.active_tip = nil
  local pending = tip_queue.pending
  if #pending > 0 then
    local next_tip = table.remove(pending, 1)
    tip_queue.active_tip = next_tip
    local current_epoch = tip_queue.epoch
    _present_tip(next_tip)

    local function _release_next()
      _release_tip(current_epoch, next_tip)
    end

    local scheduler = tip_queue.runtime.scheduler
    if type(scheduler) == "function" then
      local invoked = false
      local function _wrapped()
        invoked = true
        _release_next()
      end
      local ok, handled = pcall(scheduler, next_tip.duration, _wrapped)
      if ok and (invoked or handled == true) then
        return
      end
      if ok and tip_queue.runtime.test_mode == true then
        _release_next()
        return
      end
      _release_next()
      return
    end
    _release_next()
  end
end

local function _dispatch_next_tip()
  if tip_queue.active_tip ~= nil then
    return
  end
  local pending = tip_queue.pending
  if #pending <= 0 then
    return
  end

  local next_tip = table.remove(pending, 1)
  tip_queue.active_tip = next_tip
  local current_epoch = tip_queue.epoch
  _present_tip(next_tip)

  local function _release_next()
    _release_tip(current_epoch, next_tip)
  end

  local scheduler = tip_queue.runtime.scheduler
  if type(scheduler) == "function" then
    local invoked = false
    local function _wrapped()
      invoked = true
      _release_next()
    end
    local ok, handled = pcall(scheduler, next_tip.duration, _wrapped)
    if ok and (invoked or handled == true) then
      return
    end
    if ok and tip_queue.runtime.test_mode == true then
      _release_next()
      return
    end
    _release_next()
    return
  end

  _release_next()
end

function tip_queue.configure_runtime(adapter)
  adapter = adapter or {}
  if adapter.clear_presenter == true then
    tip_queue.runtime.presenter = nil
  end
  if adapter.presenter ~= nil then
    assert(type(adapter.presenter) == "function", "tip presenter must be function or nil")
    tip_queue.runtime.presenter = adapter.presenter
  end
  if adapter.show_tip ~= nil then
    assert(type(adapter.show_tip) == "function", "tip presenter must be function or nil")
    tip_queue.runtime.presenter = adapter.show_tip
  end
  if adapter.tip_presenter ~= nil then
    assert(type(adapter.tip_presenter) == "function", "tip presenter must be function or nil")
    tip_queue.runtime.presenter = adapter.tip_presenter
  end
  if adapter.clear_scheduler == true then
    tip_queue.runtime.scheduler = nil
  end
  if adapter.scheduler ~= nil then
    assert(type(adapter.scheduler) == "function", "tip scheduler must be function or nil")
    tip_queue.runtime.scheduler = adapter.scheduler
  end
  if adapter.schedule ~= nil then
    assert(type(adapter.schedule) == "function", "tip scheduler must be function or nil")
    tip_queue.runtime.scheduler = adapter.schedule
  end
  if adapter.test_mode ~= nil then
    tip_queue.runtime.test_mode = adapter.test_mode == true
  end
  _dispatch_next_tip()
end

function tip_queue.enqueue(intent)
  local tip = _normalize_intent(intent)
  if tip == nil then
    return false
  end
  if _has_matching_dedupe_key(tip.dedupe_key) then
    return false
  end
  local pending = tip_queue.pending
  pending[#pending + 1] = tip
  _dispatch_next_tip()
  return true
end

function tip_queue.has_blocking_pending(phase_name)
  if phase_name ~= "inter_turn" then
    return false
  end
  local active_tip = tip_queue.active_tip
  if active_tip ~= nil and active_tip.blocks_inter_turn == true then
    return true
  end
  local pending = tip_queue.pending
  for i = 1, #pending do
    if pending[i].blocks_inter_turn == true then
      return true
    end
  end
  return false
end

function tip_queue.clear()
  tip_queue.pending = {}
  tip_queue.active_tip = nil
  tip_queue.epoch = tip_queue.epoch + 1
end

return tip_queue
