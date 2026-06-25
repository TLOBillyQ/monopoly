---@diagnostic disable: missing-fields

local property = require("spec.support.property")
local roster = require("src.app.roster")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local balance = require("src.player.actions.balance")

local SEATS = 4

-- Mirror tools/acceptance/steps/setup.lua's real-startup seam: roster's only host
-- couplings are runtime_ports.resolve_roles and GameAPI.random_int. Stub both for a
-- synchronous release build (which bypasses profile bootstrap), then restore the
-- clean baseline so cases never leak into each other.
local function _mock_roles(count)
  local roles = {}
  for i = 1, count do
    local role_id = 100 + i
    local attrs = {}
    local role = {}
    role.get_roleid = function() return role_id end
    role.get_name = function() return "真人" .. tostring(i) end
    role.get_attr_raw_fixed = function(first, second)
      local attr_id = first == role and second or first
      return attrs[attr_id]
    end
    role.set_attr_raw_fixed = function(first, second, third)
      local attr_id = first == role and second or first
      local value = first == role and third or second
      attrs[attr_id] = value
      return attr_id == balance.COIN_COUNT_ATTR_ID
    end
    roles[i] = role
  end
  return roles
end

local function _build_with_signups(signup_count)
  local saved_gameapi = _G.GameAPI
  _G.GameAPI = { random_int = function(min, _) return min end }
  runtime_ports.configure({
    resolve_roles = function() return _mock_roles(signup_count) end,
  })
  local ok, result = pcall(function()
    return roster.build_game_factory({}, { build_mode = "release" })()
  end)
  runtime_ports.reset_for_tests()
  _G.GameAPI = saved_gameapi
  assert(ok, "roster build failed for signup_count=" .. tostring(signup_count) .. ": " .. tostring(result))
  return result
end

local function _count_ai(game)
  local ai = 0
  for _, player in ipairs(game.players) do
    if player.is_ai == true then
      ai = ai + 1
    end
  end
  return ai
end

describe("roster seating clamp/fill invariants over the real startup path", function()
  -- 0 -> all AI, 1..3 -> mixed, 4 -> boundary all-real, 5..8 -> real roles truncated.
  it("always seats exactly four roles, filling the AI remainder and truncating overflow", function()
    property.check_int_range(0, 8, function(signup_count)
      local game = _build_with_signups(signup_count)
      local total = #game.players
      local ai = _count_ai(game)
      local real = total - ai
      local seated_real = math.min(signup_count, SEATS)

      assert(total == SEATS,
        "expected " .. SEATS .. " seated roles for signup=" .. signup_count .. ", got " .. tostring(total))
      assert(real == seated_real,
        "expected " .. seated_real .. " real roles for signup=" .. signup_count .. ", got " .. tostring(real))
      assert(ai == SEATS - seated_real,
        "expected " .. (SEATS - seated_real) .. " AI roles for signup=" .. signup_count .. ", got " .. tostring(ai))
      assert(real + ai == SEATS,
        "real + AI roles must conserve to " .. SEATS .. " for signup=" .. signup_count)
    end)
  end)
end)
