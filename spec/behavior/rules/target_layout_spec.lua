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
