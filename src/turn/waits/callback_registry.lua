local callback_registry = {}
callback_registry.callback_keys = {
  after_action_anim = "after_action_anim",
  after_landing_visual = "after_landing_visual",
}
callback_registry.wait_keys = {
  landing_visual = "landing_visual",
}

local function _ensure_runtime(game)
  assert(type(game) == "table", "missing game")
  local runtime = game.wait_callback_runtime
  if type(runtime) ~= "table" then
    runtime = {
      callbacks = {},
      seq_by_key = {},
      pending_seq_by_key = {},
      ready_seq_by_key = {},
    }
    game.wait_callback_runtime = runtime
  end
  return runtime
end

function callback_registry.register(game, key, callback)
  assert(type(key) == "string" and key ~= "", "missing callback key")
  assert(type(callback) == "function", "missing callback")
  local runtime = _ensure_runtime(game)
  runtime.callbacks[key] = callback
  return callback
end

local function _runtime_map_getter(field)
  return function(game, key)
    return _ensure_runtime(game)[field][key]
  end
end

callback_registry.peek = _runtime_map_getter("callbacks")

function callback_registry.take(game, key)
  local runtime = _ensure_runtime(game)
  local callback = runtime.callbacks[key]
  runtime.callbacks[key] = nil
  return callback
end

function callback_registry.clear(game, key)
  local runtime = _ensure_runtime(game)
  if key ~= nil then
    runtime.callbacks[key] = nil
    runtime.pending_seq_by_key[key] = nil
    runtime.ready_seq_by_key[key] = nil
    return
  end
  runtime.callbacks = {}
  runtime.pending_seq_by_key = {}
  runtime.ready_seq_by_key = {}
end

function callback_registry.reset_runtime(game)
  -- wait_callback_runtime is runtime-only state and should be cleared with
  -- presentation/runtime rebinding instead of leaking into gameplay state.
  return callback_registry.clear(game)
end

function callback_registry.begin_wait(game, key)
  assert(type(key) == "string" and key ~= "", "missing wait key")
  local runtime = _ensure_runtime(game)
  local next_seq = (runtime.seq_by_key[key] or 0) + 1
  runtime.seq_by_key[key] = next_seq
  runtime.pending_seq_by_key[key] = next_seq
  return next_seq
end

callback_registry.pending_wait_seq = _runtime_map_getter("pending_seq_by_key")

function callback_registry.mark_wait_ready(game, key, seq)
  local runtime = _ensure_runtime(game)
  if runtime.pending_seq_by_key[key] ~= seq then
    return false
  end
  runtime.ready_seq_by_key[key] = seq
  return true
end

function callback_registry.is_wait_ready(game, key)
  local runtime = _ensure_runtime(game)
  local pending_seq = runtime.pending_seq_by_key[key]
  return pending_seq ~= nil and runtime.ready_seq_by_key[key] == pending_seq
end

function callback_registry.finish_wait(game, key, seq)
  local runtime = _ensure_runtime(game)
  if runtime.pending_seq_by_key[key] ~= seq then
    return false
  end
  runtime.pending_seq_by_key[key] = nil
  runtime.ready_seq_by_key[key] = nil
  return true
end

return callback_registry

--[[ mutate4lua-manifest
version=4
projectHash=2f2b1b8433f55deb
scope.0.id=chunk:src/turn/waits/callback_registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=104
scope.0.semanticHash=1f0dcccec0e52b5e
scope.1.id=function:_ensure_runtime
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=23
scope.1.semanticHash=70180b8568af716d
scope.2.id=function:callback_registry.register
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=31
scope.2.semanticHash=ca95abbf1db0c9ec
scope.3.id=function:_runtime_map_getter
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=37
scope.3.semanticHash=959fb213a6cfc267
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=36
scope.4.semanticHash=981b9db8a8c632d6
scope.5.id=function:callback_registry.take
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=46
scope.5.semanticHash=909c3e0acb18b90a
scope.6.id=function:callback_registry.clear
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=59
scope.6.semanticHash=822639059452c9a6
scope.7.id=function:callback_registry.reset_runtime
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=65
scope.7.semanticHash=f1ce1850b7232305
scope.8.id=function:callback_registry.begin_wait
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=74
scope.8.semanticHash=26e07be4d3244d83
scope.9.id=function:callback_registry.mark_wait_ready
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=85
scope.9.semanticHash=9fed2e0adffdd4c1
scope.10.id=function:callback_registry.is_wait_ready
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=91
scope.10.semanticHash=8f7ae74ee4110787
scope.11.id=function:callback_registry.finish_wait
scope.11.kind=function
scope.11.startLine=93
scope.11.endLine=101
scope.11.semanticHash=1be00f2314c4aa7d
]]
