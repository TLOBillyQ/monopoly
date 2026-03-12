local bankruptcy = require("src.game.systems.endgame.bankruptcy")
local session = require("src.game.scheduler.session")
local post_effects = require("src.game.systems.items.post_effects")
local strategy = require("src.game.systems.items.strategy")

local function _test_call_life_die_with_role_param_succeeds()
  local life_comp = {
    die = function(self, role)
      return true
    end,
  }
  local role = { id = 1 }
  local result = bankruptcy._call_life_die(life_comp, role)
  assert(result == true, "should return true when life_comp.die with role succeeds")
end

local function _test_call_life_die_fallback_to_just_role()
  local call_count = 0
  local life_comp = {
    die = function(self, arg)
      call_count = call_count + 1
      if arg == nil then
        return false
      end
      return true
    end,
  }
  local role = { id = 2 }
  local result = bankruptcy._call_life_die(life_comp, role)
  assert(result == true, "should fallback to just role param")
  assert(call_count >= 1, "should have called die at least once")
end

local function _test_call_life_die_fallback_to_nil()
  local call_count = 0
  local life_comp = {
    die = function(self, arg)
      call_count = call_count + 1
      if arg == nil then
        return true
      end
      return false
    end,
  }
  local role = { id = 3 }
  local result = bankruptcy._call_life_die(life_comp, role)
  assert(result == true, "should fallback to nil param eventually")
end

local function _test_call_life_die_non_table_returns_false()
  local result = bankruptcy._call_life_die("not a table", {})
  assert(result == false, "should return false for non-table life_comp")
  result = bankruptcy._call_life_die(nil, {})
  assert(result == false, "should return false for nil life_comp")
  result = bankruptcy._call_life_die(123, {})
  assert(result == false, "should return false for numeric life_comp")
end

local function _test_merge_executor_groups_combines_multiple_groups()
  local executors = require("src.game.systems.land.executors")
  local merged = executors._merge_executor_groups({
    { buy_land = { name = "buy" }, upgrade_land = { name = "upgrade" } },
    { pay_rent = { name = "rent" }, tax = { name = "tax" } },
  })
  assert(merged.buy_land ~= nil, "should have buy_land executor")
  assert(merged.upgrade_land ~= nil, "should have upgrade_land executor")
  assert(merged.pay_rent ~= nil, "should have pay_rent executor")
  assert(merged.tax ~= nil, "should have tax executor")
end

local function _test_merge_executor_groups_later_overrides_earlier()
  local executors = require("src.game.systems.land.executors")
  local merged = executors._merge_executor_groups({
    { buy_land = { name = "original" } },
    { buy_land = { name = "override" } },
  })
  assert(merged.buy_land.name == "override", "later group should override earlier")
end

local function _test_merge_executor_groups_handles_empty_groups()
  local executors = require("src.game.systems.land.executors")
  local merged = executors._merge_executor_groups({
    {},
    { buy_land = { name = "buy" } },
    {},
  })
  assert(merged.buy_land ~= nil, "should handle empty groups")
  assert(merged.buy_land.name == "buy", "should have correct executor after empty groups")
end

local function _test_mark_phase_default_sets_phase_and_dirty()
  local game = {
    turn = {},
    dirty = {}
  }
  session._mark_phase_default(game, "roll")
  assert(game.turn.phase == "roll", "should set turn phase")
  assert(game.dirty.turn == true, "should mark turn dirty")
  assert(game.dirty.any == true, "should mark any dirty")
end

local function _test_mark_phase_default_no_game_returns_early()
  local result = session._mark_phase_default(nil, "roll")
  assert(result == nil, "should return nil when no game")
end

local function _test_mark_phase_default_no_turn_returns_early()
  local game = {}
  local result = session._mark_phase_default(game, "roll")
  assert(result == nil, "should return nil when no turn")
  assert(game.turn == nil, "should not create turn table")
end

local function _test_mark_phase_default_no_dirty_ok()
  local game = {
    turn = {}
  }
  local result = session._mark_phase_default(game, "move")
  assert(game.turn.phase == "move", "should set phase even without dirty")
  assert(result == nil, "should return nil (no explicit return on success)")
end

