local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")


-- Tests for post_effects.apply_target tax item effect (CRAP=12.00, coverage=0%)


-- Tests for post_effects.apply_target exile item effect

-- Tests for post_effects.apply_target send_poor item effect

describe("items_post_effects", function()
  it("_test_apply_target_share_wealth", function()
    local game = {
      player_balance = function(self, player, currency)
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
    assert(result == true, "should return true")
    assert(user.cash == 2000, "user should have half of total")
    assert(target.cash == 2000, "target should have other half")
  end)

  it("_test_apply_target_invite_deity", function()
    local game = {
      clear_player_deity = function(self, player)
        player.status.deity = nil
      end,
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
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
    assert(result == true, "should return true")
    assert(target.status.deity == nil, "target should lose deity")
    assert(user.status.deity.type == "rich", "user should gain deity")
  end)

  it("_test_apply_target_poor", function()
    local game = {
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {} }
    local result = post_effects.apply_target(game, user, item_ids.poor, target, {})
    assert(result == true, "should return true")
    assert(target.status.deity.type == "poor", "target should have poor deity")
  end)

  it("apply_target rejects self", function()
    local game = {}
    local user = { id = 1, name = "User", status = {} }

    local ok, err = pcall(function()
      post_effects.apply_target(game, user, item_ids.share_wealth, user, {})
    end)
    assert(ok == false, "should reject self-target")
    assert(tostring(err):find("apply_target: user and target must differ", 1, true) ~= nil, "should mention self-target guard")
  end)

  it("poor card explicit duration", function()
    local constants = require("src.config.content.constants")
    local game = {
      set_player_deity = function(self, player, deity_type, remaining)
        player.status.deity = { type = deity_type, remaining = remaining }
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {}, deity_duration_turns = 99 }

    local result = post_effects.apply_target(game, user, item_ids.poor, target, {})

    assert(result == true, "should return true")
    assert(target.status.deity.remaining == constants.deity_duration_turns, "poor card should use constants duration")
  end)

  it("_test_apply_target_tax_normal", function()
    local constants = require("src.config.content.constants")
    local Inventory = require("src.player.actions.inventory")
    local game = {
      angel_immune_to_item = function() return false end,
      player_balance = function() return 1000 end,
      deduct_player_cash = function(self, player, amount)
        player.cash = (player.cash or 1000) - amount
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {}, cash = 1000, inventory = Inventory:new({ constants = constants }) }
    local result = post_effects.apply_target(game, user, item_ids.tax, target, {})
    assert(result == true, "should return true")
    assert(target.cash == 500, "target should lose 50% of cash")
  end)

  it("_test_apply_target_tax_with_angel", function()
    local game = {
      angel_immune_to_item = function(self, player, item_id)
        return item_id == item_ids.tax
      end,
    }
    local user = { id = 1, name = "User" }
    local target = { id = 2, name = "Target", status = {} }
    local result = post_effects.apply_target(game, user, item_ids.tax, target, {})
    assert(result == true, "should return true when target has angel")
  end)

  it("_test_apply_target_tax_with_tax_free", function()
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
    assert(result == true, "should return true when target uses tax_free")
    -- Tax_free item should be consumed
    assert(inventory.find_index(target, item_ids.tax_free) == nil, "tax_free should be consumed")
  end)

  it("_test_apply_target_exile", function()
    local support = require("spec.support.shared_support")
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    game.anim_gate_port = { wait_action_anim = false, wait_move_anim = false }

    local user = game.players[1]
    local target = game.players[2]
    target.position = 1

    local result = post_effects.apply_target(game, user, item_ids.exile, target, {})
    assert(result == true, "should return true")
    -- Target should be moved to mountain tile
    local mountain_idx = game.board:find_first_by_type("mountain")
    if mountain_idx then
      assert(target.position == mountain_idx, "target should be moved to mountain")
    end
  end)

  it("_test_apply_target_send_poor", function()
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
    assert(result == true, "should return true")
    assert(target.status.deity.type == "poor", "target should have poor deity")
    assert(user.status.deity == nil, "user should lose poor deity")
  end)
end)
