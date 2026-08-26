-- Mutation-pinning specs for src/rules/items/availability.lua.
-- Per [[reference_mutate4lua_test_corpus]]: closure via busted spec, not Gherkin.
-- Strategy: assert a value that DIFFERS between original and each surviving mutant.
--
-- Survivor map (mutate4lua):
--   L15 (x2)  phase_timing.pre_move = { pre_move = true, turn = true } -- two `true`
--   L27       followup_choice_item_set[item_ids.monster]  = true
--   L28       followup_choice_item_set[item_ids.missile]  = true
--   L91       `if auto_play_port.is_computer_controlled(game, player) then` -> nil
--   L92       `return roadblock.auto_candidates(game, player, 3)`   -> nil
--   L156      `type(candidates) == "table" and #candidates > 0`
--                 and->or, >->>=, 0->1
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):四个无钩子 describe 拍平合并进
-- TestAvailabilityMutation 类,用例数与改写前一一对应(9 例)。

local lu = require("luaunit")
local availability = require("src.rules.items.availability")
local item_ids = require("src.config.gameplay.item_ids")
local auto_play_port = require("src.rules.ports.auto_play")
local roadblock = require("src.rules.items.roadblock")
local inventory = require("src.rules.items.inventory")

-- Patch method-table entries in place. availability.lua captured these module
-- tables as upvalues at load time, so patching the same table object is visible
-- to the code under test. Restores originals even if fn throws.
local function _with_patches(patches, fn)
  local originals = {}
  for index, patch in ipairs(patches) do
    originals[index] = patch.target[patch.key]
    patch.target[patch.key] = patch.value
  end
  local ok, result = pcall(fn)
  for index = #patches, 1, -1 do
    patches[index].target[patches[index].key] = originals[index]
  end
  if not ok then
    error(result)
  end
  return result
end

-- Drive the roadblock branch of _can_offer_special_item through the public
-- can_offer_in_phase entry point. inventory.cfg is stubbed to a minimal cfg
-- whose offer_in_phases admits "post_action" (so _offer_window_allowed passes)
-- and with no effect_group (so the effect-group gate is skipped). The returned
-- can_offer therefore reflects exactly the roadblock candidate computation.
local ROADBLOCK_PHASE = "post_action"

local function _roadblock_can_offer(is_auto, auto_result, manual_result)
  return _with_patches({
    {
      target = inventory,
      key = "cfg",
      value = function(item_id)
        if item_id == item_ids.roadblock then
          return { offer_in_phases = { ROADBLOCK_PHASE } }
        end
        return nil
      end,
    },
    {
      target = auto_play_port,
      key = "is_computer_controlled",
      value = function() return is_auto end,
    },
    {
      target = roadblock,
      key = "auto_candidates",
      value = function() return auto_result end,
    },
    {
      target = roadblock,
      key = "manual_candidates",
      value = function() return manual_result end,
    },
  }, function()
    local can_offer = availability.can_offer_in_phase({}, {}, item_ids.roadblock, ROADBLOCK_PHASE)
    return can_offer
  end)
end

TestAvailabilityMutation = {}

-- ════════════════════════════════════════════════════════════════════════════
-- L15: phase_timing.pre_move = { pre_move = true, turn = true }  (two `true`)
-- Exercised via availability.trigger_timing_allowed, which returns
-- `phase_timing[phase][timing] == true`. Flipping either `true` to `false`
-- makes the corresponding lookup return false.
-- ════════════════════════════════════════════════════════════════════════════
TestAvailabilityMutation["test_pre_move/pre_move is allowed (kills first `true`->false on L15)"] = function(self)
  lu.assertEvalToTrue(availability.trigger_timing_allowed("pre_move", "pre_move") == true,
    "pre_move phase with pre_move timing must be allowed")
end

TestAvailabilityMutation["test_pre_move/turn is allowed (kills second `true`->false on L15)"] = function(self)
  lu.assertEvalToTrue(availability.trigger_timing_allowed("pre_move", "turn") == true,
    "pre_move phase with turn timing must be allowed")
