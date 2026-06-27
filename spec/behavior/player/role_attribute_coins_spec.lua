local support = require("spec.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local constants = require("src.config.content.constants")
local balance = require("src.player.actions.balance")
local Player = require("src.player.actions.player")
local land_rules = require("src.rules.land.landing_rules")

local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local function _role(initial)
  local attrs = {
    [balance.COIN_COUNT_ATTR_ID] = initial,
  }
  local role = {
    writes = {},
    fail_next_set = false,
    fail_values = nil,
    return_nil_on_set = false,
  }
  function role.get_attr_raw_fixed(first, second)
    local attr_id = first == role and second or first
    return attrs[attr_id]
  end
  function role:force_attr_raw_fixed(attr_id, value)
    attrs[attr_id] = value
  end
  function role.set_attr_raw_fixed(first, second, third)
    local attr_id = first == role and second or first
    local value = first == role and third or second
    if role.fail_next_set == true then
      role.fail_next_set = false
      return false
    end
    if role.fail_values and role.fail_values[value] == true then
      return false
    end
    attrs[attr_id] = value
    role.writes[#role.writes + 1] = {
      attr_id = attr_id,
      value = value,
      value_type = math.type and math.type(value) or type(value),
    }
    if role.return_nil_on_set == true then
      return nil
    end
    return true
  end
  return role
end

local function _action_anim_count(game)
  local count = 0
  if game.turn.action_anim then
    count = count + 1
  end
  return count + #(game.turn.action_anim_queue or {})
end

local function _game_with_roles(roles_by_id)
  local game
  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      return roles_by_id[player_id]
    end },
  }, function()
    game = support.new_game({ players = { "P1", "P2" } })
  end)
  return game
end

local function _assert_error_contains(fn, fragments)
  local ok, err = pcall(fn)
  assert(ok == false, "expected call to fail")
  local text = tostring(err)
  for _, fragment in ipairs(fragments) do
    assert(string.find(text, fragment, 1, true) ~= nil,
      "expected error to contain " .. tostring(fragment) .. ", got: " .. text)
  end
  return text
end

