require("test.bootstrap").install_package_paths()
-- luacheck: ignore 143 (busted injects the verified luassert object)
local luassert = assert
local property = require("test.support.property")
local board_query = require("src.rules.board.query")
local target_query = require("src.rules.items.target_query")

-- A linear board: tile i sits at (row=0, col=i-1) with id==index, so the board's
-- manhattan distance between tiles i and j is exactly |i-j|. That makes
-- indices_in_range deterministic and lets the test reason about candidates
-- without re-deriving range geometry.
local function _make_board(tile_count)
  local path = {}
  for i = 1, tile_count do
    path[i] = { id = i, row = 0, col = i - 1, type = "land", name = "tile_" .. i }
  end
  return {
    path = path,
    get_tile = function(_, idx) return path[idx] end,
    index_of_tile_id = function(_, id) return id end,
  }
end

local function _gen_case(rng)
  local tile_count = rng:int(1, 10)
  local scores = {}
  -- small score range so ties between candidates actually occur
  for i = 1, tile_count do
    scores[i] = rng:int(0, 6)
  end
  return {
    tile_count = tile_count,
    position = rng:int(1, tile_count),
    distance = rng:int(0, tile_count),
    allow_self = rng:bool(),
    scores = scores,
  }
end

-- Rebuild the candidate list exactly as find_best_tile sees it: the in-range
-- indices (which never include self), with the player's position prepended only
-- when allow_self is set.
local function _candidates(board, case)
  local list = board_query.indices_in_range(board, case.position, case.distance)
  local candidates = {}
  if case.allow_self then
    candidates[#candidates + 1] = case.position
  end
  for _, idx in ipairs(list) do
    candidates[#candidates + 1] = idx
  end
  return candidates
end


describe("TestTargetQuery", function()
  it("test_errors_on_nil_game_with_expected_message", function()
    local ok, err = pcall(target_query.find_best_tile, nil, { position = 1 }, 3, { score_fn = function() return 0 end })
    luassert.truthy(not ok, "nil game should error")
    luassert.truthy(type(err) == "string" and err:find("missing game", 1, true), "error should mention missing game, got: " .. tostring(err))
  end)

  it("test_errors_on_nil_player_with_expected_message", function()
    local ok, err = pcall(target_query.find_best_tile, { board = {} }, nil, 3, { score_fn = function() return 0 end })
    luassert.truthy(not ok, "nil player should error")
    luassert.truthy(type(err) == "string" and err:find("missing player", 1, true), "error should mention missing player, got: " .. tostring(err))
  end)

  it("test_errors_on_nil_opts_with_expected_message", function()
    local ok, err = pcall(target_query.find_best_tile, { board = {} }, { position = 1 }, 3, nil)
    luassert.truthy(not ok, "nil opts should error")
    luassert.truthy(type(err) == "string" and err:find("missing opts", 1, true), "error should mention missing opts, got: " .. tostring(err))
  end)

  it("test_returns_the_first_maximally_scored_candidate_with_its_score", function()
    property.for_all(_gen_case, function(case)
      local board = _make_board(case.tile_count)
      local game = { board = board }
      local player = { position = case.position }
      local score_fn = function(_, idx) return case.scores[idx] + 1 end

      local best_idx, best_value = target_query.find_best_tile(game, player, case.distance, {
        score_fn = score_fn,
        allow_self = case.allow_self,
      })

      local candidates = _candidates(board, case)
      local expect_idx, expect_value = nil, nil
      for _, idx in ipairs(candidates) do
        local value = score_fn(nil, idx)
        if not expect_idx or value > expect_value then
          expect_idx, expect_value = idx, value
        end
      end

      luassert.truthy(best_idx == expect_idx, "expected best index " .. tostring(expect_idx) .. ", got " .. tostring(best_idx))
      luassert.truthy(best_value == expect_value, "expected best value " .. tostring(expect_value) .. ", got " .. tostring(best_value))
      if best_idx ~= nil then
        luassert.truthy(best_value == score_fn(nil, best_idx), "returned value must be the winner's score")
      end
    end)
  end)

  it("test_includes_the_players_own_position_only_when_allow_self_is_set", function()
    property.for_all(_gen_case, function(case)
      local board = _make_board(case.tile_count)
      local game = { board = board }
      local player = { position = case.position }
      local score_fn = function(_, idx) return case.scores[idx] + 1 end

      local best_idx = target_query.find_best_tile(game, player, case.distance, {
        score_fn = score_fn,
        allow_self = case.allow_self,
      })

      local in_range = #board_query.indices_in_range(board, case.position, case.distance) > 0
      if not case.allow_self then
        luassert.truthy(best_idx ~= case.position, "must never select self when allow_self is unset")
        if not in_range then
          luassert.truthy(best_idx == nil, "no candidates means no selection")
        end
      elseif not in_range then
        luassert.truthy(best_idx == case.position, "allow_self with empty range must fall back to self")
      end
    end)
  end)



  it("test_find_best_tile_asserts_args_with_messages", function()
    -- #293:find_best_tile 的两处装配断言消息未测。
    local ok_score, err_score = pcall(target_query.find_best_tile, {}, {}, 3, {})
    luassert.truthy(ok_score == false, "missing score_fn should assert")
    luassert.truthy(tostring(err_score):find("missing score_fn", 1, true) ~= nil, "score assert should carry its message: " .. tostring(err_score))

    local ok_board, err_board = pcall(target_query.find_best_tile, {}, {}, 3, { score_fn = function() return 1 end })
    luassert.truthy(ok_board == false, "missing game.board should assert")
    luassert.truthy(tostring(err_board):find("missing game.board", 1, true) ~= nil, "board assert should carry its message: " .. tostring(err_board))
  end)

end)
