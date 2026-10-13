require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- luacheck: ignore 211
local support = require("test.support.shared_support")
local control = require("src.player.control")
local default_map = require("src.config.content.default_map")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _first_land_tile = support.first_land_tile
local _tile_state = support.tile_state
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end
local _resolve_landing = support.resolve_landing
local choice_resolver = require("src.rules.choice.resolver")

local _config_reset = require("test.support.config_reset")
local saved_agent_module
before_each(function()
  saved_agent_module = package.loaded["src.computer.agent"]
end)
after_each(function()
  package.loaded["src.computer.agent"] = saved_agent_module
end)

local function _require_upvalue(fn, expected_name)
  luassert.truthy(debug and type(debug.getupvalue) == "function", "debug.getupvalue should be available for characterization tests")
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    luassert.truthy(name ~= nil, "missing upvalue: " .. tostring(expected_name))
    if name == expected_name then
      return value
    end
    index = index + 1
  end
end

local function _reload_core_agent()
  package.loaded["src.computer.agent"] = nil
  return require("src.computer.agent")
end

local function _remote_priority_for_tile_type()
  local agent = _reload_core_agent()
  local remote_priority = _require_upvalue(agent.pick_remote_dice_value, "_remote_priority")
  return _require_upvalue(remote_priority, "_remote_priority_for_tile_type")
end

local function _remote_priority_for_land()
  local agent = _reload_core_agent()
  local remote_priority = _require_upvalue(agent.pick_remote_dice_value, "_remote_priority")
  local rules = _require_upvalue(remote_priority, "remote_priority_rules")
  return rules.land
end



