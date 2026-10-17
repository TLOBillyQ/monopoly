---@diagnostic disable: undefined-global, undefined-field, duplicate-set-field, unused-local, need-check-nil

-- 道具槽点击的分支裁定已搬离本文件：新设计里裁定独占在
-- src/turn/actions/item_slot_click.resolve（逐分支覆盖见
-- test/behavior/turn/test_item_slot_click.lua），validator 不再有
-- resolve_item_slot_action，ui_button 也不再有 item_slot 分支。
-- 因此原先钉 validator 从 ui_runtime 读 choice / 回落 turn pending / 槽位映射
-- 缺失 / 选项非法 / availability 拒因的用例在此退场，本文件只保留仍属
-- ui_runtime 契约的那一条：ui_runtime 的 pending_choice 是展示镜像，
-- 道具槽裁定的真源是 game.turn.pending_choice（含它的 meta.phase）。
local luassert = assert
local runtime_state = require("src.state.runtime")
local output_port = require("src.turn.output.state_adapter")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local item_slot_click = require("src.turn.actions.item_slot_click")
local denial_cfg = require("src.config.content.item_slot_denial")
local availability = require("src.rules.items.availability")

local function _player(id, item_ids)
  local items = {}
  for index, item_id in ipairs(item_ids or {}) do
    items[index] = { id = item_id }
  end
  return { id = id, inventory = { items = items } }
end

local function _item_window(owner_role_id, option_ids, phase)
  local options = {}
  for index, option_id in ipairs(option_ids or {}) do
    options[index] = { id = option_id }
  end
  return {
    id = "win_" .. tostring(owner_role_id),
    kind = "item_phase_passive",
    uses_item_slots = true,
    owner_role_id = owner_role_id,
    options = options,
    meta = { phase = phase or "pre_action", player_id = owner_role_id },
  }
end

-- 最小真实形状的 game：裁定只吃 players / turn / find_player_by_id，提示经
-- tip_output_port 捕获（与生产同一条端口）。
local function _item_slot_game(players, turn_choice)
  local tips = {}
  local game = {
    players = players,
    turn = {
      current_player_index = 1,
      pending_choice = turn_choice,
      used_effect_groups = {},
    },
    tip_output_port = {
      enqueue = function(_, intent)
        tips[#tips + 1] = intent
        return true
      end,
    },
  }
  function game:find_player_by_id(role_id)
    for _, player in ipairs(self.players) do
      if player.id == role_id then
        return player
      end
    end
    return nil
  end
  return game, tips
end

local function _click(game, actor_role_id, slot_index)
  return item_slot_click.resolve(game, {
    type = "item_slot_click",
    slot_index = slot_index,
    actor_role_id = actor_role_id,
    input_source = "touch",
  })
end

describe("TestUiRuntimeState", function()
  local original_can_offer_in_phase

  before_each(function()
    original_can_offer_in_phase = availability.can_offer_in_phase
  end)

  after_each(function()
    availability.can_offer_in_phase = original_can_offer_in_phase
  end)

  it("test_runtime_state_defaults_to_runtime_only_structure", function()
  local state = {}

  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  luassert.is.equal(false, ui_runtime.ui_dirty, "ensure_ui_runtime should default dirty flag to false")
  luassert.is_nil(runtime_state.get_ui_model(state), "get_ui_model should default to nil")
  luassert.is_nil(runtime_state.get_pending_choice_id(state), "get_pending_choice_id should default to nil")
  luassert.is.equal(0, runtime_state.get_pending_choice_elapsed(state), "get_pending_choice_elapsed should default to zero")
  luassert.is.equal(0, runtime_state.get_modal_elapsed(state), "get_modal_elapsed should default to zero")
  luassert.is_nil(runtime_state.get_modal_ref(state), "get_modal_ref should default to nil")

  state.ui_model = { marker = "legacy_model" }
  state.pending_choice = { id = 7, kind = "market_buy" }
  state.pending_choice_id = 7
  state.pending_choice_elapsed = 1.5
  state.ui_modal_elapsed = 2.25
  state.ui_modal_ref = "popup_1"

  luassert.is_nil(runtime_state.get_ui_model(state), "legacy root ui_model should no longer seed ui_runtime")
  luassert.is_nil(runtime_state.get_pending_choice_id(state), "legacy root pending choice id should no longer seed ui_runtime")
  end)

  it("test_output_port_uses_runtime_state_accessors", function()
  local state = {}
  local model = { screen = "choice" }
  local choice = { id = 11, kind = "item_phase_passive" }

  luassert.is_true(output_port.invalidate_ui_model(state), "invalidate_ui_model should mark ui_runtime dirty")
  luassert.is_true(runtime_state.is_ui_dirty(state), "invalidate_ui_model should write ui_runtime dirty flag")
  luassert.is_nil(state.ui_dirty, "invalidate_ui_model should not write legacy ui_dirty directly")

  output_port.sync_ui_model(state, model)
  luassert.is.equal(model, runtime_state.get_ui_model(state), "sync_ui_model should write ui_runtime model")
  luassert.is_nil(state.ui_model, "sync_ui_model should not mirror into legacy state directly")

  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 3.5 })
  luassert.is.equal(choice, runtime_state.get_pending_choice(state), "sync_pending_choice should write ui_runtime choice")
  luassert.is.equal(3.5, runtime_state.get_pending_choice_elapsed(state), "sync_pending_choice should write ui_runtime elapsed")
  luassert.is_nil(state.pending_choice, "sync_pending_choice should not mirror into legacy state directly")

  output_port.sync_modal_timer(state, { ref = "popup_ref", elapsed_seconds = 2.0 })
  luassert.is.equal("popup_ref", runtime_state.get_modal_ref(state), "sync_modal_timer should write ui_runtime ref")
  luassert.is.equal(2.0, runtime_state.get_modal_elapsed(state), "sync_modal_timer should write ui_runtime elapsed")
  luassert.is_nil(state.ui_modal_ref, "sync_modal_timer should not mirror into legacy state directly")
  end)

  it("test_tick_ui_sync_update_countdown_reads_ui_runtime", function()
  local game = {
    turn = {
      detained_wait_active = false,
      countdown_seconds = 0,
      countdown_active = false,
    },
    dirty = {},
  }
  local state = {
    countdown_last = nil,
    countdown_active_last = nil,
    ui_runtime = {
      pending_choice = { id = 3, kind = "market_buy" },
      pending_choice_elapsed = 2.0,
    },
  }

  tick_ui_sync.update_countdown(game, state)

  -- 现在 market_buy 走 timing.scope_timeouts.market_buy=60s（不再 action_timeout_seconds*2=30）。
  -- 旧 elapsed=2.0 来自 ui_runtime.pending_choice_elapsed，但新链路下当 DeadlineService 还没注册
  -- choice 时，ui_sync 回退到旧路径（旧 elapsed=2.0，新 timeout=60，countdown=ceil(60-2)=58）。
  local timing = require("src.config.gameplay.timing")
  local expected_remaining = math.ceil(timing.scope_timeouts.market_buy - 2.0)
  luassert.is.equal(expected_remaining, game.turn.countdown_seconds, "market choice countdown should reflect scope_timeouts.market_buy minus elapsed")
  luassert.is_true(game.turn.countdown_active, "countdown should become active when ui_runtime has pending choice")
  luassert.is_true(game.dirty.turn_countdown, "countdown change should mark turn_countdown dirty")
  luassert.is_true(game.dirty.any, "countdown change should mark any dirty")
  end)

