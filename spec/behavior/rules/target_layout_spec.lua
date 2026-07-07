local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local target_layout = require("src.rules.board.target_layout")

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _option(g, tile_id)
  local idx = assert(g.board:index_of_tile_id(tile_id), "missing tile id " .. tostring(tile_id))
  return { id = idx, tile_id = tile_id }
end

local function _slot_tile_ids(dense_options, slot_layout)
  local by_slot = {}
  for i, opt in ipairs(dense_options) do
    by_slot[slot_layout[i]] = opt.tile_id
  end
  return by_slot
end

describe("target_layout.arrange_target_options", function()
  it("centers the player's own tile and orders neighbors by direction and distance", function()
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(42))

    local options = {}
    for _, tile_id in ipairs({ 42, 3, 4, 31, 45, 2, 5, 1 }) do
      options[#options + 1] = _option(g, tile_id)
    end

    local dense_options, slot_layout = target_layout.arrange_target_options(g.board, p, options)
    local by_slot = _slot_tile_ids(dense_options, slot_layout)

    assert(#dense_options == 7, "seven UI slots should be filled (one candidate overflows)")
    assert(by_slot[4] == 42, "player's own tile should occupy the center slot")
    assert(by_slot[3] == 3 and by_slot[2] == 2 and by_slot[1] == 1,
      "backward neighbors should fill outward from center in distance order")
    assert(by_slot[5] == 4 and by_slot[6] == 45 and by_slot[7] == 31,
      "forward neighbors should fill outward from center in distance order")
    assert(by_slot[nil] == nil, "no slot should be assigned past the overflow candidate")
  end)

  it("omits the player's own tile from slots when it is not among the options", function()
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(42))

    local options = { _option(g, 3), _option(g, 4) }
    local dense_options, slot_layout = target_layout.arrange_target_options(g.board, p, options)
    local by_slot = _slot_tile_ids(dense_options, slot_layout)

    assert(#dense_options == 2, "only the two supplied candidates should be arranged")
    assert(by_slot[4] == nil, "center slot should stay empty when the player's tile is not offered")
    assert(by_slot[3] == 3, "sole backward candidate should sit closest to center")
    assert(by_slot[5] == 4, "sole forward candidate should sit closest to center")
  end)
end)

-- Direct-geometry scenarios. The mock board exposes an empty movement map, so
-- direction.collect_forward/backward_indices return empty sets and every
-- candidate is classified purely by manhattan geometry relative to the start
-- tile: a larger row is "backward", a smaller row is "forward". That makes the
-- slot fill / overflow ordering fully deterministic.
local function _mock_board(tiles)
  return {
    map = {
      outer_next = {},
      outer_prev = {},
      neighbors = setmetatable({}, { __index = function() return {} end }),
      entry_points = {},
      direction = function() return "right" end,
    },
    get_tile = function(_, idx) return tiles[idx] end,
    index_of_tile_id = function(_, id) return id end,
  }
end

local function _row_tiles(start_row, deltas)
  local tiles = { [1] = { id = 1, row = start_row, col = 0 } }
  local options = {}
  for offset, delta in ipairs(deltas) do
    local idx = offset + 1
    tiles[idx] = { id = idx, row = start_row + delta, col = 0 }
    options[offset] = { id = idx }
  end
  return tiles, options
end

local function _dense_ids(dense_options)
  local ids = {}
  for i, opt in ipairs(dense_options) do
    ids[i] = opt.id
  end
  return ids
end

local function _assert_list_eq(actual, expected, label)
  assert(#actual == #expected,
    label .. ": expected length " .. tostring(#expected) .. " got " .. tostring(#actual))
  for i = 1, #expected do
    assert(actual[i] == expected[i],
      label .. "[" .. tostring(i) .. "]: expected " .. tostring(expected[i]) .. " got " .. tostring(actual[i]))
  end
end

describe("target_layout.arrange_target_options slot geometry", function()
  local player = { position = 1, status = nil }

  it("spills surplus backward candidates outward into empty forward slots", function()
    -- Five backward candidates (rows 11..15) fill slots 3,2,1 then overflow into
    -- forward slots 5,6; there is no sixth slot so the layout stops at slot 6.
    local tiles, options = _row_tiles(10, { 1, 2, 3, 4, 5 })
    local dense, layout = target_layout.arrange_target_options(_mock_board(tiles), player, options)
    _assert_list_eq(_dense_ids(dense), { 4, 3, 2, 5, 6 }, "backward overflow dense ids")
    _assert_list_eq(layout, { 1, 2, 3, 5, 6 }, "backward overflow slot layout")
  end)

  it("spills surplus forward candidates inward into empty backward slots", function()
    -- Five forward candidates (rows 9..5) fill slots 5,6,7 then overflow into
    -- backward slots 3,2; slot 1 stays empty because the queue is exhausted.
    local tiles, options = _row_tiles(10, { -1, -2, -3, -4, -5 })
    local dense, layout = target_layout.arrange_target_options(_mock_board(tiles), player, options)
    _assert_list_eq(_dense_ids(dense), { 6, 5, 2, 3, 4 }, "forward overflow dense ids")
    _assert_list_eq(layout, { 2, 3, 5, 6, 7 }, "forward overflow slot layout")
  end)

  it("does not overwrite a filled forward slot when backward candidates overflow", function()
    -- Four backward candidates plus one distant forward candidate: the forward
    -- one claims slot 5 in the primary pass, so the backward overflow must skip
    -- slot 5 and land in slot 6 rather than clobbering it.
    local tiles, options = _row_tiles(10, { 1, 2, 3, 4, -5 })
    local dense, layout = target_layout.arrange_target_options(_mock_board(tiles), player, options)
    _assert_list_eq(_dense_ids(dense), { 4, 3, 2, 6, 5 }, "mixed overflow dense ids")
    _assert_list_eq(layout, { 1, 2, 3, 5, 6 }, "mixed overflow slot layout")
  end)

  it("keeps a candidate co-located with the start tile by flooring its distance to 1", function()
    -- A candidate sharing the start tile's position has manhattan distance 0;
    -- it must be floored to distance 1 so it survives the distance-1..max walk
    -- instead of being dropped into an unwalked distance-0 bucket.
    local tiles = {
      [1] = { id = 1, row = 10, col = 0 },
      [2] = { id = 2, row = 10, col = 0 },
    }
    local dense, layout = target_layout.arrange_target_options(_mock_board(tiles), player, { { id = 2 } })
    _assert_list_eq(_dense_ids(dense), { 2 }, "co-located dense ids")
    _assert_list_eq(layout, { 5 }, "co-located slot layout")
  end)
end)
