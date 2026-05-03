-- luacheck: ignore 211
local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _bind_ui_runtime = support.bind_ui_runtime
local bindings = require("src.ui.coord.event_bindings")
local logger = require("src.foundation.log.logger")
local runtime = require("src.ui.render.runtime_ui")
local canvas_registry = require("src.ui.input.canvas_route.registry")
local canvas_store = require("src.ui.state.canvas_store")
local canvas = require("src.ui.coord.canvas_coordinator")
local ui_events = require("src.ui.coord.ui_events")
local base_nodes = require("src.ui.schema.base")
local permanent_nodes = require("src.ui.schema.permanent")
local remote_choice_intents = require("src.ui.input.canvas_route.remote_choice")
local target_choice_intents = require("src.ui.input.canvas_route.target_choice")
local ids = require("fixtures.item_slot_ids")
local market_intents = require("src.ui.input.canvas_route.market")

local function _find_spec(specs, node_name)
  for _, spec in ipairs(specs or {}) do
    if spec and spec.name == node_name then
      return spec
    end
  end
  return nil
end

local function _build_crash_node()
  local node = {}
  return setmetatable(node, {
    __newindex = function(_, key, _)
      if key == "disabled" then
        error("set_node_touch_enabled 节点类型不正确")
      end
      rawset(node, key, nil)
    end,
  })
end

