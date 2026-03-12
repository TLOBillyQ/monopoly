-- T6 characterization tests for remaining hotspots
local market_slots = require("src.presentation.view.render.market_slots")
local placement = require("src.presentation.view.render.board.placement")
local status3d_status = require("src.presentation.view.render.status3d.status")
local board_feedback = require("src.presentation.view.render.board_feedback_service")

local function _test_resolve_market_name_from_entry()
  local name = market_slots._resolve_market_name(nil, 1001, { name = "EntryName" }, nil)
  assert(name == "EntryName", "should return entry name when available")
end

local function _test_resolve_market_name_from_cfg()
  local name = market_slots._resolve_market_name(nil, 1001, nil, { name = "CfgName" })
  assert(name == "CfgName", "should return cfg name when entry name missing")
end

local function _test_resolve_market_name_from_opt_label()
  local name = market_slots._resolve_market_name({ label = "OptLabel" }, 1001, nil, nil)
  assert(name == "OptLabel", "should return opt label when entry/cfg missing")
end

local function _test_resolve_market_name_fallback_to_product_id()
  local name = market_slots._resolve_market_name(nil, 1001, nil, nil)
  assert(name == "1001", "should fallback to product_id as string")
end

local function _test_resolve_occupant_slot_single_player()
  local list = { "p1" }
  local slot, count = placement._resolve_occupant_slot(list, "p1")
  assert(slot == 1, "single player should be slot 1")
  assert(count == 1, "single player count should be 1")
end

local function _test_resolve_occupant_slot_first_in_list()
  local list = { "p1", "p2", "p3" }
  local slot, count = placement._resolve_occupant_slot(list, "p1")
  assert(slot == 1, "first player should be slot 1")
  assert(count == 3, "count should be list length")
end

local function _test_resolve_occupant_slot_middle_in_list()
  local list = { "p1", "p2", "p3" }
  local slot, count = placement._resolve_occupant_slot(list, "p2")
  assert(slot == 2, "middle player should be slot 2")
  assert(count == 3, "count should be list length")
end

local function _test_resolve_occupant_slot_last_in_list()
  local list = { "p1", "p2", "p3" }
  local slot, count = placement._resolve_occupant_slot(list, "p3")
  assert(slot == 3, "last player should be slot 3")
  assert(count == 3, "count should be list length")
end

local function _test_resolve_player_status_key_eliminated()
  local game = {}
  local player = { eliminated = true }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == nil, "eliminated player should have no status key")
end

local function _test_resolve_player_status_key_nil_player()
  local key = status3d_status.resolve_player_status_key({}, nil)
  assert(key == nil, "nil player should have no status key")
end

local function _test_resolve_player_status_key_hospital()
  local game = {
    board = {
      get_tile = function()
        return { type = "hospital" }
      end,
    },
    turn = {
      no_action_notice_active = true,
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 3,
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = { stay_turns = 3 },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == "hospital", "hospital tile with stay_turns should return hospital")
end

local function _test_resolve_player_status_key_mountain()
  local game = {
    board = {
      get_tile = function()
        return { type = "mountain" }
      end,
    },
    turn = {
      detained_wait_active = true,
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 2,
    },
  }
  local player = {
    id = 1,
    position = 10,
    status = { stay_turns = 2 },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == "mountain", "mountain tile with stay_turns should return mountain")
end

local function _test_resolve_player_status_key_roadblock()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {
      player_id = 1,
      move_result = { stopped_on_roadblock = true },
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = {},
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == "roadblock", "roadblock stop should return roadblock key")
end

local function _test_resolve_player_status_key_poor_deity()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "poor", remaining = 3 },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == "poor", "poor deity should return poor key")
end

local function _test_resolve_player_status_key_rich_deity()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "rich", remaining = 5 },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == "rich", "rich deity should return rich key")
end

local function _test_resolve_player_status_key_angel_deity()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "angel", remaining = 2 },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == "angel", "angel deity should return angel key")
end

local function _test_resolve_player_status_key_no_status()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {},
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  assert(key == nil, "no special status should return nil")
end

local function _test_play_cue_nil_cue_name()
  local state = {}
  local result = board_feedback.play_tile_cue(state, nil, 1, {})
  assert(result == false, "nil cue_name should return false")
end

local function _test_play_cue_empty_cue_name()
  local state = {}
  local result = board_feedback.play_tile_cue(state, "", 1, {})
  assert(result == false, "empty cue_name should return false")
end

return {
  name = "gameplay.t6_characterization",
  tests = {
    { name = "resolve_market_name_from_entry", run = _test_resolve_market_name_from_entry },
    { name = "resolve_market_name_from_cfg", run = _test_resolve_market_name_from_cfg },
    { name = "resolve_market_name_from_opt_label", run = _test_resolve_market_name_from_opt_label },
    { name = "resolve_market_name_fallback_to_product_id", run = _test_resolve_market_name_fallback_to_product_id },
    { name = "resolve_occupant_slot_single_player", run = _test_resolve_occupant_slot_single_player },
    { name = "resolve_occupant_slot_first_in_list", run = _test_resolve_occupant_slot_first_in_list },
    { name = "resolve_occupant_slot_middle_in_list", run = _test_resolve_occupant_slot_middle_in_list },
    { name = "resolve_occupant_slot_last_in_list", run = _test_resolve_occupant_slot_last_in_list },
    { name = "resolve_player_status_key_eliminated", run = _test_resolve_player_status_key_eliminated },
    { name = "resolve_player_status_key_nil_player", run = _test_resolve_player_status_key_nil_player },
    { name = "resolve_player_status_key_hospital", run = _test_resolve_player_status_key_hospital },
    { name = "resolve_player_status_key_mountain", run = _test_resolve_player_status_key_mountain },
    { name = "resolve_player_status_key_roadblock", run = _test_resolve_player_status_key_roadblock },
    { name = "resolve_player_status_key_poor_deity", run = _test_resolve_player_status_key_poor_deity },
    { name = "resolve_player_status_key_rich_deity", run = _test_resolve_player_status_key_rich_deity },
    { name = "resolve_player_status_key_angel_deity", run = _test_resolve_player_status_key_angel_deity },
    { name = "resolve_player_status_key_no_status", run = _test_resolve_player_status_key_no_status },
    { name = "play_cue_nil_cue_name", run = _test_play_cue_nil_cue_name },
    { name = "play_cue_empty_cue_name", run = _test_play_cue_empty_cue_name },
  },
}
