-- 收口 choice_ports actor 补全的【统一后】语义：归一 + 存在性校验。
-- 生产 owner(=live player.id 整数)下与旧 raw 行为逐值相等；差异仅在
-- 非生产可达的 bogus owner —— 见对抗核证 owner-unify（未找到生产反例）。

-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

local choice_ports = require("src.turn.deadlines.choice_ports")

describe("TestPortsActorConvergence", function()
  it("test_fills_a_production_owner_live_player_id_unchanged", function()
    local game = { find_player_by_id = function(_, id) return { id = id } end }
    local action = { type = "choice_select" }
    choice_ports.ensure_actor_role_id(game, { owner_role_id = 42 }, action)
    _assert_eq(action.actor_role_id, 42, "a live owner id is filled unchanged")
  end)

  it("test_drops_a_bogus_non_existent_owner_to_the_current_player", function()
    -- 收敛点：旧 raw 会原样盖 999；统一后 find 失败 → 跌落 current。
    local game = {
      find_player_by_id = function() return nil end,
      turn = { current_player_index = 1 },
      players = { { id = 7 } },
    }
    local action = { type = "choice_select" }
    choice_ports.ensure_actor_role_id(game, { owner_role_id = 999 }, action)
    _assert_eq(action.actor_role_id, 7, "a bogus owner converges to the current player id")
  end)

  it("test_does_not_overwrite_an_already_set_actor", function()
    local action = { type = "choice_select", actor_role_id = 3 }
    choice_ports.ensure_actor_role_id({}, { owner_role_id = 1 }, action)
    _assert_eq(action.actor_role_id, 3, "a present actor is preserved")
  end)
end)
