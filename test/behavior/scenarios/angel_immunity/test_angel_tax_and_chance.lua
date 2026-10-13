require("test.bootstrap").install_package_paths()
-- busted injects luassert fields on assert.
-- luacheck: ignore 143
local luassert = assert
local function _assert_equal(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local support = require("test.support.shared_support")
local chance_resolver = require("src.rules.chance.resolver")
local chance_cfg = require("src.config.content.chance_cards")
local _config_reset = require("test.support.config_reset")

describe("TestAngelTaxAndChanceImmunity", function()
  before_each(function()
    _config_reset.reset_all()
  end)

local function _test_angel_does_not_block_tax_office_landing_effect()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  local tax_idx = support.first_tile_by_type(game.board, "tax")
  player.position = tax_idx
  game:set_player_cash(player, 10000)
  game:set_player_deity(player, "angel")

  local tile = game.board:get_tile(tax_idx)
  support.resolve_landing(game, player, tile, {})

  luassert.truthy(game:player_cash(player) < 10000,
    "angel should still pay tax office fee")
end

local function _test_non_angel_pays_tax_normally()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  local tax_idx = support.first_tile_by_type(game.board, "tax")
  player.position = tax_idx
  game:set_player_cash(player, 10000)

  local tile = game.board:get_tile(tax_idx)
  support.resolve_landing(game, player, tile, {})

  luassert.truthy(game:player_cash(player) < 10000,
    "non-angel should pay tax")
end

local function _test_resolver_blocks_negative_chance_card_for_angel_drawer()
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
  luassert.is_not_nil(card, "should find a negative pay_cash self card")

  game:set_player_cash(player, 20000)
  local result = chance_resolver.resolve(game, player, card, {})
  luassert.is_nil(result, "resolver should return nil for angel + negative card")
  _assert_equal(game:player_cash(player), 20000,
    "angel drawer's cash should be unchanged")
end

local function _test_target_all_pay_cash_skips_angel_protected_players()
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
  luassert.is_not_nil(card, "should find a negative pay_cash all card")

  chance_resolver.resolve(game, drawer, card, {})

  _assert_equal(game:player_cash(angel_player), 20000,
    "angel player should not pay: expected 20000, got " .. tostring(game:player_cash(angel_player)))
  luassert.truthy(game:player_cash(normal_player) < 20000,
    "non-angel player should pay")
end

local function _test_target_all_percent_pay_cash_skips_angel_protected_players()
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
  luassert.is_not_nil(card, "should find a negative percent_pay_cash all card")

  chance_resolver.resolve(game, drawer, card, {})

  _assert_equal(game:player_cash(angel_player), 20000,
    "angel player should not pay: expected 20000, got " .. tostring(game:player_cash(angel_player)))
  luassert.truthy(game:player_cash(normal_player) < 20000,
    "non-angel player should pay percentage")
end


it("test_angel_does_not_block_tax_office_landing_effect", _test_angel_does_not_block_tax_office_landing_effect)
it("test_non_angel_pays_tax_normally", _test_non_angel_pays_tax_normally)
it("test_resolver_blocks_negative_chance_card_for_angel_drawer", _test_resolver_blocks_negative_chance_card_for_angel_drawer)
it("test_target_all_pay_cash_skips_angel_protected_players", _test_target_all_pay_cash_skips_angel_protected_players)
it("test_target_all_percent_pay_cash_skips_angel_protected_players", _test_target_all_percent_pay_cash_skips_angel_protected_players)
end)
