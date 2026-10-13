-- coin_settlement 深模块直测:charge/transfer 两个 interface 逐点钉死。
-- 用 support.new_game 真游戏 fixture(与 land_settlement_spec 同款),
-- 破产经 player.eliminated 观测,遥测经注入的 achievement port 捕获。
require("test.bootstrap").install_package_paths()
local luassert = assert
local support = require("test.support.shared_support")
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

describe("TestCoinSettlement", function()
before_each(function()
  local _config_reset = require("test.support.config_reset")
  _config_reset.reset_all()
end)

it("test_deducts_the_amount_and_reports_charged", function()
  local g = _new_game()
  local p = g.players[1]
  g:set_player_cash(p, 1000)

  local result = coin_settlement.charge(g, p, 300, { reason = "x" })

  luassert.truthy(g:player_cash(p) == 700, "balance should drop by 300")
  luassert.truthy(result.charged == 300, "charged should equal deducted amount")
  luassert.truthy(result.bankrupt == false, "positive balance is not bankrupt")
end)

it("test_clamps_at_zero_when_amount_exceeds_balance", function()
  local g = _new_game()
  local p = g.players[1]
  g:set_player_cash(p, 200)

  local result = coin_settlement.charge(g, p, 500, { reason = "破产了" })

  luassert.truthy(g:player_cash(p) == 0, "balance clamps at zero, never negative")
  luassert.truthy(result.charged == 200, "charged reports the actually-drained amount")
end)

it("test_eliminates_the_payer_when_balance_hits_zero", function()
  local g = _new_game()
  local p = g.players[1]
  g:set_player_cash(p, 200)

  local result = coin_settlement.charge(g, p, 200, { reason = "破产了" })

  luassert.truthy(result.bankrupt == true, "zero balance is bankrupt")
  luassert.truthy(result.reason == "破产了", "reason echoed on bankruptcy")
  luassert.truthy(p.eliminated == true, "payer eliminated on non-positive balance")
end)

it("test_does_not_eliminate_while_balance_stays_positive", function()
  local g = _new_game()
  local p = g.players[1]
  g:set_player_cash(p, 500)

  coin_settlement.charge(g, p, 100, { reason = "破产了" })

  luassert.truthy(p.eliminated ~= true, "payer with cash left is not eliminated")
end)

it("test_defer_bankruptcy_reports_but_does_not_eliminate", function()
  local g = _new_game()
  local p = g.players[1]
  g:set_player_cash(p, 100)

  local result = coin_settlement.charge(g, p, 100, {
    reason = "延后淘汰",
    defer_bankruptcy = true,
  })

  luassert.truthy(result.bankrupt == true, "still reports bankruptcy")
  luassert.truthy(result.reason == "延后淘汰", "still resolves reason")
  luassert.truthy(p.eliminated ~= true, "defer must skip the eliminate call")
end)

it("test_resolves_a_function_reason_lazily", function()
  local g = _new_game()
  local p = g.players[1]
  g:set_player_cash(p, 50)

  local result = coin_settlement.charge(g, p, 50, {
    reason = function(payer) return payer.name .. " 破产" end,
  })

  luassert.truthy(result.reason == p.name .. " 破产", "function reason receives payer")
end)

it("test_moves_the_full_amount_and_credits_the_receiver", function()
  local g = _new_game()
  local payer, receiver = g.players[1], g.players[2]
  g:set_player_cash(payer, 1000)
  g:set_player_cash(receiver, 100)

  local result = coin_settlement.transfer(g, payer, receiver, 300, { reason = "x" })

  luassert.truthy(g:player_cash(payer) == 700, "payer drops by 300")
  luassert.truthy(g:player_cash(receiver) == 400, "receiver gains 300")
  luassert.truthy(result.moved == 300, "moved equals requested when affordable")
  luassert.truthy(result.bankrupt == false, "solvent payer not bankrupt")
end)

it("test_caps_at_payer_liquidity_when_short_no_money_creation", function()
  local g = _new_game()
  local payer, receiver = g.players[1], g.players[2]
  g:set_player_cash(payer, 200)
  g:set_player_cash(receiver, 0)

  local result = coin_settlement.transfer(g, payer, receiver, 500, {
    reason = "欠付破产",
  })

  luassert.truthy(result.moved == 200, "moved caps at payer's 200")
  luassert.truthy(g:player_cash(receiver) == 200, "receiver gets only what payer had")
  luassert.truthy(g:player_cash(payer) == 0, "payer drained to zero, not negative")
end)

it("test_records_cash_received_for_the_receiver_on_the_moved_amount", function()
  local g = _new_game()
  local payer, receiver = g.players[1], g.players[2]
  g:set_player_cash(payer, 1000)
  local received = _capture_cash_received(g)

  coin_settlement.transfer(g, payer, receiver, 250, { reason = "x" })

  luassert.truthy(#received == 1, "exactly one cash_received emitted")
  luassert.truthy(received[1].id == receiver.id, "telemetry targets the receiver")
  luassert.truthy(received[1].amount == 250, "telemetry carries the moved amount")
end)

it("test_does_not_record_cash_received_when_nothing_moves", function()
  local g = _new_game()
  local payer, receiver = g.players[1], g.players[2]
  g:set_player_cash(payer, 0)
  local received = _capture_cash_received(g)

  local result = coin_settlement.transfer(g, payer, receiver, 100, { reason = "x" })

  luassert.truthy(result.moved == 0, "nothing moves from an empty payer")
  luassert.truthy(#received == 0, "no telemetry for a zero move")
end)

it("test_eliminates_the_payer_on_non_positive_balance", function()
  local g = _new_game()
  local payer, receiver = g.players[1], g.players[2]
  g:set_player_cash(payer, 200)

  local result = coin_settlement.transfer(g, payer, receiver, 500, {
    reason = "被收款破产",
  })

  luassert.truthy(result.bankrupt == true, "drained payer is bankrupt")
  luassert.truthy(payer.eliminated == true, "payer eliminated immediately by default")
end)

it("test_defer_bankruptcy_reports_moved_and_bankruptcy_without_eliminating", function()
  local g = _new_game()
  local payer, receiver = g.players[1], g.players[2]
  g:set_player_cash(payer, 200)

  local result = coin_settlement.transfer(g, payer, receiver, 500, {
    defer_bankruptcy = true,
  })

  luassert.truthy(result.moved == 200, "still reports partial move")
  luassert.truthy(result.bankrupt == true, "still reports bankruptcy")
  luassert.truthy(payer.eliminated ~= true, "defer skips the eliminate call")
end)


end)
