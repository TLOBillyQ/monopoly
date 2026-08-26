local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local board_state = require("src.state.board_state")
local log_capture = require("test.support.log_capture")

-- board_state mixin methods route every tile mutation through _sync_board_visual;
-- these exercise that port resolution (attached / missing / throwing)
-- via the public set_tile_owner entry.
local function _land_tile(id, owner_id)
  return { type = "land", id = id, owner_id = owner_id }
end

TestBoardState = {}

function TestBoardState:test_pushes_the_changed_tile_through_an_attached_feedback_port()
  local synced = nil
  local self_state = {
    dirty = {},
    board_visual_feedback_port = {
      sync_many = function(_, payload)
        synced = payload
        return true
      end,
    },
  }

  board_state.set_tile_owner(self_state, _land_tile(5, 2), 7)

  _assert_eq(self_state.dirty.board_tiles, true, "owner change should mark the board dirty")
  lu.assertEvalToTrue(synced ~= nil, "an attached feedback port should receive the sync payload")
  _assert_eq(synced.tile_ids[1], 5, "sync payload should target the changed tile id")
end

function TestBoardState:test_still_completes_the_owner_change_with_no_port_and_survives_a_throwing_port()
  local no_port = { dirty = {} }
  board_state.set_tile_owner(no_port, _land_tile(1), 3)
  _assert_eq(no_port.dirty.board_tiles, true,
    "owner change should mark dirty even without a feedback port")

  local throwing = {
    dirty = {},
    board_visual_feedback_port = {
      sync_many = function()
        error("sync boom")
      end,
    },
  }
  local tile = _land_tile(2)
  local ok = pcall(board_state.set_tile_owner, throwing, tile, 4)
  _assert_eq(ok, true, "a throwing feedback port must not break the owner update")
  _assert_eq(tile.owner_id, 4, "the owner should still be applied despite the port error")
end

-- #551:失败路径可观测性契约——pcall 吞错 / port 未接线 warn 留痕且去重;
-- no-op port(handled==false)是 headless 合法日常,保持静默。
local function _count_board_state_warns(captured)
  local count = 0
  for _, line in ipairs(captured.lines) do
    if line:find("[board_state]", 1, true) ~= nil then
      count = count + 1
    end
  end
  return count
end

local function _assert_warn_contains(captured, needle, label)
  local joined = table.concat(captured.lines, "\n")
  lu.assertEvalToTrue(joined:find("[board_state]", 1, true) ~= nil
    and joined:find(needle, 1, true) ~= nil,
    label .. "; got " .. joined)
end

local function _throwing_game()
  return {
    dirty = {},
    board_visual_feedback_port = {
      sync_many = function()
        error("sync boom")
      end,
    },
  }
end

function TestBoardState:test_warns_with_the_swallowed_error_when_the_port_throws()
  local returned = "untouched"
  local ok, _, captured = log_capture.capture(function()
    returned = board_state.set_tile_owner(_throwing_game(), _land_tile(3), 5)
  end)
  lu.assertEvalToTrue(ok == true, "a throwing port must not break the owner update")
  _assert_eq(returned, nil, "public tile mutators keep returning nil on sync failure")
  _assert_warn_contains(captured, "sync boom",
    "warn should carry the category tag and the swallowed error message")
end

function TestBoardState:test_warns_when_no_feedback_port_is_wired()
  local returned = "untouched"
  local ok, _, captured = log_capture.capture(function()
    returned = board_state.set_tile_owner({ dirty = {} }, _land_tile(1), 3)
  end)
  lu.assertEvalToTrue(ok == true, "missing port must not break the owner update")
  _assert_eq(returned, nil, "public tile mutators keep returning nil with no port wired")
  _assert_warn_contains(captured, "not wired",
    "warn should report the unwired feedback port")
end

function TestBoardState:test_warns_once_per_failure_category_per_game_instance()
  local game = _throwing_game()
  local ok, _, captured = log_capture.capture(function()
    board_state.set_tile_owner(game, _land_tile(3), 5)
    board_state.set_tile_level(game, { type = "land", id = 4, owner_id = 5 }, 2)
  end)
  lu.assertEvalToTrue(ok == true, "repeated sync failures must not break tile updates")
  _assert_eq(_count_board_state_warns(captured), 1,
    "the same failure category should warn only once per game instance")
