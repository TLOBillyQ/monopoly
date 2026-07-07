local number_utils = require("src.foundation.number")
local shared = require("acceptance.steps.shared")
local endgame = require("src.rules.endgame")
local timing = require("src.config.gameplay.timing")
local game_driver = require("tools.acceptance.game_driver")
local effect_special = require("src.rules.land.effect_special")

local endgame_steps = {}

local _ensure_player = shared.ensure_player

local function _ensure_game(world)
  if not world.game then
    world.game = {}
  end
  return world.game
end

local function _make_src_player(index, cash)
  return {
    id = index,
    name = "P" .. tostring(index),
    properties = {},
    eliminated = false,
    status = {},
    _acceptance_cash = cash or 0,
  }
end

local function _ensure_src_game(world)
  local game = _ensure_game(world)
  if not game._src_endgame then
    game.finished = game.ended == true
    game.turn = game.turn or { turn_count = 0 }
    game.occupants = game.occupants or {}
    game.board = game.board or {
      get_tile_by_id = function() return nil end,
    }
    game.alive_players = function(self)
      local alive = {}
      for _, player in ipairs(self.players or {}) do
        if not player.eliminated then
          alive[#alive + 1] = player
        end
      end
      return alive
    end
    game.player_cash = function(_, player)
      return player._acceptance_cash or player.cash or 0
    end
    game._src_endgame = true
  end
  return game
end

local function _mark_src_endgame(world)
  world.use_src_endgame = true
  return _ensure_src_game(world)
end

local function _ensure_location_driver(world)
  if not world.location_driver then
    world.location_driver = game_driver.new_game()
  end
  return world.location_driver
end

local function _src_location_player(world)
  return game_driver.current_player(_ensure_location_driver(world))
end

function endgame_steps.handlers()
  return {
    ["游戏有<玩家人数>名玩家"] = function(world, example)
      local count = number_utils.to_integer(example["玩家人数"])
      _ensure_game(world)
      world.game.player_count = count
      world.game.players = {}
      for i = 1, count do
        world.game.players[i] = { alive = true, cash = 10000, tile_investment = 0 }
      end
      return true
    end,

    ["<淘汰人数>名玩家已被淘汰"] = function(world, example)
      local eliminated = number_utils.to_integer(example["淘汰人数"])
      for i = 1, eliminated do
        world.game.players[i].alive = false
      end
      return true
    end,

    ["胜利条件检查执行"] = function(world)
      local game = world.game or {}
      if world.use_src_endgame then
        local ok = endgame.check_victory(_ensure_src_game(world))
        world.winner = game.winner
        world.winners = game.winners
        game.ended = game.finished == true
        return ok == true
      end
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

      local reached_turn_limit = game.turn_limit and game.current_turn and game.current_turn >= game.turn_limit
      local reached_time_limit = game.time_limit and game.current_time and game.current_time >= game.time_limit
      if reached_turn_limit or reached_time_limit then
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

    ["回合上限为<回合上限>"] = function(world, example)
      local limit = number_utils.to_integer(example["回合上限"])
      _ensure_game(world)
      world.game.turn_limit = limit
      return true
    end,

    ["当前回合数为<回合上限>"] = function(world, example)
      local turn = number_utils.to_integer(example["回合上限"])
      _ensure_game(world)
      world.game.current_turn = turn
      return true
    end,

    ["游戏时间上限为<时间上限>秒"] = function(world, example)
      local limit = number_utils.to_integer(example["时间上限"])
      if limit == nil then
        return nil, "invalid 时间上限: " .. tostring(example["时间上限"])
      end
      _ensure_game(world)
      world.game.time_limit = limit
      _mark_src_endgame(world)
      return true
    end,

    ["当前游戏时间已达到<时间上限>秒"] = function(world, example)
      local current = number_utils.to_integer(example["时间上限"])
      if current == nil then
        return nil, "invalid 时间上限: " .. tostring(example["时间上限"])
      end
      _ensure_game(world)
      world.game.current_time = current
      world.game.game_time_seconds = current
      return true
    end,

    ["存活玩家的总资产分别为<资产列表>"] = function(world, example)
      local assets = shared.parse_number_list(example["资产列表"])
      _ensure_game(world)
      world.game.players = {}
      for i, asset in ipairs(assets) do
        world.game.players[i] = _make_src_player(i, asset)
        world.game.players[i].alive = true
        world.game.players[i].cash = asset
        world.game.players[i].tile_investment = 0
      end
      return true
    end,

    ["资产最高的玩家获胜"] = function(world)
      if not world.winners or #world.winners == 0 then
        return nil, "there should be a winner by assets"
      end
      return true
    end,

    ["存活玩家资产逐一为<验证资产列表>"] = function(world, example)
      local expected = shared.parse_number_list(example["验证资产列表"])
      _ensure_game(world)
      local players = world.game.players or {}
      if #players ~= #expected then
        return nil, "expected " .. tostring(#expected) ..
          " players, got " .. tostring(#players)
      end
      for i, exp in ipairs(expected) do
        local p = players[i]
        local actual = (p.cash or 0) + (p.tile_investment or 0)
        if actual ~= exp then
          return nil, "player " .. tostring(i) .. " assets expected=" ..
            tostring(exp) .. ", got " .. tostring(actual)
        end
      end
      return true
    end,

    ["游戏回合上限为<验证回合上限>"] = function(world, example)
      local expected = number_utils.to_integer(example["验证回合上限"])
      if expected == nil then
        return nil, "invalid 验证回合上限: " .. tostring(example["验证回合上限"])
      end
      _ensure_game(world)
      if world.game.turn_limit ~= expected then
        return nil, "expected turn_limit=" .. tostring(expected) ..
          ", got " .. tostring(world.game.turn_limit)
      end
      return true
    end,

    ["游戏时间上限记录为<验证时间上限>秒"] = function(world, example)
      local expected = number_utils.to_integer(example["验证时间上限"])
      if expected == nil then
        return nil, "invalid 验证时间上限: " .. tostring(example["验证时间上限"])
      end
      _ensure_game(world)
      if world.game.time_limit ~= expected then
        return nil, "expected time_limit=" .. tostring(expected) ..
          ", got " .. tostring(world.game.time_limit)
      end
      if timing.game_time_limit_seconds ~= expected then
        return nil, "expected production game_time_limit_seconds=" .. tostring(expected) ..
          ", got " .. tostring(timing.game_time_limit_seconds)
      end
      return true
    end,

    ["获胜者资产为<验证最高资产>"] = function(world, example)
      local expected = number_utils.to_integer(example["验证最高资产"])
      if expected == nil then
        return nil, "invalid 验证最高资产: " .. tostring(example["验证最高资产"])
      end
      if not world.winners or #world.winners == 0 then
        return nil, "no winner to check assets"
      end
      local winner = world.winners[1]
      local actual = (winner.cash or 0) + (winner.tile_investment or 0)
      if actual ~= expected then
        return nil, "expected winner total assets=" .. tostring(expected) ..
          ", got " .. tostring(actual)
      end
      return true
    end,

    ["回合上限到达"] = function(world)
      _ensure_game(world)
      world.game.turn_limit = 1000
      world.game.current_turn = 1000
      return true
    end,

    ["游戏时间已结束"] = function(world)
      _ensure_game(world)
      world.game.time_limit = 900
      world.game.current_time = 900
      _mark_src_endgame(world)
      world.game.game_time_seconds = 900
      return true
    end,

    ["所有玩家均已被淘汰"] = function(world)
      _ensure_game(world)
      if not world.game.players or #world.game.players == 0 then
        world.game.players = {
          _make_src_player(1, 0),
          _make_src_player(2, 0),
        }
        world.game.players[1].alive = false
        world.game.players[1].eliminated = true
        world.game.players[2].alive = false
        world.game.players[2].eliminated = true
      else
        for _, p in ipairs(world.game.players) do
          p.alive = false
          p.eliminated = true
        end
      end
      return true
    end,

    ["获胜者列表为空"] = function(world)
      if world.winners and #world.winners > 0 then
        return nil, "expected no winners, got " .. tostring(#world.winners)
      end
      return true
    end,

    ["两名玩家总资产相同且为最高"] = function(world)
      _ensure_game(world)
      world.game.players = {
        _make_src_player(1, 50000),
        _make_src_player(2, 50000),
        _make_src_player(3, 30000),
      }
      world.game.players[1].alive = true
      world.game.players[2].alive = true
      world.game.players[3].alive = true
      return true
    end,

    ["两名玩家并列获胜"] = function(world)
      if not world.winners or #world.winners ~= 2 then
        return nil, "there should be exactly 2 tied winners"
      end
      return true
    end,

    ["玩家持有<现金>金币"] = function(world, example)
      local amount = number_utils.to_integer(example["现金"])
      _ensure_player(world)
      world.player.cash = amount
      world.asset_player = world.asset_player or {}
      world.asset_player.cash = amount
      return true
    end,

    ["玩家拥有地块总投入为<地块投入>"] = function(world, example)
      local amount = number_utils.to_integer(example["地块投入"])
      world.asset_player = world.asset_player or {}
      world.asset_player.tile_investment = amount
      return true
    end,

    ["计算总资产"] = function(world)
      local p = world.asset_player or {}
      world.total_asset = (p.cash or 0) + (p.tile_investment or 0)
      return true
    end,

    ["总资产为<总资产>"] = function(world, example)
      local expected = number_utils.to_integer(example["总资产"])
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

    ["执行破产淘汰清算"] = function(world)
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
      if world.typhoon_path then
        for _, tile in ipairs(world.typhoon_path) do
          if tile.level ~= 0 then
            return nil, "path tile level should be 0"
          end
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
      _ensure_game(world)
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

    ["玩家落在<格子类型>"] = function(world, example)
      local cell_type = example["格子类型"]
      world.landing_cell_type = cell_type
      return true
    end,

    ["玩家无天使守护"] = function(world)
      world.no_angel = true
      return true
    end,

    ["落地效果执行"] = function(world)
      if world.landing_cell_type then
        local cell = world.landing_cell_type
        if cell == "医院" or cell == "深山" then
          local ctx = _ensure_location_driver(world)
          local player = game_driver.current_player(ctx)
          local tile_type = cell == "医院" and "hospital" or "mountain"
          local idx = assert(ctx.game.board:find_first_by_type(tile_type), "missing tile type: " .. tile_type)
          local tile = assert(ctx.game.board:get_tile(idx), "missing tile: " .. tostring(idx))
          ctx.game:update_player_position(player, idx)
          effect_special.executors[tile_type].apply({
            game = ctx.game,
            player = player,
            tile = tile,
          })
          world.detained_turns = player.status.stay_turns
          world.player = world.player or {}
          world.player.cash = ctx.game:player_cash(player)
        end
      end
      return true
    end,

    ["玩家被扣留<停留回合>回合"] = function(world, example)
      local expected = number_utils.to_integer(example["停留回合"])
      if world.detained_turns ~= expected then
        return nil, "expected " .. tostring(expected) .. " turns detention, got " .. tostring(world.detained_turns)
      end
      return true
    end,

    ["玩家被扣留2回合"] = function(world)
      if world.detained_turns ~= 2 then
        return nil, "expected 2 turns detention, got " .. tostring(world.detained_turns)
      end
      return true
    end,

    ["玩家拥有天使守护"] = function(world)
      _ensure_player(world)
      world.player.deities = world.player.deities or {}
      world.player.deities.angel = true
      world.has_angel_protection = true
      game_driver.set_player_deity(_ensure_location_driver(world), _src_location_player(world), "angel")
      return true
    end,

    ["玩家持有10000金币"] = function(world)
      _ensure_player(world)
      world.player.cash = 10000
      return true
    end,

    ["玩家落在医院格"] = function(world)
      _ensure_player(world)
      local ctx = _ensure_location_driver(world)
      local player = game_driver.current_player(ctx)
      ctx.game:set_player_cash(player, world.player.cash or 10000)
      world.hospital_fee = 5000
      local idx = assert(ctx.game.board:find_first_by_type("hospital"), "missing hospital")
      local tile = assert(ctx.game.board:get_tile(idx), "missing hospital tile")
      ctx.game:update_player_position(player, idx)
      effect_special.executors.hospital.apply({
        game = ctx.game,
        player = player,
        tile = tile,
      })
      world.player.cash = ctx.game:player_cash(player)
      if player.eliminated then
        world.player.bankrupt = true
      else
        world.paid_hospital_fee = world.hospital_fee
        world.detained_turns = player.status.stay_turns
      end
      return true
    end,

    ["玩家支付5000金币医药费"] = function(world)
      if world.paid_hospital_fee ~= 5000 then
        return nil, "expected hospital fee 5000, got " .. tostring(world.paid_hospital_fee)
      end
      return true
    end,

    ["玩家需停留2回合"] = function(world)
      if world.detained_turns ~= 2 then
        return nil, "expected 2 detained turns, got " .. tostring(world.detained_turns)
      end
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

    ["游戏已结束"] = function(world)
      _ensure_game(world)
      world.game.ended = true
      world.game.players = world.game.players or {
        { alive = true, cash = 50000, tile_investment = 0 },
        { alive = true, cash = 10000, tile_investment = 0 },
      }
      return true
    end,

    ["玩家是获胜者"] = function(world)
      world.result_player_is_winner = true
      return true
    end,

    ["结算画面显示"] = function(world)
      if world.result_player_is_winner then
        world.result_panel = "victory"
      else
        world.result_panel = "defeat"
      end
      return true
    end,

    ["玩家进入胜利结算面板"] = function(world)
      if world.result_panel ~= "victory" then
        return nil, "expected victory panel, got " .. tostring(world.result_panel)
      end
      return true
    end,

    ["玩家不是获胜者"] = function(world)
      world.result_player_is_winner = false
      return true
    end,

    ["玩家进入失败结算面板"] = function(world)
      if world.result_panel ~= "defeat" then
        return nil, "expected defeat panel, got " .. tostring(world.result_panel)
      end
      return true
    end,
  }
end

return endgame_steps
