---@diagnostic disable: missing-fields
local roster_roles = require("src.app.roster_roles")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_assets = require("src.config.runtime_assets")
local logger = require("src.foundation.log")

-- roster_roles' only host couplings are runtime_ports.resolve_roles and
-- GameAPI.random_int; synthetic fill is driven by runtime_assets. Stub all three
-- deterministically (random_int -> min keeps the unit-key pool in order) so the
-- roster-building branches are observable, then restore the clean baseline.
local function _configure_assets()
  runtime_assets.configure_for_tests({
    refs = {
      images = {
        AI2 = "AVATAR_2",
        AI3 = "AVATAR_3",
        AI4 = "AVATAR_4",
        Empty = "EMPTY_IMG",
      },
      synthetic_ai = {
        names = { [2] = "乙", [3] = "丙", [4] = "丁" },
        unit_keys = { "U1", "U2", "U3", "U4" },
      },
    },
    constants = {},
    skins = {},
    startup_item_ids = {},
  })
end

local function _role(id, name)
  return {
    get_roleid = function() return id end,
    get_name = function() return name end,
  }
end

-- Run `fn` with resolve_roles stubbed to `roles_source` (a value or a function),
-- GameAPI.random_int deterministic, and logger calls captured. `calls` counts how
-- often the resolver ran so the first-resolve-vs-retry branch stays observable.
local function _with_roles(roles_source, fn)
  local saved_gameapi = _G.GameAPI
  local saved_warn, saved_info = logger.warn, logger.info
  local logs = { warn = 0, info = 0, resolve_calls = 0 }
  logger.warn = function() logs.warn = logs.warn + 1 end
  logger.info = function() logs.info = logs.info + 1 end
  _G.GameAPI = { random_int = function(min, _) return min end }
  _configure_assets()
  local base = type(roles_source) == "function" and roles_source or function() return roles_source end
  runtime_ports.configure({
    resolve_roles = function()
      logs.resolve_calls = logs.resolve_calls + 1
      return base()
    end,
  })
  local ok, err = pcall(fn, logs)
  runtime_ports.reset_for_tests()
  runtime_assets.reset_for_tests()
  _G.GameAPI = saved_gameapi
  logger.warn, logger.info = saved_warn, saved_info
  assert(ok, err)
end

local function _count_synthetic(roster)
  local n = 0
  for _, entry in ipairs(roster) do
    if entry.synthetic == true then
      n = n + 1
    end
  end
  return n
end

