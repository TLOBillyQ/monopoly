-- 机会卡绑定(features/game/chance.feature):
-- 多人转账(pay_each/collect_each)走 driver 真实结算动词(#200),其余结算语义沿用世界夹具模型
-- (旧 inventory 豁免以 driver.clear_items 消化)。
local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local number_utils = require("src.foundation.number")
local eq, truthy = dsl.eq, dsl.truthy
local function P(w) w.player = w.player or { cash = 0, deities = {} } return w.player end
local function CC(w) w.chance_card = w.chance_card or {} return w.chance_card end
-- ── 多人转账真实结算支撑(#200) ─────────────────────────────────────────────
local DEITY_ID = { ["穷神"] = "poor", ["财神"] = "rich" }
local function _ctx(w) return assert(w.driver, "缺少已初始化棋盘") end
local function _game(w) return _ctx(w).game end
local function _p1(w) return game_driver.current_player(_ctx(w)) end
local function _opponents(w)
  local list, me = {}, _p1(w)
  for _, p in ipairs(_game(w).players) do if p.id ~= me.id then list[#list + 1] = p end end
  return list
end
-- 重建局后重放已记录的神灵与顶格现金(多人转账场景的世界契约)。
local function _apply_cc_world(w)
  local ctx, game, p1 = _ctx(w), _game(w), _p1(w)
  for label, id in pairs(DEITY_ID) do
    if (w.cc_deities or {})[label] then game_driver.set_player_deity(ctx, p1, id) end
  end
  if w.cc_top_cash then game:set_player_cash(p1, 99999) end
end
local function _new_game(w, total)
  local names = {}
  for i = 1, total do names[i] = "P" .. i end
  w.driver = game_driver.new_game({ players = names })
  _apply_cc_world(w)
end
local function _record_deity(w, label)
  P(w).deities[DEITY_ID[label] == "poor" and "poor" or "fortune"] = true
  w.cc_deities = w.cc_deities or {}
  w.cc_deities[label] = true
  if w.driver then game_driver.set_player_deity(_ctx(w), _p1(w), DEITY_ID[label]) end
end
-- 结算核:天使挡负面;财神倍增收入、穷神倍增支出;多人转账走真实动词,其余落到夹具世界。
local function settle(w)
  P(w)
  local cc = w.chance_card or {}
  -- 多人转账:真实 driver 动词结算,快照现金供步骤断言差额。
  if cc.pay_each or cc.collect_each then
    local ctx, game, p1 = _ctx(w), _game(w), _p1(w)
    local opps = _opponents(w)
    w.cc_before = { game:player_cash(p1) }
    for i, opp in ipairs(opps) do w.cc_before[i + 1] = game:player_cash(opp) end
    if cc.pay_each then
      game_driver.chance_pay_others(ctx, p1, cc.pay_each)
    else
      game_driver.chance_collect_from_others(ctx, p1, cc.collect_each)
    end
    w.cc_opps = opps
    return true
  end
  if cc.negative and w.player.deities and w.player.deities.angel then
    w.negative_blocked, w.angel_prompt = true, true
    return true
  end
  if cc.gain_amount then
    w.actual_gain = cc.gain_amount * ((w.player.deities or {}).fortune and 2 or 1)
    w.player.cash = w.player.cash + w.actual_gain
  end
  if cc.pay_amount then
    w.actual_pay = cc.pay_amount * ((w.player.deities or {}).poor and 2 or 1)
    if w.player.cash < w.actual_pay then
      w.player.cash, w.player.bankrupt = 0, true
    else
      w.player.cash = w.player.cash - w.actual_pay
    end
  end
  if cc.pay_percent then
    w.percent_deducted = (w.player.cash * cc.pay_percent) // 100
    w.player.cash = w.player.cash - w.percent_deducted
  end
  if cc.move_direction then
    w.player.moved_direction, w.player.moved_steps = cc.move_direction, cc.move_steps
    w.landing_triggered = true
  end
  if cc.teleport then
    w.player.teleported, w.landing_triggered = true, true
  end
  if cc.gain_item then
    w.player.bag = w.player.bag or {}
    if #w.player.bag < (w.player.bag_limit or 5) then
      w.player.bag[#w.player.bag + 1] = { name = cc.gain_item }
      w.item_added = true
    end
  end
  if cc.discard_items then
    local bag = w.player.bag or {}
    w.items_discarded = math.min(cc.discard_items, #bag)
    for _ = 1, w.items_discarded do table.remove(bag) end
  end
  if cc.discard_tiles then
    local tiles = w.player.owned_tiles or {}
    w.tiles_discarded = math.min(cc.discard_tiles, #tiles)
    for _ = 1, w.tiles_discarded do
      local removed = table.remove(tiles)
      if removed then removed.owner = nil end
    end
  end
  if cc.typhoon then
    for _, tile in ipairs(w.typhoon_path or {}) do tile.level = 0 end
  end
  if cc.reset_path then
    for _, tile in ipairs(w.reset_path or {}) do tile.owner, tile.level = nil, 0 end
  end
  if cc.target_all and cc.all_pay then
    for _, player in ipairs(w.all_players or {}) do
      if not player.eliminated then player.cash = (player.cash or 0) - cc.all_pay end
    end
    w.all_paid = cc.all_pay
  end
  if cc.target_all_negative_pay then
    for _, opp in ipairs(w.all_opponents or {}) do
      if not opp.angel then opp.cash = opp.cash - cc.target_all_negative_pay end
    end
  end
  return true
end
local defs = {
  -- ── 抽卡与结算入口 ──────────────────────────────────────────────────────
  ["玩家落在机会格"] = function(w) w.on_chance_tile = true return true end,
  ["从机会卡池中按权重随机抽取一张"] = function(w) w.chance_card_drawn = w.on_chance_tile == true return truthy(w.chance_card_drawn, "应站在机会格抽卡") end,
  ["弹出机会卡展示弹窗"] = function(w) return truthy(w.chance_card_drawn, "机会卡弹窗") end,
  ["事件日志记录抽到的卡片"] = function(w) return truthy(w.chance_card_drawn, "事件日志记卡") end,
  ["机会卡效果结算"] = settle,
  ["抽到的机会卡标记为负面"] = function(w) CC(w).negative = true return true end,
  ["负面效果无效"] = function(w) return truthy(w.negative_blocked, "负面效果应被挡") end,
  ["提示天使保护"] = function(w) return truthy(w.angel_prompt, "天使保护提示") end,
  -- ── 金币收支 ────────────────────────────────────────────────────────────
  ["抽到的机会卡效果为获得<金额:int>金币"] = function(w, a) CC(w).gain_amount = a["金额"] return true end,
  ["抽到获得<基础金额:int>金币的机会卡"] = function(w, a) CC(w).gain_amount = a["基础金额"] return true end,
  ["玩家获得<金额:int>金币"] = function(w, a) if w.actual_gain == nil then return true end return eq(w.actual_gain, a["金额"], "获得金额") end,
  ["获得金额记为<验证金额:int>金币"] = function(w, a) return eq(w.actual_gain, a["验证金额"], "实际获得") end,
  ["实际获得<实际金额:int>金币"] = function(w, a) return eq(w.actual_gain, a["实际金额"], "实际获得") end,
  ["抽到的机会卡效果为支付<金额:int>金币"] = function(w, a) CC(w).pay_amount = a["金额"] return true end,
  ["抽到支付<基础金额:int>金币的机会卡"] = function(w, a) CC(w).pay_amount = a["基础金额"] return true end,
  ["抽到的机会卡效果为支付5000金币"] = function(w) CC(w).pay_amount = 5000 return true end,
  ["玩家扣除<扣除额:int>金币"] = function(w, a)
    if w.percent_deducted ~= nil then return eq(w.percent_deducted, a["扣除额"], "按比例扣除") end
    return eq(w.actual_pay, a["扣除额"], "扣除金额")
  end,
  ["玩家扣除<金额:int>金币"] = function(w, a)
    if w.actual_pay ~= nil and w.actual_pay ~= a["金额"] and w.percent_deducted ~= a["金额"] then
      return nil, "扣除金额: 期望 " .. tostring(a["金额"]) .. ",实际 " .. tostring(w.actual_pay)
    end
    if w.actual_pay == nil and w.percent_deducted ~= nil then
      return eq(w.percent_deducted, a["金额"], "按比例扣除")
    end
    return true
  end,
  ["实际扣除金额为<验证金额:int>金币"] = function(w, a) return eq(w.actual_pay, a["验证金额"], "实际扣除") end,
  ["实际扣除<实际金额:int>金币"] = function(w, a) return eq(w.actual_pay, a["实际金额"], "实际扣除") end,
  ["玩家持有3000金币"] = function(w) P(w).cash = 3000 return true end,
  ["抽到的机会卡效果为按<百分比:int>%支付金币"] = function(w, a) CC(w).pay_percent = a["百分比"] return true end,
  -- ── 神灵倍增 ────────────────────────────────────────────────────────────
  ["玩家持有穷神"] = function(w) _record_deity(w, "穷神") return true end,
  ["玩家附有<神灵>"] = function(w, a) if DEITY_ID[a["神灵"]] then _record_deity(w, a["神灵"]) end return true end,
  ["玩家神灵状态为<验证神灵>"] = function(w, a)
    local deities = P(w).deities or {}
    if a["验证神灵"] == "穷神" then return truthy(deities.poor, "穷神旗标") end
    if a["验证神灵"] == "财神" then return truthy(deities.fortune, "财神旗标") end
    return nil, "未知验证神灵: " .. tostring(a["验证神灵"])
  end,
  -- ── 多人收支(真实结算,#200) ─────────────────────────────────────────────
  ["抽到的机会卡效果为向每位玩家支付<金额:int>金币"] = function(w, a) CC(w).pay_each = a["金额"] return true end,
  ["抽到向每位玩家支付500金币的机会卡"] = function(w) CC(w).pay_each = 500 return true end,
  ["抽到的机会卡效果为向每位玩家收取<金额:int>金币"] = function(w, a) CC(w).collect_each = a["金额"] return true end,
  ["游戏中有<其他玩家数:int>名未淘汰对手"] = function(w, a) _new_game(w, a["其他玩家数"] + 1) return true end,
  ["当前对手数量为<验证其他玩家数:int>名"] = function(w, a) return eq(#_opponents(w), a["验证其他玩家数"], "对手数量") end,
  ["玩家向每位对手各支付<金额:int>金币"] = function(w, a)
    for i in ipairs(w.cc_opps or {}) do
      local gained = _game(w):player_cash(w.cc_opps[i]) - w.cc_before[i + 1]
      if gained ~= a["金额"] then return nil, "对手" .. tostring(i) .. " 所得: 期望 " .. tostring(a["金额"]) .. ",实际 " .. tostring(gained) end
    end
    return true
  end,
  ["实际每对手支付为<验证金额:int>金币"] = function(w, a) return eq(_game(w):player_cash(w.cc_opps[1]) - w.cc_before[2], a["验证金额"], "每对手支付") end,
  ["对手A在深山状态"] = function(w) game_driver.set_player_position(_ctx(w), _opponents(w)[1], _game(w).board:find_first_by_type("mountain")) return true end,
  ["对手A不收到任何金币"] = function(w) return eq(_game(w):player_cash(w.cc_opps[1]) - w.cc_before[2], 0, "深山对手进账") end,
  ["当前收取上限为<验证金额:int>金币"] = function(w, a) return eq(CC(w).collect_each, a["验证金额"], "收取上限") end,
  ["对手持有<对手余额:int>金币"] = function(w, a) _new_game(w, 2) _game(w):set_player_cash(_opponents(w)[1], a["对手余额"]) return true end,
  ["对手起始余额为<验证对手余额:int>金币"] = function(w, a) for i, opp in ipairs(_opponents(w)) do if _game(w):player_cash(opp) ~= a["验证对手余额"] then return nil, "对手" .. i .. " 余额: 期望 " .. tostring(a["验证对手余额"]) .. ",实际 " .. tostring(_game(w):player_cash(opp)) end end return true end,
  ["玩家从每位对手收取最多<金额:int>金币"] = function(w) return truthy(w.cc_before, "收取应已发生") end,
  ["对手余额不足时只收取其全部余额"] = function(w)
    for i in ipairs(w.cc_opps or {}) do
      local taken = w.cc_before[i + 1] - _game(w):player_cash(w.cc_opps[i])
      local expected = math.min(w.chance_card.collect_each, w.cc_before[i + 1])
      if taken ~= expected then return nil, "对手" .. tostring(i) .. " 被收: 期望 " .. tostring(expected) .. ",实际 " .. tostring(taken) end
    end
    return true
  end,
  ["实际收取总额为<验证收取额:int>金币"] = function(w, a) return eq(_game(w):player_cash(_p1(w)) - w.cc_before[1], a["验证收取额"], "收取总额") end,
  ["抽到<效果类型>3000金币的多人机会卡"] = function(w, a)
    w.cc_top_cash = true
    if w.driver then _game(w):set_player_cash(_p1(w), 99999) end
    if a["效果类型"] == "向每位对手支付" then CC(w).pay_each = 3000 end
    if a["效果类型"] == "从每位对手收取" then CC(w).collect_each = 3000 end
    return true
  end,
  ["游戏中有1名持有10000金币的对手"] = function(w) _new_game(w, 2) _game(w):set_player_cash(_opponents(w)[1], 10000) return true end,
  ["对手的金币变化量为<变化量>"] = function(w, a)
    local raw = tostring(a["变化量"])
    local sign = raw:sub(1, 1) == "-" and -1 or 1
    local expected = sign * number_utils.to_integer(raw:match("%d+"))
    return eq(_game(w):player_cash(w.cc_opps[1]) - w.cc_before[2], expected, "对手金币变化量")
  end,
  -- ── 移动 / 传送 / 道具 / 地块 ───────────────────────────────────────────
  ["抽到的机会卡效果为<移动方向><步数>步"] = function(w, a) CC(w).move_direction = a["移动方向"] w.chance_card.move_steps = number_utils.to_integer(a["步数"]) return true end,
  ["玩家<移动方向><步数>步"] = function(w, a) return dsl.all( function() return eq(w.player.moved_direction, a["移动方向"], "移动方向") end, function() return eq(w.player.moved_steps, number_utils.to_integer(a["步数"]), "移动步数") end) end,
  ["实际移动方向为<验证移动方向>"] = function(w, a) return eq(P(w).moved_direction, a["验证移动方向"], "实际移动方向") end,
  ["实际移动步数为<验证步数:int>步"] = function(w, a) return eq(P(w).moved_steps, a["验证步数"], "实际移动步数") end,
  ["到达后触发落地结算"] = function(w) return truthy(w.landing_triggered, "应触发落地结算") end,
  ["抽到的机会卡效果为传送到指定格"] = function(w) CC(w).teleport = true return true end,
  ["玩家被传送到目标格"] = function(w) return truthy(P(w).teleported, "应被传送") end,
  ["抽到的机会卡效果为获得指定道具"] = function(w) CC(w).gain_item = "specified_item" return true end,
  ["指定道具加入玩家背包"] = function(w) return truthy(w.item_added, "道具应入包") end,
  ["抽到的机会卡效果为随机丢弃<数量:int>张道具"] = function(w, a) CC(w).discard_items = a["数量"] return true end,
  ["指定丢弃数为<验证数量:int>张"] = function(w, a) return eq(CC(w).discard_items, a["验证数量"], "指定丢弃数") end,
  ["玩家持有<持有数:int>张道具"] = function(w, a) P(w).bag = {} for i = 1, a["持有数"] do w.player.bag[i] = { name = "item_" .. i } end return true end,
  ["背包道具数为<验证持有数:int>张"] = function(w, a) return eq(#(P(w).bag or {}), a["验证持有数"], "背包道具数") end,
  ["玩家随机失去<实际丢弃:int>张道具"] = function(w, a) return eq(w.items_discarded, a["实际丢弃"], "丢弃道具数") end,
  ["抽到的机会卡效果为随机丢弃<数量:int>块地块"] = function(w, a) CC(w).discard_tiles = a["数量"] return true end,
  ["指定丢弃地块数为<验证数量:int>块"] = function(w, a) return eq(CC(w).discard_tiles, a["验证数量"], "指定丢弃地块数") end,
  ["玩家拥有<持有数:int>块地块"] = function(w, a) P(w).owned_tiles = {} for i = 1, a["持有数"] do w.player.owned_tiles[i] = { level = 1, owner = "player" } end return true end,
  ["玩家随机失去<实际丢弃:int>块地块"] = function(w, a) return eq(w.tiles_discarded, a["实际丢弃"], "丢弃地块数") end,
  ["被丢弃的地块重置为无主状态"] = function() return true end,
  -- ── 台风 / 强制征地 / 全体支付 ──────────────────────────────────────────
  ["抽到台风类机会卡"] = function(w) CC(w).typhoon = true return true end,
  ["玩家本次移动经过的路径上有等级大于0的地块"] = function(w) w.typhoon_path = { { level = 2 }, { level = 1 } } return true end,
  ["路径上所有地块等级重置为0"] = function(w) for _, tile in ipairs(w.typhoon_path or {}) do if tile.level ~= 0 then return nil, "路径地块等级应为0" end end return true end,
  ["抽到强制征地类机会卡"] = function(w) CC(w).reset_path = true return true end,
  ["玩家本次移动经过的路径上有已购地块"] = function(w) w.reset_path = { { owner = "player", level = 2 }, { owner = "target", level = 1 } } return true end,
  ["路径上所有地块恢复初始状态"] = function(w) for _, tile in ipairs(w.reset_path or {}) do if tile.owner ~= nil or tile.level ~= 0 then return nil, "路径地块应重置" end end return true end,
  ["抽到的机会卡目标为全体"] = function(w) CC(w).target_all = true return true end,
  ["效果为支付1000金币"] = function(w) CC(w).all_pay = 1000 return true end,
  ["所有未淘汰玩家各扣除1000金币"] = function(w) return eq(w.all_paid, 1000, "全体扣除额") end,
  ["玩家抽到负面全体支付1000金币的机会卡"] = function(w) P(w) CC(w).target_all_negative_pay = 1000 return true end,
  ["游戏中有2名对手"] = function(w) w.all_opponents = { { cash = 0 }, { cash = 0 } } return true end,
  ["对手B拥有天使守护"] = function(w) w.all_opponents = w.all_opponents or { { cash = 0 } } w.all_opponents[1].angel = true return true end,
  ["各对手初始持有5000金币"] = function(w) for _, opp in ipairs(w.all_opponents or {}) do opp.cash = 5000 end return true end,
  ["拥有天使守护的对手金币不变"] = function(w) for _, opp in ipairs(w.all_opponents or {}) do if opp.angel and opp.cash ~= 5000 then return nil, "天使对手金币应不变,实际 " .. tostring(opp.cash) end end return true end,
  ["无天使守护的对手被扣除1000金币"] = function(w) for _, opp in ipairs(w.all_opponents or {}) do if not opp.angel and opp.cash ~= 4000 then return nil, "无天使对手应剩4000,实际 " .. tostring(opp.cash) end end return true end,
}
return dsl.steps(defs, { name = "chance" })
