local dsl = require("packages.acceptance.step_dsl")
local logger = require("src.foundation.log")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local paid_purchase_gateway = require("src.host.paid_purchase_gateway")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
-- 付费货币域绑定（#192 簇 B）：消化旧 src.rules.market.purchase 豁免——购买一律经真实黑市选择的
-- choice_select 派发；宿主侧走真实 paid_purchase_gateway + 桩宿主环境,断言全部落在可观测面。
local PAID_PRODUCT_ID, PAID_GOODS_ID = 2009, "goods_strong_card"
local function _ctx(w) return assert(w.driver, "缺少已初始化棋盘") end
local function _game(w) return _ctx(w).game end
local function _p1(w) return game_driver.current_player(_ctx(w)) end
local function _items(w) return #game_driver.items_of(nil, _p1(w)) end
local function _limit(w) return _game(w).market_limits[PAID_PRODUCT_ID] end
local function _panels(w) return #w.paid_env.panel_calls end
local function _open_market(w)
  local ctx = _ctx(w)
  game_driver.seat_to_land_on_market(ctx, _p1(w))
  local choice = turn_driver.advance_to_choice(ctx)
  assert(choice ~= nil and choice.kind == "market_buy", "黑市选择未打开: " .. tostring(choice and choice.kind))
end
local function _buy(w)
  local game = _game(w)
  local choice = assert(game.turn.pending_choice, "黑市选择窗口未打开")
  game.turn_runtime:dispatch({ type = "choice_select", choice_id = choice.id, option_id = PAID_PRODUCT_ID })
  return true
