local lu = require("luaunit")
local support = require("test.support.shared_support")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local TurnScheduler = require("src.turn.scheduler")
local phase_registry = require("src.turn.phases.registry")

local function _new_manual_game()
  return support.new_game({ ai = {}, auto_all = false })
end

local function _run_landing_turn(game, player, move_result)
  local phases = phase_registry.build_default_phases()
  phases.start = function()
    return "landing", { player = player, move_result = move_result or {} }
  end
  game.turn_runtime = TurnScheduler:new(game, phases)
  game.turn_runtime:run_turn()
end

local function _set_all_market_goods_unbuyable(game)
  for product_id in pairs(game.market_limits or {}) do
    game.market_limits[product_id] = 0
  end
end

TestLandingAutoAdvance = {}

function TestLandingAutoAdvance:test_sold_out_market_landing_skips_choice_and_continues_to_inter_turn_wait()
  local game = _new_manual_game()
  local player = game.players[1]
  local market_index = assert(support.first_tile_by_type(game.board, "market"))

  _set_all_market_goods_unbuyable(game)
  game:update_player_position(player, market_index)

  _run_landing_turn(game, player)

  lu.assertNil(game.turn.pending_choice)
  lu.assertIs(game.turn.phase, "inter_turn_wait")
  lu.assertTrue(game.turn.inter_turn_wait_active)
end

function TestLandingAutoAdvance:test_free_rent_card_on_enemy_land_is_consumed_without_waiting_for_choice()
  local game = _new_manual_game()
  local player = game.players[1]
  local owner = game.players[2]
  local land_index, land_tile = support.first_land_tile(game.board)
  local player_cash = game:player_cash(player)
  local owner_cash = game:player_cash(owner)

  game:set_tile_owner(land_tile, owner.id)
  game:set_player_property(owner, land_tile.id, true)
  inventory.add(player, { id = item_ids.free_rent })
  game:update_player_position(player, land_index)

  _run_landing_turn(game, player)

  lu.assertNil(game.turn.pending_choice)
  lu.assertIs(game.turn.phase, "inter_turn_wait")
  lu.assertIs(support.count_item(player, item_ids.free_rent), 0)
  lu.assertIs(game:player_cash(player), player_cash)
  lu.assertIs(game:player_cash(owner), owner_cash)
end

function TestLandingAutoAdvance:test_declining_strong_card_uses_free_rent_and_does_not_open_second_choice()
  local game = _new_manual_game()
  local player = game.players[1]
  local owner = game.players[2]
  local land_index, land_tile = support.first_land_tile(game.board)
  local player_cash = game:player_cash(player)
  local owner_cash = game:player_cash(owner)

  game:set_tile_owner(land_tile, owner.id)
  game:set_player_property(owner, land_tile.id, true)
  inventory.add(player, { id = item_ids.strong })
  inventory.add(player, { id = item_ids.free_rent })
  game:update_player_position(player, land_index)

  _run_landing_turn(game, player)

  local strong_choice = assert(game.turn.pending_choice, "strong card prompt should open first")
  lu.assertIs(strong_choice.kind, "rent_card_prompt")
  lu.assertIs(strong_choice.meta.card_kind, "strong")

  game:dispatch_action({
    type = "choice_cancel",
    choice_id = strong_choice.id,
    actor_role_id = player.id,
  })

  lu.assertNil(game.turn.pending_choice)
  lu.assertIs(game.turn.phase, "inter_turn_wait")
  lu.assertIs(support.count_item(player, item_ids.strong), 1)
  lu.assertIs(support.count_item(player, item_ids.free_rent), 0)
  lu.assertIs(game:player_cash(player), player_cash)
  lu.assertIs(game:player_cash(owner), owner_cash)
end

function TestLandingAutoAdvance:test_accepting_strong_card_prompt_executes_the_selected_card()
  local game = _new_manual_game()
  local player = game.players[1]
  local owner = game.players[2]
  local land_index, land_tile = support.first_land_tile(game.board)

  game:set_tile_owner(land_tile, owner.id)
  game:set_player_property(owner, land_tile.id, true)
  inventory.add(player, { id = item_ids.strong })
  game:update_player_position(player, land_index)

  _run_landing_turn(game, player)

  local strong_choice = assert(game.turn.pending_choice, "strong card prompt should open first")
  lu.assertIs(strong_choice.meta.card_kind, "strong")

  game:dispatch_action({
    type = "choice_select",
    choice_id = strong_choice.id,
    option_id = "use",
    actor_role_id = player.id,
  })

  lu.assertNil(game.turn.pending_choice)
  lu.assertIs(support.count_item(player, item_ids.strong), 0, "接受提示应消耗强征卡")
  lu.assertIs(support.tile_state(game, land_tile).owner_id, player.id, "强征应把地块转到出牌者名下")
end

function TestLandingAutoAdvance:test_unknown_rent_card_kind_falls_through_to_paying_rent()
  local game = _new_manual_game()
  local player = game.players[1]
  local owner = game.players[2]
  local land_index, land_tile = support.first_land_tile(game.board)

  game:set_tile_owner(land_tile, owner.id)
  game:set_player_property(owner, land_tile.id, true)
  inventory.add(player, { id = item_ids.strong })
  game:update_player_position(player, land_index)

  _run_landing_turn(game, player)

  local strong_choice = assert(game.turn.pending_choice, "strong card prompt should open first")
  -- 把 card_kind 改成登记表里没有的值:选择器应落到「不执行任何卡」的分支,
  -- 再顺着无卡兜底走到正常付租。
  strong_choice.meta.card_kind = "spec_unknown_card"
  local player_cash = game:player_cash(player)
  local owner_cash = game:player_cash(owner)

  game:dispatch_action({
    type = "choice_select",
    choice_id = strong_choice.id,
    option_id = "use",
    actor_role_id = player.id,
  })

  lu.assertNil(game.turn.pending_choice)
  lu.assertIs(support.count_item(player, item_ids.strong), 1, "未知卡种不应消耗手牌")
  lu.assertIs(support.tile_state(game, land_tile).owner_id, owner.id, "未知卡种不应转移地权")
  lu.assertTrue(game:player_cash(player) < player_cash, "未知卡种应回落到正常付租")
  lu.assertTrue(game:player_cash(owner) > owner_cash, "地主应收到租金")
end


return TestLandingAutoAdvance
