local logger = require("src.foundation.log")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local paid_purchase_gateway = require("src.host.paid_purchase_gateway")
local game_driver = require("tools.acceptance.game_driver")
local inventory_module = require("src.rules.items.inventory")
local market_purchase = require("src.rules.market.purchase")

local paid_currency_steps = {}

local PAID_PRODUCT_ID = 2009
local PAID_GOODS_ID = "goods_strong_card"
local PAID_ITEM_NAME = "强征卡"

local function _game(world) return world.driver.game end
local function _player(world) return game_driver.current_player(world.driver) end

local function _new_role(role_id, panel_calls)
  local role = { role_id = role_id }
  role.get_roleid = function() return role.role_id end
  role.show_goods_purchase_panel = function(goods_id, show_time)
    panel_calls[#panel_calls + 1] = { role_id = role_id, goods_id = goods_id, show_time = show_time }
  end
  role.set_goods_panel_visible = function() end
  return role
end

local function _setup_paid_env(world, opts)
  opts = opts or {}
  local game = _game(world)

  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(paid_purchase_gateway)

  local panel_calls = {}
  local role_by_player_id = {}
  for _, p in ipairs(game.players) do
    role_by_player_id[p.id] = _new_role(p.id, panel_calls)
  end

  local goods_list = opts.goods_list or {
    { name = PAID_ITEM_NAME, goods_id = PAID_GOODS_ID },
  }
  local trigger_handlers = {}
  local scheduled_callbacks = {}

  world._saved_resolve_role = runtime_ports.resolve_role
  runtime_ports.resolve_role = function(player_id)
    return role_by_player_id[player_id]
  end

  world._saved_schedule = runtime_ports.schedule
  runtime_ports.schedule = function(_, fn)
    scheduled_callbacks[#scheduled_callbacks + 1] = fn
  end

  world._saved_GameAPI = _G.GameAPI
  _G.GameAPI = {
    random_int = _G.GameAPI and _G.GameAPI.random_int or function(mn, _) return mn end,
    get_goods_list = function() return goods_list end,
  }

  world._saved_RegisterTriggerEvent = _G.RegisterTriggerEvent
  _G.RegisterTriggerEvent = function(args, callback)
    local role_id = args and args[2] or nil
    trigger_handlers[role_id] = callback
  end

  world._saved_EVENT = _G.EVENT
  _G.EVENT = { SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS" }

  if opts.capture_warns then
    world._saved_warn = logger.warn
    world.captured_warns = {}
    logger.warn = function(...)
      world.captured_warns[#world.captured_warns + 1] = table.concat({ ... }, " ")
    end
  end

  world.paid_env = {
    panel_calls = panel_calls,
    trigger_handlers = trigger_handlers,
    role_by_player_id = role_by_player_id,
    scheduled_callbacks = scheduled_callbacks,
  }
  return world.paid_env
end

local function _cleanup_paid_env(world)
  if world._saved_resolve_role ~= nil then
    runtime_ports.resolve_role = world._saved_resolve_role
    world._saved_resolve_role = nil
  end
  if world._saved_schedule ~= nil then
    runtime_ports.schedule = world._saved_schedule
    world._saved_schedule = nil
  end
  if world._saved_GameAPI ~= nil then
    _G.GameAPI = world._saved_GameAPI
    world._saved_GameAPI = nil
  end
  if world._saved_RegisterTriggerEvent ~= nil then
    _G.RegisterTriggerEvent = world._saved_RegisterTriggerEvent
    world._saved_RegisterTriggerEvent = nil
  end
  if world._saved_EVENT ~= nil then
    _G.EVENT = world._saved_EVENT
    world._saved_EVENT = nil
  end
  if world._saved_warn ~= nil then
    logger.warn = world._saved_warn
    world._saved_warn = nil
  end
  paid_purchase_port.reset_for_tests()
end

local function _fire_callback(world, goods_id)
  local player = _player(world)
  local cb = world.paid_env.trigger_handlers[player.id]
  if type(cb) ~= "function" then
    return nil, "purchase callback not registered for player " .. tostring(player.id)
  end
  cb(nil, nil, {
    role = world.paid_env.role_by_player_id[player.id],
    goods_id = goods_id or PAID_GOODS_ID,
  })
  return true
end

function paid_currency_steps.handlers()
  return {
    ["黑市中存在付费货币商品"] = function(world)
      _setup_paid_env(world, {})
      world.before_inventory_count = inventory_module.count(_player(world))
      world.before_market_limit = _game(world).market_limits[PAID_PRODUCT_ID]
      return true
    end,

    ["玩家选择购买该付费道具"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      world.purchase_rejected = not (type(result) == "table" and result.ok == true)
      return true
    end,

    ["宿主支付面板被打开一次"] = function(world)
      local count = #world.paid_env.panel_calls
      if count ~= 1 then
        return nil, "expected 1 panel call, got " .. tostring(count)
      end
      return true
    end,

    ["黑市选择窗口保持开放等待支付回调"] = function(world)
      local result = world.purchase_result
      if not (type(result) == "table" and result.deferred_fulfillment == true) then
        return nil, "expected deferred_fulfillment=true, got: " .. tostring(result and result.deferred_fulfillment)
      end
      _cleanup_paid_env(world)
      return true
    end,

    ["玩家已发起付费道具购买"] = function(world)
      _setup_paid_env(world, {})
      local game = _game(world)
      local player = _player(world)
      world.before_inventory_count = inventory_module.count(player)
      world.before_market_limit = game.market_limits[PAID_PRODUCT_ID]
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      return true
    end,

    ["宿主支付回调成功到达"] = function(world)
      local ok, err = _fire_callback(world)
      if not ok then
        return nil, err
      end
      return true
    end,

    ["道具被加入玩家背包"] = function(world)
      local after = inventory_module.count(_player(world))
      if after ~= world.before_inventory_count + 1 then
        return nil, "expected inventory count " .. tostring(world.before_inventory_count + 1)
          .. ", got " .. tostring(after)
      end
      return true
    end,

    ["该商品全局库存减少1"] = function(world)
      local after = _game(world).market_limits[PAID_PRODUCT_ID]
      local expected = world.before_market_limit - 1
      if after ~= expected then
        return nil, "expected market_limit " .. tostring(expected) .. ", got " .. tostring(after)
      end
      _cleanup_paid_env(world)
      return true
    end,

    ["付费道具在宿主商品列表中没有对应映射"] = function(world)
      _setup_paid_env(world, {
        goods_list = { { name = "不存在的商品", goods_id = "goods_unknown" } },
        capture_warns = true,
      })
      return true
    end,

    ["玩家尝试购买该付费道具"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      world.purchase_rejected = not (type(result) == "table" and result.ok == true)
      return true
    end,

    ["支付面板不被打开"] = function(world)
      local count = #world.paid_env.panel_calls
      if count ~= 0 then
        return nil, "expected 0 panel calls, got " .. tostring(count)
      end
      return true
    end,

    ["系统记录缺少映射的警告"] = function(world)
      local found = false
      for _, w in ipairs(world.captured_warns or {}) do
        if w:find("market paid goods mapping missing:", 1, true) then
          found = true
          break
        end
      end
      _cleanup_paid_env(world)
      if not found then
        return nil, "no mapping missing warning was logged"
      end
      return true
    end,

    ["玩家连续两次尝试购买该付费道具"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local r1 = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      local r2 = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_results = { r1, r2 }
      world.purchase_rejected = not (type(r1) == "table" and r1.ok == true)
      return true
    end,

    ["缺少映射的警告仅被记录一次"] = function(world)
      local count = 0
      for _, w in ipairs(world.captured_warns or {}) do
        if w:find("market paid goods mapping missing:", 1, true) then
          count = count + 1
        end
      end
      _cleanup_paid_env(world)
      if count ~= 1 then
        return nil, "expected warn count 1, got " .. tostring(count)
      end
      return true
    end,

    ["玩家已发起付费道具购买且回调尚未到达"] = function(world)
      _setup_paid_env(world, {})
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      world.panel_count_after_first = #world.paid_env.panel_calls
      return true
    end,

    ["玩家再次尝试购买同一付费道具"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.second_purchase_result = result
      world.purchase_rejected = not (type(result) == "table" and result.ok == true)
      return true
    end,

    ["第二次请求被拒绝"] = function(world)
      local result = world.second_purchase_result
      if not (type(result) == "table" and result.ok == false) then
        return nil, "second purchase should be rejected, got ok=" .. tostring(result and result.ok)
      end
      return true
    end,

    ["支付面板不被再次打开"] = function(world)
      local count = #world.paid_env.panel_calls
      local expected = world.panel_count_after_first or 1
      if count ~= expected then
        return nil, "panel should not open again: expected count=" .. tostring(expected)
          .. " got=" .. tostring(count)
      end
      _cleanup_paid_env(world)
      return true
    end,

    ["玩家再次尝试购买该付费道具"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      world.purchase_rejected = not (type(result) == "table" and result.ok == true)
      return true
    end,

    ["购买请求已超时"] = function(world)
      local scheduled = world.paid_env.scheduled_callbacks
      for _, fn in ipairs(scheduled) do
        if type(fn) == "function" then
          fn()
        end
      end
      world.paid_env.scheduled_callbacks = {}
      return true
    end,

    ["购买请求被正常发起"] = function(world)
      local result = world.purchase_result
      if not (type(result) == "table" and result.ok == true) then
        return nil, "purchase should succeed after timeout, got ok=" .. tostring(result and result.ok)
      end
      return true
    end,

    ["支付面板被打开"] = function(world)
      local count = #world.paid_env.panel_calls
      if count < 1 then
        return nil, "expected at least 1 panel call, got " .. tostring(count)
      end
      _cleanup_paid_env(world)
      return true
    end,

    ["黑市中存在付费货币商品且库存充足"] = function(world)
      _setup_paid_env(world, {})
      local game = _game(world)
      local player = _player(world)
      if game.market_limits[PAID_PRODUCT_ID] < 2 then
        game.market_limits[PAID_PRODUCT_ID] = 10
      end
      inventory_module.clear(player)
      world.before_inventory_count = inventory_module.count(player)
      world.before_market_limit = game.market_limits[PAID_PRODUCT_ID]
      return true
    end,

    ["玩家完成第一次付费购买并收到回调"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      local ok, err = _fire_callback(world)
      if not ok then
        return nil, err
      end
      return true
    end,

    ["玩家发起第二次相同商品的付费购买并收到回调"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local result = market_purchase.execute(game, player, PAID_PRODUCT_ID)
      world.purchase_result = result
      local ok, err = _fire_callback(world)
      if not ok then
        return nil, err
      end
      return true
    end,

    ["玩家背包中收到两件该道具"] = function(world)
      local after = inventory_module.count(_player(world))
      local expected = world.before_inventory_count + 2
      if after ~= expected then
        return nil, "expected inventory count " .. tostring(expected) .. ", got " .. tostring(after)
      end
      return true
    end,

    ["该商品全局库存减少2"] = function(world)
      local after = _game(world).market_limits[PAID_PRODUCT_ID]
      local expected = world.before_market_limit - 2
      if after ~= expected then
        return nil, "expected market_limit " .. tostring(expected) .. ", got " .. tostring(after)
      end
      _cleanup_paid_env(world)
      return true
    end,
  }
end

return paid_currency_steps
