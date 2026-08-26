-- force-skip 退还预消耗道具 pin(深化迁移 step 0 起草,step 4 激活)
--
-- 起草时核实的两个潜伏缺陷(现已修复):
-- 1. item_preconsume_policy.refund 曾不存在 → 退还静默 no-op;现为薄适配
--    到 settlement.abandon(托管台账幂等退还);
-- 2. force_skip 曾只传 state._game(生产从未赋值)→ refund 收到 nil game;
--    现 api.force_skip 把自持的 game 下传。
-- 本 pin 用生产形状 state(不设 _game)+ 真实 escrow 预消耗写入口构造 fixture。
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local availability = require("src.rules.items.availability")
local item_ids = require("src.config.gameplay.item_ids")
local runtime_state = require("src.state.runtime")
local settlement = require("src.rules.items.settlement")
local use_flow = require("src.rules.items.use_flow")
local DeadlineService = require("src.turn.deadlines")
local config_reset = require("test.support.config_reset")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _with_patches(patches, fn)
  local previous = {}
  for index, patch in ipairs(patches) do
    previous[index] = patch.target[patch.key]
    patch.target[patch.key] = patch.value
  end
  local ok, result = pcall(fn)
  for index = #patches, 1, -1 do
    local patch = patches[index]
    patch.target[patch.key] = previous[index]
  end
  if not ok then
    error(result, 0)
  end
  return result
end

-- 经真实 begin_item_use 拿 followup spec,再经 settlement.escrow(真实预消耗写入口)
-- 装饰后挂起;choice.meta 仍不手搓。原经 item_phase_choice handler 的构造链随该
-- 生产死 kind 一起收掉了;escrow 面的去留另行裁决(见 escrow 死面 issue),本 pin
-- 钉的是 force_skip 的退还读面(生产每次 force_skip 都会走)。
local function _open_preconsumed_followup_choice(game, player, item_id)
  -- 隔离 force_skip 之后 advance_turn 的重开窗:pin 只关心退还与本 choice 的清理。
  game.intent_output_port = {
    push_popup = function()
      return true
    end,
    open_choice = function()
      return true
    end,
  }
  local result
  _with_patches({
    {
      target = availability,
      key = "can_offer_in_phase",
      value = function()
        return true, "ok"
      end,
    },
  }, function()
    result = use_flow.begin_item_use(game, player.id, item_id, { phase = "landing" })
  end)
  local followup_spec = result and result.intent and result.intent.choice_spec or nil
  assert(followup_spec ~= nil, "waiting item use should surface a followup choice spec")
  settlement.escrow(player, item_id, followup_spec)
  return support.open_choice(game, followup_spec)
end

TestForceSkipRefundPin = {}

function TestForceSkipRefundPin:setUp()
  config_reset.reset_all()
end

function TestForceSkipRefundPin:test_force_skip_refunds_the_preconsumed_item_to_the_bag()
  local g = support.new_game({ map = default_map })
  local player = g.players[1]
  g.players[2].inventory:add({ id = item_ids.mine })
  player.inventory:add({ id = item_ids.steal })

  local choice = _open_preconsumed_followup_choice(g, player, item_ids.steal)
  _assert_eq(support.count_item(player, item_ids.steal), 0, "followup open must have preconsumed the card")
  -- 模拟目标失效导致无可选项——这是超时走 force_skip(而非自动选首选项)的触发条件
  choice.options = {}

  -- 生产形状 state:不手工赋值 state._game(生产代码从未赋值;手工赋值会掩盖缺陷 2)
  local state = runtime_state.ensure_all({})
  DeadlineService.force_skip(g, state, choice, "tick_timeout")

  _assert_eq(support.count_item(player, item_ids.steal), 1, "force-skip must refund the preconsumed card")
  _assert_eq(g.turn.pending_choice, nil, "force-skip should clear the pending choice")
end


return TestForceSkipRefundPin
