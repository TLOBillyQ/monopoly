local bankruptcy = require("src.game.systems.endgame.bankruptcy")
local session = require("src.game.scheduler.session")
local post_effects = require("src.game.systems.items.post_effects")
local strategy = require("src.game.systems.items.strategy")

local function _reload_module(module_name, overrides, fn)
  local original = {}
  for key, value in pairs(overrides or {}) do
    original[key] = package.loaded[key]
    package.loaded[key] = value
  end
  local original_module = package.loaded[module_name]
  package.loaded[module_name] = nil
  local ok, result = pcall(function()
    local loaded = require(module_name)
    return fn(loaded)
  end)
  package.loaded[module_name] = original_module
  for key, value in pairs(original) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end

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
  local game = { turn = { phase = "post_action" } }
  local player = { id = 1, status = { inventory = {} } }
  local result = strategy._try_use_item(game, player, gameplay_rules.item_ids.dice_multiplier, nil, false)
  assert(result == nil, "should return nil when item not AI-usable in phase")
end

local function _test_try_use_item_returns_waiting_payload()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local inventory_module = require("src.game.systems.items.inventory")
  local executor_module = require("src.game.systems.items.executor")
  local original_cfg = inventory_module.cfg
  local original_find_index = inventory_module.find_index
  local original_use_item = executor_module.use_item
  inventory_module.cfg = function()
    return { timing = "pre_action" }
  end
  inventory_module.find_index = function() return 1 end
  executor_module.use_item = function(_, _, _, opts)
    assert(opts.by_ai == true, "expected by_ai flag")
    assert(opts.auto_play == true, "expected auto_play flag")
    return { waiting = true, source = "test" }
  end

  local ok, err = pcall(function()
    local game = { turn = { phase = "pre_action" } }
    local player = { id = 1, status = { inventory = { gameplay_rules.item_ids.dice_multiplier } } }
    local result = strategy._try_use_item(game, player, gameplay_rules.item_ids.dice_multiplier, nil, true)
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
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local inventory_module = require("src.game.systems.items.inventory")
  local executor_module = require("src.game.systems.items.executor")
  local original_cfg = inventory_module.cfg
  local original_find_index = inventory_module.find_index
  local original_use_item = executor_module.use_item
  inventory_module.cfg = function()
    return { timing = "pre_action" }
  end
  inventory_module.find_index = function() return 1 end
  executor_module.use_item = function() return true end

  local ok, err = pcall(function()
    local game = { turn = { phase = "pre_action" } }
    local player = { id = 1, status = { inventory = { gameplay_rules.item_ids.dice_multiplier } } }
    local result = strategy._try_use_item(game, player, gameplay_rules.item_ids.dice_multiplier, nil, false)
    assert(result == nil, "should ignore non-waiting executor result")
  end)

  inventory_module.cfg = original_cfg
  inventory_module.find_index = original_find_index
  executor_module.use_item = original_use_item
  if not ok then
    error(err)
  end
end

-- Tests for post_effects.apply_target tax item effect (CRAP=12.00, coverage=0%)
local function _test_apply_target_tax_normal()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local constants = require("Config.generated.constants")
  local Inventory = require("src.game.core.player.inventory")
  local game = {
    player_has_deity = function() return false end,
    player_balance = function() return 1000 end,
    deduct_player_cash = function(self, player, amount)
      player.cash = (player.cash or 1000) - amount
    end,
  }
  local user = { id = 1, name = "User" }
  local target = { id = 2, name = "Target", status = {}, cash = 1000, inventory = Inventory:new({ constants = constants }) }
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.tax, target, {})
  assert(result == true, "should return true")
  assert(target.cash == 500, "target should lose 50% of cash")
end

local function _test_apply_target_tax_with_angel()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local game = {
    player_has_deity = function(self, player, deity)
      return deity == "angel"
    end,
  }
  local user = { id = 1, name = "User" }
  local target = { id = 2, name = "Target", status = {} }
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.tax, target, {})
  assert(result == true, "should return true when target has angel")
end

