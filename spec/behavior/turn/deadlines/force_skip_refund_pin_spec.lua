-- force-skip 退还预消耗道具 pin(深化迁移 step 0 起草,step 4 激活)
--
-- 起草时核实的两个潜伏缺陷(现已修复):
-- 1. item_preconsume_policy.refund 曾不存在 → 退还静默 no-op;现为薄适配
--    到 settlement.abandon(托管台账幂等退还);
-- 2. force_skip 曾只传 state._game(生产从未赋值)→ refund 收到 nil game;
--    现 api.force_skip 把自持的 game 下传。
-- 本 pin 用生产形状 state(不设 _game)+ 真实 item_phase_choice 预消耗路径构造 fixture。
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local availability = require("src.rules.items.availability")
local choice_resolver = require("src.rules.choice.resolver")
local item_ids = require("src.config.gameplay.item_ids")
local runtime_state = require("src.state.runtime")
local DeadlineService = require("src.turn.deadlines")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
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

-- 经真实 item_phase_choice handler 走非重复阶段预消耗(availability 收窄 patch 是唯一 stub),
-- 返回已挂起的预消耗 followup pending choice。禁止手搓 choice.meta。
local function _open_preconsumed_followup_choice(game, player, item_id)
  local captured = {}
  game.intent_output_port = {
    push_popup = function()
      return true
    end,
    open_choice = function(_, choice_spec)
      captured.spec = choice_spec
      return true
    end,
  }
  local phase_choice = support.open_choice(game, {
    kind = "item_phase_choice",
    options = { { id = item_id, label = "道具" } },
    meta = { player_id = player.id, phase = "landing" },
  })
  _with_patches({
    {
      target = availability,
      key = "can_offer_in_phase",
      value = function()
        return true, "ok"
      end,
    },
  }, function()
    choice_resolver.resolve(game, phase_choice, { option_id = item_id })
  end)
  assert(captured.spec ~= nil, "preconsumed followup choice spec should be dispatched")
  return support.open_choice(game, captured.spec)
end

describe("force_skip refund of preconsumed items", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("force_skip refunds the preconsumed item to the bag", function()
    local g = support.new_game({ map = default_map })
    local player = g.players[1]
    g.players[2].inventory:add({ id = item_ids.mine })
    player.inventory:add({ id = item_ids.steal })

    local choice = _open_preconsumed_followup_choice(g, player, item_ids.steal)
    _assert_eq(_count_item(player, item_ids.steal), 0, "followup open must have preconsumed the card")
    -- 模拟目标失效导致无可选项——这是超时走 force_skip(而非自动选首选项)的触发条件
    choice.options = {}

    -- 生产形状 state:不手工赋值 state._game(生产代码从未赋值;手工赋值会掩盖缺陷 2)
    local state = runtime_state.ensure_all({})
    DeadlineService.force_skip(g, state, choice, "tick_timeout")

    _assert_eq(_count_item(player, item_ids.steal), 1, "force-skip must refund the preconsumed card")
    _assert_eq(g.turn.pending_choice, nil, "force-skip should clear the pending choice")
  end)
end)
