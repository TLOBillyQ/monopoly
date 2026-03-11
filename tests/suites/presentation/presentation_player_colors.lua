local player_colors = require("src.presentation.view.support.player_colors")
local assets = require("src.presentation.runtime.view.assets")
local runtime = require("src.presentation.runtime.ui")
local base_nodes = require("src.presentation.schema.canvas.base.nodes")
local support = require("support.presentation_support")
local _with_patches = support.with_patches

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, (msg or "") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local function _test_remap_by_index_integer_ids()
  player_colors.remap_by_index({
    { id = 1 }, { id = 2 }, { id = 3 }, { id = 4 },
  })
  _assert_eq(player_colors.resolve_owner_color(1), 0xe57373, "player 1 should be red")
  _assert_eq(player_colors.resolve_owner_color(2), 0xffeb3b, "player 2 should be yellow")
  _assert_eq(player_colors.resolve_owner_color(3), 0x4fc3f7, "player 3 should be blue")
  _assert_eq(player_colors.resolve_owner_color(4), 0xba68c8, "player 4 should be purple")
  _assert_eq(player_colors.resolve_owner_color(999), 0xcfcfcf, "unknown id returns default")
end

local function _test_remap_by_index_role_ids()
  player_colors.remap_by_index({
    { id = "role_abc" }, { id = "role_def" }, { id = 9999 },
  })
  _assert_eq(player_colors.resolve_owner_color("role_abc"), 0xe57373, "role_abc should be red (index 1)")
  _assert_eq(player_colors.resolve_owner_color("role_def"), 0xffeb3b, "role_def should be yellow (index 2)")
  _assert_eq(player_colors.resolve_owner_color(9999), 0x4fc3f7, "9999 should be blue (index 3)")
  _assert_eq(player_colors.resolve_owner_color(1), 0xcfcfcf, "integer 1 should no longer match")
end

local function _test_remap_by_index_caps_at_4()
  player_colors.remap_by_index({
    { id = "a" }, { id = "b" }, { id = "c" }, { id = "d" }, { id = "e" },
  })
  _assert_eq(player_colors.resolve_owner_color("d"), 0xba68c8, "4th player should be purple")
  _assert_eq(player_colors.resolve_owner_color("e"), 0xcfcfcf, "5th player has no color")
end

local function _test_remap_by_index_nil_safe()
  player_colors.remap_by_index(nil)
  player_colors.remap_by_index({})
  _assert_eq(player_colors.resolve_owner_color(1), 0xcfcfcf, "empty remap returns default")
end

local function _test_capture_player_colors_prefers_base_panel_colors()
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

  assert(captured ~= nil, "capture should set owner colors from base panel")
  _assert_eq(captured["p1"], sampled[1], "p1 should use base panel color #1")
  _assert_eq(captured["p2"], sampled[2], "p2 should use base panel color #2")
  _assert_eq(captured["p3"], sampled[3], "p3 should use base panel color #3")
  _assert_eq(captured["p4"], sampled[4], "p4 should use base panel color #4")
  _assert_eq(fallback_calls, 0, "capture should not fallback when sampled colors are valid")
end

local function _test_capture_player_colors_fallbacks_on_invalid_sample()
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

return {
  name = "presentation_player_colors",
  tests = {
    { name = "remap_by_index_integer_ids", run = _test_remap_by_index_integer_ids },
    { name = "remap_by_index_role_ids", run = _test_remap_by_index_role_ids },
    { name = "remap_by_index_caps_at_4", run = _test_remap_by_index_caps_at_4 },
    { name = "remap_by_index_nil_safe", run = _test_remap_by_index_nil_safe },
    { name = "capture_player_colors_prefers_base_panel_colors", run = _test_capture_player_colors_prefers_base_panel_colors },
    { name = "capture_player_colors_fallbacks_on_invalid_sample", run = _test_capture_player_colors_fallbacks_on_invalid_sample },
  },
}
