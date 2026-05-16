local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")

local endgame_steps = {}

local _ensure_player = shared.ensure_player

function endgame_steps.handlers()
  return {
    ["游戏有<p1>名玩家"] = function(world, example)
      local count = number_utils.to_integer(example.p1)
      world.game = world.game or {}
      world.game.player_count = count
      world.game.players = {}
      for i = 1, count do
        world.game.players[i] = { alive = true, cash = 10000, tile_investment = 0 }
      end
      return true
    end,

    ["<p2>名玩家已被淘汰"] = function(world, example)
      local eliminated = number_utils.to_integer(example.p2)
      for i = 1, eliminated do
        world.game.players[i].alive = false
      end
      return true
    end,

    ["胜利条件检查执行"] = function(world)
      local game = world.game or {}
      if game.ended then
        world.already_ended = true
        return true
      end

      local alive = {}
      for _, p in ipairs(game.players or {}) do
        if p.alive then
          alive[#alive + 1] = p
        end
      end

      if #alive == 1 then
        world.winner = alive[1]
        game.ended = true
        return true
      end

      if game.turn_limit and game.current_turn and game.current_turn >= game.turn_limit then
        local max_asset = -1
        local winners = {}
        for _, p in ipairs(alive) do
          local asset = (p.cash or 0) + (p.tile_investment or 0)
          if asset > max_asset then
            max_asset = asset
            winners = { p }
          elseif asset == max_asset then
            winners[#winners + 1] = p
          end
        end
        world.winners = winners
        game.ended = true
        return true
      end

      return true
    end,

    ["唯一存活玩家获胜"] = function(world)
      if not world.winner then
        return nil, "there should be exactly one winner"
      end
      return true
    end,

    ["游戏标记为已结束"] = function(world)
      if not world.game.ended then
        return nil, "game should be marked as ended"
      end
      return true
    end,

    ["回合上限为<p3>"] = function(world, example)
      local limit = number_utils.to_integer(example.p3)
      world.game = world.game or {}
      world.game.turn_limit = limit
      return true
    end,

    ["当前回合数为<p3>"] = function(world, example)
      local turn = number_utils.to_integer(example.p3)
      world.game = world.game or {}
      world.game.current_turn = turn
      return true
    end,

    ["存活玩家的总资产分别为<p4>"] = function(world, example)
      local assets = shared.parse_number_list(example.p4)
      world.game = world.game or {}
      world.game.players = {}
      for i, asset in ipairs(assets) do
        world.game.players[i] = { alive = true, cash = asset, tile_investment = 0 }
      end
      return true
    end,

    ["资产最高的玩家获胜"] = function(world)
      if not world.winners or #world.winners == 0 then
        return nil, "there should be a winner by assets"
      end
      return true
    end,

    ["回合上限到达"] = function(world)
      world.game = world.game or {}
      world.game.turn_limit = 1000
      world.game.current_turn = 1000
      return true
    end,

    ["两名玩家总资产相同且为最高"] = function(world)
      world.game = world.game or {}
      world.game.players = {
        { alive = true, cash = 50000, tile_investment = 0 },
        { alive = true, cash = 50000, tile_investment = 0 },
        { alive = true, cash = 30000, tile_investment = 0 },
      }
      return true
    end,

    ["两名玩家并列获胜"] = function(world)
      if not world.winners or #world.winners ~= 2 then
        return nil, "there should be exactly 2 tied winners"
      end
      return true
    end,

    ["玩家持有<p5>金币"] = function(world, example)
      local amount = number_utils.to_integer(example.p5)
      _ensure_player(world)
      world.player.cash = amount
      world.asset_player = world.asset_player or {}
      world.asset_player.cash = amount
      return true
    end,

    ["玩家拥有地块总投入为<p6>"] = function(world, example)
      local amount = number_utils.to_integer(example.p6)
      world.asset_player = world.asset_player or {}
      world.asset_player.tile_investment = amount
      return true
    end,

    ["计算总资产"] = function(world)
      local p = world.asset_player or {}
      world.total_asset = (p.cash or 0) + (p.tile_investment or 0)
      return true
    end,

    ["总资产为<p7>"] = function(world, example)
      local expected = number_utils.to_integer(example.p7)
      if world.total_asset ~= expected then
        return nil, "expected total asset " .. tostring(expected) .. ", got " .. tostring(world.total_asset)
      end
      return true
    end,

    ["玩家拥有3块地块"] = function(world)
      world.bankrupt_player = {
        tiles = {
          { level = 2, owner = "player" },
          { level = 1, owner = "player" },
          { level = 0, owner = "player" },
        },
        bag = { { name = "item1" } },
        deities = { angel = true },
      }
      return true
    end,

    ["玩家破产淘汰"] = function(world)
      local p = world.bankrupt_player
      if p then
        if p.tiles then
          for _, tile in ipairs(p.tiles) do
            tile.owner = nil
            tile.level = 0
          end
        end
        p.bag = {}
        p.deities = {}
        p.eliminated = true
        if p.position then
          world.vacated_cell = p.position
          p.position = nil
        end
        return true
      end
      if world.player then
        if not world.player.bankrupt then
          world.player.bankrupt = true
        end
        if world.player.owned_tiles then
          for _, tile in ipairs(world.player.owned_tiles) do
            tile.owner = nil
            tile.level = 0
          end
        end
        world.player.bag = {}
        world.player.deities = {}
      end
      return true
    end,

    ["玩家的所有地块重置为无主"] = function(world)
      local p = world.bankrupt_player
      if not p then
        return nil, "no bankrupt player"
      end
      for _, tile in ipairs(p.tiles or {}) do
        if tile.owner ~= nil then
          return nil, "tile should be ownerless"
        end
      end
      return true
    end,

    ["地块等级重置为0"] = function(world)
      local p = world.bankrupt_player
      if p then
        for _, tile in ipairs(p.tiles or {}) do
          if tile.level ~= 0 then
            return nil, "tile level should be 0"
          end
        end
        return true
      end
      if world.monster_target then
        if world.monster_target.level ~= 0 then
          return nil, "tile level should be 0"
        end
      end
      if world.missile_target then
        if world.missile_target.level ~= 0 then
          return nil, "tile level should be 0"
        end
      end
      return true
    end,

    ["玩家持有道具且附有神灵"] = function(world)
      world.bankrupt_player = {
        tiles = {},
        bag = { { name = "item1" }, { name = "item2" } },
        deities = { fortune = true, poor = true },
      }
      return true
    end,

    ["玩家的背包被清空"] = function(world)
      local p = world.bankrupt_player
      if not p or #(p.bag or {}) ~= 0 then
        return nil, "bag should be empty"
      end
      return true
    end,

    ["玩家的神灵被移除"] = function(world)
      local p = world.bankrupt_player
      if not p then
        return nil, "no bankrupt player"
      end
      if next(p.deities or {}) ~= nil then
        return nil, "deities should be removed"
      end
      return true
    end,

    ["玩家位于格子5"] = function(world)
      world.bankrupt_player = {
        tiles = {},
        bag = {},
        deities = {},
        position = 5,
      }
      world.cells = world.cells or {}
      world.cells[5] = world.cells[5] or { occupants = { "player" } }
      return true
    end,

    ["格子5的占位列表不再包含该玩家"] = function(world)
      if world.vacated_cell ~= 5 then
        return nil, "cell 5 should be vacated"
      end
      return true
    end,

    ["游戏已标记为结束"] = function(world)
      world.game = world.game or {}
      world.game.ended = true
      world.game.players = { { alive = true, cash = 50000, tile_investment = 0 } }
      return true
    end,

    ["再次检查胜利条件"] = function(world)
      world.recheck = true
      return true
    end,

    ["直接返回已结束状态"] = function(world)
      if not world.already_ended and not world.game.ended then
        return nil, "should return already-ended status"
      end
      return true
    end,

    ["不重复判定胜者"] = function(world)
      if world.winner and world.recheck then
        return nil, "should not re-determine winner"
      end
      return true
    end,

    ["玩家落在<p8>"] = function(world, example)
      local cell_type = example.p8
      world.landing_cell_type = cell_type
      return true
    end,

    ["玩家无天使守护"] = function(world)
      world.no_angel = true
      return true
    end,

    ["落地效果执行"] = function(world)
      if world.landing_cell_type and world.no_angel then
        local cell = world.landing_cell_type
        if cell == "医院" or cell == "深山" then
          world.detained_turns = 2
        end
      end
      if world.has_angel_protection then
        world.angel_immune = true
        world.angel_protection_triggered = true
      end
      return true
    end,

    ["玩家被扣留<p9>回合"] = function(world, example)
      local expected = number_utils.to_integer(example.p9)
      if world.detained_turns ~= expected then
        return nil, "expected " .. tostring(expected) .. " turns detention, got " .. tostring(world.detained_turns)
      end
      return true
    end,

    ["玩家拥有天使守护"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.angel = true
      world.has_angel_protection = true
      return true
    end,

    ["玩家落在医院或深山"] = function(world)
      world.landing_cell_type = "医院"
      if world.has_angel_protection then
        world.angel_protection_triggered = true
      else
        world.detained_turns = 2
      end
      return true
    end,

    ["玩家不被扣留"] = function(world)
      if world.detained_turns and world.detained_turns > 0 then
        return nil, "player should not be detained"
      end
      return true
    end,

    ["天使守护抵消提示"] = function(world)
      if not world.angel_protection_triggered then
        return nil, "angel protection prompt should appear"
      end
      return true
    end,
  }
end

return endgame_steps
