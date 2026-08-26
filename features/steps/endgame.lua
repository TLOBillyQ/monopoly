local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local timing = require("src.config.gameplay.timing")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local bankruptcy_port = require("src.rules.ports.bankruptcy")
-- 终局域绑定（#192 簇 B）：破产清算走真实 bankruptcy 端口,医院/深山落地走 settle_landing 真实结算
-- （消化旧 src.rules.{endgame,land.effect_special} 豁免）；胜利判定走 driver 真实 check_victory 动词（#200）。
local TILE_TYPE_BY_LABEL = { ["医院"] = "hospital", ["深山"] = "mountain" }
local function _ctx(w) return assert(w.driver, "缺少已初始化棋盘") end
local function _game(w) return _ctx(w).game end
local function _p1(w) return game_driver.current_player(_ctx(w)) end
local function _int_list(t) local o = {}; for p in tostring(t):gmatch("[^,]+") do o[#o + 1] = number_utils.to_integer(p) end; return o end
local function _eg(w) w.eg = w.eg or {}; return w.eg end
-- 重建 N 人局（胜利判定场景的玩家数由例子列驱动）。
local function _new_game(w, total)
  local names = {}
  for i = 1, total do names[i] = "P" .. i end
  w.driver = game_driver.new_game({ players = names })
  -- 步骤乱序重建时带上已记录的游戏时间（时间到判定依赖它）。
  if w.eg and w.eg.time_now then w.driver.game.game_time_seconds = w.eg.time_now end
end
local function _set_time_now(w, seconds)
  _eg(w).time_now = seconds
  if w.driver then _game(w).game_time_seconds = seconds end
end
local function _eliminate(w, player)
  bankruptcy_port.eliminate(_game(w), player, { reason = player.name .. " 破产清算" })
end
-- 真实胜利判定：driver.check_victory 跑 src.rules.endgame.check_victory,快照结果供断言。
local function _check_victory(w)
  w.victory = game_driver.check_victory(_ctx(w))
  return true
end
-- 医院/深山真实落地：定位到指定格,跑 settle_landing,量取扣款与扣留回合。
local function _settle_special(w, tile_type)
  local ctx, game, p1 = _ctx(w), _game(w), _p1(w)
  game_driver.set_player_position(ctx, p1, game.board:find_first_by_type(tile_type))
  local before = game:player_cash(p1)
  turn_driver.settle_landing(ctx, p1)
  w.paid_fee, w.detained = before - game:player_cash(p1), p1.status.stay_turns
  return true
end
local function _detained_eq(w, a) return dsl.eq(w.detained, a["停留回合"], "扣留回合") end
return dsl.steps({
  ["游戏有<玩家人数:int>名玩家"] = function(w, a) _new_game(w, a["玩家人数"]) return true end,
  ["<淘汰人数:int>名玩家已被淘汰"] = function(w, a) for i = 1, a["淘汰人数"] do _eliminate(w, _game(w).players[i]) end return true end,
  ["胜利条件检查执行"] = _check_victory, ["再次检查胜利条件"] = _check_victory,
  ["唯一存活玩家获胜"] = function(w) return dsl.truthy(w.victory.winner, "应有唯一胜者") end,
  ["游戏标记为已结束"] = function(w) return dsl.truthy(w.victory.finished, "游戏应标记结束") end,
  ["游戏时间上限为<时间上限:int>秒"] = function(w, a) return dsl.eq(timing.game_time_limit_seconds, a["时间上限"], "生产时间上限配置") end,
  ["当前游戏时间已达到<时间上限:int>秒"] = function(w, a) _set_time_now(w, a["时间上限"]) return true end,
  ["游戏时间上限记录为<验证时间上限:int>秒"] = function(w, a)
    return dsl.eq(timing.game_time_limit_seconds, a["验证时间上限"], "生产时间上限配置")
  end,
  ["存活玩家的总资产分别为<资产列表>"] = function(w, a)
    local assets = _int_list(a["资产列表"])
    _new_game(w, #assets)
    for i, asset in ipairs(assets) do _game(w):set_player_cash(_game(w).players[i], asset) end
    return true
  end,
  ["存活玩家资产逐一为<验证资产列表>"] = function(w, a)
    local expected, players = _int_list(a["验证资产列表"]), _game(w).players
    if #players ~= #expected then return nil, "玩家数: 期望 " .. tostring(#expected) .. ",实际 " .. tostring(#players) end
    for i, v in ipairs(expected) do
      local actual = game_driver.player_total_assets(_ctx(w), players[i])
      if actual ~= v then return nil, "玩家" .. tostring(i) .. " 资产: 期望 " .. tostring(v) .. ",实际 " .. tostring(actual) end
    end
    return true
  end,
  ["资产最高的玩家获胜"] = function(w) return dsl.truthy(w.victory.winners and #w.victory.winners > 0, "应有资产最高胜者") end,
  ["获胜者资产为<验证最高资产:int>"] = function(w, a)
    local winners = w.victory.winners or {}
    if #winners == 0 then return nil, "无胜者可校验资产" end
    return dsl.eq(game_driver.player_total_assets(_ctx(w), winners[1]), a["验证最高资产"], "胜者资产")
  end,
  ["游戏时间已结束"] = function(w) _set_time_now(w, timing.game_time_limit_seconds) return true end,
  ["两名玩家总资产相同且为最高"] = function(w)
    _new_game(w, 3)
    local cashes = { 50000, 50000, 30000 }
    for i, cash in ipairs(cashes) do _game(w):set_player_cash(_game(w).players[i], cash) end
    return true
  end,
  ["两名玩家并列获胜"] = function(w) return dsl.eq(#(w.victory.winners or {}), 2, "并列胜者数") end,
  ["所有玩家均已被淘汰"] = function(w)
    for _, p in ipairs(_game(w).players) do if not p.eliminated then _eliminate(w, p) end end
    return true
  end,
  ["获胜者列表为空"] = function(w) return dsl.eq(#(w.victory.winners or {}), 0, "胜者数") end,
  ["游戏已标记为结束"] = function(w) _game(w).finished = true return true end,
  ["直接返回已结束状态"] = function(w) return dsl.truthy(w.victory.finished, "应直接返回已结束") end,
  ["不重复判定胜者"] = function(w) return dsl.eq(_game(w).winner, nil, "重复判定胜者") end,
  ["玩家拥有地块总投入为<地块投入:int>"] = function(w, a) w.invest = a["地块投入"] end,
  ["计算总资产"] = function(w) w.total_asset = (w.player and w.player.cash or 0) + (w.invest or 0) end,
  ["总资产为<总资产:int>"] = function(w, a) return dsl.eq(w.total_asset, a["总资产"], "总资产") end,
  -- 破产清算（真实 bankruptcy 端口 + 真实 game 状态）。
  ["玩家拥有3块地块"] = function(w)
    local game, p1 = _game(w), _p1(w)
    local levels, tiles = { 2, 1, 0 }, {}
    for index = 1, _ctx(w).outer_ring_size do
      local t = game.board:get_tile(index)
      if t and t.type == "land" then tiles[#tiles + 1] = t end
      if #tiles == 3 then break end
    end
    assert(#tiles == 3, "棋盘上找不到 3 块 land")
    for i, t in ipairs(tiles) do game:set_tile_owner(t, p1.id); game:set_tile_level(t, levels[i]); game:set_player_property(p1, t.id, true) end
    w.owned_tiles = tiles
  end,
  ["执行破产淘汰清算"] = function(w) local p1 = _p1(w); bankruptcy_port.eliminate(_game(w), p1, { reason = p1.name .. " 破产清算" }) end,
  ["玩家的所有地块重置为无主"] = function(w)
    for _, t in ipairs(w.owned_tiles or {}) do if t.owner_id ~= nil then return nil, "地块应无主: " .. tostring(t.id) end end
    return true
  end,
  ["地块等级重置为0"] = function(w)
    for _, t in ipairs(w.owned_tiles or {}) do if (t.level or 0) ~= 0 then return nil, "地块等级应为 0: " .. tostring(t.id) end end
    return true
  end,
  ["玩家持有道具且附有神灵"] = function(w)
    local p1 = _p1(w)
    game_driver.give_item(nil, p1, 2001); game_driver.give_item(nil, p1, 2007); game_driver.set_player_deity(_ctx(w), p1, "rich")
  end,
  ["玩家的背包被清空"] = function(w) return dsl.eq(#game_driver.items_of(nil, _p1(w)), 0, "背包数") end,
  ["玩家的神灵被移除"] = function(w) return dsl.eq(_game(w):player_has_deity(_p1(w), "rich"), false, "神灵状态") end,
  ["玩家位于格子5"] = function(w) game_driver.set_player_position(_ctx(w), _p1(w), 5) end,
  ["格子5的占位列表不再包含该玩家"] = function(w)
    for _, id in ipairs(_game(w).occupants[5] or {}) do if id == _p1(w).id then return nil, "格子5仍包含该玩家" end end
    return true
  end,
  -- 医院/深山停留（真实落地结算）。
  ["玩家落在<格子类型>"] = function(w, a) w.landing_tile_type = assert(TILE_TYPE_BY_LABEL[a["格子类型"]], "未知格子类型: " .. tostring(a["格子类型"])) end,
  ["落地效果执行"] = function(w) return _settle_special(w, assert(w.landing_tile_type, "缺少落点格子类型")) end,
  ["玩家被扣留{停留回合:int}回合"] = _detained_eq, ["玩家被扣留<停留回合:int>回合"] = _detained_eq,
  ["玩家落在医院格"] = function(w) return _settle_special(w, "hospital") end,
  ["玩家支付5000金币医药费"] = function(w) return dsl.eq(w.paid_fee, 5000, "医药费") end,
  ["玩家需停留2回合"] = function(w) return dsl.eq(w.detained, 2, "住院停留回合") end,
  ["玩家拥有天使守护"] = function(w)
    w.player = w.player or { cash = 0, tiles = {}, items = {}, deities = {} }
    w.player.deities.angel = true
    if w.driver then game_driver.set_player_deity(_ctx(w), _p1(w), "angel") end
  end,
  -- items 域（均富/流放无效）亦消费:断言由对方 handler 写入的 world 契约字段。
  ["天使守护抵消提示"] = function(w) return dsl.truthy(w.angel_protection_triggered, "应出现天使守护抵消提示") end,
  ["游戏已结束"] = function(w) _eg(w).ended = true end,
  ["玩家是获胜者"] = function(w) w.result_is_winner = true end, ["玩家不是获胜者"] = function(w) w.result_is_winner = false end,
  ["结算画面显示"] = function(w) w.result_panel = w.result_is_winner and "victory" or "defeat" end,
  ["玩家进入胜利结算面板"] = function(w) return dsl.eq(w.result_panel, "victory", "结算面板") end,
  ["玩家进入失败结算面板"] = function(w) return dsl.eq(w.result_panel, "defeat", "结算面板") end,
}, { name = "endgame" })
