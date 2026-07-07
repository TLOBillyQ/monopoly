local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local _wrap_ui_refs = P.wrap_ui_refs
local timing = require("src.config.gameplay.timing")
local base_nodes = require("src.ui.schema.base")

local function _new_cash_delta_presenter_env(opts)
  opts = opts or {}
  local presenter = require("src.ui.render.widgets.presenter")
  local number_utils = require("src.foundation.number")
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY_AVATAR" }),
    ui = {
      item_slots = {},
      base_hidden_nodes = {},
      base_hidden_labels = {},
      auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
      item_slot_item_ids_by_role = {},
      labels = {},
      buttons = {},
      visible = {},
      touch_enabled = {},
      set_label = function(self, name, text)
        if opts.missing_delta_node and string.match(name, "^基础%-玩家%d消耗金币显示$") then
          error("missing node")
        end
        self.labels[name] = text
      end,
      set_button = function(self, name, text)
        self.buttons[name] = text
      end,
      set_visible = function(self, name, value)
        if opts.missing_delta_node and string.match(name, "^基础%-玩家%d消耗金币显示$") then
          error("missing node")
        end
        self.visible[name] = value
      end,
      set_touch_enabled = function(self, name, value)
        self.touch_enabled[name] = value
      end,
      query_node = function()
        return {}
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    auto_enabled_by_player = { [1] = false },
    board = { players = {} },
    item_slots_by_player = {},
    panel = {
      turn_label = "倒计时:0",
      auto_label = "托管",
      auto_label_by_player = { [1] = "托管" },
      no_action_visible = false,
      no_action_text = "",
      player_rows = {
        { name = "P1", avatar = nil, eliminated = false, cash_value = 0, total_assets_value = 0, cash = "现金: 0", land_count = "", total_assets = "总资产: 0" },
        { name = "P2", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P3", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P4", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
  }
  local runtime = {
    set_client_role = function() end,
    resolve_role_id = function(role)
      if role and role.get_roleid then
        return role.get_roleid()
      end
      return nil
    end,
    for_each_role_or_global = function(fn)
      fn(nil)
    end,
    query_node = function()
      return {}
    end,
    set_node_texture_native_size = function() end,
  }
  local function set_cash(index, value)
    local row = ui_model.panel.player_rows[index]
    row.cash_value = value
    if value == nil then
      row.cash = ""
    else
      row.cash = "现金: " .. number_utils.format_integer_part(value)
    end
  end
  local function set_total_assets(index, value)
    local row = ui_model.panel.player_rows[index]
    row.total_assets_value = value
    if value == nil then
      row.total_assets = ""
    else
      row.total_assets = "总资产: " .. number_utils.format_integer_part(value)
    end
  end
  local function set_eliminated(index, value)
    local row = ui_model.panel.player_rows[index]
    row.eliminated = value == true
  end
  local function refresh()
    presenter.refresh(state, ui_model, {
      runtime = runtime,
      refresh_item_slots = function() end,
    })
  end
  local function refresh_with(overrides)
    local deps = {
      runtime = runtime,
      refresh_item_slots = function() end,
    }
    for key, value in pairs(overrides or {}) do
      deps[key] = value
    end
    presenter.refresh(state, ui_model, deps)
  end
  return {
    state = state,
    ui_model = ui_model,
    runtime = runtime,
    refresh = refresh,
    refresh_with = refresh_with,
    set_cash = set_cash,
    set_total_assets = set_total_assets,
    set_eliminated = set_eliminated,
  }
end

describe("presentation_player_panels", function()
  it("_test_panel_controls_base_non_player_visibility_tracks_boolean_input", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local ui = {
      base_hidden_nodes = { "node_a" },
      base_hidden_labels = { "label_a" },
      set_visible = function(_, name, value)
        visible[name] = value
      end,
    }

    panel_controls.apply_base_non_player_visibility(ui, false)
    _assert_eq(visible.node_a, false, "false visibility should hide base hidden nodes")
    _assert_eq(visible.label_a, false, "false visibility should hide base hidden labels")

    panel_controls.apply_base_non_player_visibility(ui, true)
    _assert_eq(visible.node_a, true, "true visibility should show base hidden nodes")
    _assert_eq(visible.label_a, true, "true visibility should show base hidden labels")
  end)

  it("_test_panel_avatar_uses_native_size_path", function()
    local presenter = require("src.ui.render.widgets.presenter")
    local native_size_calls = 0
    local client_role = { stale = true }
    local state = {
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY_AVATAR" }),
      ui = {
        item_slots = {},
        base_hidden_nodes = {},
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        item_slot_item_ids_by_role = {},
        set_label = function() end,
        set_visible = function() end,
        set_touch_enabled = function() end,
        query_node = function()
          return {}
        end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      auto_enabled_by_player = { [1] = false },
      board = { players = {} },
      item_slots_by_player = {},
      panel = {
        turn_label = "倒计时:0",
        auto_label = "托管",
        auto_label_by_player = { [1] = "托管" },
        no_action_visible = false,
        no_action_text = "",
        player_rows = {
          { name = "P1", avatar = "A1", cash = "", land_count = "", total_assets = "" },
          { name = "P2", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "P3", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "P4", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
    }
    local runtime = {
      set_client_role = function(role)
        client_role = role
      end,
      resolve_role_id = function() return nil end,
      for_each_role_or_global = function(fn)
        fn(nil)
      end,
      set_node_texture_native_size = function()
        native_size_calls = native_size_calls + 1
      end,
    }

    presenter.refresh(state, ui_model, {
      runtime = runtime,
      refresh_item_slots = function() end,
    })

    _assert_eq(native_size_calls, 4, "panel avatar should use native-size path")
    _assert_eq(client_role, nil, "panel presenter should restore client_role to nil")
  end)

  it("_test_panel_presenter_auto_label_defaults_and_countdown_contract", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.auto_control_nodes = nil
    env.ui_model.panel.auto_label = "默认托管"
    env.ui_model.panel.auto_label_by_player = { [1] = "玩家1托管" }

    env.refresh()

    _assert_eq(env.state.ui.labels[base_nodes.auto_label], "玩家1托管",
      "presenter should prefer current player's auto label")
    _assert_eq(env.state.ui.visible[base_nodes.auto_button], true,
      "default auto button should be visible when ui omits auto_control_nodes")
    _assert_eq(env.state.ui.visible[base_nodes.auto_label], true,
      "default auto label should be visible when ui omits auto_control_nodes")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.auto_button], true,
      "default auto button should remain touchable for the player role")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.auto_label], false,
      "default auto label should stay non-clickable")
    _assert_eq(env.state.ui.visible[base_nodes.countdown], true,
      "missing countdown_visible should default to visible")
    _assert_eq(env.state.ui.visible[base_nodes.countdown_line], true,
      "missing countdown_visible should keep countdown line visible")
    _assert_eq(env.state.ui.labels[base_nodes.countdown], "倒计时:0",
      "countdown label should still be synchronized")
    assert(env.state.ui.visible[base_nodes.action_hint] ~= true,
      "no-action hint should stay hidden when no_action_visible is false")

    env.ui_model.panel.auto_label_by_player = {}
    env.ui_model.panel.auto_label = "默认托管"
    env.refresh()
    _assert_eq(env.state.ui.labels[base_nodes.auto_label], "默认托管",
      "presenter should fall back to panel auto_label")

    env.ui_model.panel.auto_label_by_player = nil
    env.ui_model.panel.auto_label = "默认托管"
    env.refresh()
    _assert_eq(env.state.ui.labels[base_nodes.auto_label], "默认托管",
      "presenter should fall back when per-player auto labels are absent")

    env.ui_model.panel.auto_label = nil
    env.state.ui.labels[base_nodes.auto_label] = "保留"
    env.refresh()
    _assert_eq(env.state.ui.labels[base_nodes.auto_label], "保留",
      "missing auto label should not clear the previous label")
  end)

  it("_test_panel_presenter_input_block_blocks_base_controls_and_recovers_item_cache", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.base_hidden_nodes = { base_nodes.action_button }
    env.state.ui.input_blocked = true
    env.state.ui.item_slot_item_ids_by_role = "stale"

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.action_button], false,
      "input lock should hide base action controls even for the current player")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.action_button], false,
      "input lock should disable base action touch")
    _assert_eq(env.state.ui.visible[base_nodes.end_button], false,
      "input lock should also hide the optional end button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.end_button], false,
      "input lock should disable the optional end button touch")
    _assert_eq(type(env.state.ui.item_slot_item_ids_by_role), "table",
      "presenter should recover a malformed item-slot cache")
    _assert_eq(type(env.state.ui.item_slot_item_ids), "table",
      "presenter should publish an empty current item-slot list after cache recovery")
    assert(next(env.state.ui.item_slot_item_ids) == nil,
      "recovered item-slot list should be empty without cached current-player ids")
  end)

  it("_test_panel_presenter_secondary_confirm_hides_end_button", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.base_hidden_nodes = { base_nodes.action_button, base_nodes.end_button }
    env.state.ui.choice_active = true
    env.state.ui.active_choice_screen_key = "secondary_confirm"
    env.ui_model.choice = {
      id = 11,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      allow_cancel = true,
    }

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.end_button], false,
      "secondary confirm screen should hide the optional end button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.end_button], false,
      "secondary confirm screen should disable the optional end button touch")
  end)

  it("_test_panel_presenter_optional_item_target_selection_shows_cancel_button", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.base_hidden_nodes = { base_nodes.action_button, base_nodes.end_button }
    env.ui_model.choice = {
      id = 11,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      allow_cancel = true,
      meta = { passive_origin = true },
    }

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.action_button], false,
      "item target selection should hide the normal action button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.action_button], false,
      "item target selection should disable the normal action button")
    _assert_eq(env.state.ui.visible[base_nodes.end_button], false,
      "item target selection should hide the optional end button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.end_button], false,
      "item target selection should disable the optional end button")
    _assert_eq(env.state.ui.visible[base_nodes.cancel_button], true,
      "item target selection should show the cancel button for the current player")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.cancel_button], true,
      "item target selection should let the current player cancel the target selection")
    _assert_eq(env.state.ui.buttons[base_nodes.cancel_button], nil,
      "item target selection cancel button should not write button text")
    _assert_eq(env.state.ui.labels[base_nodes.cancel_button], nil,
      "item target selection cancel button should not write label text")
  end)

  it("_test_panel_presenter_optional_landing_choice_shows_end_button", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.base_hidden_nodes = { base_nodes.action_button, base_nodes.end_button }
    env.ui_model.choice = {
      id = 12,
      kind = "landing_optional_effect",
      allow_cancel = true,
    }

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.action_button], false,
      "optional landing choice should hide the normal action button")
    _assert_eq(env.state.ui.visible[base_nodes.end_button], true,
      "optional landing choice should show the end button")
  end)

  it("_test_panel_presenter_non_cancelable_optional_choice_hides_base_progression_buttons", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.base_hidden_nodes = { base_nodes.action_button, base_nodes.end_button }
    env.ui_model.choice = {
      id = 13,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      allow_cancel = false,
    }

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.action_button], false,
      "non-cancelable optional choice should not expose the normal action button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.action_button], false,
      "non-cancelable optional choice should not route through the normal action button")
    _assert_eq(env.state.ui.visible[base_nodes.end_button], false,
      "non-cancelable optional choice should hide the optional end button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.end_button], false,
      "non-cancelable optional choice should not build cancel affordance touch")
  end)

  it("_test_panel_presenter_wait_action_hides_optional_end_button", function()
    local env = _new_cash_delta_presenter_env()
    env.state.ui.base_hidden_nodes = { base_nodes.action_button, base_nodes.end_button }

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.action_button], true,
      "wait action should keep the normal action button visible")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.action_button], true,
      "wait action should keep the normal action button touchable")
    _assert_eq(env.state.ui.visible[base_nodes.end_button], false,
      "wait action should hide the optional end button")
    _assert_eq(env.state.ui.touch_enabled[base_nodes.end_button], false,
      "hidden optional end button should not be touchable")
  end)

  it("_test_panel_presenter_syncs_current_player_cached_item_ids", function()
    local env = _new_cash_delta_presenter_env()
    local cached = { 2001, 2002 }
    env.state.ui.item_slot_item_ids_by_role = { [1] = cached }

    env.refresh()

    _assert_eq(env.state.ui.item_slot_item_ids, cached,
      "presenter should publish cached item ids for the current player")

    env.ui_model.current_player_id = nil
    env.refresh()

    assert(next(env.state.ui.item_slot_item_ids) == nil,
      "missing current player should publish an empty item-slot list")
  end)

  it("_test_panel_presenter_hides_auto_effect_for_unmapped_role", function()
    local env = _new_cash_delta_presenter_env()
    local unmapped_role = { get_roleid = function() return 99 end }
    env.ui_model.item_slots_by_player = { [1] = {} }
    env.ui_model.auto_enabled_by_player = { [99] = true }
    env.runtime.for_each_role_or_global = function(fn)
      fn(unmapped_role)
    end

    env.refresh()

    _assert_eq(env.state.ui.visible[base_nodes.auto_effect], false,
      "unmapped roles should not display another player's auto effect")
  end)

  it("_test_panel_presenter_uses_custom_touch_policy_dependency", function()
    local env = _new_cash_delta_presenter_env()
    local calls = {}
    local custom_policy = {
      set_auto_controls_touch = function(_, is_player_role, controls)
        calls[#calls + 1] = {
          is_player_role = is_player_role,
          controls = controls,
        }
      end,
    }

    env.refresh_with({ ui_touch_policy = custom_policy })

    _assert_eq(#calls, 1, "presenter should use injected touch policy")
    _assert_eq(calls[1].is_player_role, true,
      "presenter should pass player-role state to injected touch policy")
    _assert_eq(calls[1].controls, env.state.ui.auto_control_nodes,
      "presenter should pass resolved auto controls to injected touch policy")
  end)

  it("_test_panel_presenter_applies_player_colors_to_all_four_slots", function()
    local env = _new_cash_delta_presenter_env()
    local colored = {}
    local role = {
      get_roleid = function() return 1 end,
      set_image_color = function(_, node)
        colored[node] = true
      end,
    }
    env.ui_model.item_slots_by_player = { [1] = {} }
    env.ui_model.board.players = {
      { id = 1 },
      { id = 2 },
      { id = 3 },
      { id = 4 },
    }
    env.runtime.query_node = function(name)
      return name
    end
    env.runtime.for_each_role_or_global = function(fn)
      fn(role)
    end

    env.refresh()

    _assert_eq(colored["基础_玩家1底板颜色"], true,
      "player 1 color node should be updated")
    _assert_eq(colored["基础_玩家4底板颜色"], true,
      "player 4 color node should be updated")
  end)

  it("_test_panel_cash_delta_shows_negative_and_auto_hides", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _new_cash_delta_presenter_env()
    local scheduled = {}

    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      env.set_cash(1, 100)
      env.refresh()
      env.set_cash(1, 80)
      env.refresh()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "-20",
        "cash delta should render negative text immediately when show_delay=0")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true,
        "cash delta label should be visible immediately")
      _assert_eq(#scheduled, 1, "cash delta should schedule hide once after immediate show")
      _assert_eq(scheduled[1].delay, timing.panel_cash_delta_visible_seconds,
        "cash delta hide duration should follow dedicated gameplay rule")
      scheduled[1].cb()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "cash delta label should clear after timeout")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "cash delta label should hide after timeout")
    end)
  end)

  it("_test_panel_cash_delta_shows_positive_and_auto_hides", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _new_cash_delta_presenter_env()
    local scheduled = {}

    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      env.set_cash(1, 80)
      env.refresh()
      env.set_cash(1, 120)
      env.refresh()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40",
        "cash delta should render positive text immediately when show_delay=0")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true,
        "cash delta label should be visible immediately")
      _assert_eq(#scheduled, 1, "cash delta should schedule hide once after immediate show")
      _assert_eq(scheduled[1].delay, timing.panel_cash_delta_visible_seconds,
        "cash delta hide duration should follow dedicated gameplay rule")
      scheduled[1].cb()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "cash delta label should clear after timeout")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "cash delta label should hide after timeout")
    end)
  end)

  it("_test_panel_cash_delta_shows_each_change_independently", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _new_cash_delta_presenter_env()
    local scheduled = {}

    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      env.set_cash(1, 100)
      env.refresh()
      env.set_cash(1, 80)
      env.refresh()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "-20",
        "first change should display its own delta")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true,
        "first change should be visible")
      _assert_eq(#scheduled, 1, "first change should schedule a hide")
      env.set_cash(1, 120)
      env.refresh()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40",
        "second change should display its own instantaneous delta (not net vs. earlier anchor)")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true,
        "label should remain visible after second change")
      _assert_eq(#scheduled, 2, "second change should schedule a fresh hide; earlier hide is invalidated by token bump")
      scheduled[1].cb()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40",
        "stale hide callback should not clear current label")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true,
        "stale hide callback should not flip visibility")
      scheduled[2].cb()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "",
        "latest hide should clear the label")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false,
        "latest hide should flip visibility off")
    end)
  end)

  it("_test_panel_cash_delta_reverse_event_replaces_previous_delta", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _new_cash_delta_presenter_env()
    local scheduled = {}

    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      -- 模拟"经过起点 +2000，紧随其后买地 -1000"：两次变化在显示窗口内反向
      env.set_cash(1, 10000)
      env.refresh()
      env.set_cash(1, 12000)
      env.refresh()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+2000",
        "pass-start reward shows its own delta")
      env.set_cash(1, 11000)
      env.refresh()
      _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "-1000",
        "buy-land cost shows its own delta, not net (+2000 - 1000 = +1000)")
      _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true,
        "buy-land delta should be visible")
    end)
  end)

  it("_test_panel_cash_delta_hides_when_value_unchanged", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _new_cash_delta_presenter_env()
    local scheduled = {}

    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      env.set_cash(1, 100)
      env.refresh()
      env.set_cash(1, 100)
      env.refresh()
    end)

    _assert_eq(#scheduled, 0, "unchanged cash should not schedule show or hide")
    _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"] or "", "", "unchanged cash should keep delta label empty")
    _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "unchanged cash should keep delta label hidden")
  end)

  it("_test_panel_cash_delta_missing_node_is_safe", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")
    local env = _new_cash_delta_presenter_env({ missing_delta_node = true })
    local scheduled = {}
    local ok, err = pcall(function()
      _with_patches({
        { target = runtime_ports, key = "schedule", value = function(delay, cb)
          scheduled[#scheduled + 1] = { delay = delay, cb = cb }
        end },
      }, function()
        env.set_cash(1, 100)
        env.refresh()
        env.set_cash(1, 80)
        env.refresh()
        assert(#scheduled == 0, "missing cash delta node should not schedule a hide when set_label fails")
      end)
    end)

    assert(ok, "missing cash delta node should not crash: " .. tostring(err))
    _assert_eq(env.state.ui.labels["基础_玩家1现金"], "现金: 80", "base cash label should still update")
  end)

  it("_test_panel_crown_shows_for_top_total_assets_and_ties", function()
    local env = _new_cash_delta_presenter_env()
    env.set_total_assets(1, 100)
    env.set_total_assets(2, 120)
    env.set_total_assets(3, 120)
    env.set_total_assets(4, 80)

    env.refresh()

    _assert_eq(env.state.ui.visible["基础_玩家1皇冠"], false, "player1 crown should hide when not top")
    _assert_eq(env.state.ui.visible["基础_玩家2皇冠"], true, "player2 crown should show when tied top")
    _assert_eq(env.state.ui.visible["基础_玩家3皇冠"], true, "player3 crown should show when tied top")
    _assert_eq(env.state.ui.visible["基础_玩家4皇冠"], false, "player4 crown should hide when not top")
  end)

  it("_test_panel_crown_excludes_eliminated_players", function()
    local env = _new_cash_delta_presenter_env()
    env.set_total_assets(1, 80)
    env.set_total_assets(2, 200)
    env.set_total_assets(3, 100)
    env.set_total_assets(4, 60)
    env.set_eliminated(2, true)

    env.refresh()

    _assert_eq(env.state.ui.visible["基础_玩家1皇冠"], false, "player1 crown should hide when not top among active players")
    _assert_eq(env.state.ui.visible["基础_玩家2皇冠"], false, "eliminated player crown should hide")
    _assert_eq(env.state.ui.visible["基础_玩家3皇冠"], true, "active top player crown should show")
    _assert_eq(env.state.ui.visible["基础_玩家4皇冠"], false, "player4 crown should hide")
  end)

  it("_test_panel_apply_player_colors_updates_image_and_labels", function()
    local panel_player_slots = require("src.ui.render.widgets.player_slots")
    local image_calls = {}
    local label_calls = {}

    panel_player_slots.apply_player_colors({
      set_image_color = function(_, node, color, alpha)
        image_calls[#image_calls + 1] = { node = node, color = color, alpha = alpha }
      end,
      set_label_color = function(_, node, color, alpha)
        label_calls[#label_calls + 1] = { node = node, color = color, alpha = alpha }
      end,
    }, {
      query_node = function(name)
        if name == "基础-玩家2消耗金币显示" then
          error("missing label node")
        end
        return name
      end,
    }, {
      id = 2,
    }, 2)

    _assert_eq(#image_calls, 1, "player color should tint one image node")
    _assert_eq(image_calls[1].node, "基础_玩家2底板颜色", "player color should target indexed image node")
    _assert_eq(image_calls[1].alpha, 0, "player color should keep image alpha at zero")
    _assert_eq(#label_calls, 4, "player color should tint every resolved label node")
    _assert_eq(label_calls[1].node, "基础_玩家2名字", "player color should tint player name label")
    _assert_eq(label_calls[#label_calls].alpha, 0, "player color should keep label alpha at zero")
  end)

  it("_test_panel_apply_player_colors_skips_when_role_has_no_color_hooks", function()
    local panel_player_slots = require("src.ui.render.widgets.player_slots")
    local queried = 0

    panel_player_slots.apply_player_colors({}, {
      query_node = function()
        queried = queried + 1
        return {}
      end,
    }, {
      id = 1,
    }, 1)

    _assert_eq(queried, 0, "panel player colors should early-return before querying nodes without color hooks")
  end)

  it("_test_panel_controls_target_selection_shows_cancel_button", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local touch = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function(_, name, value)
        touch[name] = value
      end,
    }
    local ui_model = {
      choice = {
        id = 11,
        kind = "item_phase_passive",
        allow_cancel = true,
        meta = { passive_origin = true },
      },
    }

    panel_controls.apply_base_action_controls(ui, ui_model, true)

    _assert_eq(visible[base_nodes.action_button], false,
      "target selection should hide action button")
    _assert_eq(visible[base_nodes.end_button], false,
      "target selection should hide end button")
    _assert_eq(visible[base_nodes.cancel_button], true,
      "target selection should show cancel button")
    _assert_eq(touch[base_nodes.cancel_button], true,
      "cancel button should be touchable when shown")
  end)

  it("_test_panel_controls_wait_action_hides_cancel_button", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function() end,
    }

    panel_controls.apply_base_action_controls(ui, {}, true)

    _assert_eq(visible[base_nodes.cancel_button], false,
      "wait action should hide cancel button")
    _assert_eq(visible[base_nodes.action_button], true,
      "wait action should show action button")
  end)

  it("_test_panel_controls_non_cancelable_optional_hides_all_main_buttons", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function() end,
    }
    local ui_model = {
      choice = {
        id = 12,
        kind = "item_phase_passive",
        allow_cancel = false,
      },
    }

    panel_controls.apply_base_action_controls(ui, ui_model, true)

    _assert_eq(visible[base_nodes.action_button], false,
      "non-cancelable optional should hide action")
    _assert_eq(visible[base_nodes.end_button], false,
      "non-cancelable optional should hide end")
    _assert_eq(visible[base_nodes.cancel_button], false,
      "non-cancelable optional should hide cancel")
  end)

  it("_test_panel_controls_pre_action_item_phase_shows_action_button", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local touch = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function(_, name, value)
        touch[name] = value
      end,
    }
    local ui_model = {
      choice = {
        id = 21,
        kind = "item_phase_passive",
        allow_cancel = true,
        meta = { phase = "pre_action" },
      },
    }

    panel_controls.apply_base_action_controls(ui, ui_model, true)

    _assert_eq(visible[base_nodes.action_button], true,
      "pre-action item phase should show the action button before the roll")
    _assert_eq(touch[base_nodes.action_button], true,
      "pre-action action button should stay touchable before the roll")
    _assert_eq(visible[base_nodes.end_button], false,
      "pre-action item phase should hide the end button")
    _assert_eq(visible[base_nodes.cancel_button], false,
      "pre-action item phase should hide the cancel button")
  end)

  it("_test_panel_controls_post_action_item_phase_still_shows_end_button", function()
    local panel_controls = require("src.ui.render.widgets.panel_controls")
    local visible = {}
    local ui = {
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_touch_enabled = function() end,
    }
    local ui_model = {
      choice = {
        id = 22,
        kind = "item_phase_passive",
        allow_cancel = true,
        meta = { phase = "post_action" },
      },
    }

    panel_controls.apply_base_action_controls(ui, ui_model, true)

    _assert_eq(visible[base_nodes.end_button], true,
      "post-action item phase should still show the end button after the roll")
    _assert_eq(visible[base_nodes.action_button], false,
      "post-action item phase should hide the action button")
    _assert_eq(visible[base_nodes.cancel_button], false,
      "post-action item phase should hide the cancel button")
  end)
end)
