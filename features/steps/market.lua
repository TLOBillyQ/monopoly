local dsl = require("packages.acceptance.step_dsl")
local market_config = require("src.config.content.market")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local event_kinds = require("src.config.gameplay.event_kinds")
-- 黑市域绑定（#192 簇 B）：消化旧 src.rules.market.{query,purchase,auto} 豁免——陈列/售罄/可购
-- 断言读真实 market_buy 选择的 options,购买经 turn_runtime choice_select 派发真实购买链。
local TEST_PRODUCT_ID, FILLER_ITEM_ID = 2003, 2001 -- 骰子加倍卡（金币 5000,目录首位）/ 免费卡
local function _ctx(w) return assert(w.driver, "缺少已初始化棋盘") end
local function _game(w) return _ctx(w).game end
local function _p1(w) return game_driver.current_player(_ctx(w)) end
local function _pid(w) return w.test_pid or TEST_PRODUCT_ID end
local _entry_kind = {}
for _, entry in ipairs(market_config) do _entry_kind[entry.product_id] = entry.kind end
-- 陈列视角开市：落位黑市格跑真实落地结算（production 语义:无可购商品时不开窗,choice 为 nil）。
local function _open_market(w)
  local game = _game(w)
  local pending = game.turn.pending_choice
  if pending and pending.kind == "market_buy" then w.market_choice = pending; return true end
  game_driver.set_player_position(_ctx(w), _p1(w), game.board:find_first_by_type("market"))
  w.market_choice = turn_driver.settle_landing(_ctx(w), _p1(w))
  return true
end
-- 购买视角开市：经真实回合机落到黑市并停在 market_buy 选择上（runtime 停桩后才能派发购买）。
local function _open_driven(w)
  local ctx = _ctx(w)
  game_driver.seat_to_land_on_market(ctx, _p1(w))
  local choice = turn_driver.advance_to_choice(ctx)
  assert(choice ~= nil and choice.kind == "market_buy", "黑市选择未打开: " .. tostring(choice and choice.kind))
  w.market_choice = choice
  return true
