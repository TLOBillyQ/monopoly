local strategy = require("src.rules.items.strategy")
local item_ids = require("src.config.gameplay.item_ids")

local function _test_try_use_item_cond_false_returns_nil()
  local game = { turn = { phase = "pre_action" } }
  local player = { id = 1, status = { inventory = {} } }
  local called_cond = false
  local cond = function()
    called_cond = true
    return false
  end
  local result = strategy._try_use_item(game, player, 1, cond, false)
  assert(result == nil, "should return nil when cond returns false")
  assert(called_cond == true, "should have called cond")
end

local function _test_try_use_item_no_inventory_returns_nil()
  local game = { turn = { phase = "pre_action" } }
  local player = {
    id = 1,
    inventory = {
      items = {},
      find_index = function()
        return nil
      end,
    },
  }
  local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, false)
  assert(result == nil, "should return nil when item not in inventory")
end

local function _test_try_use_item_not_ai_usable_returns_nil()
  local game = { turn = { phase = "post_action" } }
  local player = { id = 1, status = { inventory = {} } }
  local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, false)
  assert(result == nil, "should return nil when item not AI-usable in phase")
end

local function _test_try_use_item_returns_waiting_payload()
  local inventory_module = require("src.rules.items.inventory")
  local executor_module = require("src.rules.items.executor")
  local original_cfg = inventory_module.cfg
  local original_find_index = inventory_module.find_index
  local original_use_item = executor_module.use_item
  inventory_module.cfg = function()
    return { offer_in_phases = { "pre_action" } }
  end
  inventory_module.find_index = function() return 1 end
  executor_module.use_item = function(_, _, _, opts)
    assert(opts.by_ai == true, "expected by_ai flag")
    assert(opts.auto_play == true, "expected auto_play flag")
    return { waiting = true, source = "test" }
  end

  local ok, err = pcall(function()
    local game = { turn = { phase = "pre_action" } }
    local player = { id = 1, status = { inventory = { item_ids.dice_multiplier } } }
    local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, true)
    assert(type(result) == "table", "should return waiting table")
    assert(result.source == "test", "should preserve executor payload")
  end)

  inventory_module.cfg = original_cfg
  inventory_module.find_index = original_find_index
  executor_module.use_item = original_use_item
  if not ok then
    error(err)
  end
end

local function _test_try_use_item_returns_nil_for_non_waiting_result()
  local inventory_module = require("src.rules.items.inventory")
  local executor_module = require("src.rules.items.executor")
  local original_cfg = inventory_module.cfg
  local original_find_index = inventory_module.find_index
  local original_use_item = executor_module.use_item
  inventory_module.cfg = function()
    return { offer_in_phases = { "pre_action" } }
  end
  inventory_module.find_index = function() return 1 end
  executor_module.use_item = function() return true end

  local ok, err = pcall(function()
    local game = { turn = { phase = "pre_action" } }
    local player = { id = 1, status = { inventory = { item_ids.dice_multiplier } } }
    local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, false)
    assert(result == nil, "should ignore non-waiting executor result")
  end)

  inventory_module.cfg = original_cfg
  inventory_module.find_index = original_find_index
  executor_module.use_item = original_use_item
  if not ok then
    error(err)
  end
end

return {
  name = "items_strategy",
  tests = {
    { name = "_test_try_use_item_cond_false_returns_nil", run = _test_try_use_item_cond_false_returns_nil },
    { name = "_test_try_use_item_no_inventory_returns_nil", run = _test_try_use_item_no_inventory_returns_nil },
    { name = "_test_try_use_item_not_ai_usable_returns_nil", run = _test_try_use_item_not_ai_usable_returns_nil },
    { name = "_test_try_use_item_returns_waiting_payload", run = _test_try_use_item_returns_waiting_payload },
    { name = "_test_try_use_item_returns_nil_for_non_waiting_result", run = _test_try_use_item_returns_nil_for_non_waiting_result },
  },
}
