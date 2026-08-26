-- luacheck: ignore 211

local lu = require("luaunit")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches
local monopoly_event = require("src.foundation.events")
local host_events = require("src.ui.seams.host_events")
local board_feedback = require("src.ui.render.board_feedback.service")

local function _load_fresh(module_path)
  package.loaded[module_path] = nil
  return require(module_path)
end

local function _load_fresh_handlers()
  package.loaded["src.ui.coord.event_handlers"] = nil
  return require("src.ui.coord.event_handlers")
end

local function _clicker_role(role_id)
  return { role = { get_roleid = function() return role_id end } }
end

TestGameplayT5Hotspot = {}

function TestGameplayT5Hotspot:test_build_intent_always_emits_item_slot_click_without_reading_choice()
  -- 展示层只报事实:无遮挡时点哪个槽就产哪个槽的 item_slot_click,
  -- 不看 choice、不看道具镜像——「能不能用」全归 turn 层裁定。
  local item_slot_intents = _load_fresh("src.ui.input.route_item_slots")
  local state = {
    ui = { item_slots = { "slot1", "slot2" } },
  }

  local specs = item_slot_intents.build(state)
  lu.assertEvalToTrue(#specs == 2, "each item slot should get exactly one route spec")

  -- 没有任何 pending choice(既没道具窗也没道具镜像),照样产 intent
  local first = specs[1].build_intent(_clicker_role(7))
  lu.assertEvalToTrue(type(first) == "table", "build_intent should return a table")
  lu.assertEvalToTrue(first.type == "item_slot_click",
    "intent type should be item_slot_click, got " .. tostring(first.type))
  lu.assertEvalToTrue(first.slot_index == 1, "slot 1 should carry slot_index 1")
  lu.assertEvalToTrue(first.actor_role_id == 7,
    "intent should carry the clicking role, got " .. tostring(first.actor_role_id))
  lu.assertEvalToTrue(first.id == nil, "item_slot_click intent must not carry a ui_button id")

  local second = specs[2].build_intent(_clicker_role(7))
  lu.assertEvalToTrue(second.slot_index == 2, "slot 2 should carry slot_index 2")
end

function TestGameplayT5Hotspot:test_build_intent_returns_nil_when_overlay_blocks_the_click()
  local item_slot_intents = _load_fresh("src.ui.input.route_item_slots")
  local state = {
    ui = { item_slots = { "slot1" }, popup_active = true },
  }

  local specs = item_slot_intents.build(state)
  lu.assertEvalToTrue(#specs == 1, "should generate a spec for the item slot")

  local intent = specs[1].build_intent(_clicker_role(7))
  lu.assertEvalToTrue(intent == nil, "clicks under an overlay are mis-taps and must stay silent")
end

function TestGameplayT5Hotspot:test_build_intent_handles_missing_ui_state()
  local item_slot_intents = _load_fresh("src.ui.input.route_item_slots")
  local nodes = require("src.ui.schema.permanent")

  -- State with nil ui, should fall back to nodes
  local state = {}

  local specs = item_slot_intents.build(state)
  local expected_slots = nodes.item_slots or {}
  local base = #expected_slots
  lu.assertEvalToTrue(
    #specs == base * 2 + 1 or #specs == base * 2 or #specs == base + 1 or #specs == base,
    "should handle missing ui state"
  )
end

function TestGameplayT5Hotspot:test_on_bankruptcy_tiles_cleared_returns_true_when_sync_succeeds()
  local state_ports = _load_fresh("src.ui.ports.state")
  local ports = state_ports.build()

  local game = {
    landing_visual_hold_state = {
      on_board_visual_sync = function(_, payload)
        lu.assertEvalToTrue(type(payload.tile_ids) == "table", "should receive tile_ids")
        return true
      end
    }
  }

  local result = ports.on_bankruptcy_tiles_cleared(game, nil, { 1, 2, 3 })
  lu.assertEvalToTrue(result == true, "should return true when sync succeeds")
end

function TestGameplayT5Hotspot:test_on_bankruptcy_tiles_cleared_returns_false_when_no_state()
  local state_ports = _load_fresh("src.ui.ports.state")
  local ports = state_ports.build()

  local game = {}
  local result = ports.on_bankruptcy_tiles_cleared(game, nil, { 1, 2, 3 })
  lu.assertEvalToTrue(result == false, "should return false when no landing_visual_hold_state")
end

function TestGameplayT5Hotspot:test_on_bankruptcy_tiles_cleared_returns_false_when_sync_returns_false()
  local state_ports = _load_fresh("src.ui.ports.state")
  local ports = state_ports.build()

  local game = {
    landing_visual_hold_state = {
      on_board_visual_sync = function()
        return false
      end
    }
  }

  local result = ports.on_bankruptcy_tiles_cleared(game, nil, { 1, 2, 3 })
  lu.assertEvalToTrue(result == false, "should return false when sync returns false")
end

function TestGameplayT5Hotspot:test_rent_paid_handler_calls_board_feedback()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id, payload = payload }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.land.rent_paid]
    lu.assertEvalToTrue(type(handler) == "function", "rent_paid handler should be registered")
    handler(nil, nil, { owner = { id = 5 }, amount = 100 })
  end)

  lu.assertEvalToTrue(#calls == 1, "rent_paid should call board_feedback once")
  lu.assertEvalToTrue(calls[1].cue_name == "cash_burst", "rent_paid should use cash_burst cue")
  lu.assertEvalToTrue(calls[1].player_id == 5, "rent_paid should target owner")
end

function TestGameplayT5Hotspot:test_rent_paid_handler_skips_when_no_context()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, nil) -- nil context
    local handler = handlers[monopoly_event.land.rent_paid]
    lu.assertEvalToTrue(type(handler) == "function", "rent_paid handler should be registered")
    handler(nil, nil, { owner = { id = 5 } })
  end)

  lu.assertEvalToTrue(#calls == 0, "rent_paid should not call board_feedback when no context")
end

function TestGameplayT5Hotspot:test_rent_bankrupt_handler_calls_board_feedback()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id, payload = payload }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.land.rent_bankrupt]
    lu.assertEvalToTrue(type(handler) == "function", "rent_bankrupt handler should be registered")
    handler(nil, nil, { owner = { id = 3 }, amount = 200 })
  end)

  lu.assertEvalToTrue(#calls == 1, "rent_bankrupt should call board_feedback once")
  lu.assertEvalToTrue(calls[1].cue_name == "cash_burst", "rent_bankrupt should use cash_burst cue")
  lu.assertEvalToTrue(calls[1].player_id == 3, "rent_bankrupt should target owner")
end

function TestGameplayT5Hotspot:test_tax_paid_handler_calls_board_feedback()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id, payload = payload }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.land.tax_paid]
    lu.assertEvalToTrue(type(handler) == "function", "tax_paid handler should be registered")
    handler(nil, nil, { player = { id = 2 }, amount = 50 })
  end)

  lu.assertEvalToTrue(#calls == 1, "tax_paid should call board_feedback once")
  lu.assertEvalToTrue(calls[1].cue_name == "tax_wave", "tax_paid should use tax_wave cue")
  lu.assertEvalToTrue(calls[1].player_id == 2, "tax_paid should target player")
end

function TestGameplayT5Hotspot:test_bankruptcy_handler_calls_board_feedback()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id, payload = payload }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.feedback.bankruptcy]
    lu.assertEvalToTrue(type(handler) == "function", "bankruptcy handler should be registered")
    handler(nil, nil, { player = { id = 4 } })
  end)

  lu.assertEvalToTrue(#calls == 1, "bankruptcy should call board_feedback once")
  lu.assertEvalToTrue(calls[1].cue_name == "bankruptcy_slam", "bankruptcy should use bankruptcy_slam cue")
  lu.assertEvalToTrue(calls[1].player_id == 4, "bankruptcy should target player")
end

function TestGameplayT5Hotspot:test_bankruptcy_handler_uses_player_id_directly()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.feedback.bankruptcy]
    handler(nil, nil, { player_id = 7 }) -- player_id directly, not nested in player
  end)

  lu.assertEvalToTrue(#calls == 1, "bankruptcy should call board_feedback once")
  lu.assertEvalToTrue(calls[1].player_id == 7, "bankruptcy should use player_id directly")
end

function TestGameplayT5Hotspot:test_register_node_click_skips_when_already_registered()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local registered = { test_node = true }
  local listeners = {}
  local cache = {}

  -- Should return early without error
  event_bindings.register_node_click(cache, "test_node", function() end, registered, listeners)
  -- No assertion needed - just verifying no error is thrown
end

function TestGameplayT5Hotspot:test_register_node_click_handles_missing_nodes()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local runtime = require("src.ui.render.support.runtime_ui")
  local registered = {}
  local listeners = {}
  local cache = {}

  _with_patches({
    {
      target = runtime,
      key = "query_nodes",
      value = function()
        error("query failed")
      end,
    },
  }, function()
    -- Should handle error gracefully
    event_bindings.register_node_click(cache, "missing_node", function() end, registered, listeners)
  end)

  lu.assertEvalToTrue(registered["missing_node"] == nil, "should not register when query fails")
end

function TestGameplayT5Hotspot:test_register_node_click_caches_nodes()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local runtime = require("src.ui.render.support.runtime_ui")
  local registered = {}
  local listeners = {}
  local cache = {}
  local query_count = 0

  -- Mock UIManager.EVENT if not present
  if not _G.UIManager then
    _G.UIManager = { EVENT = { CLICK = "click" } }
  end
  if not _G.UIManager.EVENT then
    _G.UIManager.EVENT = { CLICK = "click" }
  end

  _with_patches({
    {
      target = runtime,
      key = "query_nodes",
      value = function(name)
        query_count = query_count + 1
        return { { listen = function() return {} end } }
      end,
    },
  }, function()
    -- First call should query nodes
    event_bindings.register_node_click(cache, "test_node", function() end, registered, listeners)
    lu.assertEvalToTrue(query_count == 1, "first call should query nodes")

    -- Reset registered to allow second registration
    registered["test_node"] = nil

    -- Second call should use cache
    event_bindings.register_node_click(cache, "test_node", function() end, registered, listeners)
    lu.assertEvalToTrue(query_count == 1, "second call should use cached nodes")
  end)
end

function TestGameplayT5Hotspot:test_register_node_click_registers_multiple_nodes()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local runtime = require("src.ui.render.support.runtime_ui")
  local registered = {}
  local listeners = {}
  local cache = {}
  local listen_calls = {}

  -- Mock UIManager.EVENT if not present
  if not _G.UIManager then
    _G.UIManager = { EVENT = { CLICK = "click" } }
  end
  if not _G.UIManager.EVENT then
    _G.UIManager.EVENT = { CLICK = "click" }
  end

  _with_patches({
    {
      target = runtime,
      key = "query_nodes",
      value = function(name)
        return {
          {
            listen = function(event, callback)
              listen_calls[#listen_calls + 1] = { event = event }
              return { disconnect = function() end }
            end
          },
          {
            listen = function(event, callback)
              listen_calls[#listen_calls + 1] = { event = event }
              return { disconnect = function() end }
            end
          }
        }
      end,
    },
  }, function()
    event_bindings.register_node_click(cache, "multi_node", function() end, registered, listeners)
    lu.assertEvalToTrue(#listen_calls == 2, "should register listeners for all nodes")
    lu.assertEvalToTrue(#listeners == 2, "should add all listeners to list")
  end)
end

function TestGameplayT5Hotspot:test_register_node_click_handles_empty_nodes_result()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local runtime = require("src.ui.render.support.runtime_ui")
  local registered = {}
  local listeners = {}
  local cache = {}

  _with_patches({
    {
      target = runtime,
      key = "query_nodes",
      value = function(name)
        return {} -- empty result
      end,
    },
  }, function()
    event_bindings.register_node_click(cache, "empty_node", function() end, registered, listeners)
    lu.assertEvalToTrue(registered["empty_node"] == nil, "should not register when nodes is empty")
  end)
end

function TestGameplayT5Hotspot:test_register_node_click_logs_action_log_button_query_failure()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local runtime = require("src.ui.render.support.runtime_ui")
  local always_show_nodes = require("src.ui.schema.base")
  local registered = {}
  local listeners = {}
  local cache = {}

  _with_patches({
    {
      target = runtime,
      key = "query_nodes",
      value = function(name)
        error("query failed")
      end,
    },
  }, function()
    -- Mock the action_log_button name to trigger the log path
    local original_action_log_button = always_show_nodes.action_log_button
    always_show_nodes.action_log_button = "test_action_log_btn"
    event_bindings.register_node_click(cache, "test_action_log_btn", function() end, registered, listeners)
    always_show_nodes.action_log_button = original_action_log_button
    lu.assertEvalToTrue(registered["test_action_log_btn"] == nil, "should not register when query fails")
  end)
end

function TestGameplayT5Hotspot:test_register_node_click_logs_action_log_button_not_found()
  local event_bindings = _load_fresh("src.ui.coord.event_bindings")
  local runtime = require("src.ui.render.support.runtime_ui")
  local always_show_nodes = require("src.ui.schema.base")
  local registered = {}
  local listeners = {}
  local cache = {}

  _with_patches({
    {
      target = runtime,
      key = "query_nodes",
      value = function(name)
        return {} -- empty result to trigger not found path
      end,
    },
  }, function()
    -- Mock the action_log_button name to trigger the log path
    local original_action_log_button = always_show_nodes.action_log_button
    always_show_nodes.action_log_button = "test_action_log_btn2"
    event_bindings.register_node_click(cache, "test_action_log_btn2", function() end, registered, listeners)
    always_show_nodes.action_log_button = original_action_log_button
    lu.assertEvalToTrue(registered["test_action_log_btn2"] == nil, "should not register when nodes not found")
  end)
end

function TestGameplayT5Hotspot:test_build_choice_view_builds_basic_view()
  local choice_builder = _load_fresh("src.ui.view.choice_builder")

  local pending = {
    id = 123,
    kind = "test_choice",
    title = "Test Title",
    body = "Test Body",
    options = { { id = "opt1", label = "Option 1" }, { id = "opt2", label = "Option 2" } },
    allow_cancel = true,
    cancel_label = "Cancel",
  }

  local game = { turn = {} }
  local view = choice_builder.build_choice_view(pending, { game = game })

  lu.assertEvalToTrue(view.id == 123, "view should preserve id")
  lu.assertEvalToTrue(view.kind == "test_choice", "view should preserve kind")
  lu.assertEvalToTrue(view.title == "Test Title", "view should preserve title")
  lu.assertEvalToTrue(view.body == "Test Body", "view should preserve body")
  lu.assertEvalToTrue(#view.options == 2, "view should have 2 options")
  lu.assertEvalToTrue(view.options[1].label == "Option 1", "view should preserve option labels")
  lu.assertEvalToTrue(view.allow_cancel == true, "view should preserve allow_cancel")
  lu.assertEvalToTrue(view.cancel_label == "Cancel", "view should preserve cancel_label")
end

function TestGameplayT5Hotspot:test_build_choice_view_uses_phase_title()
  local choice_builder = _load_fresh("src.ui.view.choice_builder")

  local pending = {
    id = 1,
    title = "Use Item",
    options = {},
  }

  local game = {
    turn = {
      item_phase_active = "pre_action",
    },
  }

  local view = choice_builder.build_choice_view(pending, { game = game })
  lu.assertEvalToTrue(view.title == "Use Item", "title should not include phase label (item-ui simplification removed phase prefix)")
end

function TestGameplayT5Hotspot:test_build_choice_view_joins_body_lines()
  local choice_builder = _load_fresh("src.ui.view.choice_builder")

  local pending = {
    id = 1,
    body_lines = { "Line 1", "Line 2", "Line 3" },
    options = {},
  }

  local game = { turn = {} }
  local view = choice_builder.build_choice_view(pending, { game = game })
  lu.assertEvalToTrue(view.body == "Line 1\nLine 2\nLine 3", "body should join lines with newlines")
end

function TestGameplayT5Hotspot:test_build_choice_view_prefers_body_lines_over_body()
  local choice_builder = _load_fresh("src.ui.view.choice_builder")

  local pending = {
    id = 1,
    body = "Direct body",
    body_lines = { "Line 1", "Line 2" },
    options = {},
  }

  local game = { turn = {} }
  local view = choice_builder.build_choice_view(pending, { game = game })
  lu.assertEvalToTrue(view.body == "Line 1\nLine 2", "should prefer body_lines over body")
end

function TestGameplayT5Hotspot:test_build_choice_view_uses_default_option_label()
  local choice_builder = _load_fresh("src.ui.view.choice_builder")

  local pending = {
    id = 1,
    options = { { id = "opt1" } }, -- no label
  }

  local game = { turn = {} }
  local view = choice_builder.build_choice_view(pending, { game = game })
  lu.assertEvalToTrue(view.options[1].label == "opt1", "should use id as default label")
end

function TestGameplayT5Hotspot:test_build_choice_view_copies_option_view_fields()
  local choice_builder = _load_fresh("src.ui.view.choice_builder")

  local pending = {
    id = 1,
    options = {
      {
        id = "opt1",
        label = "Buy",
        can_buy = true,
        requires_pre_confirm = true,
        pre_confirm_kind = "expensive",
        confirm_title = "Confirm Purchase",
        confirm_body = "Are you sure?",
      }
    },
  }

  local game = { turn = {} }
  local view = choice_builder.build_choice_view(pending, { game = game })
  local opt = view.options[1]
  lu.assertEvalToTrue(opt.id == "opt1", "should copy id")
  lu.assertEvalToTrue(opt.can_buy == true, "should copy can_buy")
  lu.assertEvalToTrue(opt.requires_pre_confirm == true, "should copy requires_pre_confirm")
  lu.assertEvalToTrue(opt.pre_confirm_kind == "expensive", "should copy pre_confirm_kind")
  lu.assertEvalToTrue(opt.confirm_title == "Confirm Purchase", "should copy confirm_title")
  lu.assertEvalToTrue(opt.confirm_body == "Are you sure?", "should copy confirm_body")
end


return TestGameplayT5Hotspot