end

function TestBoardState:test_stays_silent_when_the_port_reports_nothing_handled()
  local noop = {
    dirty = {},
    board_visual_feedback_port = {
      sync_many = function()
        return false
      end,
    },
  }
  local returned = "untouched"
  local ok, _, captured = log_capture.capture(function()
    returned = board_state.set_tile_owner(noop, _land_tile(6), 8)
  end)
  lu.assertEvalToTrue(ok == true, "an unhandled sync must not break the owner update")
  _assert_eq(returned, nil, "public tile mutators keep returning nil when nothing is handled")
  _assert_eq(_count_board_state_warns(captured), 0,
    "a no-op port (headless default) is legitimate and must stay silent")
end


return TestBoardState

--[[ mutate4lua-manifest
version=4
projectHash=1342c73369b6c394
scope.0.id=chunk:test/behavior/state/test_board_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=139
scope.0.semanticHash=86e750bea108b00a
scope.1.id=function:_land_tile
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=8d87a8f93a904cd1
scope.2.id=function:TestBoardState:test_pushes_the_changed_tile_through_an_attached_feedback_port
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=33
scope.2.semanticHash=fafae68e1365b9aa
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=24
scope.3.semanticHash=8c0504027265179f
scope.4.id=function:TestBoardState:test_still_completes_the_owner_change_with_no_port_and_survives_a_throwing_port
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=53
scope.4.semanticHash=7656d255906e5b36
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=46
scope.5.semanticHash=b1f16ed07f03ac7a
scope.6.id=function:_count_board_state_warns
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=65
scope.6.semanticHash=d532367cffd6a11d
scope.7.id=function:_assert_warn_contains
scope.7.kind=function
scope.7.startLine=67
scope.7.endLine=72
scope.7.semanticHash=d9fbc5902cbd73eb
scope.8.id=function:_throwing_game
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=83
scope.8.semanticHash=49bef5256e741d7a
scope.9.id=function:<anonymous>#3
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=80
scope.9.semanticHash=b1f16ed07f03ac7a
scope.10.id=function:TestBoardState:test_warns_with_the_swallowed_error_when_the_port_throws
scope.10.kind=function
scope.10.startLine=85
scope.10.endLine=94
scope.10.semanticHash=fdef61e30e595403
scope.11.id=function:<anonymous>#4
scope.11.kind=function
scope.11.startLine=87
scope.11.endLine=89
scope.11.semanticHash=2ff075160fb5fcfc
scope.12.id=function:TestBoardState:test_warns_when_no_feedback_port_is_wired
scope.12.kind=function
scope.12.startLine=96
scope.12.endLine=105
scope.12.semanticHash=a24ca1f0ed44919e
scope.13.id=function:<anonymous>#5
scope.13.kind=function
scope.13.startLine=98
scope.13.endLine=100
scope.13.semanticHash=ce25581fc710f207
scope.14.id=function:TestBoardState:test_warns_once_per_failure_category_per_game_instance
scope.14.kind=function
scope.14.startLine=107
scope.14.endLine=116
scope.14.semanticHash=70fc920e7ab14354
scope.15.id=function:<anonymous>#6
scope.15.kind=function
scope.15.startLine=109
scope.15.endLine=112
scope.15.semanticHash=359a609026bd399a
scope.16.id=function:TestBoardState:test_stays_silent_when_the_port_reports_nothing_handled
scope.16.kind=function
scope.16.startLine=118
scope.16.endLine=135
scope.16.semanticHash=7997e5f747600478
scope.17.id=function:<anonymous>#7
scope.17.kind=function
scope.17.startLine=122
scope.17.endLine=124
scope.17.semanticHash=22b57f529f3a8828
scope.18.id=function:<anonymous>#8
scope.18.kind=function
scope.18.startLine=128
scope.18.endLine=130
scope.18.semanticHash=2a5e93154a0f364b
]]