local function _test_apply_target_tax_with_tax_free()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local constants = require("Config.generated.constants")
  local Inventory = require("src.game.core.player.inventory")
  local inventory = require("src.game.systems.items.inventory")
  local game = {
    player_has_deity = function() return false end,
  }
  local user = { id = 1, name = "User" }
  local target = { id = 2, name = "Target", status = {}, inventory = Inventory:new({ constants = constants }) }
  -- Give target a tax_free item
  inventory.give(target, gameplay_rules.item_ids.tax_free)
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.tax, target, {})
  assert(result == true, "should return true when target uses tax_free")
  -- Tax_free item should be consumed
  assert(inventory.find_index(target, gameplay_rules.item_ids.tax_free) == nil, "tax_free should be consumed")
end

-- Tests for post_effects.apply_target exile item effect
local function _test_apply_target_exile()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local support = require("support.domain_support")
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  game.anim_gate_port = { wait_action_anim = false, wait_move_anim = false }

  local user = game.players[1]
  local target = game.players[2]
  target.position = 1

  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.exile, target, {})
  assert(result == true, "should return true")
  -- Target should be moved to mountain tile
  local mountain_idx = game.board:find_first_by_type("mountain")
  if mountain_idx then
    assert(target.position == mountain_idx, "target should be moved to mountain")
  end
end

-- Tests for post_effects.apply_target send_poor item effect
local function _test_apply_target_send_poor()
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local game = {
    set_player_deity = function(self, player, deity_type, remaining)
      player.status.deity = { type = deity_type, remaining = remaining }
    end,
    clear_player_deity = function(self, player)
      player.status.deity = nil
    end,
  }
  local user = { id = 1, name = "User", status = { deity = { type = "poor", remaining = 3 } } }
  local target = { id = 2, name = "Target", status = {} }
  local result = post_effects.apply_target(game, user, gameplay_rules.item_ids.send_poor, target, {})
  assert(result == true, "should return true")
  assert(target.status.deity.type == "poor", "target should have poor deity")
  assert(user.status.deity == nil, "user should lose poor deity")
end

