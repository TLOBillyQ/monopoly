local support = require("spec.support.shared_support")
local gain_reveal = require("src.rules.items.gain_reveal")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")

local _assert_eq = support.assert_eq

local function _new_game()
  local g = support.new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  return g
end

describe("item_get_reveal", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("queues_item_get_reveal_action_anim_for_realtime_gain", function()
    local g = _new_game()
    local player = g.players[1]

    local queued = gain_reveal.queue(g, player, item_ids.free_rent, { source = "item_tile" })

    _assert_eq(queued, true, "realtime gain should queue reveal anim")
    local anim = assert(g.turn.action_anim, "missing item get reveal anim")
    _assert_eq(anim.kind, "item_get_reveal", "reveal anim kind mismatch")
    _assert_eq(anim.player_id, player.id, "reveal player mismatch")
    _assert_eq(anim.owner_role_id, player.id, "reveal owner role mismatch")
    _assert_eq(anim.item_id, item_ids.free_rent, "reveal item mismatch")
    _assert_eq(anim.item_name, inventory.item_name(item_ids.free_rent), "reveal item name mismatch")
    _assert_eq(anim.duration, timing.item_get_reveal_seconds, "reveal duration mismatch")
    _assert_eq(anim.source, "item_tile", "reveal source mismatch")
  end)

  it("preserves_gain_order_behind_current_source_animation", function()
    local g = _new_game()
    local player = g.players[1]
    g.turn.action_anim = { seq = 9, kind = "chance", player_id = player.id }
    g.turn.action_anim_seq = 9

    gain_reveal.queue(g, player, item_ids.free_rent, { source = "chance" })
    gain_reveal.queue(g, player, item_ids.roadblock, { source = "chance" })

    local queue = g.turn.action_anim_queue or {}
    _assert_eq(#queue, 2, "two gained items should be queued")
    _assert_eq(queue[1].kind, "item_get_reveal", "first queued reveal kind mismatch")
    _assert_eq(queue[1].item_id, item_ids.free_rent, "first reveal item mismatch")
    _assert_eq(queue[2].item_id, item_ids.roadblock, "second reveal item mismatch")
  end)

  it("does_not_queue_when_action_anim_gate_is_disabled", function()
    local g = support.new_game()
    local player = g.players[1]
    g.anim_gate_port = { wait_action_anim = false, wait_move_anim = false }

    local queued = gain_reveal.queue(g, player, item_ids.free_rent)

    _assert_eq(queued, false, "disabled gate should skip reveal anim")
    _assert_eq(g.turn.action_anim, nil, "disabled gate should not set current anim")
    _assert_eq(#(g.turn.action_anim_queue or {}), 0, "disabled gate should not append queue")
  end)

  it("plain_inventory_give_with_game_context_does_not_trigger_reveal", function()
    local g = _new_game()
    local player = g.players[1]

    local ok = inventory.give(player, item_ids.free_rent, { game = g })

    _assert_eq(ok, true, "inventory give should still add item")
    _assert_eq(g.turn.action_anim, nil, "plain inventory give should not queue reveal")
    _assert_eq(#(g.turn.action_anim_queue or {}), 0, "plain inventory give should not enqueue reveal")
  end)
end)