describe("roster_roles.build_startup_roster", function()
  it("seats exactly the real roles when their count matches the cap", function()
    _with_roles({ _role(101, "甲"), _role(102, "乙"), _role(103, "丙"), _role(104, "丁") }, function(logs)
      local roster = roster_roles.build_startup_roster(4)
      assert(#roster == 4, "should seat four roles, got " .. tostring(#roster))
      assert(_count_synthetic(roster) == 0, "a full real roster needs no synthetic fill")
      assert(roster[1].role_id == 101, "first seat keeps the resolved role id")
      assert(roster[1].name == "甲", "first seat keeps the resolved role name")
      assert(logs.warn == 0, "an exactly-full roster must not warn about truncation")
      assert(logs.resolve_calls == 1, "a successful first resolve must not trigger a retry")
    end)
  end)

  it("fills the remaining seats with synthetic roles in pool order", function()
    _with_roles({ _role(101, "甲") }, function(logs)
      local roster = roster_roles.build_startup_roster(4)
      assert(#roster == 4, "should fill up to the cap, got " .. tostring(#roster))
      assert(logs.resolve_calls == 1, "a non-empty first resolve must not retry")
      assert(_count_synthetic(roster) == 3, "three seats should be synthetic")
      assert(roster[1].role_id == 101, "the single real role keeps its seat")
      assert(roster[2].synthetic == true and roster[2].role_id == -2, "second seat is synthetic slot -2")
      assert(roster[2].unit_key == "U1", "synthetic seats consume the unit-key pool in order")
      assert(roster[3].unit_key == "U2", "third synthetic seat takes the next pool key")
      assert(roster[4].role_id == -4, "fourth synthetic seat is slot -4")
      assert(roster[2].avatar_image_key == "AVATAR_2", "synthetic avatar resolves from the AI image ref")
    end)
  end)

  it("truncates real roles past the cap and warns", function()
    _with_roles({
      _role(101), _role(102), _role(103), _role(104), _role(105), _role(106),
    }, function(logs)
      local roster = roster_roles.build_startup_roster(4)
      assert(#roster == 4, "roster must clamp to the cap, got " .. tostring(#roster))
      assert(_count_synthetic(roster) == 0, "an over-full real roster needs no synthetic fill")
      assert(logs.warn == 1, "truncation should warn exactly once")
    end)
  end)

  it("skips roles without a resolvable id and backfills with synthetic seats", function()
    _with_roles({ _role(101, "甲"), _role(nil, "无效"), _role(103, "丙") }, function()
      local roster = roster_roles.build_startup_roster(4)
      assert(roster[1].role_id == 101, "first valid role keeps its seat")
      assert(roster[2].role_id == 103, "the id-less role is skipped, not seated")
      assert(_count_synthetic(roster) == 2, "the two empty seats are filled synthetically")
    end)
  end)

  it("drops empty role names to nil", function()
    _with_roles({ _role(101, "") }, function()
      local roster = roster_roles.build_startup_roster(1)
      assert(#roster == 1, "cap of one seats a single role")
      assert(roster[1].role_id == 101, "the real role is seated")
      assert(roster[1].name == nil, "an empty role name resolves to nil")
    end)
  end)

  it("retries the role resolver once and logs the recovery", function()
    local attempts = 0
    _with_roles(function()
      attempts = attempts + 1
      if attempts == 1 then
        return {}
      end
      return { _role(201, "甲"), _role(202, "乙") }
    end, function(logs)
      local roster = roster_roles.build_startup_roster(4)
      assert(attempts == 2, "an empty first resolve should trigger exactly one retry")
      assert(roster[1].role_id == 201, "the retried roles are seated")
      assert(logs.info >= 1, "a successful retry should log the recovery")
      assert(_count_synthetic(roster) == 2, "remaining seats are filled synthetically")
    end)
  end)

  it("seats an all-synthetic roster when no real roles resolve", function()
    _with_roles({}, function()
      local roster = roster_roles.build_startup_roster(4)
      assert(#roster == 4, "the cap is filled entirely with synthetic seats")
      assert(_count_synthetic(roster) == 4, "every seat is synthetic")
      assert(roster[1].role_id == -1, "synthetic seats start at slot -1")
    end)
  end)

  it("seats every real role with no synthetic fill when the cap is unset", function()
    _with_roles({ _role(101, "甲"), _role(102, "乙") }, function()
      local roster = roster_roles.build_startup_roster(nil)
      assert(#roster == 2, "an unset cap seats exactly the resolved roles")
      assert(_count_synthetic(roster) == 0, "an unset cap performs no synthetic backfill")
    end)
  end)

  it("skips roles missing a get_roleid accessor entirely", function()
    _with_roles({ { get_name = function() return "无效" end }, _role(103, "丙") }, function()
      local roster = roster_roles.build_startup_roster(4)
      assert(roster[1].role_id == 103, "the accessor-less role is skipped, not seated")
      assert(_count_synthetic(roster) == 3, "the empty seats are backfilled synthetically")
    end)
  end)

  it("skips roles whose id accessor raises", function()
    _with_roles({ { get_roleid = function() error("boom") end }, _role(103, "丙") }, function()
      local roster = roster_roles.build_startup_roster(4)
      assert(roster[1].role_id == 103, "a raising id accessor is skipped, not seated")
      assert(_count_synthetic(roster) == 3, "the empty seats are backfilled synthetically")
    end)
  end)

  it("drops the name to nil when the name accessor raises", function()
    _with_roles({ { get_roleid = function() return 101 end, get_name = function() error("boom") end } }, function()
      local roster = roster_roles.build_startup_roster(1)
      assert(roster[1].role_id == 101, "the role is still seated despite the name failure")
      assert(roster[1].name == nil, "a raising name accessor resolves to nil, not the error")
    end)
  end)
end)

describe("roster_roles.build_startup_ai_map", function()
  it("marks only synthetic role ids", function()
    local ai = roster_roles.build_startup_ai_map({
      { role_id = 1 },
      { role_id = -2, synthetic = true },
      { role_id = -3, synthetic = true },
    })
    assert(ai ~= nil, "a roster with synthetic seats yields an ai map")
    assert(ai[-2] == true and ai[-3] == true, "synthetic seats are marked ai")
    assert(ai[1] == nil, "real seats are never marked ai")
  end)

  it("returns nil for an all-real or empty roster", function()
    assert(roster_roles.build_startup_ai_map({ { role_id = 1 }, { role_id = 2 } }) == nil,
      "an all-real roster has no ai map")
    assert(roster_roles.build_startup_ai_map({}) == nil, "an empty roster has no ai map")
    assert(roster_roles.build_startup_ai_map(nil) == nil, "a nil roster has no ai map")
  end)
end)

describe("roster_roles.build_synthetic_player_specs", function()
  it("emits one spec per synthetic seat, preserving fields and order", function()
    local specs = roster_roles.build_synthetic_player_specs({
      { role_id = 1, name = "甲" },
      { role_id = -2, synthetic = true, name = "乙", unit_key = "U1", avatar_image_key = "A2" },
      { role_id = -3, synthetic = true, name = "丙", unit_key = "U2", avatar_image_key = "A3" },
    })
    assert(#specs == 2, "only synthetic seats produce specs, got " .. tostring(#specs))
    assert(specs[1].player_id == -2, "spec carries the synthetic role id as player_id")
    assert(specs[1].name == "乙" and specs[1].unit_key == "U1" and specs[1].avatar_image_key == "A2",
      "spec preserves the synthetic seat fields")
    assert(specs[2].player_id == -3, "specs preserve roster order")
  end)

  it("returns an empty list when there are no synthetic seats", function()
    local specs = roster_roles.build_synthetic_player_specs({ { role_id = 1 } })
    assert(#specs == 0, "a real-only roster yields no synthetic specs")
  end)
end)
