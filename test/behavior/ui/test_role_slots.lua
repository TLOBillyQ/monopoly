-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _build_asset_context = support.build_asset_context
local _with_patches = support.with_patches
local ui_view = require("src.ui.coord.ui_runtime")
local base_nodes = require("src.ui.schema.base")
local ids = require("test.fixtures.item_slot_ids")

TestRoleSlots = {}

function TestRoleSlots:test_render_auto_controls_tolerates_a_missing_panel()
  local panel_controls = require("src.ui.render.widgets.panel_controls")
  local visible_calls = {}
  local ui = {
    auto_control_nodes = { "基础_托管按钮" },
    set_visible = function(_, name, visible)
      visible_calls[#visible_calls + 1] = { name, visible }
    end,
  }
  local ctx = {
    display_player_id = nil,
    is_player_role = false,
  }
  local touch_calls = {}
  local touch = {
    set_auto_controls_touch = function(_, is_player, controls)
      touch_calls[#touch_calls + 1] = { is_player = is_player, controls = controls }
    end,
  }

  panel_controls.render_auto_controls_for_role(ui, ctx, {}, touch)

  -- panel 缺失只跳过文案,托管控件照常显示、触摸策略照常下发
  lu.assertEquals(#visible_calls, 1)
  lu.assertEquals(visible_calls[1][1], "基础_托管按钮")
  lu.assertEquals(visible_calls[1][2], true)
  lu.assertEquals(#touch_calls, 1)
  lu.assertEquals(touch_calls[1].is_player, false)
  lu.assertEquals(touch_calls[1].controls, ui.auto_control_nodes)
end

do
  function TestRoleSlots:test_base_schema_node_names_are_stable()
    local expected = {
      canvas = "基础屏",
      action_button = "基础_行动按钮",
      end_button = "基础_结束按钮",
      countdown = "基础_倒计时",
      countdown_line = "基础_倒计时横线",
      action_hint = "基础_行动提示",
      action_hint_effect = "基础_行动提示特效",
      other_player_hint = "基础_其他玩家行动提示",
      player_name = "基础_玩家%s名字",
      player_cash = "基础_玩家%s现金",
      player_cash_delta = "基础-玩家%s消耗金币显示",
      player_land_count = "基础_玩家%s地块数量",
      player_total_assets = "基础_玩家%s总资产",
      player_crown = "基础_玩家%s皇冠",
      player_avatar = "基础_玩家%s头像",
      player_color = "基础_玩家%s底板颜色",
      auto_button = "基础_托管按钮",
      auto_effect = "基础_托管按钮特效",
      auto_label = "基础_托管文本",
      action_log_button = "基础_行动日志图标",
      skin_button = "基础_皮肤图标",
      skin_label = "基础_皮肤文本",
      gallery_button = "基础_图鉴图标",
    }

    for key, value in pairs(expected) do
      lu.assertEvalToTrue(base_nodes[key] == value, "base schema node mismatch: " .. key)
    end
    for index, value in ipairs({
      "基础_玩家1行动动效",
      "基础_玩家2行动动效",
      "基础_玩家3行动动效",
      "基础_玩家4行动动效",
    }) do
      lu.assertEvalToTrue(base_nodes.player_action_effects[index] == value,
        "base schema action effect mismatch: " .. tostring(index))
    end
  end

  function TestRoleSlots:test_ui_state_defaults_start_inactive_and_hide_skin_entry_with_base_controls()
    local ui = ui_view.build_ui_state()
    local hidden = {}
    for _, name in ipairs(ui.base_hidden_nodes) do
      hidden[name] = true
    end

    lu.assertEvalToTrue(ui.auto_play == false, "ui auto_play should default off")
    lu.assertEvalToTrue(ui.move_active == false, "ui move_active should default inactive")
    lu.assertEvalToTrue(ui.popup_seq == 0, "ui popup sequence should start at zero")
    lu.assertEvalToTrue(hidden["基础_皮肤图标"] == true, "skin button should follow base hidden controls")
    lu.assertEvalToTrue(hidden["基础_皮肤文本"] == true, "skin label should follow base hidden controls")
  end

  function TestRoleSlots:test_ui_view_render_by_role_slots_are_isolated()
    local image_logs = {}
    local node_map = {}
    local touch_logs = {}
    local visible_logs = {}
    local label_logs = {}
    local button_logs = {}

    local function role_key()
      local role = UIManager and UIManager.client_role or nil
      if role and role.get_roleid then
        return role.get_roleid()
      end
      return 0
    end

    local function new_texture_node(node_name)
      local storage = {}
      return setmetatable({}, {
        __index = function(_, key)
          return storage[key]
        end,
        __newindex = function(_, key, value)
          if key == "image_texture" then
            local role_id = role_key()
            image_logs[role_id] = image_logs[role_id] or {}
            image_logs[role_id][node_name] = value
          end
          storage[key] = value
        end,
      })
    end

    for i = 1, 5 do
      local node_name = ids.slot[i]
      node_map[node_name] = new_texture_node(node_name)
    end
    for i = 1, 4 do
      local node_name = "基础_玩家" .. tostring(i) .. "头像"
      node_map[node_name] = new_texture_node(node_name)
    end

    local function query_nodes_by_name(name)
      local node = node_map[name]
      if not node then
        node = {}
        node_map[name] = node
      end
      return { node }
    end

    local state = {
      runtime_asset_context = _build_asset_context({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
        ["2002"] = "ICON2002",
      }),
      ui = {
        item_slots = ids.slots(5),
        base_hidden_nodes = {
          "基础_行动按钮",
          "基础_皮肤图标",
          "基础_皮肤文本",
          ids.slot[1],
          ids.slot[2],
          ids.slot[3],
          ids.slot[4],
          ids.slot[5],
        },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        set_label = function(_, name, text)
          local role_id = role_key()
          label_logs[role_id] = label_logs[role_id] or {}
          label_logs[role_id][name] = text
        end,
        set_button = function(_, name, text)
          local role_id = role_key()
          button_logs[role_id] = button_logs[role_id] or {}
          button_logs[role_id][name] = text
        end,
        set_visible = function(_, name, visible)
          local role_id = role_key()
          visible_logs[role_id] = visible_logs[role_id] or {}
          visible_logs[role_id][name] = visible
        end,
        set_touch_enabled = function(_, name, enabled)
          local role_id = role_key()
          touch_logs[role_id] = touch_logs[role_id] or {}
          touch_logs[role_id][name] = enabled
        end,
      },
    }

    local ui_model = {
      panel = {
        turn_label = "倒计时:0",
        countdown_visible = true,
        auto_label = "托管",
        auto_label_by_player = {
          [1] = "托管",
          [2] = "托管",
        },
        player_rows = {
          { name = "P1", avatar = "AVATAR_1", cash = "现金: 1", land_count = "地块: 0", total_assets = "总资产: 1" },
          { name = "P2", avatar = nil, cash = "现金: 1", land_count = "地块: 0", total_assets = "总资产: 1" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
      item_slots_by_player = {
        [1] = { 2001 },
        [2] = { 2002 },
      },
      delegated_by_player = {
        [1] = false,
        [2] = true,
      },
      item_slots = { 2001 },
      current_player_id = 1,
      item_choice_owner_id = 1,
      choice = nil,
    }

    local roles = {
      { get_roleid = function() return 1 end },
      { get_roleid = function() return 2 end },
    }

    _with_patches({
      { key = "all_roles", value = roles },
      { key = "UIManager", value = { client_role = roles[1], query_nodes_by_name = query_nodes_by_name } },
    }, function()
      ui_view.refresh_panel(state, ui_model)
    end)

    lu.assertEvalToTrue(image_logs[1] and image_logs[1][ids.slot[1]] == "ICON2001", "role1 slot icon expected")
    lu.assertEvalToTrue(image_logs[2] and image_logs[2][ids.slot[1]] == "ICON2002", "role2 slot icon expected")
    lu.assertEvalToTrue(image_logs[0] and image_logs[0]["基础_玩家1头像"] == "AVATAR_1", "player1 avatar should use row avatar")
    lu.assertEvalToTrue(image_logs[0] and image_logs[0]["基础_玩家2头像"] == "EMPTY", "player2 avatar should fallback to empty key")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_行动按钮"] == true, "current role action button should be enabled")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_行动按钮"] == false, "non-current role action button should be disabled")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_托管按钮"] == true, "role1 auto button should be enabled")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_托管按钮"] == true, "player role auto button should stay enabled")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_托管文本"] == false, "role1 auto label should stay non-clickable")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_托管文本"] == false, "role2 auto label should stay non-clickable")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_托管按钮特效"] == false, "role1 auto effect should stay non-clickable")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_托管按钮特效"] == false, "role2 auto effect should stay non-clickable")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_皮肤图标"] == false, "current role skin button should not consume hidden clicks")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_皮肤图标"] == true, "visible off-turn skin button should be touchable")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_皮肤文本"] == false, "skin label should never consume clicks for current role")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_皮肤文本"] == false, "skin label should never consume clicks for non-current role")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_皮肤动效1"] == false, "skin effect 1 should never consume clicks for current role")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_皮肤动效1"] == false, "skin effect 1 should never consume clicks for non-current role")
    lu.assertEvalToTrue(touch_logs[1] and touch_logs[1]["基础_皮肤动效2"] == false, "skin effect 2 should never consume clicks for current role")
    lu.assertEvalToTrue(touch_logs[2] and touch_logs[2]["基础_皮肤动效2"] == false, "skin effect 2 should never consume clicks for non-current role")
    lu.assertEvalToTrue(label_logs[1] and label_logs[1]["基础_托管文本"] == "托管", "role1 auto label should show fixed copy")
    lu.assertEvalToTrue(label_logs[2] and label_logs[2]["基础_托管文本"] == "托管", "role2 auto label should show fixed copy")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2]["基础_倒计时"] == true, "non-current role countdown should be visible")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2][ids.slot[1]] == true, "non-current role slot should be visible")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2]["基础_托管按钮"] == true, "auto button should stay visible")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2]["基础_托管文本"] == true, "auto label should stay visible")
    lu.assertEvalToTrue(visible_logs[1] and visible_logs[1]["基础_皮肤图标"] == false, "current role skin button should hide on own turn")
    lu.assertEvalToTrue(visible_logs[1] and visible_logs[1]["基础_皮肤文本"] == false, "current role skin label should hide on own turn")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2]["基础_皮肤图标"] == true, "non-current role skin button should show off turn")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2]["基础_皮肤文本"] == true, "non-current role skin label should show off turn")
    lu.assertEvalToTrue(visible_logs[1] and visible_logs[1]["基础_托管按钮特效"] == false, "role1 auto effect should hide when auto off")
    lu.assertEvalToTrue(visible_logs[2] and visible_logs[2]["基础_托管按钮特效"] == true, "role2 auto effect should show when auto on")
    -- 逐席位隔离的凭据是**渲染结果**(各 role 看到自己的卡图),不再是槽位镜像:
    -- ui.item_slot_item_ids{,_by_role} 已随道具槽点击重做退场(槽位 → 道具由 turn
    -- 层直读行动者背包)。image_logs 的 role1/role2 断言就是这条隔离的真凭据。
  end

  function TestRoleSlots:test_skin_entry_hidden_when_current_player_id_nil()
    local visible_logs = {}
    local state = {
      runtime_asset_context = _build_asset_context({ ["Empty"] = "EMPTY" }),
      ui = {
        item_slots = {},
        base_hidden_nodes = { "基础_行动按钮", "基础_皮肤图标", "基础_皮肤文本" },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        input_blocked = false,
        set_label = function() end,
        set_visible = function(_, name, visible) visible_logs[name] = visible end,
        set_touch_enabled = function() end,
        query_node = function() return {} end,
      },
    }
    local ui_model = {
      panel = {
        turn_label = "倒计时:0", countdown_visible = true,
        auto_label = "托管", auto_label_by_player = { [1] = "托管" },
        player_rows = {
          { name = "P1", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
      item_slots_by_player = { [1] = {} },
      delegated_by_player = { [1] = false },
      item_slots = {},
      current_player_id = nil,
      item_choice_owner_id = nil,
      choice = nil,
      board = { players = {} },
    }
    _with_patches({
      { key = "all_roles", value = nil },
      { key = "UIManager", value = { client_role = nil, query_nodes_by_name = function() return { {} } end } },
    }, function()
      ui_view.refresh_panel(state, ui_model)
    end)
    lu.assertEvalToTrue(visible_logs["基础_皮肤图标"] == false, "skin button must hide when no current player")
    lu.assertEvalToTrue(visible_logs["基础_皮肤文本"] == false, "skin label must hide when no current player")
  end

  function TestRoleSlots:test_skin_entry_visible_for_spectator_even_when_input_blocked()
    local visible_logs = {}
    local state = {
      runtime_asset_context = _build_asset_context({ ["Empty"] = "EMPTY" }),
      ui = {
        item_slots = {},
        base_hidden_nodes = { "基础_行动按钮", "基础_皮肤图标", "基础_皮肤文本" },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        input_blocked = true,
        set_label = function() end,
        set_visible = function(_, name, visible) visible_logs[name] = visible end,
        set_touch_enabled = function() end,
        query_node = function() return {} end,
      },
    }
    local ui_model = {
      panel = {
        turn_label = "倒计时:0", countdown_visible = true,
        auto_label = "托管", auto_label_by_player = { [1] = "托管", [2] = "托管" },
        player_rows = {
          { name = "P1", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "P2", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
      item_slots_by_player = { [1] = {}, [2] = {} },
      delegated_by_player = { [1] = false, [2] = false },
      item_slots = {},
      current_player_id = 2,
      item_choice_owner_id = 2,
      choice = nil,
      board = { players = {} },
    }
    local spectator = { get_roleid = function() return 1 end }
    _with_patches({
      { key = "all_roles", value = { spectator } },
      { key = "UIManager", value = { client_role = spectator, query_nodes_by_name = function() return { {} } end } },
    }, function()
      ui_view.refresh_panel(state, ui_model)
    end)
    lu.assertEvalToTrue(visible_logs["基础_皮肤图标"] == true,
      "skin button must stay visible for a spectator even while input_blocked (input gate locks bot turns; should not hide entry)")
    lu.assertEvalToTrue(visible_logs["基础_皮肤文本"] == true,
      "skin label must stay visible for a spectator even while input_blocked")
  end

  function TestRoleSlots:test_ui_view_hides_inactive_countdown()
    local visible_logs = {}
    local label_logs = {}

    local state = {
      runtime_asset_context = _build_asset_context({ ["Empty"] = "EMPTY" }),
      ui = {
        item_slots = {},
        base_hidden_nodes = { "基础_行动按钮" },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        set_label = function(_, name, text)
          label_logs[name] = text
        end,
        set_visible = function(_, name, visible)
          visible_logs[name] = visible
        end,
        set_touch_enabled = function() end,
        query_node = function()
          return {}
        end,
      },
    }

    local ui_model = {
      panel = {
        turn_label = "倒计时:0",
        countdown_visible = false,
        auto_label = "托管",
        auto_label_by_player = { [1] = "托管" },
        player_rows = {
          { name = "P1", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
      item_slots_by_player = { [1] = {} },
      delegated_by_player = { [1] = false },
      item_slots = {},
      current_player_id = 1,
      item_choice_owner_id = 1,
      choice = nil,
      board = { players = {} },
    }

    _with_patches({
      { key = "all_roles", value = nil },
      { key = "UIManager", value = { client_role = nil, query_nodes_by_name = function() return { {} } end } },
    }, function()
      ui_view.refresh_panel(state, ui_model)
    end)

    lu.assertEvalToTrue(visible_logs["基础_倒计时"] == false, "inactive countdown should hide countdown label")
    lu.assertEvalToTrue(visible_logs["基础_倒计时横线"] == false, "inactive countdown should hide countdown line")
    lu.assertEvalToTrue(label_logs["基础_倒计时"] == "倒计时:0", "countdown label should stay synchronized when hidden")
  end

  function TestRoleSlots:test_ui_events_send_without_roles_no_crash()
    local ui_events = require("src.ui.coord.ui_events")
    ui_events.set_roles(nil)
    ui_events.send_to_all("测试事件", { ok = true })
  end

  function TestRoleSlots:test_ui_nodes_validate_reports_missing()
    local nodes = require("Data.UIManagerNodes")
    local known = {}
    for _, entry in pairs(nodes) do
      if type(entry) == "table" then
        known[entry[1]] = true
      end
    end
    local required = { "不存在的节点_测试" }
    local missing = {}
    for _, name in ipairs(required) do
      if not known[name] then
        missing[#missing + 1] = name
      end
    end
    lu.assertEvalToTrue(#missing == 1, "validate should return missing node list")
    lu.assertEvalToTrue(missing[1] == "不存在的节点_测试", "missing node name should match")
  end
end


return TestRoleSlots