-- Tests for asset_handlers (CRAP hotspots with low coverage)
local function _test_asset_handlers_destroy_buildings_on_path()
  local asset_handlers = require("src.game.systems.chance.handlers.asset_handlers")
  local monopoly_event = require("src.core.events.monopoly_events")
  local events = {}
  local common = {
    emit_event = function(_, payload)
      table.insert(events, payload)
    end,
    dependencies = function()
      return {
        monopoly_event = monopoly_event,
      }
    end,
  }
  local handlers = {}
  asset_handlers.register(handlers, common)

  local game = {
    board = {
      get_tile = function(_, idx)
        if idx == 1 then return { type = "land", level = 2, name = "Tile1" } end
        if idx == 2 then return { type = "land", level = 0, name = "Tile2" } end
        if idx == 3 then return { type = "chance", name = "Chance" } end
        return nil
      end,
    },
    set_tile_level = function(_, tile, level)
      tile.level = level
    end,
  }

  handlers.destroy_buildings_on_path(game, {}, {}, { visited = { 1, 2, 3 } })

  assert(#events == 1, "should emit one event for tile with buildings")
  assert(events[1].effect == "destroy_buildings_on_path", "should have correct effect")
end

local function _test_asset_handlers_reset_tiles_on_path()
  local asset_handlers = require("src.game.systems.chance.handlers.asset_handlers")
  local monopoly_event = require("src.core.events.monopoly_events")
  local events = {}
  local tile_state_calls = {}
  local common = {
    emit_event = function(_, payload)
      table.insert(events, payload)
    end,
    dependencies = function()
      return {
        tile_state = function(game, tile)
          table.insert(tile_state_calls, tile)
          return { owner_id = tile.mock_owner }
        end,
        monopoly_event = monopoly_event,
      }
    end,
  }
  local handlers = {}
  asset_handlers.register(handlers, common)

  local owners = {}
  local reset_tiles = {}
  local game = {
    board = {
      get_tile = function(_, idx)
        if idx == 1 then return { type = "land", id = "t1", mock_owner = "p1", name = "Tile1" } end
        if idx == 2 then return { type = "land", id = "t2", mock_owner = nil, name = "Tile2" } end
        if idx == 3 then return { type = "chance", id = "t3", name = "Chance" } end
        return nil
      end,
    },
    find_player_by_id = function(_, id)
      return { id = id, properties = { t1 = true } }
    end,
    set_player_property = function(_, player, tile_id, owned)
      owners[tile_id] = owned
    end,
    reset_tile = function(_, tile)
      table.insert(reset_tiles, tile.id)
    end,
  }

  handlers.reset_tiles_on_path(game, {}, {}, { visited = { 1, 2, 3 } })

  assert(#events == 2, "should emit two events for land tiles")
  assert(events[1].effect == "reset_tiles_on_path", "should have correct effect")
  assert(reset_tiles[1] == "t1", "should reset tile with owner")
  assert(reset_tiles[2] == "t2", "should reset tile without owner")
end

local function _test_market_context_entry_name_vehicle_cfg()
  local context = require("src.game.systems.market.application.context")
  local name = context.entry_name({ kind = "vehicle", product_id = 5001 })
  assert(type(name) == "string" and name ~= "", "vehicle entry should resolve configured vehicle name")
end

local function _test_market_context_entry_name_item_cfg_and_fallback()
  local context = require("src.game.systems.market.application.context")
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local configured = context.entry_name({ kind = "item", product_id = gameplay_rules.item_ids.free_rent })
  local fallback = context.entry_name({ kind = "item", product_id = 999999, name = "FallbackName" })
  assert(type(configured) == "string" and configured ~= "", "item entry should resolve configured item name")
  assert(fallback == "FallbackName", "unknown item should fallback to entry.name")
end

local function _test_choice_session_apply_navigation_tab_select_and_empty_tab_feedback()
  local feedback_calls = {}
  local result = _reload_module("src.game.systems.market.application.choice_session", {
    ["src.game.systems.market.application.choice"] = {
      build = function()
        return {
          title = "Market",
          body_lines = {},
          options = {},
          allow_cancel = true,
          cancel_label = "Cancel",
          active_tab = "items",
          page_index = 1,
          page_count = 2,
          owner_role_id = 2,
          meta = {},
        }
      end,
    },
    ["src.game.systems.market.application.feedback"] = {
      emit_buy_failed = function(player, entry, reason, body)
        feedback_calls[#feedback_calls + 1] = { player = player, reason = reason, body = body }
      end,
    },
    ["src.core.choice.contract"] = {
      resolve_owner_role_id = function(choice) return choice.owner_role_id end,
    },
  }, function(choice_session)
    local game = {
      dirty = {},
      find_player_by_id = function(_, id)
        return { id = id, name = "P" .. tostring(id) }
      end,
    }
    local pending_choice = { kind = "market_buy", owner_role_id = 2, active_tab = "skin", page_index = 3, page_count = 5 }
    local ok = choice_session.apply_navigation(game, pending_choice, { type = "market_tab_select", tab = "items" })
    assert(ok == true, "tab select should succeed")
    assert(pending_choice.active_tab == "items", "should switch active tab")
    assert(pending_choice.page_index == 1, "tab switch should reset page index")
    assert(game.dirty.turn == true and game.dirty.any == true, "should mark choice dirty")
  end)
  assert(#feedback_calls == 1, "empty tab should emit feedback once")
  assert(feedback_calls[1].reason == "empty_tab", "should emit empty_tab reason")
end

local function _test_choice_session_apply_navigation_prev_next_and_rejects()
  local build_calls = {}
  _reload_module("src.game.systems.market.application.choice_session", {
    ["src.game.systems.market.application.choice"] = {
      build = function(_, _, state)
        build_calls[#build_calls + 1] = {
          active_tab = state.active_tab,
          page_index = state.page_index,
          page_count = state.page_count,
        }
        if state.page_index == 9 then
          return nil
        end
        return {
          title = "Market",
          body_lines = {},
          options = { { id = "opt" } },
          allow_cancel = true,
          cancel_label = "Cancel",
          active_tab = state.active_tab,
          page_index = state.page_index,
          page_count = state.page_count,
          owner_role_id = 2,
          meta = {},
        }
      end,
    },
    ["src.game.systems.market.application.feedback"] = {
      emit_buy_failed = function() end,
    },
    ["src.core.choice.contract"] = {
      resolve_owner_role_id = function(choice) return choice.owner_role_id end,
    },
  }, function(choice_session)
    local game = {
      dirty = {},
      find_player_by_id = function(_, id)
        if id == 2 then
          return { id = id, name = "P2" }
        end
        return nil
      end,
    }
    local pending_choice = { kind = "market_buy", owner_role_id = 2, active_tab = "items", page_index = 2, page_count = 5 }
    assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_prev" }) == true,
      "prev page should rebuild")
    assert(build_calls[1].page_index == 1, "prev page should decrement page index")
    assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == true,
      "next page should rebuild")
    assert(build_calls[2].page_index == 2, "next page should increment page index from updated state")
    pending_choice.owner_role_id = nil
    assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == false,
      "missing owner should reject")
    pending_choice.owner_role_id = 99
    assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == false,
      "missing player should reject")
    pending_choice.owner_role_id = 2
    pending_choice.page_index = 8
    assert(choice_session.apply_navigation(game, pending_choice, { type = "market_page_next" }) == false,
      "build nil should reject")
  end)
  assert(#build_calls == 3, "should build for prev, next, and nil-spec branch")
end

local function _test_choice_session_refresh_after_paid_callback_rebuilds_pending()
  local rebuilt_calls = 0
  local result = _reload_module("src.game.systems.market.application.choice_session", {
    ["src.game.systems.market.application.choice"] = {
      build = function()
        rebuilt_calls = rebuilt_calls + 1
        return {
          title = "Market",
          body_lines = { "line" },
          options = { { id = 1 } },
          allow_cancel = true,
          cancel_label = "Cancel",
          active_tab = "items",
          page_index = 2,
          page_count = 4,
          owner_role_id = 7,
          meta = { refreshed = true },
        }
      end,
    },
    ["src.core.choice.contract"] = {
      resolve_owner_role_id = function(choice) return choice.owner_role_id end,
    },
  }, function(choice_session)
    local pending_choice = { kind = "market_buy", owner_role_id = 7, active_tab = "skin", page_index = 1, page_count = 1 }
    local game = { dirty = {}, turn = { pending_choice = pending_choice } }
    local ok = choice_session.refresh_after_paid_callback(game, { id = 7, name = "P7" }, { product_id = 2001 })
    assert(ok == true, "refresh_after_paid_callback should rebuild pending choice")
    assert(pending_choice.page_index == 2, "should update pending choice page")
    assert(pending_choice.meta.refreshed == true, "should update pending choice meta")
  end)
  assert(result == nil, "reload wrapper should finish")
  assert(rebuilt_calls == 1, "should rebuild exactly once")
end

local function _test_choice_session_refresh_after_paid_callback_rejects_non_owner_and_failed_rebuild()
  local warnings = {}
  _reload_module("src.game.systems.market.application.choice_session", {
    ["src.game.systems.market.application.choice"] = {
      build = function()
        return nil
      end,
    },
    ["src.core.choice.contract"] = {
      resolve_owner_role_id = function(choice) return choice.owner_role_id end,
    },
    ["src.core.utils.logger"] = {
      warn = function(...)
        warnings[#warnings + 1] = table.concat({ ... }, " ")
      end,
    },
  }, function(choice_session)
    local pending_choice = { kind = "market_buy", owner_role_id = 7, active_tab = "skin", page_index = 1, page_count = 1 }
    local game = { dirty = {}, turn = { pending_choice = pending_choice } }
    assert(choice_session.refresh_after_paid_callback(game, { id = 8, name = "P8" }, { product_id = 2001 }) == false,
      "other player callback should be ignored")
    assert(choice_session.refresh_after_paid_callback(game, { id = 7, name = "P7" }, { product_id = 2001 }) == false,
      "failed rebuild should return false")
    game.turn.pending_choice = { kind = "other_kind", owner_role_id = 7 }
    assert(choice_session.refresh_after_paid_callback(game, { id = 7, name = "P7" }, { product_id = 2001 }) == false,
      "non-market pending choice should reject")
  end)
  assert(#warnings == 2, "failed rebuild should emit rebuild warning and callback warning")
end

local function _test_purchase_execute_paid_purchase_success_and_failure()
  local start_calls = {}
  _reload_module("src.game.systems.market.application.purchase", {
    ["src.game.systems.market.application.context"] = {
      entry_by_id = function(product_id)
        return { product_id = product_id, kind = "item", currency = "金豆", name = "Paid Item" }
      end,
      entry_currency = function(entry)
        return entry.currency
      end,
      is_paid_currency = function(currency)
        return currency == "金豆"
      end,
    },
    ["src.game.systems.market.application.purchase_policy"] = {
      validate_entry = function()
        return { ok = true }
      end,
    },
    ["src.game.systems.market.application.local_purchase"] = {
      execute = function()
        error("local purchase should not run for paid currency")
      end,
    },
    ["src.game.systems.market.application.feedback"] = {
      emit_buy_failed = function(player, entry, reason, body)
        start_calls[#start_calls + 1] = { failed = true, reason = reason, body = body }
      end,
    },
    ["src.game.systems.market.application.paid_purchase_callback"] = {
      handle = function() end,
    },
    ["src.game.systems.market.ports.paid_purchase_port"] = {
      setup_for_game = function() end,
      start = function(_, _, entry)
        start_calls[#start_calls + 1] = { failed = false, product_id = entry.product_id }
        if #start_calls == 1 then
          return true
        end
        return false, "gateway_down"
      end,
    },
  }, function(purchase)
    local game = {}
    local player = { id = 3, name = "Buyer" }
    local success = purchase.execute(game, player, "2001", {})
    assert(success.ok == true and success.deferred_fulfillment == true, "paid purchase should defer fulfillment on success")
    local failure = purchase.execute(game, player, "2001", {})
    assert(failure.ok == false and failure.reason == "gateway_down", "paid purchase failure should preserve gateway reason")
  end)
  assert(#start_calls == 3, "expected success start, failed start, and failure feedback")
  assert(start_calls[1].product_id == 2001, "product id should be normalized before start")
  assert(start_calls[3].failed == true and start_calls[3].reason == "gateway_down", "failure should emit feedback")
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
    { name = "_test_try_use_item_returns_waiting_payload", run = _test_try_use_item_returns_waiting_payload },
    { name = "_test_try_use_item_returns_nil_for_non_waiting_result", run = _test_try_use_item_returns_nil_for_non_waiting_result },
    { name = "_test_apply_target_tax_normal", run = _test_apply_target_tax_normal },
    { name = "_test_apply_target_tax_with_angel", run = _test_apply_target_tax_with_angel },
    { name = "_test_apply_target_tax_with_tax_free", run = _test_apply_target_tax_with_tax_free },
    { name = "_test_apply_target_exile", run = _test_apply_target_exile },
    { name = "_test_apply_target_send_poor", run = _test_apply_target_send_poor },
    { name = "_test_asset_handlers_destroy_buildings_on_path", run = _test_asset_handlers_destroy_buildings_on_path },
    { name = "_test_asset_handlers_reset_tiles_on_path", run = _test_asset_handlers_reset_tiles_on_path },
    { name = "_test_market_context_entry_name_vehicle_cfg", run = _test_market_context_entry_name_vehicle_cfg },
    { name = "_test_market_context_entry_name_item_cfg_and_fallback", run = _test_market_context_entry_name_item_cfg_and_fallback },
    { name = "_test_choice_session_apply_navigation_tab_select_and_empty_tab_feedback", run = _test_choice_session_apply_navigation_tab_select_and_empty_tab_feedback },
    { name = "_test_choice_session_apply_navigation_prev_next_and_rejects", run = _test_choice_session_apply_navigation_prev_next_and_rejects },
    { name = "_test_choice_session_refresh_after_paid_callback_rebuilds_pending", run = _test_choice_session_refresh_after_paid_callback_rebuilds_pending },
    { name = "_test_choice_session_refresh_after_paid_callback_rejects_non_owner_and_failed_rebuild", run = _test_choice_session_refresh_after_paid_callback_rejects_non_owner_and_failed_rebuild },
    { name = "_test_purchase_execute_paid_purchase_success_and_failure", run = _test_purchase_execute_paid_purchase_success_and_failure },
  },
}
