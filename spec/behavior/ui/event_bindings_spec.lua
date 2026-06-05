-- luacheck: ignore 211
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _bind_ui_runtime = support.bind_ui_runtime
local bindings = require("src.ui.coord.event_bindings")
local logger = require("src.foundation.log")
local runtime = require("src.ui.render.runtime_ui")
local canvas_registry = require("src.ui.input.routes")
local canvas_store = require("src.ui.state.canvas_store")
local canvas = require("src.ui.coord.canvas_coordinator")
local ui_events = require("src.ui.coord.ui_events")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local base_nodes = require("src.ui.schema.base")
local base_contract = require("src.ui.schema.base_contract")
local skin_nodes = require("src.ui.schema.skin")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local permanent_nodes = require("src.ui.schema.permanent")
local remote_choice_intents = require("src.ui.input.route_remote_choice")
local target_choice_intents = require("src.ui.input.route_target_choice")
local ids = require("spec.fixtures.item_slot_ids")
local market_intents = require("src.ui.input.route_market")
local ui_manager_nodes = require("Data.UIManagerNodes")

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

local function _with_ui_manager_nodes(entries, fn)
  local original = {}
  for key, value in pairs(ui_manager_nodes) do
    original[key] = value
    ui_manager_nodes[key] = nil
  end
  for key, value in pairs(entries) do
    ui_manager_nodes[key] = value
  end

  local handler = debug and debug.traceback or function(err) return err end
  local ok, err = xpcall(fn, handler)

  for key in pairs(ui_manager_nodes) do
    ui_manager_nodes[key] = nil
  end
  for key, value in pairs(original) do
    ui_manager_nodes[key] = value
  end

  if not ok then
    error(err)
  end
end