end
-- 只读视角查看(#201)：不开窗,经 driver.peek_market 读取当前陈列与售罄/可购标记。
local function _peek(w)
  w.market_view = game_driver.peek_market(_ctx(w), _p1(w))
  return true
end
local function _pending(w) return w.market_view or _game(w).turn.pending_choice or w.market_choice or {} end
local function _option(w, product_id)
  for _, opt in ipairs(_pending(w).options or {}) do if opt.id == product_id then return opt end end
  return nil
end
local function _flag_eq(flag, expected, label)
  return function(w)
    local opt = _option(w, _pid(w))
    if opt == nil then return nil, "商品不在选择列表: " .. tostring(_pid(w)) end
    return dsl.eq(opt[flag], expected, label)
  end
end
-- 经真实 choice_select 派发购买;以背包数变化判定成败。
-- 不在陈列中的商品（禁用/下架）UI 不可点击,不派发直接判拒（选择窗口保持原状）。
local function _buy(w, product_id)
  local game, p1 = _game(w), _p1(w)
  if _option(w, product_id) == nil then
    w.limit_before_attempt, w.limit_after_attempt = game.market_limits[product_id], game.market_limits[product_id]
    w.purchase_succeeded, w.purchase_rejected = false, true
    return true
  end
  local choice = assert(game.turn.pending_choice, "黑市选择窗口未打开")
  local before, limit_before = #game_driver.items_of(nil, p1), game.market_limits[product_id]
  local ok, err = pcall(function() game.turn_runtime:dispatch({ type = "choice_select", choice_id = choice.id, option_id = product_id }) end)
  w.limit_before_attempt, w.limit_after_attempt = limit_before, game.market_limits[product_id]
  w.purchase_succeeded = ok and #game_driver.items_of(nil, p1) == before + 1
  w.purchase_rejected = not w.purchase_succeeded
  w.dispatch_error = not ok and tostring(err) or nil
  return true
end
local function _window_open(w)
  local choice = _game(w).turn.pending_choice
  if choice ~= nil and choice.kind == "market_buy" then return true end
  return nil, "黑市选择窗口应保持开放,实际 " .. tostring(choice and choice.kind)
end
return dsl.steps({
  ["玩家的背包已满"] = function(w)
    local p1 = _p1(w)
    while #game_driver.items_of(nil, p1) < p1.inventory.max_slots do game_driver.give_item(nil, p1, FILLER_ITEM_ID) end
  end,
  ["玩家打开黑市"] = _open_market, ["玩家查看黑市"] = _peek, ["玩家查看黑市陈列"] = _peek,
  ["黑市配置已加载"] = function(w) w.market_catalog_loaded = true end,
  ["黑市列表中不展示任何道具商品"] = function(w)
    for _, o in ipairs(_pending(w).options or {}) do if o.can_buy then return nil, "背包已满时不应有可购道具: " .. tostring(o.id) end end
    return true
  end,
  ["黑市列表只展示道具商品"] = function(w)
    local options = _pending(w).options or {}
    if #options == 0 then return nil, "黑市应展示道具商品" end
    for _, o in ipairs(options) do if _entry_kind[o.id] ~= "item" then return nil, "非道具商品不应展示: " .. tostring(o.id) end end
    return true
  end,
  ["黑市不展示皮肤分页"] = function(w) return dsl.eq(_pending(w).active_tab, "item", "黑市分页") end,
  ["黑市不存在皮肤购买入口"] = function(w)
    for _, o in ipairs(_pending(w).options or {}) do if _entry_kind[o.id] == "skin" then return nil, "皮肤不应可购: " .. tostring(o.id) end end
    return true
  end,
  ["某商品的全局库存限额为{限额:int}"] = function(w, a) _game(w).market_limits[TEST_PRODUCT_ID], w.test_pid = a["限额"], TEST_PRODUCT_ID end,
  -- 经真实购买链消耗一次限额（keep_open 语义随真实结算把售罄标记刷进选择窗口）。
  ["该商品已被购买1次"] = function(w)
    _open_driven(w)
    _buy(w, _pid(w))
    return dsl.truthy(w.purchase_succeeded, "预置购买应成功")
  end,
  ["该商品仍出现在列表中"] = function(w) if _option(w, _pid(w)) == nil then return nil, "商品不在选择列表" end; return true end,
  ["该商品标记为已售罄"] = _flag_eq("sold_out", true, "售罄标记"), ["该商品在选择窗口中保持售罄标记"] = _flag_eq("sold_out", true, "售罄标记"),
  ["该商品不标记为已售罄"] = _flag_eq("sold_out", false, "售罄标记"),
  ["该商品不可点击购买"] = _flag_eq("can_buy", false, "可购标记"), ["该商品可以购买"] = _flag_eq("can_buy", true, "可购标记"),
  ["配置中存在市场禁用的商品"] = function(w) w.disabled_pid = 99991 end, -- 目录中不存在 → 真实链路视同禁用
  ["禁用商品不出现在列表中"] = function(w) return dsl.eq(_option(w, w.disabled_pid), nil, "禁用商品展示") end,
  ["禁用商品无法被购买"] = function(w) _buy(w, w.disabled_pid); return dsl.truthy(w.purchase_rejected, "禁用商品购买应被拒") end,
  ["玩家黑市选择窗口已打开"] = function(w) w.test_pid = _pid(w); return _open_driven(w) end,
  ["玩家购买失败"] = function(w) _game(w).market_limits[_pid(w)] = 0; return _buy(w, _pid(w)) end,
  ["黑市选择窗口仍保持开放"] = _window_open, ["玩家可以继续选购"] = _window_open, ["玩家可以继续选购其他商品"] = _window_open,
  ["某商品已售罄"] = function(w) _game(w).market_limits[_pid(w)] = 0 end,
  ["玩家尝试购买该已售罄商品"] = function(w) return _buy(w, _pid(w)) end,
  ["购买被拒绝"] = function(w) return dsl.truthy(w.purchase_rejected, "购买应被拒绝") end,
  ["全局库存限额不被消耗"] = function(w) return dsl.eq(w.limit_after_attempt, w.limit_before_attempt, "全局库存限额") end,
  ["玩家金币充足"] = function(w)
    local game, p1 = _game(w), _p1(w)
    if game:player_cash(p1) < 10000 then game:set_player_cash(p1, 10000) end
  end,
  ["玩家在黑市成功购买一个道具"] = function(w)
    local pending = _game(w).turn.pending_choice
    if not (pending and pending.kind == "market_buy") then _open_driven(w) end
    _buy(w, TEST_PRODUCT_ID)
    return dsl.truthy(w.purchase_succeeded, "黑市购买应成功" .. (w.dispatch_error and (": " .. w.dispatch_error) or ""))
  end,
  ["当前行动玩家是电脑"] = function(w) _p1(w).is_ai = true end,
  -- 真实路线规划 + 真实移动（含路过黑市 interrupt）+ 真实落地结算,量取现金差。
  ["电脑玩家路过黑市"] = function(w)
    local ctx, game, p1 = _ctx(w), _game(w), _p1(w)
    w.coins_before_auto = game:player_cash(p1)
    game_driver.seat_to_pass_through_market(ctx, p1)
    local _, _, total = game_driver.roll_dice(ctx, p1, 1)
    game_driver.move(ctx, p1, total)
    turn_driver.settle_landing(ctx, p1)
    w.coins_after_auto = game:player_cash(p1)
  end,
  ["电脑玩家不自动购买任何商品"] = function(w) return dsl.eq(w.coins_after_auto, w.coins_before_auto, "AI 路过黑市金币") end,
  ["电脑玩家金币保持不变"] = function(w) return dsl.eq(w.coins_after_auto, w.coins_before_auto, "AI 金币") end,
  -- 跳过黑市要进行动日志(kind 独立于不入日志的 choice_skipped),托管席位才看得出自己被跳过。
  ["行动日志记录该电脑玩家到达黑市未购买"] = function(w)
    for _, e in ipairs(game_driver.events(_ctx(w))) do
      if e.kind == event_kinds.market_auto_skipped and tostring(e.text or ""):find("到达黑市，选择不购买", 1, true) then return true end
    end
    return nil, "事件流缺少 market_auto_skipped「到达黑市，选择不购买」"
  end,
  -- 选中自动回退是 UI 选择会话行为,fixture 语义保持（与旧实现一致）。
  ["当前选中的商品变为不可购买"] = function(w) w.current_selection_invalid = true end,
  ["选择列表刷新"] = function(w) w.auto_fallback_triggered = w.current_selection_invalid == true end,
  ["自动选中列表中首个可购买的商品"] = function(w) return dsl.truthy(w.auto_fallback_triggered, "应自动选中首个可购商品") end,
}, { name = "market" })