describe("presentation_ui.event_bindings", function()
  it("enable_action_log_toggle_touch_fallback_never_crash_on_bad_cached_nodes", function()
    logger.clear()
    local cache = {
      [base_nodes.action_log_button] = { _build_crash_node() },
    }
    local manager = { client_role = { any = true } }

    local ok = false
    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
    }, function()
      ok = pcall(bindings.enable_action_log_toggle_touch, cache, nil)
    end)

    assert(ok, "enable_action_log_toggle_touch should not crash on bad cached nodes")
    _assert_eq(manager.client_role, nil, "fallback should restore client role to nil")
  end)

  it("enable_action_log_toggle_touch_prefers_named_ui_touch_path", function()
    logger.clear()
    local calls = {}
    local ui = {
      set_touch_enabled = function(_, name, enabled)
        calls[#calls + 1] = { name = name, enabled = enabled }
      end,
    }

    _with_patches({
      { target = runtime, key = "query_nodes", value = function(name)
        error("query_nodes should not be called for ui path: " .. tostring(name))
      end },
    }, function()
      bindings.enable_action_log_toggle_touch({}, ui)
    end)

    _assert_eq(#calls, 1, "ui path should touch one action-log toggle node")
    _assert_eq(calls[1].name, base_nodes.action_log_button, "touch should target action-log button")
    _assert_eq(calls[1].enabled, true, "toggle button should be enabled")
  end)

  it("enable_action_log_toggle_touch_fallback_queries_targets_and_tolerates_bad_nodes", function()
    logger.clear()
    local cache = {}
    local query_calls = 0
    local good_node = {}
    local bad_node = _build_crash_node()
    local manager = { client_role = { any = true } }

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime, key = "query_nodes", value = function(name)
        query_calls = query_calls + 1
        return { good_node, bad_node }
      end },
    }, function()
      bindings.enable_action_log_toggle_touch(cache, {
        set_touch_enabled = function()
          error("force fallback")
        end,
      })
    end)

    assert(query_calls >= 1, "fallback path should query action-log target nodes")
    _assert_eq(good_node.disabled, false, "fallback should enable nodes returned by runtime.query_nodes")
    _assert_eq(manager.client_role, nil, "fallback should restore client role to nil")
  end)

  it("register_node_click_handles_query_failure_and_missing_nodes", function()
    logger.clear()
    local shown = {}
    local registered = {}
    local listeners = {}

    _with_patches({
      { target = runtime, key = "query_nodes", value = function(name)
        if name == "missing_query" then
          error("boom")
        end
        return {}
      end },
      { target = require("src.host"), key = "enqueue_tip", value = function(intent)
        shown[#shown + 1] = intent and intent.text or nil
      end },
    }, function()
      bindings.register_node_click({}, "missing_query", function() end, registered, listeners)
      bindings.register_node_click({}, "missing_nodes", function() end, registered, listeners)
    end)

    _assert_eq(#shown, 2, "register_node_click should show tip for query failures and missing nodes")
    _assert_eq(registered.missing_query, nil, "query failure should not mark node as registered")
    _assert_eq(registered.missing_nodes, nil, "missing nodes should not mark node as registered")
    _assert_eq(#listeners, 0, "failed registrations should not create listeners")
  end)

  it("canvas_intents_cover_remote_target_and_market_paths", function()
    logger.clear()
    local state = {
      ui = {},
      ui_model = {
        choice = {
          id = 9,
          options = {
            { id = 21, label = "A" },
            { id = 22, label = "B" },
          },
        },
        market = {
          choice_id = 18,
          options = {
            { id = 33, label = "购买" },
          },
        },
      },
      target_choice_runtime = {
        locked_option_id = 22,
      },
    }
    _bind_ui_runtime(state)
    state.ui_runtime.pending_choice_selected_option_id = 21

    local remote_specs = remote_choice_intents.build(state)
    local target_specs = target_choice_intents.build(state)
    local market_item_specs = market_intents.build_items(state)
    local market_control_specs = market_intents.build_controls(state)

    _assert_eq(remote_specs[1].build_intent().type, "choice_select", "remote choice should build select intent")
    _assert_eq(remote_specs[1].build_intent().option_id, 21, "remote choice should resolve option by index")
    _assert_eq(target_specs[1].build_intent().type, "choice_select", "target confirm should emit choice select for locked option")
    _assert_eq(target_specs[2].build_intent().type, "target_unlock", "target cancel should unlock locked target")
    _assert_eq(target_specs[3].build_intent().type, "target_lock", "target slot should build target lock intent")
    state.ui_runtime.pending_choice_selected_option_id = 33
    _assert_eq(market_item_specs[1].build_intent().type, "market_select", "market item should build selection intent")
    _assert_eq(market_control_specs[1].build_intent().type, "market_confirm", "market confirm should use selected option")
    _assert_eq(market_control_specs[2].build_intent().type, "choice_cancel", "market cancel should map to choice cancel")
    _assert_eq(#market_control_specs, 7, "market controls should expose 7 entries (vehicle tab removed)")
  end)

  it("target slot button second tap on same locked option dispatches choice_select via confirm", function()
    logger.clear()
    local state = {
      ui = {},
      ui_model = {
        choice = {
          id = 7,
          options = {
            { id = "tile_5", label = "A" },
            { id = "tile_8", label = "B" },
          },
        },
      },
      target_choice_runtime = {
        locked_option_id = "tile_5",
      },
    }
    _bind_ui_runtime(state)
    state.ui_runtime.pending_choice_selected_option_id = "tile_5"

    local target_specs = target_choice_intents.build(state)
    local intent = target_specs[3].build_intent()
    _assert_eq(intent.type, "choice_select", "second tap on locked slot should emit choice_select")
    _assert_eq(intent.option_id, "tile_5", "second tap should resolve to locked option id")
    _assert_eq(intent.choice_id, 7, "choice_select should carry choice id")
  end)

  it("target slot button single-option choice auto-dispatches choice_select on first tap", function()
    logger.clear()
    local state = {
      ui = {},
      ui_model = {
        choice = {
          id = 11,
          options = {
            { id = "tile_only", label = "A" },
          },
        },
      },
      target_choice_runtime = {
        locked_option_id = nil,
      },
    }
    _bind_ui_runtime(state)

    local target_specs = target_choice_intents.build(state)
    local intent = target_specs[3].build_intent()
    _assert_eq(intent.type, "choice_select", "single-option slot tap should short-circuit to choice_select")
    _assert_eq(intent.option_id, "tile_only", "single-option slot should resolve to that option id")
    _assert_eq(intent.choice_id, 11, "choice_select should carry choice id")
  end)

  it("target slot button different option re-locks without confirming", function()
    logger.clear()
    local state = {
      ui = {},
      ui_model = {
        choice = {
          id = 13,
          options = {
            { id = "tile_5", label = "A" },
            { id = "tile_8", label = "B" },
          },
        },
      },
      target_choice_runtime = {
        locked_option_id = "tile_5",
      },
    }
    _bind_ui_runtime(state)
    state.ui_runtime.pending_choice_selected_option_id = "tile_5"

    local dispatched = {}
    state.turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
    }

    local target_specs = target_choice_intents.build(state)
    local intent = target_specs[4].build_intent()
    _assert_eq(intent.type, "target_lock", "tap on different option should re-lock not confirm")
    _assert_eq(intent.option_id, "tile_8", "re-lock should carry the new option id")
    for _, action in ipairs(dispatched) do
      assert(action.type ~= "choice_select", "re-lock must not dispatch choice_select")
    end
  end)

  it("canvas_intents_return_nil_when_choice_or_market_missing", function()
    logger.clear()
    local state = {
      ui = {},
      ui_model = {},
      target_choice_runtime = {
        locked_option_id = nil,
      },
    }
    _bind_ui_runtime(state)

    local remote_specs = remote_choice_intents.build(state)
    local target_specs = target_choice_intents.build(state)
    local market_item_specs = market_intents.build_items(state)
    local market_control_specs = market_intents.build_controls(state)

    _assert_eq(remote_specs[1].build_intent(), nil, "remote choice should bail out without current choice")
    _assert_eq(target_specs[1].build_intent(), nil, "target confirm should bail out without locked option")
    _assert_eq(target_specs[2].build_intent(), nil, "target cancel should bail out without locked option")
    _assert_eq(market_item_specs[1].build_intent(), nil, "market item intent should bail out without market")
    _assert_eq(market_control_specs[1].build_intent(), nil, "market confirm should bail out without market")
    _assert_eq(market_control_specs[4].build_intent(), nil, "market paging should bail out without market")
    _assert_eq(market_control_specs[6].build_intent(), nil, "market tab select should bail out without market")
  end)

  it("canvas_registry_builds_canvas_first_route_specs", function()
    local state = {
      ui = {
        item_slots = ids.slots(1),
        card_outlines = ids.outlines(1),
        popup_screen = {
          dismiss_nodes = { "卡牌展示_图片" },
        },
        popup_active = true,
      },
      ui_model = {
        choice = {
          id = 10,
          kind = "item_phase_choice",
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
          options = { { id = 2001, label = "路障卡" } },
        },
      },
    }
    _bind_ui_runtime(state)

    local specs = canvas_registry.build_route_specs(state)
    assert(_find_spec(specs, base_nodes.action_button) ~= nil, "route specs should include base action button")
    assert(_find_spec(specs, base_nodes.action_log_button) ~= nil, "route specs should include action log button")
    local outline_spec = _find_spec(specs, ids.outline[1])
    assert(outline_spec ~= nil, "route specs should include item outline node")
    local intent = outline_spec.build_intent and outline_spec.build_intent() or nil
    _assert_eq(intent and intent.id, "item_slot_1", "outline click should still map to item slot intent")
  end)

  it("canvas_store_patch_slice_marks_dirty", function()
    local state = {
      ui = {
        canvas_state = {},
      },
    }
    canvas_store.ensure(state)
    canvas_store.patch_slice(state, "choice", function(slice)
      slice.active = true
    end)

    local dirty = canvas_store.consume_dirty(state)
    _assert_eq(dirty.any, true, "canvas store should mark any dirty after patch")
    _assert_eq(dirty.choice, true, "canvas store should mark choice slice dirty after patch")
    _assert_eq(canvas_store.get_slice(state, "choice").active, true, "canvas store should persist patched value")

    local dirty_after_consume = canvas_store.consume_dirty(state)
    _assert_eq(dirty_after_consume.any, false, "canvas store consume should clear dirty flag")
  end)

  it("canvas_store_rejects_unsupported_dirty_key", function()
    local state = {
      ui = {
        canvas_state = {},
      },
    }

    local ok, err = pcall(function()
      canvas_store.mark_dirty(state, "popup")
    end)

    _assert_eq(ok, false, "canvas store should reject unsupported dirty keys")
    assert(string.find(err or "", "unsupported canvas dirty key", 1, true), "canvas store should explain rejected dirty key")
  end)

  it("canvas_switch_keeps_always_show_visible", function()
    local calls = {}
    local role = { id = "r1" }
    local canvas_names = {
      base_nodes.canvas,
      permanent_nodes.canvas,
      "其他屏",
    }
    local show = {
      [base_nodes.canvas] = "show_base",
      [permanent_nodes.canvas] = "show_always",
      ["其他屏"] = "show_other",
    }
    local hide = {
      [base_nodes.canvas] = "hide_base",
      [permanent_nodes.canvas] = "hide_always",
      ["其他屏"] = "hide_other",
    }
    _with_patches({
      { target = ui_events, key = "canvas_names", value = canvas_names },
      { target = ui_events, key = "show", value = show },
      { target = ui_events, key = "hide", value = hide },
      { target = ui_events, key = "send_to_all", value = function(event_name)
        calls[#calls + 1] = "all:" .. tostring(event_name)
      end },
      { target = ui_events, key = "send_to_role", value = function(_, event_name)
        calls[#calls + 1] = "role:" .. tostring(event_name)
      end },
    }, function()
      canvas.switch({ debug_visible = false }, nil)
      canvas.switch_for_role({ debug_visible_by_role = {} }, nil, role)
    end)

    local joined = table.concat(calls, "|")
    assert(not joined:find("hide_always", 1, true), "always_show canvas should not be hidden")
    assert(joined:find("all:show_always", 1, true), "switch() should show always_show canvas")
    assert(joined:find("role:show_always", 1, true), "switch_for_role() should show always_show canvas")
  end)
end)
