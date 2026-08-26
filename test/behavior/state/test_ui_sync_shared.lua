-- #293 批3 pin:src/state/ui_sync_shared.lua 既有无直测(ui 层只桩),22 个
-- 幸存者分两簇:is_only_turn_countdown 的 dirty 谓词链与 build_ui_env 的
-- 字段搬运。逐面直测按变异位点钉死。

local lu = require("luaunit")
local shared = require("src.state.ui_sync_shared")

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

TestUiSyncShared = {}

-- ============ is_only_turn_countdown ============

function TestUiSyncShared:test_returns_false_when_turn_countdown_is_not_true()
  -- L5 `dirty ~= nil and dirty.turn_countdown == true` 的 and->or:turn_countdown
  -- 非 true 时必须拒绝(变异体因 dirty 非 nil 放行到其它守卫,组合后反成 true)。
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = false }), false,
    "turn_countdown=false must not qualify as only-turn-countdown")
end

function TestUiSyncShared:test_rejects_each_other_dirty_domain()
  -- L9 `dirty.players or dirty.board_tiles or dirty.turn or dirty.market or dirty.ui`
  -- 的四个 or->and 变异:对应字段置 true 时变异体把链断成假,必须各自被拒。
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, players = true }), false,
    "players dirty must disqualify")
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, board_tiles = true }), false,
    "board_tiles dirty must disqualify")
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, turn = true }), false,
    "turn dirty must disqualify")
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, market = true }), false,
    "market dirty must disqualify")
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, ui = true }), false,
    "ui dirty must disqualify")
end

function TestUiSyncShared:test_rejects_pending_inventory_dirty()
  -- L13 `dirty.inventory == true` 的 ==->~= 变异:inventory 置真必须 disqualify。
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, inventory = true }), false,
    "pending inventory dirty must disqualify")
end

function TestUiSyncShared:test_accepts_exactly_turn_countdown_without_inventory()
  -- 干净路径:仅 turn_countdown 且 inventory 未置真时必须放行。
  _assert_eq(shared.is_only_turn_countdown({ turn_countdown = true, inventory = false }), true,
    "only turn_countdown must qualify")
end

-- ============ build_ui_env ============

function TestUiSyncShared:test_build_ui_env_carries_winner_last_turn_finished_and_winner_name()
  -- L27 `game and game[key] or nil` 的 and/or 双变异、L31 `_winner_name` 的
  -- and/or 三变异、L35/L36 调用换 nil、L39/L40 字段名与调用换 nil:全字段
  -- 必须原样进 env。
  local game = {
    winner = "w1",
    last_turn = "lt9",
    finished = true,
    winner_names = "王",
  }
  local env = shared.build_ui_env("state_marker", game)
  _assert_eq(env.last_turn, "lt9", "env must carry the last turn marker")
  _assert_eq(env.finished, true, "env must carry the finished flag")
  _assert_eq(env.winner_name, "王", "env must prefer winner_names for the display name")
  _assert_eq(env.game, game, "env must carry the game reference")
  _assert_eq(env.ui_state, "state_marker", "env must carry the ui state")
end

function TestUiSyncShared:test_build_ui_env_falls_back_to_winner_name_from_player()
  -- L31 内层 `game.winner_names or (winner and winner.name)` 的 or->and:
  -- 无 winner_names 时 winner.name 必须兜底。
  local winner = { name = "甲" }
  local env = shared.build_ui_env(nil, { winner = winner })
  _assert_eq(env.winner_name, "甲", "winner.name must back the display name")
end

return TestUiSyncShared
