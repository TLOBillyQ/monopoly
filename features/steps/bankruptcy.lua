local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
-- 破产域绑定（#192 簇 B）：租金破产走 settle_landing 真实结算链,住院费走 game:player_apply_hospital_effects；
-- 机会卡 pay/collect 走 driver 真实结算动词（#200,真实 charge/transfer + 破产链）。
local function _ctx(w) return assert(w.driver, "缺少已初始化棋盘") end
local function _game(w) return _ctx(w).game end
local function _p1(w) return game_driver.current_player(_ctx(w)) end
local function _opponents(w)
  local list, me = {}, _p1(w)
  for _, p in ipairs(_game(w).players) do if p.id ~= me.id then list[#list + 1] = p end end
  return list
end
return dsl.steps({
  ["结算租金前玩家持有<余额:int>金币"] = function(w, a) _game(w):set_player_cash(_p1(w), a["余额"]); w.bk_balance = a["余额"] end,
  ["对手拥有玩家所在地块且应付租金为<租金:int>金币"] = function(w, a)
    local game = _game(w)
    local idx = game_driver.first_land_tile(_ctx(w))
    local tile = game.board:get_tile(idx)
    tile.price = a["租金"] * 2 -- level 0 租金 = floor(price * 0.5)
    game:set_tile_owner(tile, _opponents(w)[1].id); game:set_tile_level(tile, 0)
    game_driver.set_player_position(_ctx(w), _p1(w), idx); w.bk_rent = a["租金"]
  end,
  ["玩家落地结算租金"] = function(w) turn_driver.settle_landing(_ctx(w), _p1(w)) end,
  ["结算后玩家<结果>"] = function(w, a)
    local p = _p1(w)
    if a["结果"] == "破产" then return dsl.truthy(p.eliminated, "玩家应破产淘汰") end
    if a["结果"] ~= "存活" then return nil, "未知结果: " .. tostring(a["结果"]) end
    return dsl.all(function() return dsl.eq(p.eliminated or false, false, "存活") end,
      function() return dsl.eq(_game(w):player_cash(p), w.bk_balance - w.bk_rent, "存活余额") end)
  end,
  ["支付机会卡前玩家持有1000金币"] = function(w) _game(w):set_player_cash(_p1(w), 1000) end,
  ["游戏中有3名未淘汰对手"] = function(w)
    local active = 0
    for _, opp in ipairs(_opponents(w)) do if not opp.eliminated then active = active + 1 end end
    return dsl.eq(active, 3, "未淘汰对手数")
  end,
  ["玩家结算向每位对手支付500金币的机会卡"] = function(w)
    local game, opponents = _game(w), _opponents(w)
    w.opp_before = {}
    for i, opp in ipairs(opponents) do w.opp_before[i] = game:player_cash(opp) end
    game_driver.chance_pay_others(_ctx(w), _p1(w), 500)
  end,
  ["玩家支付前两位对手各500金币后破产淘汰"] = function(w)
    local game, opponents = _game(w), _opponents(w)
    if not _p1(w).eliminated then return nil, "玩家应中途破产淘汰" end
    for i = 1, 2 do
      local gained = game:player_cash(opponents[i]) - w.opp_before[i]
      if gained ~= 500 then return nil, "对手" .. tostring(i) .. " 应收到 500,实际 " .. tostring(gained) end
    end
    return true
  end,
  ["第三位对手不再收到支付"] = function(w) return dsl.eq(_game(w):player_cash(_opponents(w)[3]) - w.opp_before[3], 0, "第三位对手所得") end,
  ["对手A持有500金币"] = function(w) w.opp_a = _opponents(w)[1]; _game(w):set_player_cash(w.opp_a, 500) end,
  ["玩家结算向每位对手收取1000金币的机会卡"] = function(w)
    w.bk_player_before = _game(w):player_cash(_p1(w))
    game_driver.chance_collect_from_others(_ctx(w), _p1(w), 1000)
  end,
  ["对手A支付全部500金币后破产淘汰"] = function(w)
    return dsl.all(function() return dsl.truthy(w.opp_a.eliminated, "对手A应破产淘汰") end,
      function() return dsl.eq(_game(w):player_cash(w.opp_a), 0, "对手A余额") end)
  end,
  ["玩家至少收到对手A的500金币"] = function(w)
    local gained = _game(w):player_cash(_p1(w)) - w.bk_player_before
    if gained < 500 then return nil, "玩家至少应收到 500,实际 " .. tostring(gained) end
    return true
  end,
  ["落院前玩家持有0金币"] = function(w) _game(w):set_player_cash(_p1(w), 0) end,
  ["玩家落在医院结算住院费"] = function(w) _game(w):player_apply_hospital_effects(_p1(w)) end,
  ["玩家因住院费破产淘汰"] = function(w) return dsl.truthy(_p1(w).eliminated, "玩家应因住院费破产淘汰") end,
}, { name = "bankruptcy" })
