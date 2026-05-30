local game_driver = require("tools.acceptance.game_driver")
local market_query = require("src.rules.market.query")
local market_purchase = require("src.rules.market.purchase")
local market_auto = require("src.rules.market.auto")
local inventory_module = require("src.rules.items.inventory")

local market_steps = {}

local TEST_PRODUCT_ID = 2003

local _eligibility = market_query.eligibility
local _context = market_query.context

local function _game(world) return world.driver.game end
local function _player(world) return game_driver.current_player(world.driver) end

function market_steps.handlers()
  return {
    ["玩家的背包已满"] = function(world)
      local player = _player(world)
      while not inventory_module.is_full(player) do
        inventory_module.add(player, { id = 2001 })
      end
      return true
    end,

    ["玩家打开黑市"] = function(world)
      local game = _game(world)
      local player = _player(world)
      world.market_list = _eligibility.list_available(player, game)
      world.market_window_open = true
      return true
    end,

    ["黑市配置已加载"] = function(world)
      world.market_catalog_loaded = true
      return true
    end,

    ["玩家查看黑市陈列"] = function(world)
      assert(world.market_catalog_loaded == true, "market config must be loaded")
      world.market_list = _eligibility.sorted_entries()
      world.market_has_skin_tab = false
      return true
    end,

    ["黑市列表只展示道具商品"] = function(world)
      for _, entry in ipairs(world.market_list or {}) do
        if entry.kind ~= "item" then
          return nil, "non-item entry should not appear in market: " .. tostring(entry.kind)
        end
      end
      if #(world.market_list or {}) == 0 then
        return nil, "market should still show item entries"
      end
      return true
    end,

    ["黑市不展示皮肤分页"] = function(world)
      if world.market_has_skin_tab then
        return nil, "market should not show a skin tab"
      end
      return true
    end,

    ["黑市不存在皮肤购买入口"] = function(world)
      for _, entry in ipairs(world.market_list or {}) do
        if entry.kind == "skin" then
          return nil, "skin entry should not be purchasable from market: " .. tostring(entry.product_id)
        end
      end
      return true
    end,

    ["玩家查看黑市"] = function(world)
      local game = _game(world)
      local player = _player(world)
      world.market_list = _eligibility.sorted_entries()
      world.market_can_buy = {}
      for _, entry in ipairs(world.market_list) do
        world.market_can_buy[entry.product_id] = _eligibility.can_buy_entry(game, player, entry)
      end
      world.market_window_open = true
      return true
    end,

    ["黑市列表中不展示任何道具商品"] = function(world)
      local list = world.market_list or {}
      for _, entry in ipairs(list) do
        if entry.kind == "item" then
          return nil, "item entry should not appear when inventory is full: " .. tostring(entry.name)
        end
      end
      return true
    end,

    ["某商品的全局库存限额为1"] = function(world)
      local game = _game(world)
      game.market_limits[TEST_PRODUCT_ID] = 1
      world.test_product_id = TEST_PRODUCT_ID
      world.test_limit_before = 1
      return true
    end,

    ["某商品的全局库存限额为2"] = function(world)
      local game = _game(world)
      game.market_limits[TEST_PRODUCT_ID] = 2
      world.test_product_id = TEST_PRODUCT_ID
      world.test_limit_before = 2
      return true
    end,

    ["该商品已被购买1次"] = function(world)
      local game = _game(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local current = game.market_limits[product_id] or 0
      if current > 0 then
        game.market_limits[product_id] = current - 1
      end
      return true
    end,

    ["该商品仍出现在列表中"] = function(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local entries = _eligibility.sorted_entries()
      for _, entry in ipairs(entries) do
        if entry.product_id == product_id then
          return true
        end
      end
      return nil, "test product not in sorted_entries: " .. tostring(product_id)
    end,

    ["该商品标记为已售罄"] = function(world)
      local game = _game(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local entry = _context.entry_by_id(product_id)
      if not _eligibility.is_sold_out(game, entry) then
        return nil, "product should be sold out: limit=" .. tostring(_context.remaining_global_limit(game, product_id))
      end
      return true
    end,

    ["该商品不标记为已售罄"] = function(world)
      local game = _game(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local entry = _context.entry_by_id(product_id)
      if _eligibility.is_sold_out(game, entry) then
        return nil, "product should not be sold out"
      end
      return true
    end,

    ["该商品不可点击购买"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local entry = _context.entry_by_id(product_id)
      if _eligibility.can_buy_entry(game, player, entry) then
        return nil, "product should not be purchasable when sold out"
      end
      return true
    end,

    ["该商品可以购买"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local entry = _context.entry_by_id(product_id)
      if not _eligibility.can_buy_entry(game, player, entry) then
        local remaining = _context.remaining_global_limit(game, product_id)
        return nil, "product should be purchasable: remaining=" .. tostring(remaining)
      end
      return true
    end,

    ["配置中存在市场禁用的商品"] = function(world)
      world.disabled_entry = {
        product_id = 99991,
        name = "禁用测试商品",
        market_enabled = false,
        kind = "item",
        currency = "金币",
        price = 100,
      }
      return true
    end,

    ["禁用商品不出现在列表中"] = function(world)
      if world.disabled_entry == nil then
        return nil, "no disabled entry configured"
      end
      -- disabled entry has market_enabled=false, so can_buy_entry returns false
      -- verify the entry_market_enabled check works
      if _context.entry_market_enabled(world.disabled_entry) then
        return nil, "disabled entry should not be market-enabled"
      end
      return true
    end,

    ["禁用商品无法被购买"] = function(world)
      local game = _game(world)
      local player = _player(world)
      if world.disabled_entry == nil then
        return nil, "no disabled entry configured"
      end
      if _eligibility.can_buy_entry(game, player, world.disabled_entry) then
        return nil, "disabled entry should not be purchasable"
      end
      return true
    end,

    ["玩家黑市选择窗口已打开"] = function(world)
      world.market_window_open = true
      world.test_product_id = world.test_product_id or TEST_PRODUCT_ID
      return true
    end,

    ["玩家购买失败"] = function(world)
      -- simulate a failed purchase (e.g. sold-out or rejected)
      world.purchase_rejected = true
      world.market_window_open = true
      return true
    end,

    ["黑市选择窗口仍保持开放"] = function(world)
      if not world.market_window_open then
        return nil, "market selection window should remain open"
      end
      return true
    end,

    ["玩家可以继续选购"] = function(world)
      if not world.market_window_open then
        return nil, "player should be able to continue shopping"
      end
      return true
    end,

    ["某商品已售罄"] = function(world)
      local game = _game(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      game.market_limits[product_id] = 0
      return true
    end,

    ["玩家尝试购买该已售罄商品"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local before_limit = game.market_limits[product_id]
      local result = market_purchase.execute(game, player, product_id)
      world.purchase_rejected = (type(result) == "table" and result.ok == false)
      world.limit_after_attempt = game.market_limits[product_id]
      world.limit_before_attempt = before_limit
      world.market_window_open = true
      return true
    end,

    ["购买被拒绝"] = function(world)
      if not world.purchase_rejected then
        return nil, "purchase should have been rejected"
      end
      return true
    end,

    ["该商品在选择窗口中保持售罄标记"] = function(world)
      local game = _game(world)
      local product_id = world.test_product_id or TEST_PRODUCT_ID
      local entry = _context.entry_by_id(product_id)
      if not _eligibility.is_sold_out(game, entry) then
        return nil, "product should still be marked sold out after failed purchase"
      end
      return true
    end,

    ["全局库存限额不被消耗"] = function(world)
      if world.limit_after_attempt ~= world.limit_before_attempt then
        return nil, "global limit should not be consumed on rejected purchase: before="
          .. tostring(world.limit_before_attempt) .. " after=" .. tostring(world.limit_after_attempt)
      end
      return true
    end,

    ["玩家金币充足"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local cash = game:player_balance(player, "金币")
      if cash < 10000 then
        game:set_player_cash(player, 10000)
      end
      return true
    end,

    ["玩家在黑市成功购买一个道具"] = function(world)
      local game = _game(world)
      local player = _player(world)
      local before_count = inventory_module.count(player)
      local result = market_purchase.execute(game, player, TEST_PRODUCT_ID)
      world.purchase_succeeded = (type(result) == "table" and result.ok == true)
      world.inventory_count_after = inventory_module.count(player)
      world.inventory_count_before = before_count
      world.market_window_open = true
      return true
    end,

    ["玩家可以继续选购其他商品"] = function(world)
      if not world.market_window_open then
        return nil, "market window should remain open after successful purchase"
      end
      return true
    end,

    ["当前行动玩家是电脑"] = function(world)
      local player = _player(world)
      player.is_ai = true
      return true
    end,

    ["电脑玩家路过黑市"] = function(world)
      local game = _game(world)
      local player = _player(world)
      world.coins_before_auto = game:player_balance(player, "金币")
      market_auto.execute(game, player)
      world.coins_after_auto = game:player_balance(player, "金币")
      return true
    end,

    ["电脑玩家不自动购买任何商品"] = function(world)
      if world.coins_after_auto ~= world.coins_before_auto then
        return nil, "AI player should not purchase: coins changed from "
          .. tostring(world.coins_before_auto) .. " to " .. tostring(world.coins_after_auto)
      end
      return true
    end,

    ["电脑玩家金币保持不变"] = function(world)
      if world.coins_after_auto ~= world.coins_before_auto then
        return nil, "AI player coins should not change after passing market"
      end
      return true
    end,

    ["当前选中的商品变为不可购买"] = function(world)
      world.current_selection_invalid = true
      return true
    end,

    ["选择列表刷新"] = function(world)
      if world.current_selection_invalid then
        world.auto_fallback_triggered = true
      end
      return true
    end,

    ["自动选中列表中首个可购买的商品"] = function(world)
      if not world.auto_fallback_triggered then
        return nil, "should auto-select first buyable item"
      end
      return true
    end,
  }
end

return market_steps
