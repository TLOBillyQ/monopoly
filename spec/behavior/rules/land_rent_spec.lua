local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local land_rules = require("src.rules.land.landing_rules")
local rent_payment = require("src.rules.land.rent_payment")
local rent_resolver = require("src.rules.land.rent_resolver")

local _new_game = function()
  return support.new_game({ map = default_map })
end

local function _ensure_land_neighbors(board)
  if board.land_neighbors then
    return board.land_neighbors
  end
  -- Mirrors src.rules.land.rent_resolver._ensure_land_neighbors so tests share the same topology.
  local neighbors = assert(board.map and board.map.neighbors, "missing board.map.neighbors")
  local land_neighbors = {}
  for _, tile in ipairs(board.path or {}) do
    if tile and tile.type == "land" then
      local list = {}
      for _, next_id in pairs(neighbors[tile.id] or {}) do
        local next_tile = board:get_tile_by_id(next_id)
        if next_tile and next_tile.type == "land" then
          list[#list + 1] = next_id
        end
      end
      land_neighbors[tile.id] = list
    end
  end
  board.land_neighbors = land_neighbors
  return land_neighbors
end

local function _find_largest_connected_strip(board)
  local land_neighbors = _ensure_land_neighbors(board)
  local visited = {}
  local best_component = {}
  for _, tile in ipairs(board.path) do
    if tile.type == "land" and not visited[tile.id] then
      local component = { tile }
      visited[tile.id] = true
      local head = 1
      local queue = { tile.id }
      while head <= #queue do
        local tid = queue[head]
        head = head + 1
        for _, next_id in ipairs(land_neighbors[tid] or {}) do
          if not visited[next_id] then
            visited[next_id] = true
            local next_tile = board:get_tile_by_id(next_id)
            component[#component + 1] = next_tile
            queue[#queue + 1] = next_id
          end
        end
      end
      if #component > #best_component then
        best_component = component
      end
    end
  end
  return best_component
end

local function _find_strip(board, min_length)
  local strip = _find_largest_connected_strip(board)
  assert(#strip >= min_length,
    "board has no connected land strip of length >= " .. tostring(min_length)
      .. " (largest = " .. tostring(#strip) .. ")")
  -- truncate to requested length while keeping connectivity (BFS order is contiguous)
  local out = {}
  for i = 1, min_length do out[i] = strip[i] end
  return out
end

local function _grant_strip_to_owner(game, owner, strip)
  for _, tile in ipairs(strip) do
    game:set_tile_owner(tile, owner.id)
    game:set_player_property(owner, tile.id, true)
  end
end

describe("domain land rent contiguous behavior", function()
  it("execute_pay_rent emits payload with contiguous_count, single_rent, deity_multiplier", function()
    local g = _new_game()
    local payer = g.players[1]
    local owner = g.players[2]
    local three_strip = _find_strip(g.board, 3)
    _grant_strip_to_owner(g, owner, three_strip)

    local hit_tile = three_strip[2]
    payer.position = assert(g.board:index_of_tile_id(hit_tile.id), "hit index missing")
    local result = land_rules.execute_pay_rent(g, payer.id, hit_tile.id)
    assert.is_truthy(result and result.ok, "execute_pay_rent should succeed")

    local payload = result.payload
    assert.equals(3, payload.contiguous_count, "payload should expose contiguous_count")
    assert.is_true(payload.single_rent > 0, "payload should expose single_rent")
    assert.equals(1, payload.deity_multiplier, "no deity → multiplier == 1")

    local pricing = require("src.rules.land.pricing")
    local expected = 0
    for _, tile in ipairs(three_strip) do
      expected = expected + pricing.rent_for_level(tile, 0)
    end
    assert.equals(expected, payload.amount, "amount should equal contiguous sum without deity")
  end)

  it("rent_paid multiplier_text includes contiguous indicator when count > 1", function()
    local g = _new_game()
    local payer = g.players[1]
    local owner = g.players[2]
    local strip = _find_largest_connected_strip(g.board)
    assert(#strip >= 2, "test requires a strip with count > 1")
    _grant_strip_to_owner(g, owner, strip)

    local hit_tile = strip[1]
    payer.position = assert(g.board:index_of_tile_id(hit_tile.id), "hit index missing")
    local result = land_rules.execute_pay_rent(g, payer.id, hit_tile.id)
    assert.is_truthy(result and result.payload, "missing payload")
    local multiplier_text = result.payload.multiplier_text
    assert.is_truthy(multiplier_text, "multiplier_text should be present when count > 1")
    assert.is_true(multiplier_text:find("连片 %d") ~= nil,
      "multiplier_text should show contiguous rent breakdown when count > 1, got: " .. multiplier_text)
  end)

  it("rent_paid multiplier_text is nil when count == 1 and no deity", function()
    local g = _new_game()
    local payer = g.players[1]
    local owner = g.players[2]
    -- Find an isolated land tile: pick one whose all land-neighbors have no owner
    local land_neighbors = _ensure_land_neighbors(g.board)
    local isolated = nil
    for _, tile in ipairs(g.board.path) do
      if tile.type == "land" and #(land_neighbors[tile.id] or {}) == 0 then
        isolated = tile
        break
      end
    end
    if not isolated then
      -- fall back: grant only one tile from a multi-tile strip
      local strip = _find_largest_connected_strip(g.board)
      isolated = strip[1]
    end
    g:set_tile_owner(isolated, owner.id)
    g:set_player_property(owner, isolated.id, true)

    payer.position = assert(g.board:index_of_tile_id(isolated.id), "hit index missing")
    local result = land_rules.execute_pay_rent(g, payer.id, isolated.id)
    assert.equals(1, result.payload.contiguous_count,
      "isolated tile should report contiguous_count == 1")
    assert.is_nil(result.payload.multiplier_text,
      "multiplier_text should be nil when no contiguous bonus and no deity")
    assert.is_nil(result.payload.text:find("连片", 1, true),
      "main text should NOT mention contiguous when count == 1, got: " .. result.payload.text)
  end)

  it("contiguous_count is owner-symmetric (AI-owned vs human-owned same strip)", function()
    local g = _new_game()
    local ai = g.players[2]
    local strip = _find_largest_connected_strip(g.board)
    assert(#strip >= 2, "test requires a strip with count > 1")
    _grant_strip_to_owner(g, ai, strip)

    local hit_tile = strip[1]
    local idx = assert(g.board:index_of_tile_id(hit_tile.id), "hit index missing")
    local breakdown = rent_resolver.contiguous_breakdown(g, g.board, idx, ai.id)
    assert.equals(#strip, breakdown.count,
      "owner being AI does not change contiguous_count semantics")

    local g2 = _new_game()
    local human2 = g2.players[1]
    local strip2 = _find_largest_connected_strip(g2.board)
    _grant_strip_to_owner(g2, human2, strip2)
    local idx2 = assert(g2.board:index_of_tile_id(strip2[1].id), "hit index missing")
    local b2 = rent_resolver.contiguous_breakdown(g2, g2.board, idx2, human2.id)
    assert.equals(breakdown.count, b2.count,
      "AI-owned strip and human-owned strip share contiguous_count semantics")
  end)

  it("PIN: paying exactly full rent leaves payer at zero but NOT bankrupt", function()
    local g = _new_game()
    local payer, owner = g.players[1], g.players[2]
    local strip = _find_strip(g.board, 1)
    _grant_strip_to_owner(g, owner, strip)
    local hit = strip[1]
    payer.position = assert(g.board:index_of_tile_id(hit.id))

    -- 先探出这次租金额,再把 payer 现金精确设为 rent。
    local probe = rent_payment.execute_pay_rent(g, payer.id, hit.id)
    local rent = probe.payload.amount
    -- 复位一局重来,精确边界:cash == rent
    g = _new_game(); payer, owner = g.players[1], g.players[2]
    _grant_strip_to_owner(g, owner, _find_strip(g.board, 1))
    local hit2 = _find_strip(g.board, 1)[1]
    payer.position = assert(g.board:index_of_tile_id(hit2.id))
    g:set_player_cash(payer, rent)

    local result = rent_payment.execute_pay_rent(g, payer.id, hit2.id)

    assert(g:player_cash(payer) == 0, "payer drained to exactly zero")
    assert(result.event == "rent_paid", "paying full rent is rent_paid, not rent_bankrupt")
    assert(result.bankrupt_reason == nil, "exact-full payment is not bankruptcy")
  end)

  it("PIN: paying less than full rent is rent_bankrupt with owner credited the partial", function()
    local g = _new_game()
    local payer, owner = g.players[1], g.players[2]
    _grant_strip_to_owner(g, owner, _find_strip(g.board, 1))
    local hit = _find_strip(g.board, 1)[1]
    payer.position = assert(g.board:index_of_tile_id(hit.id))
    local received = {}
    g.achievement_progress_port = {
      cash_received = function(_, p, amt) received[#received+1] = { id = p.id, amount = amt }; return true end,
    }
    g:set_player_cash(payer, 1)  -- 远小于任何 rent

    local owner_before = g:player_cash(owner)
    local result = rent_payment.execute_pay_rent(g, payer.id, hit.id)

    assert(result.event == "rent_bankrupt", "short payer triggers rent_bankrupt")
    assert(result.bankrupt_reason ~= nil, "bankrupt_reason set for land_events to eliminate")
    assert(g:player_cash(payer) == 0, "payer fully drained")
    assert(g:player_cash(owner) == owner_before + 1, "owner credited the partial 1")
    assert(received[1] and received[1].id == owner.id and received[1].amount == 1,
      "cash_received telemetry fires for the partial amount")
    assert(payer.eliminated ~= true, "eliminate deferred to land_events")
  end)
end)

describe("domain land rent contiguous cache and boundary behavior", function()
  -- Synthetic single-land-tile board so version/cache/topology boundaries are
  -- directly controllable, which the default_map fixtures cannot exercise.
  local function _make_board(tiles, neighbors)
    local by_id = {}
    for _, t in ipairs(tiles) do
      by_id[t.id] = t
    end
    return {
      map = { neighbors = neighbors },
      path = tiles,
      get_tile_by_id = function(_, id) return by_id[id] end,
      get_tile = function(_, index) return tiles[index] end,
    }
  end

  -- price 200, upgrade_costs {100} → rent_for_level 0 = 100, level 1 = 200.
  local function _single_land(owner_id, level)
    return {
      id = 1,
      type = "land",
      price = 200,
      owner_id = owner_id,
      level = level or 0,
      upgrade_costs = { 100 },
    }
  end

  it("contiguous_rent and contiguous_count return numeric values for an owned tile", function()
    local game = {}
    local tile = _single_land("p1", 0)
    local board = _make_board({ tile }, { [1] = {} })
    -- kills L114 replace _resolve_component(...) with nil (would return nil rent).
    assert.equals(100, rent_resolver.contiguous_rent(game, board, 1, "p1"))
    assert.equals(1, rent_resolver.contiguous_count(game, board, 1, "p1"))
  end)

  it("returns zero rent, zero count and a zero breakdown when the query owner does not own the tile", function()
    local game = {}
    local tile = _single_land(nil, 0) -- unowned
    local board = _make_board({ tile }, { [1] = {} })
    -- kills both L97 replace 0 with 1 (rent slot and count slot of the early return).
    assert.equals(0, rent_resolver.contiguous_rent(game, board, 1, "p1"))
    assert.equals(0, rent_resolver.contiguous_count(game, board, 1, "p1"))
    -- kills all three L126 replace 0 with 1 (count/single_rent/total_rent of the zero breakdown).
    local breakdown = rent_resolver.contiguous_breakdown(game, board, 1, "p1")
    assert.equals(0, breakdown.count)
    assert.equals(0, breakdown.single_rent)
    assert.equals(0, breakdown.total_rent)
  end)

  it("keeps the cached total stale until the rent-version changes", function()
    local game = {}
    local tile = _single_land("p1", 0)
    local board = _make_board({ tile }, { [1] = {} })
    game._land_rent_version = 5

    local first = rent_resolver.contiguous_breakdown(game, board, 1, "p1")
    assert.equals(100, first.total_rent)

    -- Raise the level (fresh rent would be 200) but keep the same version.
    -- The cached total must remain 100.
    tile.level = 1
    local second = rent_resolver.contiguous_breakdown(game, board, 1, "p1")
    -- kills L37 replace ~= with == (would rebuild on equal version) and
    -- L50 replace not with removed not (would reset tile_count and force recompute).
    assert.equals(100, second.total_rent)
    -- kills L53 replace not with removed not (would reset tile_rents, dropping cached rents).
    assert.equals(1, #second.rents)
    assert.equals(100, second.rents[1])
  end)

  it("bumping rent-version from the implicit-zero default invalidates the cache", function()
    local game = {}
    local tile = _single_land("p1", 0)
    local board = _make_board({ tile }, { [1] = {} })
    -- No _land_rent_version set → version defaults to 0.
    assert.equals(100, rent_resolver.contiguous_rent(game, board, 1, "p1"))

    tile.level = 1
    game._land_rent_version = 1
    -- kills L35 replace 0 with 1 (default of nil version): a 1-default would match the
    -- stored cache version and wrongly reuse the stale 100.
    assert.equals(200, rent_resolver.contiguous_rent(game, board, 1, "p1"))
  end)

  it("changing rent-version away from a truthy value invalidates the cache", function()
    local game = {}
    local tile = _single_land("p1", 0)
    local board = _make_board({ tile }, { [1] = {} })
    game._land_rent_version = 7
    assert.equals(100, rent_resolver.contiguous_rent(game, board, 1, "p1"))

    tile.level = 1
    game._land_rent_version = 0
    -- kills L35 replace or with and: `version and 0` would collapse the stored version to 0,
    -- matching the new 0 version and wrongly reusing the stale 100.
    assert.equals(200, rent_resolver.contiguous_rent(game, board, 1, "p1"))
  end)

  it("skips non-land path tiles when building land neighbors", function()
    local game = {}
    local land = _single_land("p1", 0) -- id 1
    local non_land = { id = 2, type = "toolshop" }
    -- Only the land tile has a neighbors entry; the non-land tile deliberately has none.
    local board = _make_board({ land, non_land }, { [1] = {} })
    -- kills L16 replace and with or: touching tile id 2 would hit
    -- `assert(neigh ~= nil)` on the missing neighbors entry and throw.
    assert.equals(100, rent_resolver.contiguous_rent(game, board, 1, "p1"))
  end)

  it("drops neighbor ids that resolve to no tile", function()
    local game = {}
    local land = _single_land("p1", 0) -- id 1
    -- Neighbor id 99 has no corresponding tile → get_tile_by_id returns nil.
    local board = _make_board({ land }, { [1] = { 99 } })
    -- kills L22 replace and with or: a nil next_tile would be indexed (`next_tile.type`) and throw.
    assert.equals(100, rent_resolver.contiguous_rent(game, board, 1, "p1"))
  end)
end)