end

-- ════════════════════════════════════════════════════════════════════════════
-- L27 / L28: followup_choice_item_set[monster] / [missile] = true.
-- Exercised via availability.requires_followup_choice, which returns
-- `followup_choice_item_set[item_id] == true`.
-- ════════════════════════════════════════════════════════════════════════════
TestAvailabilityMutation["test_monster requires a followup choice (kills L27 `true`->false)"] = function(self)
  lu.assertEvalToTrue(availability.requires_followup_choice(item_ids.monster) == true,
    "monster must require a followup choice")
end

TestAvailabilityMutation["test_missile requires a followup choice (kills L28 `true`->false)"] = function(self)
  lu.assertEvalToTrue(availability.requires_followup_choice(item_ids.missile) == true,
    "missile must require a followup choice")
end

-- ════════════════════════════════════════════════════════════════════════════
-- L91: `if auto_play_port.is_computer_controlled(game, player) then` -> nil.
-- Original branches to auto_candidates when auto; mutant always falls to
-- manual_candidates. Make the two paths yield opposite offerability.
-- ════════════════════════════════════════════════════════════════════════════
TestAvailabilityMutation["test_auto player uses auto_candidates (kills L91 condition->nil)"] = function(self)
  -- is_auto true; auto path non-empty (offer), manual path empty (no offer).
  -- Original: auto path -> can_offer true. Mutant(nil cond): manual -> false.
  local can_offer = _roadblock_can_offer(true, { { idx = 1 } }, {})
  lu.assertEvalToTrue(can_offer == true,
    "auto player with non-empty auto_candidates must be offerable; got " .. tostring(can_offer))
end

TestAvailabilityMutation["test_manual player uses manual_candidates (guards L91 the other way)"] = function(self)
  -- is_auto false; manual non-empty, auto empty. Original: manual -> true.
  local can_offer = _roadblock_can_offer(false, {}, { { idx = 1 } })
  lu.assertEvalToTrue(can_offer == true,
    "manual player with non-empty manual_candidates must be offerable; got " .. tostring(can_offer))
end

TestAvailabilityMutation["test_auto_candidates result is returned, not discarded (kills L92 ->nil)"] = function(self)
  -- is_auto true; auto non-empty, manual empty. Original returns the auto list
  -- (offerable). Mutant replacing the call with nil -> type(nil) fails -> false.
  local can_offer = _roadblock_can_offer(true, { { idx = 1 }, { idx = 2 } }, {})
  lu.assertEvalToTrue(can_offer == true,
    "auto_candidates list must drive offerability; got " .. tostring(can_offer))
end

-- ════════════════════════════════════════════════════════════════════════════
-- L156: `return type(candidates) == "table" and #candidates > 0`
--   and->or : empty table -> original false, mutant true.
--   >-> >=  : empty table -> original false, mutant true.
--   0 -> 1  : single-element table -> original true, mutant false.
-- ════════════════════════════════════════════════════════════════════════════
TestAvailabilityMutation["test_empty candidate table is NOT offerable (kills and->or and >->>=)"] = function(self)
  -- type=="table" true, #==0. Original: true and (0>0) -> false.
  -- Mut and->or: true or ... -> true. Mut >->>=: true and (0>=0) -> true.
  local can_offer = _roadblock_can_offer(true, {}, {})
  lu.assertEvalToTrue(can_offer == false,
    "empty roadblock candidates must NOT be offerable; got " .. tostring(can_offer))
end

TestAvailabilityMutation["test_single candidate IS offerable (kills 0->1)"] = function(self)
  -- #==1. Original: 1>0 -> true. Mut 0->1: 1>1 -> false.
  local can_offer = _roadblock_can_offer(true, { { idx = 1 } }, {})
  lu.assertEvalToTrue(can_offer == true,
    "a single roadblock candidate must be offerable; got " .. tostring(can_offer))
end


return TestAvailabilityMutation
