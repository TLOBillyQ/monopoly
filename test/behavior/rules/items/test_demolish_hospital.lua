-- demolish_hospital 直测(#259 变异清扫 survivor 闭合):
-- _relocate_to_hospital 的 move_dir_mode "clear" 字面值,与
-- _patch_queued_anim_targets 的 `action_anim_queue or {}` `or` -> `and`
-- (变异体在 queue 缺位时对 nil 跑 ipairs 报错)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local demolish_hospital = require("src.rules.items.demolish_hospital")
local event_feed = require("src.rules.ports.event_feed")

local _assert_eq = support.assert_eq

TestDemolishHospital = {}

function TestDemolishHospital:test_handle_result_relocates_with_move_dir_mode_clear_and_patches_the_queued_anim()
  local relocated = {}
  local anim = { kind = "missile", tile_index = 3, player_id = 1 }
  local game = {
    board = { find_first_by_type = function() return 9 end },
    player_relocate = function(_, target, opts)
      relocated[#relocated + 1] = { target = target, opts = opts }
    end,
    player_apply_hospital_effects = function() end,
    turn = { action_anim = anim }, -- action_anim_queue 故意缺位
  }
  local target = { id = 2 }
  support.with_patches({
    { target = event_feed, key = "publish", value = function() end },
  }, function()
    local result = demolish_hospital.handle_result(
      game, { id = 1 }, 3, "missile", { target }, nil, "msg", {}
    )
    _assert_eq(result.ok, true, "handle_result should succeed without a queued anim")
  end)
  _assert_eq(#relocated, 1, "the casualty should be relocated")
  _assert_eq(relocated[1].opts.move_dir_mode, "clear", "relocation must clear the heading")
  _assert_eq(relocated[1].opts.destination_index, 9, "relocation targets the hospital")
  _assert_eq(anim.to_index, 9, "the matching queued anim should be patched to the hospital")
end


function TestDemolishHospital:test_handle_result_patches_matching_entries_in_the_queued_anim_list()
  local queued = { kind = "missile", tile_index = 3, player_id = 1 }
  local unrelated = { kind = "typhoon", tile_index = 3, player_id = 1 }
  local game = {
    board = { find_first_by_type = function() return 9 end },
    player_relocate = function() end,
    player_apply_hospital_effects = function() end,
    turn = {
      action_anim_queue = { queued, unrelated },
    },
  }
  support.with_patches({
    { target = event_feed, key = "publish", value = function() end },
  }, function()
    demolish_hospital.handle_result(game, { id = 1 }, 3, "missile", { { id = 2 } }, nil, "msg", {})
  end)

  _assert_eq(queued.to_index, 9, "the matching queued anim should be patched to the hospital")
  _assert_eq(unrelated.to_index, nil, "non-matching queued anim should be left untouched")
end

function TestDemolishHospital:test_handle_result_asserts_missing_hospital()
  -- #293:assert 消息「missing hospital」→ nil 变异未测。
  local game = {
    board = {
      find_first_by_type = function() return nil end,
    },
  }
  local ok, err = pcall(demolish_hospital.handle_result, game, {}, 3, "missile", {}, nil, "msg", {})
  lu.assertEvalToTrue(ok == false, "missing hospital should assert")
  lu.assertEvalToTrue(tostring(err):find("missing hospital", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err))
end


return TestDemolishHospital
