---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local luax = require("test.support.luax")
local landing_optional = require("src.rules.choice_handlers.landing_optional")
local land_settlement = require("src.rules.land.settlement")
local logger = require("src.foundation.log")

-- 原生 LuaUnit 转换(busted → LuaUnit):describe 拍平为文件级 Test 类,
-- has_error 双参形式走 luax.has_error(实参序与消息剥壳语义对齐 busted),
-- 断言词汇切到 lu.assertXxx,用例数与改写前一一对应(14 例)。

local function _handler(finish_choice)
  local registry = {}
  landing_optional.register(registry, { finish_choice = finish_choice })
  return registry.landing_optional_effect
end

local function _game()
  return {
    find_player_by_id = function(_, player_id)
      if player_id == 1 then
        return { id = 1 }
      end
      return nil
    end,
    board = {
      get_tile_by_id = function(_, tile_id)
        if tile_id == 7 then
          return { id = 7 }
        end
        return nil
      end,
    },
  }
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

local function _with_warn_capture(fn)
  local captured = {}
  local prev = logger.warn
  logger.warn = function(...)
    captured[#captured + 1] = table.concat({ ... }, " ")
  end
  local ok, err = pcall(fn, captured)
  logger.warn = prev
  if not ok then
    error(err, 0)
  end
  return captured
end

TestLandingOptionalHandler = {}

function TestLandingOptionalHandler:test_declares_player_and_tile_as_required_meta()
  local handler = _handler(function() end)
  lu.assertEvalToTrue(handler ~= nil, "registers under landing_optional_effect")
  local required = {}
  for _, field in ipairs(handler.required_meta) do
    required[field] = true
  end
  lu.assertEvalToTrue(required.player_id == true, "player_id is required meta")
  lu.assertEvalToTrue(required.tile_id == true, "tile_id is required meta")
end

function TestLandingOptionalHandler:test_normalize_meta_coerces_ids_and_defaults_owner_role()
  local handler = _handler(function() end)
  local choice_spec = { kind = "landing_optional_effect" }
  local normalized = handler.normalize_meta(_game(), { player_id = "1", tile_id = "7" }, choice_spec)

  lu.assertEvalToTrue(normalized.player_id == 1, "player_id normalized to integer")
  lu.assertEvalToTrue(normalized.tile_id == 7, "tile_id normalized to integer")
  lu.assertEvalToTrue(choice_spec.owner_role_id == 1, "owner_role_id defaults to the normalized player")
end

function TestLandingOptionalHandler:test_normalize_meta_keeps_an_explicit_owner_role()
  local handler = _handler(function() end)
  local choice_spec = { kind = "landing_optional_effect", owner_role_id = 9 }
  handler.normalize_meta(_game(), { player_id = 1, tile_id = 7 }, choice_spec)
  lu.assertEvalToTrue(choice_spec.owner_role_id == 9, "explicit owner_role_id is preserved")
end

function TestLandingOptionalHandler:test_meta_validator_accepts_known_player_and_tile()
  local handler = _handler(function() end)
  local ok = pcall(function()
    handler.meta_validator(_game(), { player_id = 1, tile_id = 7 }, { kind = "landing_optional_effect" })
  end)
  lu.assertEvalToTrue(ok == true, "known player and tile validate")
end

function TestLandingOptionalHandler:test_meta_validator_rejects_unknown_player()
  local handler = _handler(function() end)
  local ok, err = pcall(function()
    handler.meta_validator(_game(), { player_id = 42, tile_id = 7 }, { kind = "landing_optional_effect" })
  end)
  lu.assertEvalToTrue(ok == false, "unknown player must not validate")
  lu.assertEvalToTrue(tostring(err):find("missing player"), "error names the missing player: " .. tostring(err))
end

function TestLandingOptionalHandler:test_meta_validator_rejects_unknown_tile()
  local handler = _handler(function() end)
  local ok, err = pcall(function()
    handler.meta_validator(_game(), { player_id = 1, tile_id = 99 }, { kind = "landing_optional_effect" })
  end)
  lu.assertEvalToTrue(ok == false, "unknown tile must not validate")
  lu.assertEvalToTrue(tostring(err):find("missing tile"), "error names the missing tile: " .. tostring(err))
end

function TestLandingOptionalHandler:test_meta_validator_rejects_non_table_effect_ids()
  local handler = _handler(function() end)
  local ok, err = pcall(function()
    handler.meta_validator(_game(), { player_id = 1, tile_id = 7, effect_ids = "not_a_table" },
      { kind = "landing_optional_effect" })
  end)
  lu.assertEvalToTrue(ok == false, "string effect_ids must not validate")
  lu.assertEvalToTrue(tostring(err):find("requires table meta.effect_ids"), "error explains effect_ids: " .. tostring(err))
end

function TestLandingOptionalHandler:test_meta_validator_accepts_table_effect_ids()
  local handler = _handler(function() end)
  local ok = pcall(function()
    handler.meta_validator(_game(), { player_id = 1, tile_id = 7, effect_ids = { "toll" } },
      { kind = "landing_optional_effect" })
  end)
  lu.assertEvalToTrue(ok == true, "table effect_ids validate")
end

function TestLandingOptionalHandler:test_normalize_action_requires_a_non_empty_option_id()
  local handler = _handler(function() end)

  local normalized = handler.normalize_action(nil, nil, { option_id = "confirm" })
  lu.assertEvalToTrue(normalized.option_id == "confirm", "valid option_id passes through")

  -- pcall 只钉失败不钉消息,message->nil 变异体能活;改 has_error 精确匹配。
  luax.has_error(function()
    handler.normalize_action(nil, nil, { option_id = "" })
  end, "landing_optional_effect requires string action.option_id")

  luax.has_error(function()
    handler.normalize_action(nil, nil, {})
  end, "landing_optional_effect requires string action.option_id")
end

function TestLandingOptionalHandler:test_execute_returns_the_settlement_result_when_it_stays_open()
  local finished = false
  local handler = _handler(function()
    finished = true
  end)
  local stay_result = { stay = true, ok = true }

  _with_resolve_stub(function()
    return stay_result
  end, function()
    local result = handler.execute(_game(), { kind = "landing_optional_effect" }, { option_id = "confirm" })
    lu.assertEvalToTrue(result == stay_result, "a staying settlement is returned as-is")
  end)

  lu.assertEvalToTrue(finished == false, "a staying settlement must not finish the choice")
end

function TestLandingOptionalHandler:test_execute_finishes_the_choice_when_the_settlement_does_not_stay()
  local finish_calls = {}
  local handler = _handler(function(game, keep_open)
    finish_calls[#finish_calls + 1] = { game = game, keep_open = keep_open }
    return "finished"
  end)
  local game = _game()

  _with_resolve_stub(function()
    return { stay = false, ok = true }
  end, function()
    local result = handler.execute(game, { kind = "landing_optional_effect" }, { option_id = "confirm" })
    lu.assertEvalToTrue(result == "finished", "returns whatever finish_choice returns")
  end)

  lu.assertEvalToTrue(#finish_calls == 1, "finish_choice called exactly once")
  lu.assertEvalToTrue(finish_calls[1].game == game, "finish_choice receives the game")
  lu.assertEvalToTrue(finish_calls[1].keep_open == false, "finish_choice closes the choice")
end

function TestLandingOptionalHandler:test_execute_finishes_the_choice_when_there_is_no_settlement_result()
  local finish_calls = 0
  local handler = _handler(function()
    finish_calls = finish_calls + 1
    return "finished"
  end)

  _with_resolve_stub(function()
    return nil
  end, function()
    handler.execute(_game(), { kind = "landing_optional_effect" }, { option_id = "confirm" })
  end)

  lu.assertEvalToTrue(finish_calls == 1, "a nil settlement still finishes the choice")
end

function TestLandingOptionalHandler:test_execute_warns_and_finishes_when_the_settlement_is_blocked()
  local finish_calls = 0
  local handler = _handler(function()
    finish_calls = finish_calls + 1
  end)

  local warnings = _with_warn_capture(function()
    _with_resolve_stub(function()
      return { ok = false, reason = "insufficient_cash" }
    end, function()
      handler.execute(_game(), { kind = "landing_optional_effect" }, { option_id = "confirm" })
    end)
  end)

  lu.assertEvalToTrue(#warnings == 1, "a blocked settlement warns exactly once")
  lu.assertEvalToTrue(warnings[1]:find("insufficient_cash"), "the warning carries the block reason: " .. warnings[1])
  lu.assertEvalToTrue(finish_calls == 1, "a blocked settlement still finishes the choice")
end

function TestLandingOptionalHandler:test_execute_does_not_warn_when_the_settlement_succeeds()
  local handler = _handler(function() end)

  local warnings = _with_warn_capture(function()
    _with_resolve_stub(function()
      return { ok = true, stay = false }
    end, function()
      handler.execute(_game(), { kind = "landing_optional_effect" }, { option_id = "confirm" })
    end)
  end)

  lu.assertEvalToTrue(#warnings == 0, "a successful settlement must not warn")
end


return TestLandingOptionalHandler
