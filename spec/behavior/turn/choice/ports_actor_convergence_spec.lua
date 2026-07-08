-- 收口 choice_ports actor 补全的【统一后】语义：归一 + 存在性校验。
-- 生产 owner(=live player.id 整数)下与旧 raw 行为逐值相等；差异仅在
-- 非生产可达的 bogus owner —— 见对抗核证 owner-unify（未找到生产反例）。
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local choice_ports = require("src.turn.deadlines.choice_ports")

describe("choice_ports.ensure_actor_role_id (unified via owner)", function()
  it("fills a production owner (live player id) unchanged", function()
    local game = { find_player_by_id = function(_, id) return { id = id } end }
    local action = { type = "choice_select" }
    choice_ports.ensure_actor_role_id(game, { owner_role_id = 42 }, action)
    _assert_eq(action.actor_role_id, 42, "a live owner id is filled unchanged")
  end)

  it("drops a bogus (non-existent) owner to the current player", function()
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

  it("does not overwrite an already-set actor", function()
    local action = { type = "choice_select", actor_role_id = 3 }
    choice_ports.ensure_actor_role_id({}, { owner_role_id = 1 }, action)
    _assert_eq(action.actor_role_id, 3, "a present actor is preserved")
  end)
end)
