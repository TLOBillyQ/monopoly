-- use_flow_resolvers 直测:kind 描述表三件事(消耗时机 / 失败兜底 reason / apply 失败形状)。
-- 集成 spec 跑通各 kind 的成功流程,但没钉描述表字段本身(变异清扫 #259 survivor
-- 真缺口闭合):settlement.execute 桩捕获 opts,逐 kind 钉 consume 与 fallback_reason。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local settlement = require("src.rules.items.settlement")
local target_resolve = require("src.rules.items.target_resolve")
local roadblock = require("src.rules.items.roadblock")
local resolvers = require("src.rules.items.use_flow_resolvers")

TestUseFlowResolvers = {}

local _player = { id = 1 }

-- settlement.execute 桩:捕获 opts(consume / fallback_reason),不真的执行 apply。
local function _capture_opts(extra_patches, game, choice)
  local captured = {}
  local patches = {
    { target = settlement, key = "execute", value = function(_, _, _, _, opts)
      captured.opts = opts
      return { executed = true }
    end },
  }
  for _, patch in ipairs(extra_patches or {}) do
    patches[#patches + 1] = patch
  end
  with_patches(patches, function()
    resolvers.resolve(game, choice, { option_id = 1 }, {}, {}, _player, 2001)
  end)
  return captured.opts
end

function TestUseFlowResolvers:test_item_target_player_consumes_after_success_with_invalid_target_fallback()
  local opts = _capture_opts(nil, {}, { kind = "item_target_player" })

  lu.assertNotNil(opts, "descriptor should reach settlement.execute")
  lu.assertIs(opts.consume, "after_success")
  lu.assertIs(opts.fallback_reason, "invalid_target")
end

function TestUseFlowResolvers:test_remote_dice_value_consumes_before_apply_with_effect_rejected_fallback()
  local opts = _capture_opts(nil, {}, { kind = "remote_dice_value" })

  lu.assertNotNil(opts, "descriptor should reach settlement.execute")
  lu.assertIs(opts.consume, "before_apply")
  lu.assertIs(opts.fallback_reason, "effect_rejected")
end

function TestUseFlowResolvers:test_roadblock_target_consumes_before_apply_with_effect_rejected_fallback()
  local opts = _capture_opts({
    { target = roadblock, key = "is_ui_candidate", value = function()
      return true
    end },
  }, {}, { kind = "roadblock_target" })

  lu.assertNotNil(opts, "descriptor should reach settlement.execute")
  lu.assertIs(opts.consume, "before_apply")
  lu.assertIs(opts.fallback_reason, "effect_rejected")
end

function TestUseFlowResolvers:test_demolish_target_consumes_before_apply_with_effect_rejected_fallback()
  local opts = _capture_opts(nil, {}, { kind = "demolish_target" })

  lu.assertNotNil(opts, "descriptor should reach settlement.execute")
  lu.assertIs(opts.consume, "before_apply")
  lu.assertIs(opts.fallback_reason, "effect_rejected")
end

function TestUseFlowResolvers:test_item_target_player_apply_reports_failure_when_no_valid_target_resolves()
  local game = { registries = { items = { target_candidates = function()
    return {}
  end } } }
  local apply_result = "unset"
  with_patches({
    { target = settlement, key = "execute", value = function(_, _, _, apply_fn)
      apply_result = apply_fn(function() end)
      return { executed = true }
    end },
    { target = target_resolve, key = "resolve_valid_target", value = function()
      return nil
    end },
  }, function()
    resolvers.resolve(game, { kind = "item_target_player" }, { option_id = 99 }, {}, {}, _player, 2001)
  end)

  lu.assertFalse(apply_result, "apply must report failure (false) when the target does not resolve")
end



function TestUseFlowResolvers:test_item_target_player_asserts_missing_registries_with_messages()
  -- #293:item_target_player apply 的两处装配断言消息未测。
  local ok_registries, err_registries = pcall(resolvers.resolve, {}, { kind = "item_target_player" }, { option_id = 1 }, {}, {}, { id = 1 }, 2001)
  lu.assertEvalToTrue(ok_registries == false, "missing registries should assert")
  lu.assertEvalToTrue(tostring(err_registries):find("missing game.registries", 1, true) ~= nil,
    "registries assert should carry its message: " .. tostring(err_registries))

  local ok_items, err_items = pcall(resolvers.resolve, { registries = {} }, { kind = "item_target_player" }, { option_id = 1 }, {}, {}, { id = 1 }, 2001)
  lu.assertEvalToTrue(ok_items == false, "missing item registry should assert")
  lu.assertEvalToTrue(tostring(err_items):find("missing item registry", 1, true) ~= nil,
    "item registry assert should carry its message: " .. tostring(err_items))
end

return TestUseFlowResolvers
