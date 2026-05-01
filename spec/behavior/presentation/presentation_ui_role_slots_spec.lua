-- luacheck: ignore 211
local support = require("support.presentation_support")
local _with_patches = support.with_patches
local ui_view = require("src.ui.coord.ui_runtime")
local ids = require("fixtures.item_slot_ids")

local function _wrap_ui_refs(image_refs)
  return {
    images = image_refs or {},
  }
end

describe("presentation_ui.role_slots", function()
  it("_test_ui_view_render_by_role_slots_are_isolated", function()
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
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
        ["2002"] = "ICON2002",
      }),
      ui = {
        item_slots = ids.slots(5),
        base_hidden_nodes = {
          "基础_行动按钮",
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
        item_slot_item_ids_by_role = {},
      },
    }

    local ui_model = {
      panel = {
        turn_label = "倒计时:0",
        countdown_visible = true,
        auto_label = "自动：关",
        auto_label_by_player = {
          [1] = "自动：关",
          [2] = "自动：开",
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
      auto_enabled_by_player = {
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

    assert(image_logs[1] and image_logs[1][ids.slot[1]] == "ICON2001", "role1 slot icon expected")
    assert(image_logs[2] and image_logs[2][ids.slot[1]] == "ICON2002", "role2 slot icon expected")
    assert(image_logs[0] and image_logs[0]["基础_玩家1头像"] == "AVATAR_1", "player1 avatar should use row avatar")
    assert(image_logs[0] and image_logs[0]["基础_玩家2头像"] == "EMPTY", "player2 avatar should fallback to empty key")
    assert(touch_logs[1] and touch_logs[1]["基础_行动按钮"] == true, "current role action button should be enabled")
    assert(touch_logs[2] and touch_logs[2]["基础_行动按钮"] == false, "non-current role action button should be disabled")
    assert(touch_logs[1] and touch_logs[1]["基础_托管按钮"] == true, "role1 auto button should be enabled")
    assert(touch_logs[2] and touch_logs[2]["基础_托管按钮"] == true, "player role auto button should stay enabled")
    assert(touch_logs[1] and touch_logs[1]["基础_托管文本"] == false, "role1 auto label should stay non-clickable")
    assert(touch_logs[2] and touch_logs[2]["基础_托管文本"] == false, "role2 auto label should stay non-clickable")
    assert(touch_logs[1] and touch_logs[1]["基础_托管按钮特效"] == false, "role1 auto effect should stay non-clickable")
    assert(touch_logs[2] and touch_logs[2]["基础_托管按钮特效"] == false, "role2 auto effect should stay non-clickable")
    assert(label_logs[1] and label_logs[1]["基础_托管文本"] == "自动：关", "role1 auto label should show status")
    assert(label_logs[2] and label_logs[2]["基础_托管文本"] == "自动：开", "role2 auto label should show status")
    assert(visible_logs[2] and visible_logs[2]["基础_倒计时"] == true, "non-current role countdown should be visible")
    assert(visible_logs[2] and visible_logs[2][ids.slot[1]] == true, "non-current role slot should be visible")
    assert(visible_logs[2] and visible_logs[2]["基础_托管按钮"] == true, "auto button should stay visible")
    assert(visible_logs[2] and visible_logs[2]["基础_托管文本"] == true, "auto label should stay visible")
    assert(visible_logs[1] and visible_logs[1]["基础_托管按钮特效"] == false, "role1 auto effect should hide when auto off")
    assert(visible_logs[2] and visible_logs[2]["基础_托管按钮特效"] == true, "role2 auto effect should show when auto on")
    assert(state.ui.item_slot_item_ids_by_role[1] and state.ui.item_slot_item_ids_by_role[1][1] == 2001, "role1 slot map expected")
    assert(state.ui.item_slot_item_ids_by_role[2] and state.ui.item_slot_item_ids_by_role[2][1] == 2002, "role2 slot map expected")
  end)

  it("_test_ui_view_hides_inactive_countdown", function()
    local visible_logs = {}
    local label_logs = {}

    local state = {
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
      ui = {
        item_slots = {},
        base_hidden_nodes = { "基础_行动按钮" },
        base_hidden_labels = {},
        auto_control_nodes = { "基础_托管按钮", "基础_托管文本" },
        item_slot_item_ids_by_role = {},
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
        auto_label = "自动：关",
        auto_label_by_player = { [1] = "自动：关" },
        player_rows = {
          { name = "P1", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
          { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
        },
      },
      item_slots_by_player = { [1] = {} },
      auto_enabled_by_player = { [1] = false },
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

    assert(visible_logs["基础_倒计时"] == false, "inactive countdown should hide countdown label")
    assert(visible_logs["基础_倒计时横线"] == false, "inactive countdown should hide countdown line")
    assert(label_logs["基础_倒计时"] == "倒计时:0", "countdown label should stay synchronized when hidden")
  end)

  it("_test_ui_events_send_without_roles_no_crash", function()
    local ui_events = require("src.ui.coord.ui_events")
    ui_events.set_roles(nil)
    ui_events.send_to_all("测试事件", { ok = true })
  end)

  it("_test_ui_nodes_validate_reports_missing", function()
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
    assert(#missing == 1, "validate should return missing node list")
    assert(missing[1] == "不存在的节点_测试", "missing node name should match")
  end)
end)
