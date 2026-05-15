local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local support = require("spec.support.rules_support")

local function _invite_deity_candidates(game, user)
  local spec = assert(post_effects.get_target_spec(item_ids.invite_deity))
  local candidates = {}
  for _, target in ipairs(game.players) do
    if target ~= user and not target.eliminated and spec.filter_target(game, user, target) then
      candidates[#candidates + 1] = target
    end
  end
  return candidates
end

local function _contains_player(players, expected)
  for _, player in ipairs(players) do
    if player == expected then
      return true
    end
  end
  return false
end

local function _assert_eq(actual, expected, message)
  assert(actual == expected, message .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

describe("invite_deity transfer atomicity", function()
  it("invite_deity rejects empty placeholder", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local a = game.players[1]
    local b = game.players[2]

    b.status.deity = { type = "", remaining = 0 }

    _assert_eq(_contains_player(_invite_deity_candidates(game, a), b), false, "empty placeholder should not be a candidate")
  end)

  it("invite_deity happy path", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local a = game.players[1]
    local b = game.players[2]

    b.status.deity = { type = "rich", remaining = 3 }

    _assert_eq(post_effects.apply_target(game, a, item_ids.invite_deity, b, {}), true, "invite should apply")
    _assert_eq(a.status.deity.type, "rich", "user should gain rich deity")
    _assert_eq(a.status.deity.remaining, 3, "user should keep remaining turns")
    _assert_eq(b.status.deity.type, "", "target deity type should be cleared")
    _assert_eq(b.status.deity.remaining, 0, "target deity remaining should be cleared")
  end)

  it("invite_deity filter rejects no-deity", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local a = game.players[1]
    local b = game.players[2]

    b.status = nil

    _assert_eq(_contains_player(_invite_deity_candidates(game, a), b), false, "no-deity player should not be a candidate")
  end)

  it("chain send invite", function()
    local game = support.new_game({ players = { "A", "B", "C" }, auto_all = true })
    local a = game.players[1]
    local b = game.players[2]
    local c = game.players[3]

    a.status.deity = { type = "poor", remaining = 3 }
    _assert_eq(post_effects.apply_target(game, a, item_ids.send_poor, b, {}), true, "send_poor should apply")

    _assert_eq(a.status.deity.type, "", "sender deity type should be cleared")
    _assert_eq(a.status.deity.remaining, 0, "sender deity remaining should be cleared")
    _assert_eq(_contains_player(_invite_deity_candidates(game, c), a), false, "cleared sender should not be an invite candidate")
  end)
end)

describe("send_poor transfer atomicity", function()
  local function _send_poor_apply()
    return assert(post_effects.get_target_spec(item_ids.send_poor)).apply
  end

  it("send_poor rejects rich user", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "rich", remaining = 3 }

    assert.has_error(function()
      _send_poor_apply()(game, user, target, {})
    end, "send_poor.apply: user must have effective poor deity")
  end)

  it("send_poor rejects angel user", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "angel", remaining = 3 }

    assert.has_error(function()
      _send_poor_apply()(game, user, target, {})
    end, "send_poor.apply: user must have effective poor deity")
  end)

  it("send_poor rejects expired poor", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "poor", remaining = 0 }

    assert.has_error(function()
      _send_poor_apply()(game, user, target, {})
    end, "send_poor.apply: user must have effective poor deity")
  end)

  it("send_poor happy path", function()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "poor", remaining = 3 }

    _assert_eq(_send_poor_apply()(game, user, target, {}), true, "send_poor should apply")
    _assert_eq(user.status.deity.type, "", "sender deity type should be cleared")
    _assert_eq(user.status.deity.remaining, 0, "sender deity remaining should be cleared")
    _assert_eq(target.status.deity.type, "poor", "target should receive poor deity")
    _assert_eq(target.status.deity.remaining, 3, "target should keep remaining turns")
  end)
end)
