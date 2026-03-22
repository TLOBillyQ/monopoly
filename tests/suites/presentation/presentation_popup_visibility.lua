local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches
local runtime_port = require("src.ui.render.runtime_ui")
local ui_view = require("src.ui.ctl.ui_runtime")
local modal_presenter = require("src.ui.ctl.modal")

local _build_popup_view_state = support.build_popup_view_state
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event

local function _test_push_popup_sets_card_image_by_image_ref()
  local last_image_key = nil
  local card_node = {
    set_texture_keep_size = function(_, image_key)
      last_image_key = image_key
    end,
  }
  local state, nodes, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, card_node)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
    modal_presenter.push_popup(state, {
      title = "道具卡",
      body = "测试",
      image_ref = 2001,
    })
  end)

  _assert_eq(last_image_key, "ICON2001", "popup card should use mapped image")
  _assert_eq(nodes["卡牌展示_图片"].visible, true, "popup card should be visible when image exists")
end

local function _test_push_popup_hides_card_and_clears_image_when_missing()
  local last_image_key = nil
  local card_node = {
    set_texture_keep_size = function(_, image_key)
      last_image_key = image_key
    end,
  }
  local state, nodes, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, card_node)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
    modal_presenter.push_popup(state, {
      title = "道具卡",
      body = "测试",
      image_ref = 2001,
    })
    modal_presenter.push_popup(state, {
      title = "黑市",
      body = "测试2",
    })
  end)

  _assert_eq(last_image_key, "EMPTY", "popup card should reset to empty key when image missing")
  _assert_eq(nodes["卡牌展示_图片"].visible, false, "popup card should hide when image missing")
end

local function _test_popup_hidden_for_non_current_role()
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })
  state.ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = {}, [2] = {} },
  }
  local role1_events = {}
  local role2_events = {}
  local roles = {
    _build_role_with_events(1, role1_events),
    _build_role_with_events(2, role2_events),
  }
  _bind_ui_runtime(state)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = roles },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role.get_roleid()
    end },
  }, function()
    modal_presenter.push_popup(state, {
      title = "黑市",
      body = "测试",
    })
  end)

  assert(_has_event(role1_events, "显示卡牌展示屏"), "current role should see popup canvas")
  assert(not _has_event(role2_events, "显示卡牌展示屏"), "non-current role should not see popup canvas")
end

local function _test_popup_visible_for_all_roles_when_allowed_kind()
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })
  state.ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = {}, [2] = {} },
  }
  _bind_ui_runtime(state)
  local role1_events = {}
  local role2_events = {}
  local roles = {
    _build_role_with_events(1, role1_events),
    _build_role_with_events(2, role2_events),
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = roles },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role.get_roleid()
    end },
  }, function()
    modal_presenter.push_popup(state, {
      title = "机会卡",
      body = "测试",
      kind = "chance_card",
    })
    modal_presenter.push_popup(state, {
      title = "道具卡",
      body = "测试",
      kind = "item_card",
    })
  end)

  assert(_has_event(role1_events, "显示卡牌展示屏"), "current role should see popup canvas")
  assert(_has_event(role2_events, "显示卡牌展示屏"), "non-current role should see popup canvas")
end

local function _test_bankruptcy_popup_visible_for_all_roles()
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })
  state.ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = {}, [2] = {} },
  }
  _bind_ui_runtime(state)
  local role1_events = {}
  local role2_events = {}
  local roles = {
    _build_role_with_events(1, role1_events),
    _build_role_with_events(2, role2_events),
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = roles },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role.get_roleid()
    end },
  }, function()
    modal_presenter.push_popup(state, {
      kind = "bankruptcy",
      text = "破产测试",
    })
  end)

  assert(_has_event(role1_events, "显示破产展示屏"), "current role should see bankruptcy canvas")
  assert(_has_event(role2_events, "显示破产展示屏"), "non-current role should see bankruptcy canvas")
end

local function _test_bankruptcy_popup_avatar_uses_native_size_path()
  local native_calls = 0
  local avatar_image_key = nil
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
    { target = runtime_port, key = "set_node_texture_native_size", value = function(_, image_key)
      native_calls = native_calls + 1
      avatar_image_key = image_key
    end },
  }, function()
    modal_presenter.push_popup(state, {
      kind = "bankruptcy",
      text = "破产测试",
      avatar_key = 2002,
    })
  end)

  _assert_eq(native_calls, 1, "bankruptcy popup avatar should use native-size path")
  _assert_eq(avatar_image_key, 2002, "bankruptcy popup avatar should forward payload image key")
