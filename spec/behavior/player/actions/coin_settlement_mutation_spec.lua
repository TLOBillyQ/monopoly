-- Mutation-pinning specs for src/player/actions/coin_settlement.lua.
--
-- Three mutants survive on this file. Analysis (below) shows all THREE are
-- EQUIVALENT mutants over the value domain the module enforces: every coin
-- amount and delta is a finite integer (coin_validation._require_finite_integer
-- rejects non-integers), so the clamp/partial boundaries collapse to identical
-- observable behaviour. No test can distinguish them; the tests here instead pin
-- the surrounding boundary semantics so the equivalence stays true if the
-- clamp/partial logic is ever changed.
--
--   L62  if opts and opts.allow_partial == true and payer_before < requested then
--        replace `<` with `<=` :  differs only at payer_before == requested, where
--        BOTH branches return (requested, payer_before) == (payer_before, payer_before)
--        because requested == payer_before. Return tuple identical -> EQUIVALENT.
--
--   L76  if next_cash < 0 then next_cash = 0 end
--        replace `<` with `<=` : differs only at next_cash == 0, where the clamp
--        assigns 0 to a value already 0 -> result 0 either way -> EQUIVALENT.
--        replace `0` with `1`  : `< 1` vs `< 0` differ only on next_cash in [0,1);
--        next_cash = int + int is always an integer, so the only member is 0, and
--        the clamp maps 0 -> 0 -> result identical -> EQUIVALENT (integer domain).

local coin_store = require("src.player.actions.coin_store")
local coin_settlement = require("src.player.actions.coin_settlement")

local function _player(initial)
  return { _coin_role = coin_store.new_memory_coin_role(initial) }
end

local function _game()
  return { dirty = {} }
end

local NO_ANIM = { suppress_cash_receive_anim = true }

describe("coin_settlement.add_delta negative-result clamp (L76 boundary)", function()
  it("clamps a would-be-negative balance to exactly 0", function()
    local game, player = _game(), _player(5)
    local updated = coin_settlement.add_delta(game, player, -10, NO_ANIM)
    -- next_cash = 5 + (-10) = -5 -> clamp to 0.
    assert(updated == 0, "under-run must clamp to 0; got " .. tostring(updated))
    assert(coin_store.read_count(player) == 0, "stored balance must be 0 after clamp")
  end)

  it("leaves an exactly-zero result at 0 (L76 '<' vs '<=' boundary, equivalent)", function()
    local game, player = _game(), _player(10)
    local updated = coin_settlement.add_delta(game, player, -10, NO_ANIM)
    -- next_cash = 0: `< 0` false (original) and `<= 0` true (mutant) both yield 0.
    assert(updated == 0, "exact-zero result must stay 0; got " .. tostring(updated))
  end)

  it("does not clamp a positive result", function()
    local game, player = _game(), _player(10)
    local updated = coin_settlement.add_delta(game, player, 5, NO_ANIM)
    assert(updated == 15, "positive result must pass through unclamped; got " .. tostring(updated))
  end)
end)

describe("coin_settlement.transfer allow_partial cap (L62 boundary)", function()
  it("caps the transferred amount at the payer's balance when partial is allowed", function()
    local game = _game()
    local payer, receiver = _player(30), _player(0)
    local payer_after, receiver_after, actual =
      coin_settlement.transfer(game, payer, receiver, 100,
        { allow_partial = true, suppress_cash_receive_anim = true })
    -- payer_before (30) < requested (100) -> actual capped to 30.
    assert(actual == 30, "partial transfer must cap at payer balance; got " .. tostring(actual))
    assert(payer_after == 0, "payer must end at 0; got " .. tostring(payer_after))
    assert(receiver_after == 30, "receiver must receive the capped amount; got " .. tostring(receiver_after))
  end)

  it("transfers the full amount when balance equals request (L62 '<' vs '<=', equivalent)", function()
    local game = _game()
    local payer, receiver = _player(100), _player(0)
    local payer_after, receiver_after, actual =
      coin_settlement.transfer(game, payer, receiver, 100,
        { allow_partial = true, suppress_cash_receive_anim = true })
    -- payer_before == requested == 100: `<` (full) and `<=` (partial) both give 100.
    assert(actual == 100, "equal-balance transfer must move the full amount; got " .. tostring(actual))
    assert(payer_after == 0 and receiver_after == 100,
      "balances must settle to 0/100; got " .. tostring(payer_after) .. "/" .. tostring(receiver_after))
  end)
end)