describe("presentation_ui.event_bindings", function()
  before_each(function()
    runtime_ports.reset_for_tests()
  end)

  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("enable_action_log_toggle_touch_fallback_never_crash_on_bad_cached_nodes", function()
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
    local calls = {}
    local query_calls = 0
    local ui = {
      set_touch_enabled = function(_, name, enabled)
        calls[#calls + 1] = { name = name, enabled = enabled }
      end,
    }

    _with_patches({
      { target = runtime, key = "query_nodes", value = function(name)
        query_calls = query_calls + 1
        error("query_nodes should not be called for ui path: " .. tostring(name))
      end },
      { target = base_contract.action_log, key = "toggle_targets", value = { base_nodes.action_log_button } },
    }, function()
      bindings.enable_action_log_toggle_touch({}, ui)
    end)

    _assert_eq(#calls, 1, "ui path should touch one action-log toggle node")
    _assert_eq(calls[1].name, base_nodes.action_log_button, "touch should target action-log button")
    _assert_eq(calls[1].enabled, true, "toggle button should be enabled")
    _assert_eq(query_calls, 0, "successful ui path should not fall back to query_nodes")
  end)

  it("enable_action_log_toggle_touch_fallback_uses_cached_targets_without_querying", function()
    local query_calls = 0
    local cached_node = {}
    local cache = {
      [base_nodes.action_log_button] = { cached_node },
    }

    _with_patches({
      { target = base_contract.action_log, key = "toggle_targets", value = { base_nodes.action_log_button } },
      { target = runtime, key = "query_nodes", value = function()
        query_calls = query_calls + 1
        return {}
      end },
    }, function()
      bindings.enable_action_log_toggle_touch(cache, nil)
    end)

    _assert_eq(query_calls, 0, "fallback should reuse cached target nodes")
    _assert_eq(cached_node.disabled, false, "fallback should enable cached action-log target nodes")
  end)

  it("enable_action_log_toggle_touch_fallback_handles_nil_query_results", function()
    local ok = false

    _with_patches({
      { target = base_contract.action_log, key = "toggle_targets", value = { base_nodes.action_log_button } },
      { target = runtime, key = "query_nodes", value = function()
        return nil
      end },
    }, function()
      ok = pcall(bindings.enable_action_log_toggle_touch, {}, nil)
    end)

    assert(ok, "fallback should tolerate nil query_nodes results")
  end)

  it("enable_action_log_toggle_touch_fallback_queries_targets_and_tolerates_bad_nodes", function()
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
      { target = base_contract.action_log, key = "toggle_targets", value = { base_nodes.action_log_button } },
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

  it("register_node_click_dedupes_missing_node_tips", function()
    local shown = {}
    local registered = {}
    local listeners = {}

    _with_patches({
      { target = runtime, key = "query_nodes", value = function()
        return {}
      end },
      { target = require("src.host"), key = "enqueue_tip", value = function(intent)
        shown[#shown + 1] = intent and intent.text or nil
      end },
    }, function()
      bindings.register_node_click({}, "dedupe_missing_node", function() end, registered, listeners)
      bindings.register_node_click({}, "dedupe_missing_node", function() end, registered, listeners)
    end)

    _assert_eq(#shown, 1, "same missing node should show one deduped tip")
    _assert_eq(shown[1], "UI 节点未适配: dedupe_missing_node", "missing node tip text should include name")
  end)

  it("register_node_click_reports_missing_action_log_nodes_with_tips_without_diagnostic_logs", function()
    local logs = {}
    local shown = {}

    _with_patches({
      { target = runtime, key = "query_nodes", value = function()
        return {}
      end },
      { target = logger, key = "info", value = function(message)
        logs[#logs + 1] = tostring(message)
      end },
      { target = require("src.host"), key = "enqueue_tip", value = function(intent)
        shown[#shown + 1] = intent and intent.text or nil
      end },
    }, function()
      bindings.register_node_click({}, base_nodes.action_log_button, function() end, {}, {})
      bindings.register_node_click({}, "not_action_log", function() end, {}, {})
    end)

    _assert_eq(#shown, 2, "action log and other missing buttons should both show tips")
    _assert_eq(shown[1], "UI 节点未适配: " .. base_nodes.action_log_button,
      "action log missing node should report the adapted node name")
    _assert_eq(shown[2], "UI 节点未适配: not_action_log",
      "other missing nodes should keep generic tip behavior")
    _assert_eq(#logs, 0, "missing node failures should not log diagnostics")
  end)

  it("register_node_click_respects_registered_sentinels_and_replaces_stale_scopes", function()
    local query_calls = 0
    local reused_scope = {}
    local registered = {
      already_true = true,
      already_scoped = { __global = true },
      stale = "yes",
      reused = reused_scope,
    }
    local listeners = {}

    _with_patches({
      { key = "UIManager", value = { EVENT = { CLICK = "click" }, client_role = nil } },
      { target = runtime, key = "query_nodes", value = function(name)
        query_calls = query_calls + 1
        return {
          {
            listen = function()
              return { destroy = function() end }
            end,
            name = name,
          },
        }
      end },
    }, function()
      bindings.register_node_click({}, "already_true", function() end, registered, listeners)
      bindings.register_node_click({}, "already_scoped", function() end, registered, listeners)
      bindings.register_node_click({}, "stale", function() end, registered, listeners)
      bindings.register_node_click({}, "reused", function() end, registered, listeners)
    end)

    _assert_eq(query_calls, 2, "registered sentinel/scoped entries should skip duplicate registration")
    _assert_eq(type(registered.stale), "table", "stale registered value should be replaced with scope table")
    _assert_eq(registered.stale.__global, true, "new scope should be marked as registered")
    _assert_eq(registered.reused, reused_scope, "existing scope table should be reused")
    _assert_eq(reused_scope.__global, true, "reused scope table should be marked as registered")
    _assert_eq(#listeners, 2, "stale and reused entries should create listeners")
  end)

  it("register_node_click_dispatches_under_event_role", function()
    local role1 = { get_roleid = function() return 1 end }
    local role2 = { get_roleid = function() return 2 end }
    local manager = { client_role = nil, EVENT = { CLICK = "click" } }
    local listener_callback = nil

    local function _role_key()
      local role = manager.client_role
      if role and role.get_roleid then
        return tostring(role.get_roleid())
      end
      return "global"
    end

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime, key = "query_nodes", value = function(name)
        return {
          {
            name = name,
            listen = function(_, _, callback)
              listener_callback = callback
              return { destroy = function() end }
            end,
          },
        }
      end },
    }, function()
      runtime_ports.configure({
        resolve_roles = function()
          return { role1, role2 }
        end,
      })
      local hits = {}
      bindings.register_node_click({}, base_nodes.skin_button, function()
        hits[#hits + 1] = _role_key()
      end, {}, {})

      assert(listener_callback ~= nil, "skin button should have a click listener")
      listener_callback({ role = role1 })
      listener_callback({ role = role2 })
      _assert_eq(table.concat(hits, ","), "1,2",
        "listener should dispatch under the role supplied by the click event")
    end, { skip_runtime_context_refresh = true })
  end)

  it("register_node_click_can_dispatch_without_binding_event_role", function()
    local role1 = { get_roleid = function() return 1 end }
    local manager = { client_role = nil, EVENT = { CLICK = "click" } }
    local listener_callback = nil

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime, key = "query_nodes", value = function()
        return {
          {
            listen = function(_, _, callback)
              listener_callback = callback
              return { destroy = function() end }
            end,
          },
        }
      end },
    }, function()
      local hits = {}
      bindings.register_node_click({}, base_nodes.action_log_button, function()
        hits[#hits + 1] = manager.client_role ~= nil and "role" or "global"
      end, {}, {}, { bind_client_role = false })

      assert(listener_callback ~= nil, "action log button should have a click listener")
      listener_callback({ role = role1 })
      _assert_eq(table.concat(hits, ","), "global",
        "bind_client_role=false should ignore the event role while dispatching")
    end, { skip_runtime_context_refresh = true })
  end)

  it("register_node_click_reuses_legacy_name_cache_without_querying", function()
    local manager = { EVENT = { CLICK = "click" } }
    local query_calls = 0
    local listeners = {}
    local legacy_node = {
      listen = function()
        return { destroy = function() end }
      end,
    }
    local cache = {
      [base_nodes.skin_button] = { legacy_node },
    }

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime, key = "query_nodes", value = function()
        query_calls = query_calls + 1
        return {}
      end },
    }, function()
      bindings.register_node_click(cache, base_nodes.skin_button, function() end, {}, listeners)
    end)

    _assert_eq(query_calls, 0, "legacy name cache should be enough to register a click listener")
    _assert_eq(#listeners, 1, "legacy cached node should receive one click listener")
  end)

  it("register_node_click_uses_single_global_listener_when_query_returns_same_node_for_roles", function()
    local role1 = { get_roleid = function() return 1 end }
    local role2 = { get_roleid = function() return 2 end }
    local manager = { client_role = nil, EVENT = { CLICK = "click" } }
    local callbacks = {}
    local shared_node = {
      listen = function(_, _, callback)
        callbacks[#callbacks + 1] = callback
        return { destroy = function() end }
      end,
    }

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime, key = "query_nodes", value = function()
        return { shared_node }
      end },
    }, function()
      runtime_ports.configure({
        resolve_roles = function()
          return { role1, role2 }
        end,
      })
      local hits = {}
      bindings.register_node_click({}, base_nodes.skin_button, function()
        local role = manager.client_role
        hits[#hits + 1] = role and role.get_roleid and role.get_roleid() or "global"
      end, {}, {})

      _assert_eq(#callbacks, 1, "shared UIManager nodes must only receive one click listener")
      callbacks[1]({ role = role2 })
      _assert_eq(table.concat(hits, ","), "2",
        "single listener should dispatch under the actual event role")
    end, { skip_runtime_context_refresh = true })
  end)

  it("register_missing_button_tip_registers_only_unclaimed_buttons", function()
    local shown = {}
    local callbacks = {}
    local listeners = {}
    local registered = {
      existing_button = true,
    }

    _with_ui_manager_nodes({
      raw = "ignored",
      missing_button = { "missing_button", "EButton" },
      existing_button = { "existing_button", "EButton" },
      label_node = { "label_node", "ELabel" },
    }, function()
      _with_patches({
        { key = "UIManager", value = { EVENT = { CLICK = "click" }, client_role = nil } },
        { target = runtime, key = "query_nodes", value = function(name)
          return {
            {
              listen = function(_, _, callback)
                callbacks[name] = callback
                return { destroy = function() end }
              end,
            },
          }
        end },
        { target = require("src.host"), key = "enqueue_tip", value = function(intent)
          shown[#shown + 1] = intent and intent.text or nil
        end },
      }, function()
        bindings.register_missing_button_tip({}, registered, listeners)
        assert(type(callbacks.missing_button) == "function", "unregistered EButton should receive missing-tip listener")
        _assert_eq(callbacks.existing_button, nil, "already registered EButton should be skipped")
        _assert_eq(callbacks.label_node, nil, "non-button UI nodes should be skipped")
        callbacks.missing_button()
      end)
    end)

    _assert_eq(shown[1], "UI 节点未适配: missing_button", "missing-button fallback should show tip")
  end)

  it("canvas_intents_cover_remote_target_and_market_paths", function()
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
    _assert_eq(target_specs[1].build_intent(), nil, "target confirm button must be inert")
    _assert_eq(target_specs[2].build_intent(), nil, "target cancel button must be inert")
    local slot_intent = target_specs[3].build_intent()
    _assert_eq(slot_intent.type, "choice_select", "target slot tap should commit immediately")
    _assert_eq(slot_intent.option_id, 21, "target slot tap should resolve option by index")
    state.ui_runtime.pending_choice_selected_option_id = 33
    _assert_eq(market_item_specs[1].build_intent().type, "market_select", "market item should build selection intent")
    _assert_eq(market_control_specs[1].build_intent().type, "market_confirm", "market confirm should use selected option")
    _assert_eq(market_control_specs[2].build_intent().type, "choice_cancel", "market cancel should map to choice cancel")
    _assert_eq(#market_control_specs, 6, "market controls should expose item-only entries")
  end)

  it("target slot button first tap dispatches choice_select", function()
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
        locked_option_id = nil,
      },
    }
    _bind_ui_runtime(state)

    local target_specs = target_choice_intents.build(state)
    local intent = target_specs[3].build_intent()
    _assert_eq(intent.type, "choice_select", "first tap on slot should emit choice_select")
    _assert_eq(intent.option_id, "tile_5", "first tap should resolve slot index to option id")
    _assert_eq(intent.choice_id, 7, "choice_select should carry choice id")
  end)

  it("target slot button single-option choice auto-dispatches choice_select on first tap", function()
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

  it("target slot button tap on different option dispatches choice_select for new option", function()
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

    local target_specs = target_choice_intents.build(state)
    local intent = target_specs[4].build_intent()
    _assert_eq(intent.type, "choice_select", "tap on different slot should commit immediately")
    _assert_eq(intent.option_id, "tile_8", "commit should carry the tapped option id")
    _assert_eq(intent.choice_id, 13, "commit should carry choice id")
  end)

  it("canvas_intents_return_nil_when_choice_or_market_missing", function()
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
    assert(_find_spec(specs, base_nodes.skin_button) ~= nil, "route specs should include skin button")
    assert(_find_spec(specs, base_nodes.gallery_button) ~= nil, "route specs should include gallery button")
    local skin_action_spec = _find_spec(specs, skin_nodes.action_buttons[2])
    assert(skin_action_spec ~= nil, "route specs should include skin panel slot action")
    local skin_intent = skin_action_spec.build_intent and skin_action_spec.build_intent() or nil
    _assert_eq(skin_intent and skin_intent.type, "skin_panel_action", "skin panel slot should build skin action")
    _assert_eq(skin_intent and skin_intent.action and skin_intent.action.type, "equip",
      "skin panel slot should request equip action")
    _assert_eq(skin_intent and skin_intent.action and skin_intent.action.slot_index, 2,
      "skin panel slot should preserve clicked slot index")
    local atlas_slot_spec = _find_spec(specs, item_atlas_nodes.card_images[3])
    assert(atlas_slot_spec ~= nil, "route specs should include item atlas slot action")
    local atlas_intent = atlas_slot_spec.build_intent and atlas_slot_spec.build_intent() or nil
    _assert_eq(atlas_intent and atlas_intent.type, "item_atlas_action", "atlas slot should build atlas action")
    _assert_eq(atlas_intent and atlas_intent.action and atlas_intent.action.type, "select",
      "atlas slot should request select action")
    _assert_eq(atlas_intent and atlas_intent.action and atlas_intent.action.slot_index, 3,
      "atlas slot should preserve clicked slot index")
    local outline_spec = _find_spec(specs, ids.outline[1])
    assert(outline_spec ~= nil, "route specs should include item outline node")
    local intent = outline_spec.build_intent and outline_spec.build_intent() or nil
    _assert_eq(intent and intent.id, "item_slot_1", "outline click should still map to item slot intent")
  end)

  it("skin_gallery_view_actions_update_local_state", function()
    local skin_gallery = require("src.ui.coord.skin_gallery")
    local host = require("src.host")
    local state = { ui = {} }
    local tips = {}

    _with_patches({
      { target = host, key = "enqueue_tip", value = function(payload)
        tips[#tips + 1] = payload
      end },
    }, function()
      skin_gallery.open_skin(state, 1)
      _assert_eq(state.ui.skin_gallery.open, true, "skin panel should open")
      _assert_eq(state.ui.skin_gallery.mode, "skin", "skin panel mode should be skin")
      skin_gallery.handle_action(state, "buy", 1)
      skin_gallery.handle_action(state, "equip", 1)
      _assert_eq(state.ui.skin_gallery.selected_by_role["1"], skin_gallery.catalog[1].product_id,
        "equip should select unlocked skin")
      skin_gallery.open_gallery(state, 1)
      _assert_eq(state.ui.skin_gallery.mode, "gallery", "gallery button should open gallery mode")
      skin_gallery.handle_action(state, "close", 1)
      _assert_eq(state.ui.skin_gallery.open, false, "close action should close panel")
    end)

    assert(#tips >= 4, "skin/gallery actions should emit safe local tips")
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
