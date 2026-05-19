local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local land_rules = require("src.rules.land.landing_rules")
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
end)
