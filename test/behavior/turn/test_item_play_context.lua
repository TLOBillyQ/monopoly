local lu = require("luaunit")
local item_auto_play_context = require("src.turn.policies.item_play_context")
local control = require("src.player.control")

local function _auto_game(picks)
  local player = { id = 1 }
  control.initialize(player)
  control.toggle_manual_delegation(player)
  local game = {
    auto_play_port = {
      pick_target_player = function(_, _, item_id, candidates)
        picks.target = { item_id = item_id, candidates = candidates }
        return candidates[1]
      end,
      pick_remote_dice_value = function(_, _, dice_count)
        picks.dice = dice_count
        return 6
      end,
    },
  }
  return item_auto_play_context.build(game, player, {})
end

TestItemPlayContext = {}

function TestItemPlayContext:test_build_wires_default_auto_play_closures()
  local picks = {}
  local ctx = _auto_game(picks)

  lu.assertEvalToTrue(ctx.is_computer_controlled == true, "delegated player context should be flagged")
  lu.assertIsNil(ctx.by_ai, "the old by_ai alias must be gone")
  lu.assertIsNil(ctx.is_auto_player, "the old is_auto_player alias must be gone")

  local target = ctx.select_target_player("item_a", { { id = 9 } })
  lu.assertEvalToTrue(target and target.id == 9, "select_target_player should route to the port")
  lu.assertEvalToTrue(picks.target.item_id == "item_a", "target pick should pass the item id")

  local dice = ctx.select_remote_dice(3)
  lu.assertEvalToTrue(dice == 6, "select_remote_dice should route to the port")
  lu.assertEvalToTrue(picks.dice == 3, "dice pick should pass the dice count")
end

function TestItemPlayContext:test_build_keeps_caller_provided_closures()
  local called = {}
  local player = { id = 1 }
  control.initialize(player)
  local ctx = item_auto_play_context.build({
    auto_play_port = {},
  }, player, {
    select_target_player = function()
      called.target = true
      return nil
    end,
    select_remote_dice = function()
      called.dice = true
      return nil
    end,
  })

  ctx.select_target_player()
  ctx.select_remote_dice()
  lu.assertEvalToTrue(called.target == true, "caller closure should be kept")
  lu.assertEvalToTrue(called.dice == true, "caller dice closure should be kept")
end

-- auto 玩家 + 预置函数:保留分支在 is_auto_player 守卫之后,必须进 auto 分支才测得到。
function TestItemPlayContext:test_build_keeps_caller_provided_closures_for_auto_players()
  local called = {}
  local player = { id = 1 }
  control.initialize(player)
  control.toggle_manual_delegation(player)
  local ctx = item_auto_play_context.build({
    auto_play_port = {
      pick_target_player = function()
        return nil
      end,
      pick_remote_dice_value = function()
        return nil
      end,
    },
  }, player, {
    select_target_player = function()
      called.target = true
      return nil
    end,
    select_remote_dice = function()
      called.dice = true
      return nil
    end,
  })

  ctx.select_target_player()
  ctx.select_remote_dice()
  lu.assertEvalToTrue(called.target == true, "caller closure should be kept for auto players")
  lu.assertEvalToTrue(called.dice == true, "caller dice closure should be kept for auto players")
end

-- nil player 兜底:守卫是 player and ... or false,player 缺失必须落 false。
function TestItemPlayContext:test_build_with_nil_player_is_not_computer_controlled()
  local ctx = item_auto_play_context.build({
    auto_play_port = {},
  }, nil, {})

  lu.assertEvalToTrue(ctx.is_computer_controlled == false, "nil player must never be flagged computer controlled")
  lu.assertEvalToTrue(ctx.select_target_player == nil, "non-auto context must not wire default closures")
end


return TestItemPlayContext