-- 镜像开着窗、turn 侧不是道具窗时不许放行：ui_runtime 是展示镜像，
-- 裁定只认 game.turn.pending_choice（且必须是 item_phase_passive）。
  it("test_item_slot_click_takes_turn_choice_over_ui_runtime_mirror", function()
  local state = {}
  local mirrored_window = _item_window(8, { "item_a" })
  output_port.sync_pending_choice(state, mirrored_window, { elapsed_seconds = 0 })

  local game, tips = _item_slot_game({ _player(8, { "item_a" }) }, {
    id = 41,
    kind = "market_buy",
    options = { { id = "item_a" } },
  })

  local result = _click(game, 8, 1)
  luassert.is.equal("denied", result.status, "mirror-open window must not admit the click")
  luassert.is.equal("no_item_window", result.reason, "non item_phase_passive turn choice is not a window")
  luassert.is.equal(1, #tips, "denied click must be tipped")
  luassert.is.equal(denial_cfg.PHASE_DENIED_TEXT, tips[1].text, "denial tip text comes from the reason")
  luassert.is.equal(mirrored_window, runtime_state.get_pending_choice(state),
    "arbitration must leave the ui_runtime mirror untouched")
  end)

-- 反向：镜像陈旧（还停在 market_buy）不妨碍放行，choice_id 取 turn 侧的窗。
  it("test_item_slot_click_admits_from_turn_choice_while_mirror_is_stale", function()
  local state = {}
  output_port.sync_pending_choice(state, { id = 11, kind = "market_buy" }, { elapsed_seconds = 0 })

  local turn_window = _item_window(8, { "item_a" })
  local game, tips = _item_slot_game({ _player(8, { "item_a" }) }, turn_window)

  local result = _click(game, 8, 1)
  luassert.is.equal("select", result.status, "stale mirror must not block a live turn window")
  luassert.is.equal("choice_select", result.action.type, "admitted action type")
  luassert.is.equal(turn_window.id, result.action.choice_id, "choice id must come from the turn window")
  luassert.is.equal("item_a", result.action.option_id, "option id comes from the actor bag slot")
  luassert.is.equal(0, #tips, "admitted click must not raise a tip")
  end)

-- phase 也只从 turn 侧 choice.meta 读：读到空串就不拿空 phase 去问 availability，
-- 直接走通用拒因，避免用空口径误判出一个具体原因。
  it("test_item_slot_click_skips_availability_when_turn_choice_phase_is_blank", function()
  local calls = 0
  availability.can_offer_in_phase = function()
    calls = calls + 1
    return false, "insufficient_funds"
  end

  local game, tips = _item_slot_game({ _player(8, { "item_a", "item_b" }) },
    _item_window(8, { "item_b" }, ""))

  local result = _click(game, 8, 1)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;存量迁移见 #138
  luassert.is.equal(0, calls, "blank phase should skip the availability recheck")
  luassert.is.equal("denied", result.status, "unofferable card is still denied")
  luassert.is.equal("unknown", result.reason, "blank phase yields the unclassified reason")
  luassert.is.equal(denial_cfg.GENERIC_DENIED_TEXT, tips[1].text, "unclassified reason uses the generic text")
  end)
end)
