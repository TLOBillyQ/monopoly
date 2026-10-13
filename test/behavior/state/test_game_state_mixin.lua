require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("test.support.shared_support")
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end
local with_patches = support.with_patches

local function _clear_module(module_name)
  package.loaded[module_name] = nil
end

local function _with_game_state_mixins(player_mixin, board_mixin, turn_mixin, fn)
  with_patches({
    { target = package.loaded, key = "src.state.player_state", value = player_mixin },
    { target = package.loaded, key = "src.state.board_state", value = board_mixin },
    { target = package.loaded, key = "src.state.turn_state", value = turn_mixin },
    { target = package.loaded, key = "src.state.game_state", value = nil },
  }, function()
    _clear_module("src.state.game_state")
    fn()
    _clear_module("src.state.game_state")
  end, {
    skip_runtime_context_refresh = true,
  })
end

describe("TestGameStateMixin", function()

  it("test_installs_distinct_mixins", function()
    _with_game_state_mixins({
      player_only = function()
        return "player"
      end,
    }, {
      board_only = function()
        return "board"
      end,
    }, {
      turn_only = function()
        return "turn"
      end,
    }, function()
      local game_state = require("src.state.game_state")
      luassert.truthy(type(game_state.player_only) == "function", "player mixin should install")
      luassert.truthy(type(game_state.board_only) == "function", "board mixin should install")
      luassert.truthy(type(game_state.turn_only) == "function", "turn mixin should install")
    end)
  end)

  it("test_rejects_mixin_key_collision", function()
    _with_game_state_mixins({
      shared_key = function()
        return "player"
      end,
    }, {
      shared_key = function()
        return "board"
      end,
    }, {}, function()
      local ok, err = pcall(require, "src.state.game_state")
      _assert_eq(ok, false, "duplicate mixin key should fail module assembly")
      luassert.truthy(string.find(tostring(err), "game_state mixin collision: board.shared_key", 1, true) ~= nil, "collision error should include conflicting mixin key, err=" .. tostring(err))
    end)
  end)


end)
