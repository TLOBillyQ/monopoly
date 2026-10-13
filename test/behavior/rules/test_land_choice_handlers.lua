require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
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


describe("TestLandChoiceHandlers", function()
  it("test__test_registers_rent_and_tax_prompts", function()
    local registry = _handlers()
    luassert.is_not_nil(registry.rent_card_prompt, "rent_card_prompt registered")
    luassert.is_not_nil(registry.tax_card_prompt, "tax_card_prompt registered")
  end)

  it("test__test_rent_prompt_requires_player_and_tile", function()
    local required = _required_meta(_handlers().rent_card_prompt)
    luassert.is_true(required.player_id == true, "rent prompt requires player_id")
    luassert.is_true(required.tile_id == true, "rent prompt requires tile_id: rent is owed on a specific tile")
  end)

  it("test__test_tax_prompt_requires_player_but_not_tile", function()
    local required = _required_meta(_handlers().tax_card_prompt)
    luassert.is_true(required.player_id == true, "tax prompt requires player_id")
    luassert.is_nil(required.tile_id, "tax prompt does not require tile_id")
  end)

  it("test__test_prompts_cancel_by_selecting_skip", function()
    local registry = _handlers()
    for _, kind in ipairs({ "rent_card_prompt", "tax_card_prompt" }) do
      local cancel = registry[kind].cancel
      luassert.truthy(cancel.mode == "select_option", kind .. " cancels by selecting an option")
      luassert.truthy(cancel.option_id == "skip", kind .. " cancels via the skip option")
    end
  end)

  it("test__test_execute_returns_the_settlement_result_when_it_stays_open", function()
    local finished = false
    local registry = _handlers(function()
      finished = true
    end)
    local stay_result = { stay = true }

    _with_resolve_stub(function()
      return stay_result
    end, function()
      local result = registry.rent_card_prompt.execute({}, { kind = "rent_card_prompt" }, { option_id = "pay" })
      luassert.truthy(result == stay_result, "a staying settlement is returned as-is")
    end)

    luassert.is_false(finished, "a staying settlement must not finish the choice")
  end)

  it("test__test_execute_finishes_the_choice_when_the_settlement_does_not_stay", function()
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
      luassert.truthy(result == "finished", "returns whatever finish_choice returns")
    end)

    luassert.truthy(#finish_calls == 1, "finish_choice called exactly once")
    luassert.truthy(finish_calls[1].game == game, "finish_choice receives the game")
    luassert.is_false(finish_calls[1].keep_open, "finish_choice closes the choice")
  end)


end)
