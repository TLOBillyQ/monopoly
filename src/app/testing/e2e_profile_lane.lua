--- Pure core of the e2e profile lane (handoff e2e-profile-lane).
---
--- This module is environment-free on purpose: it enumerates profiles,
--- compares an observed game state against a profile's `expect`, and tallies a
--- run. The live editor round-trip (booting a profile, driving one turn,
--- capturing observed state) lives behind the spec/e2e boundary and feeds its
--- results back through `match` / `summarize` here. Keeping the judgment pure
--- is what lets the lane's correctness be proven headlessly.

local lane = {}

--- Split every profile the resolver knows about into the ones the lane can run
--- (those carrying an `expect`) and the ones it must skip-and-count (no
--- `expect` yet). Resolver ordering is preserved in both buckets so the lane's
--- report is stable.
---@param resolver table  -- { available_profiles(), expect_for(name) }
function lane.partition(resolver)
  local runnable, skipped = {}, {}
  for _, name in ipairs(resolver.available_profiles()) do
    if resolver.expect_for(name) ~= nil then
      runnable[#runnable + 1] = name
    else
      skipped[#skipped + 1] = name
    end
  end
  return { runnable = runnable, skipped = skipped }
end

local function _observed_field(observed, category, key, field)
  local bucket = observed and observed[category]
  local entry = bucket and bucket[key]
  if entry == nil then
    return nil
  end
  return entry[field]
end

local function _match_fields(profile_name, category, observed, expected, failures)
  for key, fields in pairs(expected or {}) do
    for field, want in pairs(fields) do
      local got = _observed_field(observed, category, key, field)
      if got ~= want then
        failures[#failures + 1] = string.format(
          "%s: %s[%s].%s expected %s, got %s",
          profile_name, category, tostring(key), tostring(field), tostring(want), tostring(got)
        )
      end
    end
  end
end

local function _has_event_kind(events, kind)
  for _, event in ipairs(events or {}) do
    if event.kind == kind then
      return true
    end
  end
  return false
end

local function _match_events(profile_name, observed, expected, failures)
  for _, wanted in ipairs(expected or {}) do
    if not _has_event_kind(observed and observed.events, wanted.kind) then
      failures[#failures + 1] = string.format(
        "%s: expected event kind %s was never observed",
        profile_name, tostring(wanted.kind)
      )
    end
  end
end

--- Compare an observed game state against a profile's expectation. Returns
--- { ok = bool, failures = { string, ... } }. Every mismatch is reported (the
--- pass does not stop at the first), and each message carries the profile name
--- plus the expected and actual values so a failing lane points straight at the
--- broken rule. A missing observed sub-table is a mismatch, never a crash.
function lane.match(profile_name, observed, expect)
  local failures = {}
  _match_fields(profile_name, "tiles", observed, expect.tiles, failures)
  _match_fields(profile_name, "players", observed, expect.players, failures)
  _match_events(profile_name, observed, expect.events, failures)
  return { ok = #failures == 0, failures = failures }
end

local function _observe_tiles(game, expect_tiles)
  local out = {}
  for idx, fields in pairs(expect_tiles or {}) do
    local tile = game.board:get_tile(idx)
    local entry = {}
    for field in pairs(fields) do
      entry[field] = tile and tile[field]
    end
    out[idx] = entry
  end
  return out
end

local function _player_in_hospital(game, player)
  if player == nil then
    return false
  end
  local hospital = game.board:find_first_by_type("hospital")
  local stay_turns = player.status and player.status.stay_turns or 0
  return player.position == hospital and stay_turns > 0
end

local function _observe_players(game, expect_players)
  local out = {}
  for idx, fields in pairs(expect_players or {}) do
    local player = game.players[idx]
    local entry = {}
    for field in pairs(fields) do
      if field == "in_hospital" then
        entry.in_hospital = _player_in_hospital(game, player)
      else
        entry[field] = player and player[field]
      end
    end
    out[idx] = entry
  end
  return out
end

local function _observe_events(recorded_events)
  local out = {}
  for _, event in ipairs(recorded_events or {}) do
    out[#out + 1] = { kind = event.kind }
  end
  return out
end

--- Reduce a live game model plus the events recorded during the driven turn
--- into the minimal observed state the expect references. This is the SAME
--- reducer the live editor lane runs (the editor only supplies the game and
--- recorded events); keeping it here means the observation is proven headlessly
--- against the real rule modules. `in_hospital` is derived (occupant relocated
--- to the hospital tile AND serving a stay), matching the demolish rule's own
--- notion of hospitalisation.
function lane.observe(game, recorded_events, expect)
  return {
    tiles = _observe_tiles(game, expect.tiles),
    players = _observe_players(game, expect.players),
    events = _observe_events(recorded_events),
  }
end

--- Tally a list of per-profile results ({ name, status }) into counts. `status`
--- is one of "passed" / "failed" / "skipped".
function lane.summarize(results)
  local counts = { passed = 0, failed = 0, skipped = 0 }
  for _, result in ipairs(results or {}) do
    if counts[result.status] ~= nil then
      counts[result.status] = counts[result.status] + 1
    end
  end
  return counts
end

return lane

--[[ mutate4lua-manifest
version=2
projectHash=6fe12467d9db64dd
scope.0.id=chunk:src/app/testing/e2e_profile_lane.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=160
scope.0.semanticHash=1e988655dd614ab2
scope.0.lastMutatedAt=2026-06-02T08:42:09Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=44
scope.0.lastMutationKilled=44
scope.1.id=function:_observed_field:29
scope.1.kind=function
scope.1.startLine=29
scope.1.endLine=36
scope.1.semanticHash=c66bd9a96b253372
scope.1.lastMutatedAt=2026-06-02T08:42:09Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:lane.match:77
scope.2.kind=function
scope.2.startLine=77
scope.2.endLine=83
scope.2.semanticHash=fb15d65fabf39482
scope.2.lastMutatedAt=2026-06-02T08:42:09Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_player_in_hospital:98
scope.3.kind=function
scope.3.startLine=98
scope.3.endLine=105
scope.3.semanticHash=72c4273bc3c69ee4
scope.3.lastMutatedAt=2026-06-02T08:42:09Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=9
scope.4.id=function:lane.observe:139
scope.4.kind=function
scope.4.startLine=139
scope.4.endLine=145
scope.4.semanticHash=a9565347d75fef1b
scope.4.lastMutatedAt=2026-06-02T08:42:09Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
]]