end

local function _test_resolve_bankruptcy_text_prefers_payload_text()
  local popup_controller = require("src.ui.ctl.popup")
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_native_size = function() end,
  })
  local captured_text = nil

  state.ui.set_label = function(_, node_name, text)
    captured_text = text
  end

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
    { target = require("src.ui.render.runtime_ui"), key = "for_each_role_or_global", value = function(fn) fn(nil) end },
  }, function()
    popup_controller.show_popup(state, {
      kind = "bankruptcy",
      text = "自定义破产文本",
    })
  end)

  _assert_eq(captured_text, "自定义破产文本", "_resolve_bankruptcy_text should prefer payload.text")
end

local function _test_resolve_bankruptcy_text_falls_back_to_reason()
  local popup_controller = require("src.ui.ctl.popup")
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_native_size = function() end,
  })
  local captured_text = nil

  state.ui.set_label = function(_, node_name, text)
    captured_text = text
  end

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
    { target = require("src.ui.render.runtime_ui"), key = "for_each_role_or_global", value = function(fn) fn(nil) end },
  }, function()
    popup_controller.show_popup(state, {
      kind = "bankruptcy",
      reason = "破产原因说明",
    })
  end)

  _assert_eq(captured_text, "破产原因说明", "_resolve_bankruptcy_text should fall back to payload.reason")
end

local function _test_resolve_bankruptcy_text_falls_back_to_player_name()
  local popup_controller = require("src.ui.ctl.popup")
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_native_size = function() end,
  })
  local captured_text = nil

  state.ui.set_label = function(_, node_name, text)
    captured_text = text
  end

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
    { target = require("src.ui.render.runtime_ui"), key = "for_each_role_or_global", value = function(fn) fn(nil) end },
  }, function()
    popup_controller.show_popup(state, {
      kind = "bankruptcy",
      player_name = "测试玩家",
    })
  end)

  _assert_eq(captured_text, "测试玩家 破产出局", "_resolve_bankruptcy_text should append 破产出局 to player_name")
end

local function _test_resolve_bankruptcy_text_uses_default_when_all_missing()
  local popup_controller = require("src.ui.ctl.popup")
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_native_size = function() end,
  })
  local captured_text = nil

  state.ui.set_label = function(_, node_name, text)
    captured_text = text
  end

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
    { target = require("src.ui.render.runtime_ui"), key = "for_each_role_or_global", value = function(fn) fn(nil) end },
  }, function()
    popup_controller.show_popup(state, {
      kind = "bankruptcy",
    })
  end)

  _assert_eq(captured_text, "破产出局", "_resolve_bankruptcy_text should return default when all fields missing")
end

return {
  name = "presentation.popup_visibility",
  tests = {
    { name = "_test_push_popup_sets_card_image_by_image_ref", run = _test_push_popup_sets_card_image_by_image_ref },
    { name = "_test_push_popup_hides_card_and_clears_image_when_missing", run = _test_push_popup_hides_card_and_clears_image_when_missing },
    { name = "_test_popup_hidden_for_non_current_role", run = _test_popup_hidden_for_non_current_role },
    { name = "_test_popup_visible_for_all_roles_when_allowed_kind", run = _test_popup_visible_for_all_roles_when_allowed_kind },
    { name = "_test_bankruptcy_popup_visible_for_all_roles", run = _test_bankruptcy_popup_visible_for_all_roles },
    { name = "_test_bankruptcy_popup_avatar_uses_native_size_path", run = _test_bankruptcy_popup_avatar_uses_native_size_path },
    { name = "_test_resolve_bankruptcy_text_prefers_payload_text", run = _test_resolve_bankruptcy_text_prefers_payload_text },
    { name = "_test_resolve_bankruptcy_text_falls_back_to_reason", run = _test_resolve_bankruptcy_text_falls_back_to_reason },
    { name = "_test_resolve_bankruptcy_text_falls_back_to_player_name", run = _test_resolve_bankruptcy_text_falls_back_to_player_name },
    { name = "_test_resolve_bankruptcy_text_uses_default_when_all_missing", run = _test_resolve_bankruptcy_text_uses_default_when_all_missing },
  },
}