end
local function _new_role(role_id, panel_calls)
  return {
    get_roleid = function() return role_id end,
    set_goods_panel_visible = function() end,
    show_goods_purchase_panel = function(goods_id, show_time) panel_calls[#panel_calls + 1] = { role_id = role_id, goods_id = goods_id, show_time = show_time } end,
  }
end
-- 先经真实回合机打开黑市选择,再铺宿主桩环境（顺序保证开市不受桩污染）。
local function _setup(w, opts)
  opts = opts or {}
  _open_market(w)
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(paid_purchase_gateway)
  local env = { panel_calls = {}, trigger_handlers = {}, role_by_player_id = {}, scheduled = {} }
  for _, p in ipairs(_game(w).players) do env.role_by_player_id[p.id] = _new_role(p.id, env.panel_calls) end
  w.paid_saved = { resolve_role = runtime_ports.resolve_role, schedule = runtime_ports.schedule,
    GameAPI = _G.GameAPI, RegisterTriggerEvent = _G.RegisterTriggerEvent, EVENT = _G.EVENT }
  runtime_ports.resolve_role = function(player_id) return env.role_by_player_id[player_id] end
  runtime_ports.schedule = function(_, fn) env.scheduled[#env.scheduled + 1] = fn end
  _G.GameAPI = {
    random_int = _G.GameAPI and _G.GameAPI.random_int or function(min) return min end,
    get_goods_list = function() return opts.goods_list or { { name = "强征卡", goods_id = PAID_GOODS_ID } } end,
  }
  _G.RegisterTriggerEvent = function(args, callback) env.trigger_handlers[args and args[2] or false] = callback end
  _G.EVENT = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" }
  if opts.capture_warns then
    w.paid_saved.warn, w.captured_warns = logger.warn, {}
    logger.warn = function(...) w.captured_warns[#w.captured_warns + 1] = table.concat({ ... }, " ") end
  end
  w.paid_env = env
  w.before_items, w.before_limit = _items(w), _limit(w)
  return true
end
local function _cleanup(w)
  local s = w.paid_saved or {}
  runtime_ports.resolve_role, runtime_ports.schedule = s.resolve_role, s.schedule
  _G.GameAPI, _G.RegisterTriggerEvent, _G.EVENT = s.GameAPI, s.RegisterTriggerEvent, s.EVENT
  if s.warn ~= nil then logger.warn = s.warn end
  w.paid_saved = nil
  paid_purchase_port.reset_for_tests()
end
local function _fire_callback(w)
  local p = _p1(w)
  local callback = w.paid_env.trigger_handlers[p.id]
  if type(callback) ~= "function" then return nil, "未注册支付回调: player " .. tostring(p.id) end
  callback(nil, nil, { role = w.paid_env.role_by_player_id[p.id], goods_id = PAID_GOODS_ID })
  return true
end
local function _mapping_warns(w)
  local count = 0
  for _, warn in ipairs(w.captured_warns or {}) do
    if warn:find("market paid goods mapping missing:", 1, true) then count = count + 1 end
  end
  return count
end
return dsl.steps({
  ["黑市中存在付费货币商品"] = function(w) return _setup(w) end,
  ["玩家选择购买该付费道具"] = _buy,
  ["宿主支付面板被打开一次"] = function(w) return dsl.eq(_panels(w), 1, "支付面板调用数") end,
  ["黑市选择窗口保持开放等待支付回调"] = function(w)
    local choice = _game(w).turn.pending_choice
    local ok = choice ~= nil and choice.kind == "market_buy"
    _cleanup(w)
    return dsl.truthy(ok, "黑市窗口应等待回调保持开放")
  end,
  ["玩家已发起付费道具购买"] = function(w) _setup(w); return _buy(w) end,
  ["宿主支付回调成功到达"] = _fire_callback,
  ["道具被加入玩家背包"] = function(w) return dsl.eq(_items(w), w.before_items + 1, "背包道具数") end,
  ["该商品全局库存减少{减少数:int}"] = function(w, a)
    local ok, err = dsl.eq(_limit(w), w.before_limit - a["减少数"], "全局库存")
    _cleanup(w); return ok, err
  end,
  ["付费道具在宿主商品列表中没有对应映射"] = function(w)
    return _setup(w, { goods_list = { { name = "不存在的商品", goods_id = "goods_unknown" } }, capture_warns = true })
  end,
  ["玩家尝试购买该付费道具"] = function(w)
    _buy(w)
    w.purchase_rejected = _items(w) == w.before_items and _limit(w) == w.before_limit
  end,
  ["支付面板不被打开"] = function(w) return dsl.eq(_panels(w), 0, "支付面板调用数") end,
  ["系统记录缺少映射的警告"] = function(w) local n = _mapping_warns(w); _cleanup(w); return dsl.truthy(n > 0, "应记录缺少映射警告") end,
  ["玩家连续两次尝试购买该付费道具"] = function(w) _buy(w); return _buy(w) end,
  ["缺少映射的警告仅被记录一次"] = function(w) local n = _mapping_warns(w); _cleanup(w); return dsl.eq(n, 1, "缺少映射警告次数") end,
  ["玩家已发起付费道具购买且回调尚未到达"] = function(w) _setup(w); _buy(w); w.panel_count_after_first = _panels(w) end,
  ["玩家再次尝试购买同一付费道具"] = function(w) w.items_before_second = _items(w); return _buy(w) end,
  ["第二次请求被拒绝"] = function(w) return dsl.eq(_items(w), w.items_before_second, "第二次请求后背包数") end,
  ["支付面板不被再次打开"] = function(w)
    local ok, err = dsl.eq(_panels(w), w.panel_count_after_first, "支付面板调用数")
    _cleanup(w); return ok, err
  end,
  ["购买请求已超时"] = function(w)
    for _, fn in ipairs(w.paid_env.scheduled) do if type(fn) == "function" then fn() end end
    w.paid_env.scheduled = {}
  end,
  ["玩家再次尝试购买该付费道具"] = _buy,
  ["购买请求被正常发起"] = function(w) return dsl.truthy(_panels(w) > (w.panel_count_after_first or 0), "超时后购买应重新发起") end,
  ["支付面板被打开"] = function(w) local n = _panels(w); _cleanup(w); return dsl.truthy(n >= 1, "支付面板应被打开") end,
  ["黑市中存在付费货币商品且库存充足"] = function(w)
    _setup(w)
    local game = _game(w)
    if (game.market_limits[PAID_PRODUCT_ID] or 0) < 2 then game.market_limits[PAID_PRODUCT_ID] = 10 end
    game_driver.clear_items(nil, _p1(w))
    w.before_items, w.before_limit = _items(w), _limit(w)
  end,
  ["玩家完成第一次付费购买并收到回调"] = function(w) _buy(w); return _fire_callback(w) end,
  ["玩家发起第二次相同商品的付费购买并收到回调"] = function(w) _buy(w); return _fire_callback(w) end,
  ["玩家背包中收到两件该道具"] = function(w) return dsl.eq(_items(w), w.before_items + 2, "背包道具数") end,
}, { name = "paid_currency" })
