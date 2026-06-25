local strategy = require("src.rules.items.strategy")
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")

local function _new_game()
  return support.new_game({ map = default_map })
end

describe("items_strategy", function()
  it("auto_pre_action_returns_use_flow_result_for_target_items", function()
    local g = _new_game()
    local actor = g.players[2]
    local target = g.players[1]
    actor.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })

    local result = strategy.auto_pre_action(g, actor, "pre_action")

    assert(type(result) == "table", "auto target item should return a use-flow result")
    assert(result.ok == true, "auto target item should apply successfully")
    assert(result.status == "applied", "auto target item should be normalized as applied")
    assert(result.actor_id == actor.id, "auto target item result should carry actor id")
    assert(result.item_id == item_ids.steal, "auto target item result should carry item id")
    assert(result.item_consumed == true, "auto target item should consume the item")
  end)

  it("_test_try_use_item_cond_false_returns_nil", function()
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
  end)

  it("_test_try_use_item_no_inventory_returns_nil", function()
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
  end)

  it("_test_try_use_item_not_ai_usable_returns_nil", function()
    local game = { turn = { phase = "post_action" } }
    local player = { id = 1, status = { inventory = {} } }
    local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, false)
    assert(result == nil, "should return nil when item not AI-usable in phase")
  end)

  it("_test_try_use_item_returns_waiting_payload", function()
    local inventory_module = require("src.rules.items.inventory")
    local use_flow = require("src.rules.items.use_flow")
    local original_cfg = inventory_module.cfg
    local original_begin_item_use = use_flow.begin_item_use
    inventory_module.cfg = function()
      return { offer_in_phases = { "pre_action" } }
    end
    use_flow.begin_item_use = function(_, actor_id, item_id, opts)
      assert(actor_id == 1, "expected actor id")
      assert(item_id == item_ids.dice_multiplier, "expected item id")
      assert(opts.phase == "pre_action", "expected phase")
      assert(opts.by_ai == true, "expected by_ai flag")
      assert(opts.auto_play == true, "expected auto_play flag")
      return { ok = true, waiting = true, status = "waiting_choice", source = "test" }
    end

    local ok, err = pcall(function()
      local game = { turn = { phase = "pre_action" } }
      local player = { id = 1 }
      local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, true)
      assert(type(result) == "table", "should return waiting table")
      assert(result.source == "test", "should preserve use-flow payload")
    end)

    inventory_module.cfg = original_cfg
    use_flow.begin_item_use = original_begin_item_use
    if not ok then
      error(err)
    end
  end)

  it("_test_try_use_item_returns_nil_for_rejected_flow_result", function()
    local inventory_module = require("src.rules.items.inventory")
    local use_flow = require("src.rules.items.use_flow")
    local original_cfg = inventory_module.cfg
    local original_begin_item_use = use_flow.begin_item_use
    inventory_module.cfg = function()
      return { offer_in_phases = { "pre_action" } }
    end
    use_flow.begin_item_use = function()
      return { ok = false, status = "rejected", reason = "item_not_in_inventory" }
    end

    local ok, err = pcall(function()
      local game = { turn = { phase = "pre_action" } }
      local player = { id = 1 }
      local result = strategy._try_use_item(game, player, item_ids.dice_multiplier, nil, false)
      assert(result == nil, "should ignore rejected use-flow result")
    end)

    inventory_module.cfg = original_cfg
    use_flow.begin_item_use = original_begin_item_use
    if not ok then
      error(err)
    end
  end)
end)