describe("TestLandAiPriority", function()
  before_each(function()
    _config_reset.reset_all()
  end)
  it("test_ai_picks_land_purchase", function()
    local agent = _reload_core_agent()
    local g = _new_game()
    local ai_player = g.players[2]
    luassert.truthy(control.is_computer_controlled(ai_player), "player 2 should be AI")

    g.turn.current_player_index = 2
    g.dirty.turn = true
    g.dirty.any = true

    luassert.truthy(g:current_player() == ai_player, "AI should be current player")

    local idx, tile_ref = _first_land_tile(g.board)
    g:update_player_position(ai_player, idx)

    local res = _resolve_landing(g, ai_player, tile_ref, {})
    luassert.truthy(res and res.waiting, "should wait for choice")

    local pending = g.turn.pending_choice
    luassert.truthy(pending and pending.kind == "landing_optional_effect", "should have landing choice")
    _assert_eq(pending.route_key, "secondary_confirm", "buy_land optional should expose secondary confirm route")
    _assert_eq(pending.requires_confirm, true, "buy_land optional should expose confirm requirement")
    local first_option = pending.options and pending.options[1] or nil
    luassert.truthy(first_option and first_option.confirm_title == "买地", "buy_land should expose confirm title from use-case output")
    luassert.truthy(first_option and first_option.confirm_body == "地块：" .. tile_ref.name .. "。要买吗？", "buy_land should expose confirm body from use-case output")

    local action = agent.auto_action_for_choice(g, pending)
    luassert.truthy(action, "AI should return an action")
    luassert.truthy(action.type == "choice_select", "AI should select land purchase")
    luassert.truthy(action.option_id == "buy_land", "AI should pick buy_land")

    local before_cash = g:player_cash(ai_player)
    choice_resolver.resolve(g, pending, action)
    luassert.truthy(g:player_cash(ai_player) == before_cash - tile_ref.price, "AI cash should decrease by land price")
    luassert.truthy(_tile_state(g, tile_ref).owner_id == ai_player.id, "land should be purchased")
  end)

  it("test_ai_remote_priority_ranks_item", function()
    local remote_priority = _remote_priority_for_tile_type()
    local rank, score = remote_priority("item", 2)
    _assert_eq(rank, 1, "item should keep rank")
    _assert_eq(score, 2, "item should keep score")
  end)

  it("test_ai_remote_priority_ranks_chance", function()
    local remote_priority = _remote_priority_for_tile_type()
    local rank, score = remote_priority("chance", 3)
    _assert_eq(rank, 2, "chance should keep rank")
    _assert_eq(score, 3, "chance should keep score")
  end)

  it("test_ai_remote_priority_ranks_empty_land", function()
    local remote_priority = _remote_priority_for_land()
    local rank, score = remote_priority({}, { id = 7 }, {
      type = "land",
      owner_id = nil,
      level = 0,
      rents = { 80 },
    }, 4)
    _assert_eq(rank, 3, "empty land should keep rank")
    _assert_eq(score, 4, "empty land should keep score")
  end)

  it("test_ai_remote_priority_ranks_self_owned_land", function()
    local remote_priority = _remote_priority_for_land()
    local player = { id = 7 }
    local rank, score = remote_priority({}, player, {
      type = "land",
      owner_id = player.id,
      level = 1,
      rents = { 80, 160 },
    }, 5)
    _assert_eq(rank, 4, "self-owned land should keep rank")
    _assert_eq(score, 5, "self-owned land should keep score")
  end)

  it("test_ai_remote_priority_ranks_enemy_land", function()
    local remote_priority = _remote_priority_for_land()
    local rank, score = remote_priority({}, { id = 1 }, {
      type = "land",
      owner_id = 2,
      level = 1,
      rents = { 120, 300 },
    }, 4)
    _assert_eq(rank, 10, "enemy-owned land should keep fallback rank")
    _assert_eq(score, -300, "enemy-owned land score should be negative rent")
  end)

  it("test_ai_pick_remote_dice_value_prefers_item_rank_over_market", function()
    local agent = _reload_core_agent()
    local tiles = {
      [1] = { type = "item" },
      [2] = { type = "market" },
      [3] = { type = "chance" },
      [4] = { type = "start" },
      [5] = { type = "tax" },
      [6] = { type = "hospital" },
    }
    local board = {
      step_forward_by_facing = function(_, current, facing)
        return current + 1, nil, facing, false
      end,
      has_roadblock = function()
        return false
      end,
      has_mine = function()
        return false
      end,
      get_tile = function(_, idx)
        return tiles[idx]
      end,
    }
    local value, tile = agent.pick_remote_dice_value({
      board = board,
    }, {
      id = 1,
      position = 0,
    }, 1)

    _assert_eq(value, 1, "remote dice should prefer item rank over lower-priority tiles")
    _assert_eq(tile.type, "item", "remote dice should return the chosen item tile")
  end)

  it("test_ai_pick_remote_dice_value_prefers_lower_enemy_rent", function()
    local agent = _reload_core_agent()
    local tiles = {
      [1] = { type = "land", owner_id = 2, level = 0, rents = { 100 } },
      [2] = { type = "land", owner_id = 2, level = 1, rents = { 100, 400 } },
      [3] = { type = "land", owner_id = 2, level = 0, rents = { 150 } },
      [4] = { type = "land", owner_id = 2, level = 0, rents = { 200 } },
      [5] = { type = "land", owner_id = 2, level = 0, rents = { 250 } },
      [6] = { type = "land", owner_id = 2, level = 0, rents = { 300 } },
    }
    local board = {
      step_forward_by_facing = function(_, current, facing)
        return current + 1, nil, facing, false
      end,
      has_roadblock = function()
        return false
      end,
      has_mine = function()
        return false
      end,
      get_tile = function(_, idx)
        return tiles[idx]
      end,
    }
    local value, tile = agent.pick_remote_dice_value({
      board = board,
    }, {
      id = 1,
      position = 0,
    }, 1)

    _assert_eq(value, 1, "remote dice should prefer the lowest-rent enemy land when all ranks match")
    _assert_eq(tile.rents[1], 100, "remote dice should keep negative-rent tie-break behavior")
  end)

  it("test_ai_remote_priority_ranks_market", function()
    local remote_priority = _remote_priority_for_tile_type()
    local rank, score = remote_priority("market", 6)
    _assert_eq(rank, 6, "market should keep rank")
    _assert_eq(score, 6, "market should keep score")
  end)


end)
