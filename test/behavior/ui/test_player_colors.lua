local lu = require("luaunit")
local player_colors = require("src.ui.view.player_colors")
local assets = require("src.ui.render.support.assets")
local runtime = require("src.ui.render.support.runtime_ui")
local base_nodes = require("src.ui.schema.base")
local node_ops = require("src.ui.render.support.node_ops")
local permanent_nodes = require("src.ui.schema.permanent")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, (msg or "") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

TestPlayerColors = {}

function TestPlayerColors:test_remap_by_index_integer_ids()
  player_colors.remap_by_index({
    { id = 1 }, { id = 2 }, { id = 3 }, { id = 4 },
  })
  _assert_eq(player_colors.resolve_owner_color(1), 0xe57373, "player 1 should be red")
  _assert_eq(player_colors.resolve_owner_color(2), 0xffeb3b, "player 2 should be yellow")
  _assert_eq(player_colors.resolve_owner_color(3), 0x4fc3f7, "player 3 should be blue")
  _assert_eq(player_colors.resolve_owner_color(4), 0xba68c8, "player 4 should be purple")
  _assert_eq(player_colors.resolve_owner_color(999), 0xcfcfcf, "unknown id returns default")
end

function TestPlayerColors:test_remap_by_index_role_ids()
  player_colors.remap_by_index({
    { id = "role_abc" }, { id = "role_def" }, { id = 9999 },
  })
  _assert_eq(player_colors.resolve_owner_color("role_abc"), 0xe57373, "role_abc should be red (index 1)")
  _assert_eq(player_colors.resolve_owner_color("role_def"), 0xffeb3b, "role_def should be yellow (index 2)")
  _assert_eq(player_colors.resolve_owner_color(9999), 0x4fc3f7, "9999 should be blue (index 3)")
  _assert_eq(player_colors.resolve_owner_color(1), 0xcfcfcf, "integer 1 should no longer match")
end

function TestPlayerColors:test_remap_by_index_caps_at_4()
  player_colors.remap_by_index({
    { id = "a" }, { id = "b" }, { id = "c" }, { id = "d" }, { id = "e" },
  })
  _assert_eq(player_colors.resolve_owner_color("d"), 0xba68c8, "4th player should be purple")
  _assert_eq(player_colors.resolve_owner_color("e"), 0xcfcfcf, "5th player has no color")
end

function TestPlayerColors:test_remap_by_index_nil_safe()
  player_colors.remap_by_index(nil)
  player_colors.remap_by_index({})
  _assert_eq(player_colors.resolve_owner_color(1), 0xcfcfcf, "empty remap returns default")
end

function TestPlayerColors:test_remap_by_index_tolerates_nil_entries_in_players()
  -- 杀 L24 位点1 and->or:players 数组含 nil 条目时变异体求值 nil.id 报错。
  local ok = pcall(player_colors.remap_by_index, { nil })
  _assert_eq(ok, true, "nil entries in players must not crash the remap")
end

function TestPlayerColors:test_capture_player_colors_prefers_base_panel_colors()
  local captured = nil
  local fallback_calls = 0
  local sampled = {
    [1] = 0xaa1100,
    [2] = 0x00aa11,
    [3] = 0x0011aa,
    [4] = 0xaa00aa,
  }

  _with_patches({
    { target = runtime, key = "with_client_role", value = function(_, fn) fn() end },
    { target = runtime, key = "set_client_role", value = function() end },
    { target = runtime, key = "query_node", value = function(name)
      for index = 1, 4 do
        if name == string.format(base_nodes.player_color, index) then
          return { image_color = sampled[index] }
        end
      end
      error("unexpected node: " .. tostring(name))
    end },
    { target = player_colors, key = "set_owner_colors", value = function(colors)
      captured = colors
    end },
    { target = player_colors, key = "remap_by_index", value = function()
      fallback_calls = fallback_calls + 1
    end },
  }, function()
    assets.capture_player_colors({}, {
      players = {
        { id = "p1" },
        { id = "p2" },
        { id = "p3" },
        { id = "p4" },
      },
    })
  end)

  lu.assertEvalToTrue(captured ~= nil, "capture should set owner colors from base panel")
  _assert_eq(captured["p1"], sampled[1], "p1 should use base panel color #1")
  _assert_eq(captured["p2"], sampled[2], "p2 should use base panel color #2")
  _assert_eq(captured["p3"], sampled[3], "p3 should use base panel color #3")
  _assert_eq(captured["p4"], sampled[4], "p4 should use base panel color #4")
  _assert_eq(fallback_calls, 0, "capture should not fallback when sampled colors are valid")
end

function TestPlayerColors:test_capture_player_colors_fallbacks_on_invalid_sample()
  local captured = nil
  local fallback_calls = 0

  _with_patches({
    { target = runtime, key = "with_client_role", value = function(_, fn) fn() end },
    { target = runtime, key = "set_client_role", value = function() end },
    { target = runtime, key = "query_node", value = function(name)
      for index = 1, 4 do
        if name == string.format(base_nodes.player_color, index) then
          return { image_color = 0xffffff }
        end
      end
      error("unexpected node: " .. tostring(name))
    end },
    { target = player_colors, key = "set_owner_colors", value = function(colors)
      captured = colors
    end },
    { target = player_colors, key = "remap_by_index", value = function()
      fallback_calls = fallback_calls + 1
    end },
  }, function()
    assets.capture_player_colors({}, {
      players = {
        { id = "p1" },
        { id = "p2" },
        { id = "p3" },
        { id = "p4" },
      },
    })
  end)

  _assert_eq(captured, nil, "invalid sampled colors should not be used as source")
  _assert_eq(fallback_calls, 1, "invalid sampled colors should fallback to remap_by_index")
end

function TestPlayerColors:test_set_owner_colors_copies_supplied_owner_colors_and_defaults_missing_owners()
  player_colors.set_owner_colors("invalid")
  player_colors.set_owner_colors({
    p1 = 101,
    p2 = 202,
  })

  _assert_eq(player_colors.resolve_owner_color("p1"), 101, "setter should keep p1 color")
  _assert_eq(player_colors.resolve_owner_color("p2"), 202, "setter should keep p2 color")
  _assert_eq(player_colors.resolve_owner_color("missing"), 0xcfcfcf, "missing owner should use default")
end

function TestPlayerColors:test_assets_init_assigns_all_configured_item_slot_icons()
  local slot_images = {}
  local role_iterations = 0
  local state = {}

  _with_patches({
    { target = runtime, key = "for_each_role_or_global", value = function(fn)
      role_iterations = role_iterations + 1
      fn(nil)
    end },
    { target = runtime, key = "set_client_role", value = function(role)
      _assert_eq(role, nil, "asset init should reset client role")
    end },
    { target = node_ops, key = "set_item_slot_image", value = function(node_name, image_key)
      slot_images[#slot_images + 1] = {
        node_name = node_name,
        image_key = image_key,
      }
    end },
  }, function()
    assets.init_ui_assets(state)
  end)

  _assert_eq(role_iterations, 1, "asset init should run for global role scope")
  _assert_eq(#slot_images, 5, "asset init should set five item slot images")
  _assert_eq(slot_images[1].node_name, permanent_nodes.item_slots[1], "first slot node should match schema")
  lu.assertEvalToTrue(state.runtime_asset_context ~= nil, "asset init should store the resolver context on state")
end


return TestPlayerColors
