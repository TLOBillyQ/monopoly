-- coin_settlement 深模块直测:charge/transfer 两个 interface 逐点钉死。
-- 用 support.new_game 真游戏 fixture(与 land_settlement_spec 同款),
-- 破产经 player.eliminated 观测,遥测经注入的 achievement port 捕获。
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local coin_settlement = require("src.rules.commerce.coin_settlement")

local function _new_game()
  return support.new_game({ map = default_map })
end

-- 注入一个捕获 cash_received 的成就 port,返回捕获数组。
local function _capture_cash_received(game) -- luacheck: ignore (Task 2 transfer 测试使用)
  local received = {}
  game.achievement_progress_port = {
    cash_received = function(_, player, amount)
      received[#received + 1] = { id = player.id, amount = amount }
      return true
    end,
  }
  return received
end

describe("rules.commerce.coin_settlement", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  describe("charge", function()
    it("deducts the amount and reports charged", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 1000)

      local result = coin_settlement.charge(g, p, 300, { reason = "x" })

      assert(g:player_cash(p) == 700, "balance should drop by 300")
      assert(result.charged == 300, "charged should equal deducted amount")
      assert(result.bankrupt == false, "positive balance is not bankrupt")
    end)

    it("clamps at zero when amount exceeds balance", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 200)

      local result = coin_settlement.charge(g, p, 500, { reason = "破产了" })

      assert(g:player_cash(p) == 0, "balance clamps at zero, never negative")
      assert(result.charged == 200, "charged reports the actually-drained amount")
    end)

    it("eliminates the payer when balance hits zero", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 200)

      local result = coin_settlement.charge(g, p, 200, { reason = "破产了" })

      assert(result.bankrupt == true, "zero balance is bankrupt")
      assert(result.reason == "破产了", "reason echoed on bankruptcy")
      assert(p.eliminated == true, "payer eliminated on non-positive balance")
    end)

    it("does not eliminate while balance stays positive", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 500)

      coin_settlement.charge(g, p, 100, { reason = "破产了" })

      assert(p.eliminated ~= true, "payer with cash left is not eliminated")
    end)

    it("defer_bankruptcy reports but does not eliminate", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 100)

      local result = coin_settlement.charge(g, p, 100, {
        reason = "延后淘汰",
        defer_bankruptcy = true,
      })

      assert(result.bankrupt == true, "still reports bankruptcy")
      assert(result.reason == "延后淘汰", "still resolves reason")
      assert(p.eliminated ~= true, "defer must skip the eliminate call")
    end)

    it("resolves a function reason lazily", function()
      local g = _new_game()
      local p = g.players[1]
      g:set_player_cash(p, 50)

      local result = coin_settlement.charge(g, p, 50, {
        reason = function(payer) return payer.name .. " 破产" end,
      })

      assert(result.reason == p.name .. " 破产", "function reason receives payer")
    end)
  end)

  describe("transfer", function()
    it("moves the full amount and credits the receiver", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 1000)
      g:set_player_cash(receiver, 100)

      local result = coin_settlement.transfer(g, payer, receiver, 300, { reason = "x" })

      assert(g:player_cash(payer) == 700, "payer drops by 300")
      assert(g:player_cash(receiver) == 400, "receiver gains 300")
      assert(result.moved == 300, "moved equals requested when affordable")
      assert(result.bankrupt == false, "solvent payer not bankrupt")
    end)

    it("caps at payer liquidity when short (no money creation)", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 200)
      g:set_player_cash(receiver, 0)

      local result = coin_settlement.transfer(g, payer, receiver, 500, {
        reason = "欠付破产",
      })

      assert(result.moved == 200, "moved caps at payer's 200")
      assert(g:player_cash(receiver) == 200, "receiver gets only what payer had")
      assert(g:player_cash(payer) == 0, "payer drained to zero, not negative")
    end)

    it("records cash_received for the receiver on the moved amount", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 1000)
      local received = _capture_cash_received(g)

      coin_settlement.transfer(g, payer, receiver, 250, { reason = "x" })

      assert(#received == 1, "exactly one cash_received emitted")
      assert(received[1].id == receiver.id, "telemetry targets the receiver")
      assert(received[1].amount == 250, "telemetry carries the moved amount")
    end)

    it("does not record cash_received when nothing moves", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 0)
      local received = _capture_cash_received(g)

      local result = coin_settlement.transfer(g, payer, receiver, 100, { reason = "x" })

      assert(result.moved == 0, "nothing moves from an empty payer")
      assert(#received == 0, "no telemetry for a zero move")
    end)

    it("eliminates the payer on non-positive balance", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 200)

      local result = coin_settlement.transfer(g, payer, receiver, 500, {
        reason = "被收款破产",
      })

      assert(result.bankrupt == true, "drained payer is bankrupt")
      assert(payer.eliminated == true, "payer eliminated immediately by default")
    end)

    it("defer_bankruptcy reports moved and bankruptcy without eliminating", function()
      local g = _new_game()
      local payer, receiver = g.players[1], g.players[2]
      g:set_player_cash(payer, 200)

      local result = coin_settlement.transfer(g, payer, receiver, 500, {
        defer_bankruptcy = true,
      })

      assert(result.moved == 200, "still reports partial move")
      assert(result.bankrupt == true, "still reports bankruptcy")
      assert(payer.eliminated ~= true, "defer skips the eliminate call")
    end)
  end)
end)
