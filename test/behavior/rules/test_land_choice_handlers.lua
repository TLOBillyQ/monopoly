local lu = require("luaunit")
local land_handlers = require("src.rules.choice_handlers.land")
local land_settlement = require("src.rules.land.settlement")

local function _handlers(finish_choice)
  local registry = {}
  land_handlers.register(registry, { finish_choice = finish_choice or function() end })
  return registry
end

local function _required_meta(handler)
  local required = {}
  for _, field in ipairs(handler.required_meta) do
    required[field] = true
  end
  return required
end

local function _with_resolve_stub(stub, fn)
  local prev = land_settlement.resolve_landing_settlement_choice
  land_settlement.resolve_landing_settlement_choice = stub
  local ok, err = pcall(fn)
  land_settlement.resolve_landing_settlement_choice = prev
  if not ok then
    error(err, 0)
  end
end

TestLandChoiceHandlers = {}

function TestLandChoiceHandlers:test__test_registers_rent_and_tax_prompts(self)
  local registry = _handlers()
  lu.assertNotNil(registry.rent_card_prompt, "rent_card_prompt registered")
  lu.assertNotNil(registry.tax_card_prompt, "tax_card_prompt registered")
end

function TestLandChoiceHandlers:test__test_rent_prompt_requires_player_and_tile(self)
  local required = _required_meta(_handlers().rent_card_prompt)
  lu.assertTrue(required.player_id == true, "rent prompt requires player_id")
  lu.assertTrue(required.tile_id == true, "rent prompt requires tile_id: rent is owed on a specific tile")
end

function TestLandChoiceHandlers:test__test_tax_prompt_requires_player_but_not_tile(self)
  local required = _required_meta(_handlers().tax_card_prompt)
  lu.assertTrue(required.player_id == true, "tax prompt requires player_id")
  lu.assertNil(required.tile_id, "tax prompt does not require tile_id")
end

function TestLandChoiceHandlers:test__test_prompts_cancel_by_selecting_skip(self)
  local registry = _handlers()
  for _, kind in ipairs({ "rent_card_prompt", "tax_card_prompt" }) do
    local cancel = registry[kind].cancel
    lu.assertEvalToTrue(cancel.mode == "select_option", kind .. " cancels by selecting an option")
    lu.assertEvalToTrue(cancel.option_id == "skip", kind .. " cancels via the skip option")
  end
end

function TestLandChoiceHandlers:test__test_execute_returns_the_settlement_result_when_it_stays_open(self)
  local finished = false
  local registry = _handlers(function()
    finished = true
  end)
  local stay_result = { stay = true }

  _with_resolve_stub(function()
    return stay_result
  end, function()
    local result = registry.rent_card_prompt.execute({}, { kind = "rent_card_prompt" }, { option_id = "pay" })
    lu.assertEvalToTrue(result == stay_result, "a staying settlement is returned as-is")
  end)

  lu.assertFalse(finished, "a staying settlement must not finish the choice")
end

function TestLandChoiceHandlers:test__test_execute_finishes_the_choice_when_the_settlement_does_not_stay(self)
  local finish_calls = {}
  local registry = _handlers(function(game, keep_open)
    finish_calls[#finish_calls + 1] = { game = game, keep_open = keep_open }
    return "finished"
  end)
  local game = { id = "game" }

  _with_resolve_stub(function()
    return { stay = false }
  end, function()
    local result = registry.tax_card_prompt.execute(game, { kind = "tax_card_prompt" }, { option_id = "pay" })
    lu.assertEvalToTrue(result == "finished", "returns whatever finish_choice returns")
  end)

  lu.assertEvalToTrue(#finish_calls == 1, "finish_choice called exactly once")
  lu.assertEvalToTrue(finish_calls[1].game == game, "finish_choice receives the game")
  lu.assertFalse(finish_calls[1].keep_open, "finish_choice closes the choice")
end


return TestLandChoiceHandlers
