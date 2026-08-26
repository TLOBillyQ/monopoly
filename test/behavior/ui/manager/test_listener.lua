-- listener.lua branch-dense coverage: destroy paths and host_events.unregister_custom_event stubbing.
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local Listener = require("src.ui.manager.listener")
local host_events = require("src.ui.seams.host_events")
-- 底座加载时自备共享运行时端口基线(#217 窄 suite 子集无全量车道加载序兜底)。
require("test.support.ui_manager_nodes_support")

TestListener = {}

local unregister_calls
local original_unregister

local function _clear_context()
  -- listener.lua caches context.event_handlers at load; mutate in place.
  for k in pairs(context.event_handlers) do
    context.event_handlers[k] = nil
  end
  for k in pairs(context.nodes_list) do
    context.nodes_list[k] = nil
  end
end

local function _stub_unregister()
  original_unregister = host_events.unregister_custom_event
  host_events.unregister_custom_event = function(trigger)
    unregister_calls[#unregister_calls + 1] = trigger
    return true
  end
end

local function _restore_unregister()
  host_events.unregister_custom_event = original_unregister
end

local function _make_listener(event, callback, node_id)
  local listener = Listener:new()
  listener._event = event
  listener._callback = callback
  listener._node_id = node_id
  return listener
end

function TestListener:setUp()
  _clear_context()
  unregister_calls = {}
  _stub_unregister()
end

function TestListener:tearDown()
  _restore_unregister()
end

function TestListener:test_destroy_removes_middle_callback_and_keeps_handler_data()
  local cb1, cb2, cb3 = function() end, function() end, function() end
  local node_id = 42
  context.event_handlers["click"] = {
    trigger = 100,
    [node_id] = { callbacks = { cb1, cb2, cb3 }, node = {} },
  }

  local listener = _make_listener("click", cb2, node_id)
  listener:destroy()

  local handler_data = context.event_handlers["click"][node_id]
  lu.assertEvalToTrue(handler_data ~= nil, "handler_data should remain when callbacks still exist")
  lu.assertEvalToTrue(#handler_data.callbacks == 2, "middle callback should be removed")
  lu.assertEvalToTrue(handler_data.callbacks[1] == cb1, "first callback should stay")
  lu.assertEvalToTrue(handler_data.callbacks[2] == cb3, "third callback should stay")
  lu.assertEvalToTrue(#unregister_calls == 0, "should not unregister when handlers remain")
end

function TestListener:test_destroy_removes_last_callback_and_cleans_up_handler_data()
  local cb = function() end
  local node_id = 42
  local other_node_id = 43
  context.event_handlers["click"] = {
    trigger = 100,
    [node_id] = { callbacks = { cb }, node = {} },
    [other_node_id] = { callbacks = { function() end }, node = {} },
  }

  local listener = _make_listener("click", cb, node_id)
  listener:destroy()

  lu.assertEvalToTrue(context.event_handlers["click"][node_id] == nil,
    "handler_data for node should be removed when its callbacks become empty")
  lu.assertEvalToTrue(context.event_handlers["click"][other_node_id] ~= nil,
    "other node handler_data should remain")
  lu.assertEvalToTrue(#unregister_calls == 0, "should not unregister when other node handlers exist")
end

function TestListener:test_destroy_removes_last_node_handler_and_unregisters_custom_event()
  local cb = function() end
  local node_id = 42
  context.event_handlers["click"] = {
    trigger = 12345,
    [node_id] = { callbacks = { cb }, node = {} },
  }

  local listener = _make_listener("click", cb, node_id)
  listener:destroy()

  lu.assertEvalToTrue(context.event_handlers["click"] == nil, "event handler should be removed")
  lu.assertEvalToTrue(#unregister_calls == 1, "global_unregister_custom_event should be called once")
  lu.assertEvalToTrue(unregister_calls[1] == 12345, "unregister should receive the stored trigger")
end

function TestListener:test_destroy_is_a_no_op_when_the_event_has_no_handler_data_for_the_node()
  local other_node_id = 43
  context.event_handlers["click"] = {
    trigger = 100,
    [other_node_id] = { callbacks = { function() end }, node = {} },
  }

  local listener = _make_listener("click", function() end, 42)
  listener:destroy()

  lu.assertEvalToTrue(context.event_handlers["click"] ~= nil, "event handler should survive")
  lu.assertEvalToTrue(context.event_handlers["click"][other_node_id] ~= nil, "other node handler_data should remain")
  lu.assertEvalToTrue(#unregister_calls == 0, "should not unregister when node has no handler_data")
end

function TestListener:test_destroy_is_a_no_op_when_handler_data_carries_no_callbacks()
  local node_id = 42
  context.event_handlers["click"] = {
    trigger = 100,
    [node_id] = { node = {} },
  }

  local listener = _make_listener("click", function() end, node_id)
  listener:destroy()

  lu.assertEvalToTrue(context.event_handlers["click"][node_id] ~= nil,
    "callback-less handler_data should be left alone")
  lu.assertEvalToTrue(#unregister_calls == 0, "should not unregister when handler_data has no callbacks")
end

function TestListener:test_destroy_leaves_other_callbacks_intact_when_its_own_callback_is_already_gone()
  local cb_other = function() end
  local node_id = 42
  context.event_handlers["click"] = {
    trigger = 100,
    [node_id] = { callbacks = { cb_other }, node = {} },
  }

  local listener = _make_listener("click", function() end, node_id)
  listener:destroy()

  local handler_data = context.event_handlers["click"][node_id]
  lu.assertEvalToTrue(handler_data ~= nil, "handler_data should remain")
  lu.assertEvalToTrue(#handler_data.callbacks == 1 and handler_data.callbacks[1] == cb_other,
    "an unknown callback should remove nothing")
  lu.assertEvalToTrue(#unregister_calls == 0, "should not unregister while callbacks remain")
end

function TestListener:test_destroy_is_a_no_op_when_event_handler_missing()
  local listener = _make_listener("missing_event", function() end, 99)
  local ok = pcall(function()
    listener:destroy()
  end)

  lu.assertEvalToTrue(ok, "destroy should tolerate missing event handler")
  lu.assertEvalToTrue(#unregister_calls == 0, "should not unregister when handler missing")
end


return TestListener
