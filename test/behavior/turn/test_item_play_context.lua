-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
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

describe("TestItemPlayContext", function()

it("test_build_wires_default_auto_play_closures", function()
  local picks = {}
  local ctx = _auto_game(picks)

  luassert.truthy(ctx.is_computer_controlled == true, "delegated player context should be flagged")
  luassert.is_nil(ctx.by_ai, "the old by_ai alias must be gone")
  luassert.is_nil(ctx.is_auto_player, "the old is_auto_player alias must be gone")

  local target = ctx.select_target_player("item_a", { { id = 9 } })
  luassert.truthy(target and target.id == 9, "select_target_player should route to the port")
  luassert.truthy(picks.target.item_id == "item_a", "target pick should pass the item id")

  local dice = ctx.select_remote_dice(3)
  luassert.truthy(dice == 6, "select_remote_dice should route to the port")
  luassert.truthy(picks.dice == 3, "dice pick should pass the dice count")
end)

it("test_build_keeps_caller_provided_closures", function()
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
  luassert.truthy(called.target == true, "caller closure should be kept")
  luassert.truthy(called.dice == true, "caller dice closure should be kept")
end)

-- auto 玩家 + 预置函数:保留分支在 is_auto_player 守卫之后,必须进 auto 分支才测得到。
it("test_build_keeps_caller_provided_closures_for_auto_players", function()
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
  luassert.truthy(called.target == true, "caller closure should be kept for auto players")
  luassert.truthy(called.dice == true, "caller dice closure should be kept for auto players")
end)

-- nil player 兜底:守卫是 player and ... or false,player 缺失必须落 false。
it("test_build_with_nil_player_is_not_computer_controlled", function()
  local ctx = item_auto_play_context.build({
    auto_play_port = {},
  }, nil, {})

  luassert.truthy(ctx.is_computer_controlled == false, "nil player must never be flagged computer controlled")
  luassert.truthy(ctx.select_target_player == nil, "non-auto context must not wire default closures")
end)
end)
