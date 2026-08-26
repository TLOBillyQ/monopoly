local lu = require("luaunit")
local support = require("test.support.shared_support")
local movement = require("src.rules.movement")
local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local _config_reset = require("test.support.config_reset")

local function _event_texts(game)
  local entries = game.state and game.state.event_log and game.state.event_log.entries or {}
  local texts = {}
  for i, entry in ipairs(entries) do
    texts[i] = entry.text
  end
  return texts
end

TestGameplayAngelImmunity = {}

function TestGameplayAngelImmunity:setUp()
  _config_reset.reset_all()
end

function TestGameplayAngelImmunity:test_roadblock_angel_still_stops_and_consumes_roadblock()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  game:set_player_deity(player, "angel")
  game.board:place_roadblock(2)

  local move_result = movement.move(game, player, 3, { branch_parity = 3, skip_market_check = true })

  lu.assertTrue(move_result.stopped_on_roadblock, "angel should still stop on roadblock")
  lu.assertFalse(game.board:has_roadblock(2), "roadblock should be consumed for angel")
  lu.assertEquals(player.position, 2, "angel should stop on the roadblock tile")
end

function TestGameplayAngelImmunity:test_roadblock_non_angel_stops_and_consumes_roadblock()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  game.board:place_roadblock(2)

  local move_result = movement.move(game, player, 3, { branch_parity = 3, skip_market_check = true })

  lu.assertTrue(move_result.stopped_on_roadblock, "non-angel should stop on roadblock")
  lu.assertFalse(game.board:has_roadblock(2), "roadblock should be consumed for non-angel")
  lu.assertEquals(player.position, 2, "non-angel should stop on the roadblock tile")
end

function TestGameplayAngelImmunity:test_share_wealth_angel_blocks_effect_and_emits_immunity_event()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local user = game.players[1]
  local target = game.players[2]
  game:set_player_cash(user, 1000)
  game:set_player_cash(target, 3000)
  game:set_player_deity(target, "angel")

  local before_user = game:player_cash(user)
  local before_target = game:player_cash(target)

  local result = post_effects.apply_target(game, user, item_ids.share_wealth, target, {})

  lu.assertTrue(result, "share_wealth should still consume the card")
  lu.assertEquals(game:player_cash(user), before_user, "angel should keep user cash unchanged")
  lu.assertEquals(game:player_cash(target), before_target, "angel should keep target cash unchanged")

  local texts = _event_texts(game)
  lu.assertEvalToTrue(#texts > 0 and texts[#texts] == "P2 天使保护，均富无效", "item_immune event should be emitted")
end

function TestGameplayAngelImmunity:test_share_wealth_non_angel_shares_wealth_normally()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local user = game.players[1]
  local target = game.players[2]
  game:set_player_cash(user, 1000)
  game:set_player_cash(target, 3000)

  local result = post_effects.apply_target(game, user, item_ids.share_wealth, target, {})

  lu.assertTrue(result, "share_wealth should resolve normally")
  lu.assertEquals(game:player_cash(user), 2000, "wealth should be equalized")
  lu.assertEquals(game:player_cash(target), 2000, "wealth should be equalized")

  local texts = _event_texts(game)
  lu.assertNotEquals(texts[#texts], "P2 天使保护，均富无效", "non-angel should not emit immunity event")
end

function TestGameplayAngelImmunity:test_exile_angel_blocks_effect_and_emits_immunity_event()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local user = game.players[1]
  local target = game.players[2]
  local mountain_idx = assert(game.board:find_first_by_type("mountain"), "mountain tile should exist")
  target.position = 1
  game:set_player_deity(target, "angel")

  local before_position = target.position
  local result = post_effects.apply_target(game, user, item_ids.exile, target, {})

  lu.assertTrue(result, "exile should still consume the card")
  lu.assertEquals(target.position, before_position, "angel should not be relocated")

  local texts = _event_texts(game)
  lu.assertEvalToTrue(#texts > 0 and texts[#texts] == "P2 天使保护，流放无效", "item_immune event should be emitted")
  lu.assertEquals(game.board:find_first_by_type("mountain"), mountain_idx, "mountain tile should remain available")
end

function TestGameplayAngelImmunity:test_exile_non_angel_relocates_normally()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local user = game.players[1]
  local target = game.players[2]
  local mountain_idx = assert(game.board:find_first_by_type("mountain"), "mountain tile should exist")
  target.position = 1

  local result = post_effects.apply_target(game, user, item_ids.exile, target, {})

  lu.assertTrue(result, "exile should resolve normally")
  lu.assertEquals(target.position, mountain_idx, "non-angel should be moved to mountain")
end


return TestGameplayAngelImmunity