local function _test_apply_target_share_wealth()
  local game = {
    player_balance = function(self, player, currency)
      if player.id == 1 then return 1000 end
      if player.id == 2 then return 3000 end
      return 0
    end,
    set_player_cash = function(self, player, amount)
      player.cash = amount
    end,
  }
  local user = { id = 1, name = "User" }
  local target = { id = 2, name = "Target" }
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.share_wealth, target, {})
  assert(result == true, "should return true")
  assert(user.cash == 2000, "user should have half of total")
  assert(target.cash == 2000, "target should have other half")
end

local function _test_apply_target_invite_deity()
  local game = {
    clear_player_deity = function(self, player)
      player.status.deity = nil
    end,
    set_player_deity = function(self, player, deity_type, remaining)
      player.status.deity = { type = deity_type, remaining = remaining }
    end,
  }
  local user = { id = 1, name = "User", status = {} }
  local target = { id = 2, name = "Target", status = { deity = { type = "rich", remaining = 3 } } }
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.invite_deity, target, {})
  assert(result == true, "should return true")
  assert(target.status.deity == nil, "target should lose deity")
  assert(user.status.deity.type == "rich", "user should gain deity")
end

local function _test_apply_target_poor()
  local game = {
    set_player_deity = function(self, player, deity_type, remaining)
      player.status.deity = { type = deity_type, remaining = remaining }
    end,
  }
  local user = { id = 1, name = "User" }
  local target = { id = 2, name = "Target", status = {} }
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.poor, target, {})
  assert(result == true, "should return true")
  assert(target.status.deity.type == "poor", "target should have poor deity")
end

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
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local game = { turn = { phase = "pre_action" } }
  -- Player has empty inventory, but try to use a valid item (dice_multiplier which AI can use)
  local player = { id = 1, status = { inventory = {} } }
  local result = strategy._try_use_item(game, player, gameplay_rules.item_ids.dice_multiplier, nil, false)
  assert(result == nil, "should return nil when item not in inventory")
end

local function _test_try_use_item_not_ai_usable_returns_nil()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local game = { turn = { phase = "pre_action" } }
  local player = { id = 1, status = { inventory = {} } }
  -- Try to use an item that AI cannot use in this phase
  -- mine with manual timing in pre_action phase is allowed, so use something else
  local result = strategy._try_use_item(game, player, gameplay_rules.item_ids.steal, nil, false)
  assert(result == nil, "should return nil when item not AI-usable in phase")
end

return {
  name = "gameplay_t4_characterization",
  tests = {
    { name = "_test_call_life_die_with_role_param_succeeds", run = _test_call_life_die_with_role_param_succeeds },
    { name = "_test_call_life_die_fallback_to_just_role", run = _test_call_life_die_fallback_to_just_role },
    { name = "_test_call_life_die_fallback_to_nil", run = _test_call_life_die_fallback_to_nil },
    { name = "_test_call_life_die_non_table_returns_false", run = _test_call_life_die_non_table_returns_false },
    { name = "_test_merge_executor_groups_combines_multiple_groups", run = _test_merge_executor_groups_combines_multiple_groups },
    { name = "_test_merge_executor_groups_later_overrides_earlier", run = _test_merge_executor_groups_later_overrides_earlier },
    { name = "_test_merge_executor_groups_handles_empty_groups", run = _test_merge_executor_groups_handles_empty_groups },
    { name = "_test_mark_phase_default_sets_phase_and_dirty", run = _test_mark_phase_default_sets_phase_and_dirty },
    { name = "_test_mark_phase_default_no_game_returns_early", run = _test_mark_phase_default_no_game_returns_early },
    { name = "_test_mark_phase_default_no_turn_returns_early", run = _test_mark_phase_default_no_turn_returns_early },
    { name = "_test_mark_phase_default_no_dirty_ok", run = _test_mark_phase_default_no_dirty_ok },
    { name = "_test_apply_target_share_wealth", run = _test_apply_target_share_wealth },
    { name = "_test_apply_target_invite_deity", run = _test_apply_target_invite_deity },
    { name = "_test_apply_target_poor", run = _test_apply_target_poor },
    { name = "_test_try_use_item_cond_false_returns_nil", run = _test_try_use_item_cond_false_returns_nil },
    { name = "_test_try_use_item_no_inventory_returns_nil", run = _test_try_use_item_no_inventory_returns_nil },
    { name = "_test_try_use_item_not_ai_usable_returns_nil", run = _test_try_use_item_not_ai_usable_returns_nil },
  },
}
