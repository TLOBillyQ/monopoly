local lu = require("luaunit")
local support = require("test.support.shared_support")
local composition_root = require("src.app.compose_game")

TestComposeGame = {}

function TestComposeGame:test_exposes_only_new_game()
  local exported_key
  local exported_count = 0
  for key in pairs(composition_root) do
    exported_count = exported_count + 1
    exported_key = key
  end
  lu.assertEquals(exported_count, 1, "composition root must expose exactly one entrypoint")
  lu.assertEquals(exported_key, "new_game", "composition root must only expose game creation")
end

function TestComposeGame:test_rejects_player_mixin_collision_during_module_assembly()
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
    lu.assertFalse(ok, "duplicate player mixin key must fail module assembly")
    lu.assertStrContains(tostring(err), "compose_game mixin collision: status_ops.shared_key")
  end, {
    skip_runtime_context_refresh = true,
  })
end

function TestComposeGame:test_new_game_applies_game_defaults()
  local game_state = require("src.state.game_state")
  local game = support.new_game()
  lu.assertNotEquals(game, game_state, "new_game returns an instance, not the class")
  local player_count = 0
  for _ in pairs(game.player_by_id) do
    player_count = player_count + 1
  end
  lu.assertEquals(player_count, #game.players, "player_by_id indexes all players")
  lu.assertEquals(game._land_rent_version, 0, "land rent version defaults to zero")
  lu.assertEquals(type(game.tile_owner_notifier.notify_owner_changed), "function")
  lu.assertFalse(game.board_visual_feedback_port.sync_many())
  lu.assertEquals(type(game.intent_output_port), "table")
end

function TestComposeGame:test_new_game_installs_default_ports_for_a_fresh_class()
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
  lu.assertEquals(type(game.intent_output_port), "table")
  lu.assertFalse(game.board_visual_feedback_port.sync_many())
  lu.assertEquals(type(game.tile_owner_notifier.notify_owner_changed), "function")
end

return TestComposeGame
