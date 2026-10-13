require("test.bootstrap").install_package_paths()
local luassert = assert
local support = require("test.support.shared_support")
local composition_root = require("src.app.compose_game")

describe("TestComposeGame", function()

local function _test_exposes_only_new_game()
  local exported_key
  local exported_count = 0
  for key in pairs(composition_root) do
    exported_count = exported_count + 1
    exported_key = key
  end
  luassert.is.equal(1, exported_count, "composition root must expose exactly one entrypoint")
  luassert.is.equal("new_game", exported_key, "composition root must only expose game creation")
end

local function _test_rejects_player_mixin_collision_during_module_assembly()
  support.with_patches({
    { target = package.loaded, key = "src.app.compose_game", value = nil },
    {
      target = package.loaded,
      key = "src.state.game_state",
      value = { shared_key = function() end },
    },
    {
      target = package.loaded,
      key = "src.player.actions.status",
      value = { shared_key = function() end },
    },
  }, function()
    local ok, err = pcall(require, "src.app.compose_game")
    luassert.is_false(ok, "duplicate player mixin key must fail module assembly")
    luassert.matches("compose_game mixin collision: status_ops.shared_key", tostring(err), 1, true)
  end, {
    skip_runtime_context_refresh = true,
  })
end

local function _test_new_game_applies_game_defaults()
  local game_state = require("src.state.game_state")
  local game = support.new_game()
  luassert.is_not.same(game_state, game, "new_game returns an instance, not the class")
  local player_count = 0
  for _ in pairs(game.player_by_id) do
    player_count = player_count + 1
  end
  luassert.is.equal(#game.players, player_count, "player_by_id indexes all players")
  luassert.is.equal(0, game._land_rent_version, "land rent version defaults to zero")
  luassert.is.equal("function", type(game.tile_owner_notifier.notify_owner_changed))
  luassert.is_false(game.board_visual_feedback_port.sync_many())
  luassert.is.equal("table", type(game.intent_output_port))
end

local function _test_new_game_installs_default_ports_for_a_fresh_class()
  local fake_class = {
    __name = "FakeGame",
    new = function()
      return { rebuild = function() end }
    end,
  }
  local opts = require("src.turn.output.default_ports").resolve_game_opts({
    players = { "P1", "P2" },
    map = require("src.config.content.default_map"),
    tiles = require("src.config.content.tiles"),
  })
  local game = composition_root.new_game(opts, fake_class)
  luassert.is.equal("table", type(game.intent_output_port))
  luassert.is_false(game.board_visual_feedback_port.sync_many())
  luassert.is.equal("function", type(game.tile_owner_notifier.notify_owner_changed))
end

it("test_exposes_only_new_game", _test_exposes_only_new_game)
it("test_rejects_player_mixin_collision_during_module_assembly", _test_rejects_player_mixin_collision_during_module_assembly)
it("test_new_game_applies_game_defaults", _test_new_game_applies_game_defaults)
it("test_new_game_installs_default_ports_for_a_fresh_class", _test_new_game_installs_default_ports_for_a_fresh_class)
end)
