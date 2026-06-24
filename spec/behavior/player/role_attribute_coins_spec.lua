local support = require("spec.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local constants = require("src.config.content.constants")
local balance = require("src.player.actions.balance")
local Player = require("src.player.actions.player")

local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local function _role(initial)
  local attrs = {
    [balance.COIN_COUNT_ATTR_ID] = initial,
  }
  local role = {
    writes = {},
    fail_next_set = false,
  }
  function role:get_attr_raw_fixed(attr_id)
    return attrs[attr_id]
  end
  function role:force_attr_raw_fixed(attr_id, value)
    attrs[attr_id] = value
  end
  function role:set_attr_raw_fixed(attr_id, value)
    if self.fail_next_set == true then
      self.fail_next_set = false
      return false
    end
    attrs[attr_id] = value
    self.writes[#self.writes + 1] = {
      attr_id = attr_id,
      value = value,
    }
    return true
  end
  return role
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
    _assert_eq(game.players[1].cash, nil, "player.cash must not exist")
    _assert_eq(#(game.turn.action_anim_queue or {}), 0, "startup seed must not queue cash animation")
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
    end, { "玩家2", balance.COIN_COUNT_ATTR_ID, "回滚结果" })

    _assert_eq(roles[1]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 10000, "payer rollback")
    _assert_eq(roles[2]:get_attr_raw_fixed(balance.COIN_COUNT_ATTR_ID), 2000, "receiver unchanged")
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