describe("role attribute coins", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("seeds new players into role coin_count without player.cash", function()
    local roles = {
      [1] = _role(nil),
      [2] = _role(nil),
    }

    local game = _game_with_roles(roles)

    _assert_eq(game:player_balance(game.players[1], "金币"), constants.starting_cash, "player 1 starting coins")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), constants.starting_cash, "role attr should be seeded")
    _assert_eq(roles[1].writes[1].value_type, "float", "role attr should be seeded with a Fixed-compatible float")
    _assert_eq(game.players[1].cash, nil, "player.cash must not exist")
    _assert_eq(#(game.turn.action_anim_queue or {}), 0, "startup seed must not queue cash animation")
  end)

  it("seeds startup coins for host roles whose raw coin_count defaults to zero", function()
    local roles = {
      [1] = _role(0),
      [2] = _role(0),
    }
    local game
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        return roles[player_id]
      end },
    }, function()
      game = support.new_game({ players = { "P1", "P2", "P3", "P4" } })
    end)

    for index, player in ipairs(game.players) do
      _assert_eq(game:player_balance(player, "金币"), constants.starting_cash,
        "player " .. tostring(index) .. " starting coins")
    end
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), constants.starting_cash,
      "host role 1 should be seeded from zero")
    _assert_eq(roles[2]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), constants.starting_cash,
      "host role 2 should be seeded from zero")
  end)

  it("treats nil-returning host coin writes as success", function()
    local roles = {
      [1] = _role(nil),
      [2] = _role(nil),
    }
    roles[1].return_nil_on_set = true

    local game = _game_with_roles(roles)

    _assert_eq(game:player_balance(game.players[1], "金币"), constants.starting_cash,
      "nil-returning host setter should still seed player 1")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), constants.starting_cash,
      "nil-returning host setter should persist the seeded value")
  end)

  it("adds, deducts, and sets coin_count through the balance boundary", function()
    local roles = {
      [1] = _role(1000),
      [2] = _role(2000),
    }
    local game = _game_with_roles(roles)
    local player = game.players[1]
    game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }

    game:set_player_cash(player, 1000)
    _assert_eq(game:add_player_cash(player, 500), 1500, "add should return updated coin_count")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 1500, "add writes role attr")
    _assert_eq(game:deduct_player_cash(player, 300), 1200, "deduct should return updated coin_count")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 1200, "deduct writes role attr")
    _assert_eq(game.players[1].cash, nil, "player.cash must not be introduced")
    assert(game.turn.action_anim and game.turn.action_anim.kind == "cash_receive", "cash delta animation should remain")
  end)

  it("allows spending down to exactly zero but rejects overspending", function()
    local roles = { [1] = _role(500), [2] = _role(500) }
    local game = _game_with_roles(roles)
    game:set_player_cash(game.players[1], 500)

    _assert_eq(game:deduct_player_cash(game.players[1], 500), 0, "deducting the full balance lands on zero")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 0, "role attr reaches zero")

    _assert_error_contains(function()
      game:deduct_player_cash(game.players[1], 1)
    end, { "玩家1", "余额不足" })
  end)

  it("clamps coin_count to zero when an add drives the balance negative", function()
    local roles = { [1] = _role(100), [2] = _role(0) }
    local game = _game_with_roles(roles)
    game:set_player_cash(game.players[1], 100)

    _assert_eq(game:add_player_cash(game.players[1], -500), 0, "an over-large negative add clamps to zero, not an error")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 0, "role attr is clamped to zero")
  end)

  it("transfers coin_count between players and can move the entire balance", function()
    local roles = { [1] = _role(10000), [2] = _role(2000) }
    local game = _game_with_roles(roles)
    game:set_player_cash(game.players[1], 10000)
    game:set_player_cash(game.players[2], 2000)

    local payer_after, receiver_after = game:transfer_player_cash(game.players[1], game.players[2], 3000)
    _assert_eq(payer_after, 7000, "payer is debited by the transfer amount")
    _assert_eq(receiver_after, 5000, "receiver is credited by the transfer amount")
    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 7000, "payer role attr reflects the debit")
    _assert_eq(roles[2]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 5000, "receiver role attr reflects the credit")

    local emptied, filled = game:transfer_player_cash(game.players[1], game.players[2], 7000)
    _assert_eq(emptied, 0, "a player may transfer their entire balance")
    _assert_eq(filled, 12000, "receiver collects the full transfer")

    -- a zero-amount transfer is a no-op, not a rejection
    local same_payer, same_receiver = game:transfer_player_cash(game.players[1], game.players[2], 0)
    _assert_eq(same_payer, 0, "a zero transfer leaves the payer unchanged")
    _assert_eq(same_receiver, 12000, "a zero transfer leaves the receiver unchanged")

    _assert_error_contains(function()
      game:transfer_player_cash(game.players[1], game.players[2], 1)
    end, { "玩家1", "余额不足" })
  end)

  it("rejects a negative transfer amount", function()
    local roles = { [1] = _role(100), [2] = _role(100) }
    local game = _game_with_roles(roles)
    game:set_player_cash(game.players[1], 100)
    game:set_player_cash(game.players[2], 100)

    _assert_error_contains(function()
      game:transfer_player_cash(game.players[1], game.players[2], -5)
    end, { "玩家1", "支付金额不能为负数" })
  end)

  it("supports capped transfer settlement for rule-owned bankruptcy decisions", function()
    local roles = { [1] = _role(500), [2] = _role(2000) }
    local game = _game_with_roles(roles)
    game.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
    game:set_player_cash(game.players[1], 500)
    game:set_player_cash(game.players[2], 2000)

    local payer_after, receiver_after, moved = game:transfer_player_cash(
      game.players[1],
      game.players[2],
      3000,
      { allow_partial = true }
    )

    _assert_eq(moved, 500, "capped transfer moves only the payer's liquid balance")
    _assert_eq(payer_after, 0, "payer is capped at zero")
    _assert_eq(receiver_after, 2500, "receiver gets only the actual moved amount")
    _assert_eq(_action_anim_count(game), 2, "capped transfer keeps visible deltas for both players")
    _assert_eq(game.turn.action_anim.amount, -500, "payer delta is the actual debit")
    _assert_eq(game.turn.action_anim_queue[1].amount, 500, "receiver delta is the actual credit")
  end)

  it("initialize_player_coins preserves an already-seeded balance instead of overwriting", function()
    local role = _role(777)
    local player = { id = 1, _coin_role = role }
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function() return nil end },
    }, function()
      _assert_eq(balance.initialize_player_coins(player, 100), 777, "an existing balance is returned, not replaced")
      _assert_eq(role:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 777, "the seeded role attr is untouched")
    end)
  end)

  it("transfers coin_count atomically and rolls back first write on recipient failure", function()
    local roles = {
      [1] = _role(10000),
      [2] = _role(2000),
    }
    local game = _game_with_roles(roles)
    local payer = game.players[1]
    local receiver = game.players[2]

    game:set_player_cash(payer, 10000)
    game:set_player_cash(receiver, 2000)
    roles[2].fail_next_set = true

    _assert_error_contains(function()
      game:transfer_player_cash(payer, receiver, 3000)
    end, { "玩家2", balance.COIN_COUNT_ATTR_ID, "回滚结果=成功" })

    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 10000, "payer rollback")
    _assert_eq(roles[2]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 2000, "receiver unchanged")
    _assert_eq(_action_anim_count(game), 0, "failed transfer must not queue partial cash animations")
  end)

  it("reports fatal rollback failure when the original payer write cannot be restored", function()
    local roles = {
      [1] = _role(10000),
      [2] = _role(2000),
    }
    local game = _game_with_roles(roles)
    local payer = game.players[1]
    local receiver = game.players[2]

    game:set_player_cash(payer, 10000)
    game:set_player_cash(receiver, 2000)
    roles[1].fail_values = { [10000] = true }
    roles[2].fail_next_set = true

    _assert_error_contains(function()
      game:transfer_player_cash(payer, receiver, 3000)
    end, { "玩家2", balance.COIN_COUNT_ATTR_ID, "回滚结果=fatal" })
  end)

  it("routes rent through atomic coin settlement before emitting receiver progress", function()
    local roles = {
      [1] = _role(10000),
      [2] = _role(0),
    }
    local game = _game_with_roles(roles)
    local payer = game.players[1]
    local owner = game.players[2]
    local _, tile = support.first_land_tile(game.board)
    local progress_events = {}
    game.achievement_progress_port = {
      cash_received = function(_, player, amount)
        progress_events[#progress_events + 1] = { player = player, amount = amount }
        return true
      end,
    }

    game:set_player_cash(payer, 10000)
    game:set_player_cash(owner, 0)
    game:set_tile_owner(tile, owner.id)
    game:set_player_property(owner, tile.id, true)
    roles[2].fail_next_set = true

    _assert_error_contains(function()
      land_rules.execute_pay_rent(game, payer.id, tile.id)
    end, { "玩家2", balance.COIN_COUNT_ATTR_ID, "回滚结果=成功" })

    _assert_eq(game:player_balance(payer, "金币"), 10000, "payer debit is rolled back")
    _assert_eq(game:player_balance(owner, "金币"), 0, "owner receives no partial rent")
    _assert_eq(#progress_events, 0, "failed settlement must not report receiver progress")
  end)

  it("hard fails on invalid coin_count values and missing role attr methods", function()
    local roles = {
      [1] = _role(nil),
      [2] = _role(nil),
    }
    local game = _game_with_roles(roles)
    roles[1]:force_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID, "12.5")
    game.players[2]._coin_role = {}

    _assert_error_contains(function()
      game:player_balance(game.players[1], "金币")
    end, { "玩家1", balance.COIN_COUNT_ATTR_ID, "有限整数" })

    _assert_error_contains(function()
      game:add_player_cash(game.players[2], 500)
    end, { "玩家2", balance.COIN_COUNT_ATTR_ID, "get_attr_raw_fixed", "set_attr_raw_fixed" })
  end)

  it("Player.new no longer accepts balances or stores cash", function()
    local p = Player:new({
      id = 7,
      name = "NoCash",
      role_id = 7,
      start_index = 1,
      constants = constants,
    })

    _assert_eq(p.cash, nil, "player object should not store cash")
  end)
end)
