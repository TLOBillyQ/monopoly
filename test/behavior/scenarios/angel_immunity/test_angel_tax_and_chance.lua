local lu = require("luaunit")
local support = require("test.support.shared_support")
local chance_resolver = require("src.rules.chance.resolver")
local chance_cfg = require("src.config.content.chance_cards")
local _config_reset = require("test.support.config_reset")

TestAngelTaxAndChanceImmunity = {}

function TestAngelTaxAndChanceImmunity:setUp()
  _config_reset.reset_all()
end

function TestAngelTaxAndChanceImmunity:test_angel_does_not_block_tax_office_landing_effect()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  local tax_idx = support.first_tile_by_type(game.board, "tax")
  player.position = tax_idx
  game:set_player_cash(player, 10000)
  game:set_player_deity(player, "angel")

  local tile = game.board:get_tile(tax_idx)
  support.resolve_landing(game, player, tile, {})

  lu.assertEvalToTrue(game:player_cash(player) < 10000,
    "angel should still pay tax office fee")
end

function TestAngelTaxAndChanceImmunity:test_non_angel_pays_tax_normally()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  local tax_idx = support.first_tile_by_type(game.board, "tax")
  player.position = tax_idx
  game:set_player_cash(player, 10000)

  local tile = game.board:get_tile(tax_idx)
  support.resolve_landing(game, player, tile, {})

  lu.assertEvalToTrue(game:player_cash(player) < 10000,
    "non-angel should pay tax")
end

function TestAngelTaxAndChanceImmunity:test_resolver_blocks_negative_chance_card_for_angel_drawer()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  game:set_player_deity(player, "angel")

  local card = nil
  for _, c in ipairs(chance_cfg) do
    if c.negative and c.effect == "pay_cash" and c.target == "self" then
      card = c
      break
    end
  end
  lu.assertNotNil(card, "should find a negative pay_cash self card")

  game:set_player_cash(player, 20000)
  local result = chance_resolver.resolve(game, player, card, {})
  lu.assertNil(result, "resolver should return nil for angel + negative card")
  lu.assertEquals(game:player_cash(player), 20000,
    "angel drawer's cash should be unchanged")
end

function TestAngelTaxAndChanceImmunity:test_target_all_pay_cash_skips_angel_protected_players()
  local game = support.new_game({ players = { "P1", "P2", "P3" }, auto_all = true })
  local drawer = game.players[1]
  local angel_player = game.players[2]
  local normal_player = game.players[3]
  game:set_player_cash(drawer, 20000)
  game:set_player_cash(angel_player, 20000)
  game:set_player_cash(normal_player, 20000)
  game:set_player_deity(angel_player, "angel")

  local card = nil
  for _, c in ipairs(chance_cfg) do
    if c.negative and c.effect == "pay_cash" and c.target == "all" then
      card = c
      break
    end
  end
  lu.assertNotNil(card, "should find a negative pay_cash all card")

  chance_resolver.resolve(game, drawer, card, {})

  lu.assertEquals(game:player_cash(angel_player), 20000,
    "angel player should not pay: expected 20000, got " .. tostring(game:player_cash(angel_player)))
  lu.assertEvalToTrue(game:player_cash(normal_player) < 20000,
    "non-angel player should pay")
end

function TestAngelTaxAndChanceImmunity:test_target_all_percent_pay_cash_skips_angel_protected_players()
  local game = support.new_game({ players = { "P1", "P2", "P3" }, auto_all = true })
  local drawer = game.players[1]
  local angel_player = game.players[2]
  local normal_player = game.players[3]
  game:set_player_cash(drawer, 20000)
  game:set_player_cash(angel_player, 20000)
  game:set_player_cash(normal_player, 20000)
  game:set_player_deity(angel_player, "angel")

  local card = nil
  for _, c in ipairs(chance_cfg) do
    if c.negative and c.effect == "percent_pay_cash" and c.target == "all" then
      card = c
      break
    end
  end
  lu.assertNotNil(card, "should find a negative percent_pay_cash all card")

  chance_resolver.resolve(game, drawer, card, {})

  lu.assertEquals(game:player_cash(angel_player), 20000,
    "angel player should not pay: expected 20000, got " .. tostring(game:player_cash(angel_player)))
  lu.assertEvalToTrue(game:player_cash(normal_player) < 20000,
    "non-angel player should pay percentage")
end


return TestAngelTaxAndChanceImmunity
