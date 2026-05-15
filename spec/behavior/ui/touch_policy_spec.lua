-- luacheck: ignore 211
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local ui_view = require("src.ui.coord.ui_runtime")
local ui_touch_policy = require("src.ui.input.touch")
local ids = require("spec.fixtures.item_slot_ids")

local function _wrap_ui_refs(image_refs)
  return {
    images = image_refs or {},
  }
end

describe("presentation_ui.touch_policy", function()
  it("_test_apply_input_lock_keeps_auto_controls_enabled", function()
    local touch = {}
    local visible = {}
    local state = {
      ui_model = {
        current_player_id = 1,
        item_slots_by_player = { [1] = { 2001 } },
        panel = {
          auto_label = "自动：关",
          auto_label_by_player = { [1] = "自动：关" },
        },
      },
      ui = {
        input_blocked = true,
        item_slots = ids.slots(1),
        base_hidden_nodes = { "基础_行动按钮", ids.slot[1] },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        choice_screens = {
          player = { option_buttons = {} },
          target = {},
          remote = { option_buttons = {} },
          secondary_confirm = { body = "通用二次确认_文本", cancel = "通用二次确认_取消", confirm = "通用二次确认_确定按钮" },
        },
        set_touch_enabled = function(_, name, enabled)
          touch[name] = enabled
        end,
        set_visible = function(_, name, value)
          visible[name] = value
        end,
        set_button = function() end,
      },
    }
    local roles = {
      { get_roleid = function() return 1 end },
    }

    _with_patches({
      { key = "all_roles", value = roles },
    }, function()
      ui_view.apply_input_lock(state)
    end)

    assert(touch["基础_行动按钮"] == false, "action button should stay blocked")
    assert(touch["基础_托管按钮"] == true, "auto button should stay enabled")
    assert(touch["基础_托管文本"] == false, "auto label should stay non-clickable")
    assert(visible[ids.slot[1]] == true, "item slot should stay visible when locked")
  end)

  it("_test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped", function()
    local touch = {}
    local state = {
      ui_model = {
        current_player_id = 1,
        item_slots_by_player = {},
        panel = {
          auto_label = "自动：关",
        },
      },
      ui = {
        input_blocked = true,
        item_slots = ids.slots(1),
        base_hidden_nodes = { "基础_行动按钮", ids.slot[1] },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        choice_screens = {
          player = { option_buttons = {} },
          target = {},
          remote = { option_buttons = {} },
          secondary_confirm = { body = "通用二次确认_文本", cancel = "通用二次确认_取消", confirm = "通用二次确认_确定按钮" },
        },
        set_touch_enabled = function(_, name, enabled)
          touch[name] = enabled
        end,
        set_visible = function() end,
        set_button = function() end,
      },
    }
    local roles = {
      { get_roleid = function() return 1 end },
    }

    _with_patches({
      { key = "all_roles", value = roles },
    }, function()
      ui_view.apply_input_lock(state)
    end)

    assert(touch["基础_托管按钮"] == true, "auto button should stay enabled when role mapping is missing")
    assert(touch["基础_托管文本"] == false, "auto label should stay non-clickable when role mapping is missing")
  end)

  it("_test_apply_input_lock_disables_always_show_controls_when_market_active", function()
    local touch = {}
    local state = {
      ui_model = {
        current_player_id = 1,
        item_slots_by_player = {},
        panel = {
          auto_label = "自动：关",
        },
      },
      ui = {
        input_blocked = true,
        market_active = true,
        item_slots = ids.slots(1),
        base_hidden_nodes = { "基础_行动按钮", ids.slot[1] },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        choice_screens = {
          player = { option_buttons = {} },
          target = {},
          remote = { option_buttons = {} },
          secondary_confirm = { body = "通用二次确认_文本", cancel = "通用二次确认_取消", confirm = "通用二次确认_确定按钮" },
        },
        set_touch_enabled = function(_, name, enabled)
          touch[name] = enabled
        end,
        set_visible = function() end,
        set_button = function() end,
      },
    }
    local roles = {
      { get_roleid = function() return 1 end },
    }

    _with_patches({
      { key = "all_roles", value = roles },
    }, function()
      ui_view.apply_input_lock(state)
    end)

    assert(touch["基础_托管按钮"] == false, "auto button should yield touch priority while market is active")
    assert(touch["基础_托管文本"] == false, "auto label should stay non-clickable while market is active")
    assert(touch["基础_行动日志图标"] == false, "action log toggle should yield touch priority while market is active")
  end)

  it("_test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists", function()
    local touch_logs = {}
    local state = {
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY", ["2001"] = "ICON2001" }),
      ui = {
        item_slots = ids.slots(1),
        base_hidden_nodes = { "基础_行动按钮", ids.slot[1] },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        item_slot_item_ids_by_role = {},
        set_label = function() end,
        set_visible = function() end,
        set_touch_enabled = function(_, name, enabled)
          local role = UIManager and UIManager.client_role or nil
          local role_id = role and role.get_roleid and role.get_roleid() or 0
          touch_logs[role_id] = touch_logs[role_id] or {}
          touch_logs[role_id][name] = enabled
        end,
        query_node = function()
          return {}
        end,
      },
    }
    local ui_model = {
      panel = {
        turn_label = "倒计时:0",
        auto_label = "自动：关",
        auto_label_by_player = {
          [1] = "自动：关",
        },
        player_rows = {
          { name = "P1", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "P2", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "P3", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "P4", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
      board = { players = {} },
      current_player_id = 1,
      auto_enabled_by_player = { [1] = false },
      item_slots_by_player = { [1] = { 2001 } },
    }
    local local_role = {
      get_roleid = function()
        return 1
      end,
    }
    local unmapped_role = {
      get_roleid = function()
        return 99
      end,
    }

    _with_patches({
      { key = "all_roles", value = { local_role, unmapped_role } },
      { key = "UIManager", value = {
        client_role = local_role,
        query_nodes_by_name = function()
          return { {} }
        end,
      } },
    }, function()
      ui_view.refresh_panel(state, ui_model)
    end)

    assert(touch_logs[1] and touch_logs[1]["基础_托管按钮"] == true, "local role auto button should stay enabled")
    assert(touch_logs[99] and touch_logs[99]["基础_托管按钮"] == false, "unmapped role auto button should stay disabled")
  end)

  it("_test_ui_touch_policy_auto_controls_touch", function()
    local touch = {}
    local ui = {
      auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
      set_touch_enabled = function(_, name, enabled)
        touch[name] = enabled
      end,
    }

    ui_touch_policy.set_auto_controls_touch(ui, true)
    _assert_eq(touch["基础_托管按钮"], true, "auto button should be clickable when enabled")
    _assert_eq(touch["基础_托管文本"], false, "auto label should stay non-clickable")
    _assert_eq(touch["基础_托管按钮特效"], false, "auto effect should stay non-clickable")

    ui_touch_policy.set_auto_controls_touch(ui, false)
    _assert_eq(touch["基础_托管按钮"], false, "auto button should be non-clickable when disabled")
    _assert_eq(touch["基础_托管文本"], false, "auto label should stay non-clickable when disabled")
    _assert_eq(touch["基础_托管按钮特效"], false, "auto effect should stay non-clickable when disabled")
  end)

  it("_test_ui_touch_policy_runtime_nodes_touch_enabled", function()
    local node1 = { disabled = true }
    local node2 = { disabled = true }

    ui_touch_policy.set_runtime_nodes_touch_enabled({ node1, node2 }, true)
    _assert_eq(node1.disabled, false, "runtime node should be enabled")
    _assert_eq(node2.disabled, false, "runtime node should be enabled")

    ui_touch_policy.set_runtime_nodes_touch_enabled({ node1, node2 }, false)
    _assert_eq(node1.disabled, true, "runtime node should be disabled")
    _assert_eq(node2.disabled, true, "runtime node should be disabled")
  end)
end)
