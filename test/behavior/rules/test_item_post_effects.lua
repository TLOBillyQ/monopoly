require("test.bootstrap").install_package_paths()
-- luacheck: ignore 143 (busted injects the verified luassert object)
local luassert = assert
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")

local function _new_game()
  return support.new_game({ map = default_map })
end
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end
local _with_patches = support.with_patches

local function _action_anim_count(game)
  local count = 0
  if game.turn.action_anim then
    count = count + 1
  end
  return count + #(game.turn.action_anim_queue or {})
end



describe("TestItemPostEffects", function()
  before_each(function()
    require("test.support.config_reset").reset_all()
  end)
  it("test_apply_target_share_wealth", function()
    local game = {
      player_cash = function(self, player)
        if player.id == 1 then return 1000 end
        if player.id == 2 then return 3000 end
        return 0
      end,
      set_player_cash = function(self, player, amount)
        player.cash = amount
      end,
      angel_immune_to_item = function(self, player, item_id)
        return false
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target" }
    local result = post_effects.apply_target(game, user, item_ids.share_wealth, target, {})
    luassert.is.same(true, result, "should return true")
    luassert.is.same(2000, user.cash, "user should have half of total")
    luassert.is.same(2000, target.cash, "target should have other half")
  end)

  it("test_apply_target_invite_deity", function()
    local game = {
      clear_player_deity = function(self, player)
        player.status.deity = nil
      end,
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
      end,
      player_deity_type = function(self, player)
        local deity = player.status and player.status.deity or nil
        return deity and deity.type or nil
      end,
      transfer_deity = function(self, src, dst)
        self:set_player_deity(dst, src.status.deity.type, src.status.deity.remaining)
        self:clear_player_deity(src)
        return true
      end,
    }
    local user = { id = 1, name = "User", status = {} }
    local target = { id = 2, name = "Target", status = { deity = { type = "rich", remaining = 3 } } }
    local result = post_effects.apply_target(game, user, item_ids.invite_deity, target, {})
    luassert.is.same(true, result, "should return true")
    luassert.is_nil(target.status.deity, "target should lose deity")
    luassert.is.same("rich", user.status.deity.type, "user should gain deity")
  end)

  it("test_apply_target_poor", function()
    local game = {
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {} }
    local result = post_effects.apply_target(game, user, item_ids.poor, target, {})
    luassert.is.same(true, result, "should return true")
    luassert.is.same("poor", target.status.deity.type, "target should have poor deity")
  end)

  it("test_apply_target_rejects_self", function()
    local game = {}
    local user = { id = 1, name = "User", status = {} }

    local ok, err = pcall(function()
      post_effects.apply_target(game, user, item_ids.share_wealth, user, {})
    end)
    luassert.is.same(false, ok, "should reject self-target")
    luassert.is_not_nil(tostring(err):find("apply_target: user and target must differ", 1, true), "should mention self-target guard")
  end)

  it("test_poor_card_explicit_duration", function()
    local constants = require("src.config.content.constants")
    local game = {
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {}, deity_duration_turns = 99 }

    local result = post_effects.apply_target(game, user, item_ids.poor, target, {})

    luassert.is.same(true, result, "should return true")
    luassert.is.same(constants.deity_duration_turns, target.status.deity.remaining, "poor card should use constants duration")
  end)

  it("test_apply_target_tax_normal", function()
    local constants = require("src.config.content.constants")
    local Inventory = require("src.player.actions.inventory")
    local game = {
      angel_immune_to_item = function() return false end,
      player_cash = function() return 1000 end,
      add_player_cash = function(self, player, delta)
        player.cash = (player.cash or 0) + delta
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {}, cash = 1000, inventory = Inventory:new({ constants = constants }) }
    local result = post_effects.apply_target(game, user, item_ids.tax, target, {})
    luassert.is.same(true, result, "should return true")
    luassert.is.same(500, target.cash, "target should lose 50% of cash")
  end)

  it("test_apply_target_tax_with_angel", function()
    local game = {
      angel_immune_to_item = function(self, player, item_id)
        return item_id == item_ids.tax
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {} }
    local result = post_effects.apply_target(game, user, item_ids.tax, target, {})
    luassert.is.same(true, result, "should return true when target has angel")
  end)

  it("test_apply_target_tax_with_tax_free", function()
    local constants = require("src.config.content.constants")
    local Inventory = require("src.player.actions.inventory")
    local inventory = require("src.rules.items.inventory")
    local game = {
      angel_immune_to_item = function() return false end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {}, inventory = Inventory:new({ constants = constants }) }
    -- Give target a tax_free item
    inventory.give(target, item_ids.tax_free)
    local result = post_effects.apply_target(game, user, item_ids.tax, target, {})
    luassert.is.same(true, result, "should return true when target uses tax_free")
    -- Tax_free item should be consumed
    luassert.is_nil(inventory.find_index(target, item_ids.tax_free), "tax_free should be consumed")
  end)

  it("test_apply_target_exile", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    game.anim_gate_port = { wait_action_anim = false, wait_move_anim = false }

    local user = game.players[1]
    local target = game.players[2]
    target.position = 1

    local result = post_effects.apply_target(game, user, item_ids.exile, target, {})
    luassert.is.same(true, result, "should return true")
    -- Target should be moved to mountain tile
    local mountain_idx = game.board:find_first_by_type("mountain")
    if mountain_idx then
      luassert.is.same(mountain_idx, target.position, "target should be moved to mountain")
    end
  end)

  it("test_apply_target_send_poor", function()
    local game = {
      player_has_deity = function(self, player, deity)
        return player.status.deity.type == deity and player.status.deity.remaining > 0
      end,
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
      end,
      clear_player_deity = function(self, player)
        player.status.deity = nil
      end,
      transfer_deity = function(self, src, dst)
        local deity = src.status.deity
        self:set_player_deity(dst, deity.type, deity.remaining)
        self:clear_player_deity(src)
        return true
      end,
    }
    local user = { id = 1, name = "User", status = { deity = { type = "poor", remaining = 3 } } }
    local target = { id = 2, name = "Target", status = {} }
    local result = post_effects.apply_target(game, user, item_ids.send_poor, target, {})
    luassert.is.same(true, result, "should return true")
    luassert.is.same("poor", target.status.deity.type, "target should have poor deity")
    luassert.is_nil(user.status.deity, "user should lose poor deity")
  end)

-- Moved from test_chance.lua -------------------------------------------------

  it("test_post_effects_apply_sets_status", function()
    local g = _new_game()
    local p = g:current_player()

    post_effects.apply_post(g, p, item_ids.free_rent, {})

    luassert.is.same(true, g:has_pending_free_rent(p), "post_effects apply should set pending_free_rent status")
  end)

  it("test_post_effects_apply_deity_sets_deity", function()
    local g = _new_game()
    local p = g:current_player()

    post_effects.apply_post(g, p, item_ids.rich, {})

    luassert.is_not_nil(p.status.deity, "post_effects apply deity should set player deity")
    luassert.is.same("rich", p.status.deity.type, "post_effects apply deity should set correct deity type")
  end)

  it("test_post_effects_apply_log_emits_event", function()
    local g = _new_game()
    local p = g:current_player()
    local events = {}
    local event_feed = require("src.rules.ports.event_feed")

    _with_patches({
      { target = event_feed, key = "publish", value = function(_, event)
        events[#events + 1] = event and event.text or nil
        return true
      end },
    }, function()
      post_effects.apply_post(g, p, item_ids.strong, {})
    end)

    luassert.is.same(1, #events, "post_effects log type should emit one event")
    luassert.truthy(events[1]:find("强征"), "post_effects log type should emit strong card preparation message")
  end)

  it("test_post_effects_apply_place_mine_here_places_mine", function()
    local g = _new_game()
    local p = g:current_player()
    local idx = g.board:index_of_tile_id(2)
    g:update_player_position(p, idx)
    local tile_idx = p.position

    post_effects.apply_post(g, p, item_ids.mine, {})

    luassert.is_true(g.board:has_mine(tile_idx), "post_effects place_mine_here should place a mine at player position")
    local mine = luassert.truthy(g.board:get_mine(tile_idx), "post_effects place_mine_here should keep mine payload")
    luassert.is.same(true, mine.armed, "post_effects place_mine_here should arm normal mines immediately")
    luassert.is.same(p.id, mine.owner_id, "post_effects place_mine_here should record owner id")
    luassert.is.same(g:player_own_turn_started_count(p), mine.owner_turn_started_count_at_placement, "post_effects place_mine_here should snapshot owner own-turn count")
  end)

  it("test_post_effects_apply_clear_obstacles_ahead_clears_obstacles", function()
    local g = _new_game()
    local p = g:current_player()
    local idx = g.board:index_of_tile_id(2)
    g:update_player_position(p, idx)
    g:place_roadblock(idx + 1, { owner_id = p.id })

    luassert.is_true(g.board:has_roadblock(idx + 1), "precondition: roadblock should exist")

    post_effects.apply_post(g, p, item_ids.clear_obstacles, { branch_parity = 12 })

    luassert.is_false(g.board:has_roadblock(idx + 1), "post_effects clear_obstacles_ahead should clear roadblocks")
  end)

  it("test_post_effects_target_item_ids_returns_ordered_list", function()
    local ids = post_effects.target_item_ids()
    luassert.is_table(ids, "target_item_ids should return a table")
    luassert.is_true(#ids > 0, "target_item_ids should return non-empty list")
    -- Check for known target items (share_wealth = 2011)
    local has_share_wealth = false
    for _, id in ipairs(ids) do
      if id == item_ids.share_wealth then
        has_share_wealth = true
        break
      end
    end
    luassert.is_true(has_share_wealth, "target_item_ids should include share_wealth item")
  end)

  it("test_post_effects_get_target_spec_returns_spec", function()
    local spec = post_effects.get_target_spec(item_ids.share_wealth)
    luassert.is_table(spec, "get_target_spec should return a table for target items")
    luassert.is_function(spec.apply, "target spec should have apply function")
  end)

  it("test_post_effects_share_wealth_queues_cash_anim_for_both_players", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    g:set_player_cash(user, 1000)
    g:set_player_cash(target, 3000)
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    post_effects.apply_target(g, user, item_ids.share_wealth, target, {})

    luassert.truthy(g.turn.action_anim and g.turn.action_anim.kind == "cash_receive", "share_wealth should queue cash_receive anim")
    _assert_eq(_action_anim_count(g), 2, "share_wealth should queue one cash anim per affected player")
  end)

  it("test_post_effects_share_wealth_item_target_path_keeps_item_target_anim_only", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    g:set_player_cash(user, 1000)
    g:set_player_cash(target, 3000)
    g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    post_effects.apply_target(g, user, item_ids.share_wealth, target, {
      share_wealth_cash_receive_mode = "item_target_player_only",
    })

    luassert.is_nil(g.turn.action_anim, "item target path should suppress post-effect cash_receive anim")
  end)


end)
