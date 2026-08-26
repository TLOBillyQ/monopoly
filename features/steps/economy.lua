local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local constants = require("src.config.content.constants")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
-- 经济域绑定（#192 簇 B）：租金/税务走 settle_landing 真实结算（消化旧 land.effect_base/pricing 豁免）；购买/升级/强夺保留旧 fixture 语义。
local TAX_FREE_CARD = 2010
local function _ctx(w) return assert(w.driver, "缺少已初始化棋盘") end
local function _game(w) return _ctx(w).game end
local function _p1(w) return game_driver.current_player(_ctx(w)) end
local function _p2(w) return _game(w).players[2] end
local function _player(w) w.player = w.player or { cash = 0, tiles = {}, items = {}, deities = {} }; return w.player end
local function S(f, k) return function(w, a) w[f] = a[k] end end
local function A(f, k, l) return function(w, a) return dsl.eq(w[f], a[k], l) end end
local function _set_cash(w, a) _player(w).cash = a["余额"]; if w.driver then _game(w):set_player_cash(_p1(w), a["余额"]) end end
local function _int_list(t) local o = {}; for p in tostring(t):gmatch("[^,]+") do o[#o + 1] = number_utils.to_integer(p) end; return o end
-- 沿外环找一段连续 count 块 land（外环相邻即邻接,供连片租金真实结算）。
local function _land_run(game, count)
  local board, map = game.board, game.board.map
  local id = map.start_id
  for _ = 1, 40 do
    local run, cur = {}, id
    while #run < count do
      local tile = board:get_tile(board:index_of_tile_id(cur))
      if not (tile and tile.type == "land") then break end
      run[#run + 1] = tile; cur = map.outer_next[cur]
    end
    if #run == count then return run end
    id = map.outer_next[id]
  end
  error("外环上找不到连续 " .. tostring(count) .. " 块 land")
end
-- 按价格铺 P2 名下地块,P1 落在第一块跑真实落地结算,量取双方现金差。
local function _settle_rent(w, prices, levels)
  local ctx, game, p1, p2 = _ctx(w), _game(w), _p1(w), _p2(w)
  local tiles = _land_run(game, #prices)
  for i, t in ipairs(tiles) do t.price = prices[i]; game:set_tile_owner(t, p2.id); game:set_tile_level(t, (levels and levels[i]) or 0) end
  if w.opp_eliminated then game:set_player_eliminated(p2, true) end
  if w.opp_mountain then game:update_player_position(p2, game.board:find_first_by_type("mountain")) end
  local b1, b2 = game:player_cash(p1), game:player_cash(p2)
  game_driver.set_player_position(ctx, p1, game.board:index_of_tile_id(tiles[1].id))
  turn_driver.settle_landing(ctx, p1)
  w.rent_paid, w.owner_received = b1 - game:player_cash(p1), game:player_cash(p2) - b2
  return true
end
local function _ensure_tax(w)
  if w.tax_amount ~= nil then return end
  local game, p1 = _game(w), _p1(w)
  local before = game:player_cash(p1)
  w.tax_choice = turn_driver.settle_landing(_ctx(w), p1)
  w.tax_amount = before - game:player_cash(p1); _player(w).cash = game:player_cash(p1)
end
local function _tax_eq(w, a) _ensure_tax(w); return dsl.eq(w.tax_amount, a["税金"], "税金") end
local function _land_unowned(w, a) w.landing_tile = { price = a["地价"], owner = nil, level = 0 } end
return dsl.steps({
  ["棋盘包含地块邻接关系"] = function(w) w.adjacency = true end,
  ["玩家持有<余额:int>金币"] = _set_cash, ["玩家持有{余额:int}金币"] = _set_cash,
  ["玩家初始余额为<验证余额:int>金币"] = function(w, a) return dsl.eq(w.player and w.player.cash, a["验证余额"], "初始余额") end,
  ["玩家破产淘汰"] = function(w) if w.driver and _p1(w).eliminated then return true end; return dsl.truthy(w.player and w.player.bankrupt, "玩家应破产淘汰") end,
  ["玩家落在价格为<地价:int>的无主地块"] = _land_unowned, ["玩家落在价格为{地价:int}的无主地块"] = _land_unowned,
  ["地块价格为<验证地价:int>金币"] = function(w, a) return dsl.eq(w.landing_tile and w.landing_tile.price, a["验证地价"], "地价") end,
  ["玩家选择购买"] = function(w)
    local t = assert(w.landing_tile, "无落点地块")
    if w.player.cash < t.price then w.purchase_failed = "余额不足" else w.player.cash = w.player.cash - t.price; t.owner, w.purchased = "player", true end
  end,
  -- 同形合并：<地价>/<升级费> 扣款按已发生的动作分派。
  ["玩家扣除<升级费:int>金币"] = function(w, a) return dsl.eq(w.owned_tile.upgrade_cost, a["升级费"], "升级扣款") end,
  ["玩家扣除<地价:int>金币"] = function(w, a) if w.upgraded then return dsl.eq(w.owned_tile.upgrade_cost, a["地价"], "升级扣款") end; if w.purchased then return dsl.eq(w.landing_tile.price, a["地价"], "扣除金额") end end,
  ["玩家成为该地块的所有者"] = function(w) return dsl.truthy(w.purchased, "地块应购入") end,
  ["购买失败并提示余额不足"] = function(w) return dsl.eq(w.purchase_failed, "余额不足", "购买失败原因") end,
  ["玩家拥有一块等级为<当前等级:int>的地块"] = function(w, a) _player(w); w.owned_tile = { level = a["当前等级"], max_level = 3 } end,
  ["该地块的下一级升级费为<升级费:int>"] = function(w, a) w.owned_tile.upgrade_cost = a["升级费"] end,
  ["当前升级费为<验证升级费:int>金币"] = function(w, a) return dsl.eq(w.owned_tile and w.owned_tile.upgrade_cost, a["验证升级费"], "升级费") end,
  ["玩家选择升级"] = function(w)
    local t = assert(w.owned_tile, "无自有地块")
    if t.level >= t.max_level then w.upgrade_failed = "max_level" elseif w.player.cash < t.upgrade_cost then w.upgrade_failed = "insufficient"
    else w.player.cash = w.player.cash - t.upgrade_cost; t.level, w.upgraded = t.level + 1, true end
  end,
  ["地块等级变为<新等级:int>"] = function(w, a) return dsl.eq(w.owned_tile.level, a["新等级"], "地块等级") end,
  ["玩家拥有的地块已达最高等级"] = function(w) _player(w); w.owned_tile = { level = 3, max_level = 3, upgrade_cost = 0 } end,
  ["玩家尝试升级"] = function(w) w.upgrade_unavailable = w.owned_tile.level >= w.owned_tile.max_level end,
  ["升级选项不可用"] = function(w) return dsl.truthy(w.upgrade_unavailable, "升级应不可用") end,
  ["该地块购买价为<地价:int>"] = S("rent_price", "地价"),
  ["地块加盖次数为<加盖次数:int>"] = function(w, a) w.rent_level = a["加盖次数"]; return dsl.range(a["加盖次数"], 0, 3, "加盖次数") end,
  ["地块属于对手"] = function() end, ["对手拥有一块地块"] = function() end,
  ["对手当前在深山状态"] = function(w) w.opp_mountain = true end, ["对手已被淘汰"] = function(w) w.opp_eliminated = true end,
  ["玩家落在该地块"] = function(w) return _settle_rent(w, { w.rent_price or 1000 }, { w.rent_level or 0 }) end,
  ["玩家支付租金<应付租金:int>给对手"] = A("rent_paid", "应付租金", "应付租金"),
  ["租金不收取"] = function(w) return dsl.eq(w.rent_paid, 0, "租金") end,
  ["事件日志显示房东在深山"] = function(w)
    for _, e in ipairs(game_driver.events(_ctx(w))) do if tostring(e.text or ""):find("在深山", 1, true) then return true end end
    return nil, "事件日志缺少房东在深山记录"
  end,
  ["对手拥有<连片数:int>块相邻地块"] = S("adj_count", "连片数"), ["相邻地块数量为<验证连片数:int>块"] = A("adj_count", "验证连片数", "连片数"),
  ["各块租金分别为<各块租金>"] = function(w, a) w.adj_rents = _int_list(a["各块租金"]) end,
  ["玩家落在其中任一块"] = function(w) local p = {}; for i, r in ipairs(w.adj_rents) do p[i] = r * 2 end; return _settle_rent(w, p) end,
  ["玩家支付的租金为<总租金:int>"] = A("rent_paid", "总租金", "总租金"),
  ["玩家落在对手拥有的地块"] = function(w) w.deity_rent = true end, ["单块基础租金为<基础租金:int>"] = S("deity_base", "基础租金"),
  ["<神灵条件>"] = function(w, a)
    local c = tostring(a["神灵条件"])
    if c:find("租户持有穷神", 1, true) then game_driver.set_player_deity(_ctx(w), _p1(w), "poor") end
    if c:find("房东持有财神", 1, true) then game_driver.set_player_deity(_ctx(w), _p2(w), "rich") end
  end,
  ["应付租金为<应付租金:int>"] = S("rent_due", "应付租金"), ["应付租金记为<验证应付租金:int>金币"] = A("rent_due", "验证应付租金", "应付租金"),
  ["租金结算执行"] = function(w) return _settle_rent(w, { (w.deity_base or assert(w.rent_due, "缺少租金设定")) * 2 }) end,
  ["实际支付租金为<实际租金:int>"] = A("rent_paid", "实际租金", "实际租金"), ["房东收到<实收金额:int>金币"] = A("owner_received", "实收金额", "房东实收"),
  ["税率为50%"] = function() return dsl.eq(constants.tax_rate, 0.5, "税率") end,
  ["玩家落在税务局格"] = function(w) game_driver.set_player_position(_ctx(w), _p1(w), _game(w).board:find_first_by_type("tax")); w.on_tax = true end,
  ["玩家被收取<税金:int>金币"] = _tax_eq, ["玩家被收取{税金:int}金币"] = _tax_eq,
  ["税金为0"] = function(w) _ensure_tax(w); return dsl.eq(w.tax_amount, 0, "税金") end,
  ["玩家因余额为零而破产淘汰"] = function(w) _ensure_tax(w); return dsl.truthy(_p1(w).eliminated, "玩家应因零余额破产") end,
  ["玩家附有天使守护"] = function(w) _player(w).deities.angel = true; game_driver.set_player_deity(_ctx(w), _p1(w), "angel") end,
  ["玩家持有免税卡"] = function(w) _player(w).items.tax_free = true; game_driver.give_item(nil, _p1(w), TAX_FREE_CARD) end,
  ["弹出免税卡使用选择"] = function(w) return dsl.truthy(w.tax_free_prompt, "应弹出免税卡选择") end,
  ["若玩家确认则消耗免税卡并免税"] = function(w)
    local c = w.tax_free_prompt
    if c == true then return true end -- items 域 fixture 路径
    local game, p1 = _game(w), _p1(w)
    turn_driver.resolve_pending_choice(_ctx(w), "use")
    return dsl.all(function() return dsl.eq(game_driver.has_item(nil, p1, TAX_FREE_CARD), false, "免税卡应被消耗") end,
      function() return dsl.eq(game:player_cash(p1), w.tax_cash_before, "免税后现金") end)
  end,
  -- 跨域落地结算多路复用（旧 items 域契约保持；economy 税务分支走真实结算）。
  ["落地结算执行"] = function(w)
    if w.on_tax and w.tax_amount == nil then
      local game, p1 = _game(w), _p1(w)
      -- 免税卡确认经 resolve_pending_choice 就地解析(#201),无需停桩整回合驱动。
      w.tax_cash_before = game:player_cash(p1)
      local c = turn_driver.settle_landing(_ctx(w), p1)
      if c ~= nil and c.kind == "tax_card_prompt" then w.tax_free_prompt = c else w.tax_amount = w.tax_cash_before - game:player_cash(p1) end
      return true
    end
    local l = w.landing
    if l and l.type == "market" and l.sold_out then l.skip_choice, l.end_phase = true, true
    elseif l and l.type == "opponent_tile" and l.has_rent_free then
      l.auto_rent_free, l.rent_paid = true, false
      if l.has_seizure_card then l.seizure_prompt = true else l.no_manual_choice = true end
    end
    if w.landing_on_item_tile and w.player then
      local bag = w.player.bag or {}
      if #bag < (w.player.bag_limit or 5) then bag[#bag + 1] = { name = "random_item", weight_drawn = true }; w.player.bag, w.item_acquired = bag, true end
    end
    if w.player and w.player.items and w.player.items.tax_free then w.tax_free_prompt = w.tax_free_prompt or true end
    return true
  end,
  ["对手的地块等级为<等级:int>"] = function(w, a) w.seizure_tile = { level = a["等级"] } end,
  ["对手地块等级为<验证等级:int>"] = function(w, a) return dsl.eq(w.seizure_tile and w.seizure_tile.level, a["验证等级"], "对手地块等级") end,
  ["地块购买价为<地价:int>"] = function(w, a) w.seizure_tile.price = a["地价"] end,
  ["各级累计升级费为<累计升级费:int>"] = function(w, a) w.seizure_tile.cumulative_upgrade = a["累计升级费"] end,
  ["玩家使用强夺卡"] = function(w)
    local t = w.seizure_tile
    local total = t.price + t.cumulative_upgrade
    if w.player.cash >= total then w.player.cash = w.player.cash - total; w.seizure_paid, t.owner = total, "player" else w.seizure_failed = true end
  end,
  ["玩家支付<总投入:int>金币给对手"] = A("seizure_paid", "总投入", "强夺支付"),
  ["地块所有权转移给玩家"] = function(w) return dsl.eq(w.seizure_tile and w.seizure_tile.owner, "player", "地块归属") end,
  ["对手的地块总投入为5000"] = function(w) w.seizure_tile = { price = 5000, cumulative_upgrade = 0, level = 0 } end,
  ["玩家尝试使用强夺卡"] = function(w) w.seizure_unavailable = w.player.cash < (w.seizure_tile.price + w.seizure_tile.cumulative_upgrade) end,
  ["强夺卡不可用"] = function(w) return dsl.truthy(w.seizure_unavailable, "强夺卡应不可用") end,
}, { name = "economy" })
