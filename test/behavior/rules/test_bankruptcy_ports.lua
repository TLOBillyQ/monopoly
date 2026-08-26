-- bankruptcy / bankruptcy_feedback 端口转发直测:参数必须透传到 game 上注入的
-- 端口实现(#250 调用时查表语义),端口名解析是转发契约的一部分。
local lu = require("luaunit")

local bankruptcy = require("src.rules.ports.bankruptcy")
local bankruptcy_feedback = require("src.rules.ports.bankruptcy_feedback")

TestBankruptcyPorts = {}

function TestBankruptcyPorts:test_eliminate_forwards_to_the_injected_port()
  local seen = {}
  local game = {
    bankruptcy_port = {
      eliminate = function(g, player, opts)
        seen.g = g
        seen.player = player
        seen.opts = opts
        return "eliminated"
      end,
    },
  }
  local player = { id = 3 }
  local opts = { reason = "debt" }
  local result = bankruptcy.eliminate(game, player, opts)

  lu.assertEvalToTrue(result == "eliminated", "the port result must pass through")
  lu.assertEvalToTrue(seen.g == game, "the game must be forwarded")
  lu.assertEvalToTrue(seen.player == player, "the player must be forwarded")
  lu.assertEvalToTrue(seen.opts == opts, "the opts must be forwarded")
end

function TestBankruptcyPorts:test_on_tiles_cleared_forwards_to_the_injected_port()
  local seen = {}
  local game = {
    bankruptcy_feedback_port = {
      on_tiles_cleared = function(g, player, owned_tile_ids)
        seen.g = g
        seen.player = player
        seen.ids = owned_tile_ids
        return 7
      end,
    },
  }
  local player = { id = 5 }
  local ids = { 1, 2 }
  local result = bankruptcy_feedback.on_tiles_cleared(game, player, ids)

  lu.assertEvalToTrue(result == 7, "the port result must pass through")
  lu.assertEvalToTrue(seen.g == game, "the game must be forwarded")
  lu.assertEvalToTrue(seen.player == player, "the player must be forwarded")
  lu.assertEvalToTrue(seen.ids == ids, "the tile ids must be forwarded")
end

return TestBankruptcyPorts
