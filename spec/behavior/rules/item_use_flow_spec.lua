local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local use_flow = require("src.rules.items.use_flow")

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

describe("item_use_flow", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("begin rejects missing actor with stable reason", function()
    local g = _new_game()

    local result = use_flow.begin_item_use(g, 9999, item_ids.mine, { phase = "pre_action" })

    _assert_eq(result.ok, false, "missing actor should reject")
    _assert_eq(result.status, "rejected", "missing actor status")
    _assert_eq(result.reason, "missing_actor", "missing actor reason")
  end)

  it("begin rejects item outside current phase before executing effect", function()
    local g = _new_game()
    local player = g:current_player()
    player.inventory:add({ id = item_ids.remote_dice })

    local result = use_flow.begin_item_use(g, player.id, item_ids.remote_dice, { phase = "post_action" })

    _assert_eq(result.ok, false, "phase mismatch should reject")
    _assert_eq(result.reason, "offer_in_phases_not_allowed", "phase mismatch reason")
    _assert_eq(inventory.count(player), 1, "rejected item should remain")
  end)

  it("begin returns structured waiting choice for manual target item", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })

    local result = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })

    _assert_eq(result.ok, true, "steal begin should be accepted")
    _assert_eq(result.status, "waiting_choice", "steal should wait for target choice")
    _assert_eq(result.item_consumed, false, "waiting choice should not consume item")
    assert(result.choice_spec and result.choice_spec.kind == "item_target_player", "steal should expose target-player choice")
    _assert_eq(result.choice_spec.options[1].id, target.id, "target with item should be offered")
  end)

  it("resolve target-player choice applies item through shared flow", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })
    target.inventory:add({ id = item_ids.tax_free })

    local begin = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })
    local choice = support.open_choice(g, begin.choice_spec)

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = target.id,
      actor_role_id = user.id,
    })

    _assert_eq(result.ok, true, "target choice should apply")
    _assert_eq(result.status, "applied", "target choice status")
    _assert_eq(result.item_consumed, true, "steal card should be consumed")
    _assert_eq(_count_item(user, item_ids.steal), 0, "steal card should leave inventory")
    _assert_eq(inventory.count(target), 1, "target should lose one item")
  end)

  it("resolve rejects choices that do not belong to the selected item use", function()
    local g = _new_game()
    local user = g.players[1]
    user.inventory:add({ id = item_ids.remote_dice })
    local choice = support.open_choice(g, {
      kind = "remote_dice_value",
      options = { { id = 4, label = "4" } },
      meta = {
        player_id = user.id,
        item_id = item_ids.roadblock,
        dice_count = 1,
      },
    })

    local result = use_flow.resolve_item_use_choice(g, choice, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 4,
      actor_role_id = user.id,
    }, {
      item_id = item_ids.remote_dice,
    })

    _assert_eq(result.ok, false, "wrong item metadata should reject")
    _assert_eq(result.reason, "item_mismatch", "wrong item reason")
    _assert_eq(_count_item(user, item_ids.remote_dice), 1, "rejected choice should not consume item")
  end)
end)
