-- item_slots_highlight 直测(#262 变异清扫 survivor 闭合 + #362 锚定可见签名):
-- 签名比对重放(true→false / build_pickable_signature call→nil);
-- maybe_emit_phase_advance_reset 锚定可选槽集合签名,phase 空翻不触发全局重置。
-- choice_id 翻新不重放由验收场景 002 钉住(刷新路径根本不读 choice_id,
-- 单测无可翻转的输入)。
-- #459:0.35s 外框延迟门控随外框退役,签名变化即重放,即时反馈。
-- #595:ask/passive 双路径随 suppress 旗标一并删除,刷新只剩一条路径
-- (应用生命周期队列 → 计划 → 投递),冻结语义由生命周期事件表达。
local support = require("test.support.shared_support")
local highlight = require("src.ui.coord.item_slots_highlight")
local events = require("src.ui.coord.item_slots_events")
local highlight_lifecycle = require("src.ui.state.item_slot_highlight_lifecycle_queue")

local _assert_eq = support.assert_eq

-- 驱动一次 refresh 并捕获宿主出口事件。
local function _drive(opts)
  local captured = { emits = 0, replays = 0, resets = 0 }
  -- missing_role / missing_player 显式缺省身份(nil 是 falsy,and/or 三元
  -- 会把它兜回默认值,须用分支判定)。
  ---@type integer|nil
  local ctx_role_id = 1
  ---@type integer|nil
  local ctx_display_player_id = 1
  if opts.missing_role == true then
    ctx_role_id = nil
  end
  if opts.missing_player == true then
    ctx_display_player_id = nil
  end
  support.with_patches({
    -- replays / resets 分开计数:emit_pickable_slot_animation 是「整组重播」,
    -- emit_global_reset_animation 是「只清旧高亮」。这里替换的是出口本身,
    -- 所以 replay 不会顺带记一次 reset(真实实现里 replay 内部也发全局重置)。
    { target = events, key = "emit_pickable_slot_animation", value = function()
      captured.emits = captured.emits + 1
      captured.replays = captured.replays + 1
    end },
    { target = events, key = "emit_global_reset_animation", value = function()
      captured.emits = captured.emits + 1
      captured.resets = captured.resets + 1
    end },
  }, function()
    highlight.refresh_highlight_state(opts.state, {
      role_id = ctx_role_id,
      display_player_id = ctx_display_player_id,
      choice = {},
      ui = {},
    }, opts.sig)
  end)
  return captured
end

TestItemSlotsHighlight = {}

function TestItemSlotsHighlight:test_replays_only_when_the_signature_changes()
  -- kills _phase_gate_needs_replay's `~= signature` return true -> false and
  -- the build_pickable_signature call -> nil (mutant signatures never differ).
  local state = {}
  local first = _drive({ state = state, sig = { true, false, true } })
  _assert_eq(first.emits, 1, "the first paint emits the animation")
  local same = _drive({ state = state, sig = { true, false, true } })
  _assert_eq(same.emits, 0, "an unchanged signature does not replay")
  local changed = _drive({ state = state, sig = { true, false, false } })
  _assert_eq(changed.emits, 1, "a changed signature replays the animation")
end

function TestItemSlotsHighlight:test_confirm_freeze_blocks_replay_for_this_refresh()
  local state = {}
  highlight_lifecycle.push(state, "confirm_item_use", "c1")
  local frozen = _drive({ state = state, sig = { true, false, true } })
  _assert_eq(frozen.emits, 0, "the confirmed choice is frozen until a slot command")
end

-- #595:冻结期间集合真的变了,生产链路必须把 reset 发到宿主——旧高亮框指向的
-- 槽位已不可选,留在屏上是错的视觉。钉住「冻结不等于宿主静默」。
function TestItemSlotsHighlight:test_frozen_set_change_still_clears_host_highlight()
  local state = {}
  highlight_lifecycle.push(state, "confirm_item_use", "c1")
  _drive({ state = state, sig = { true, false, true } })
  local changed = _drive({ state = state, sig = { true, true, true } })
  _assert_eq(changed.replays, 0, "a frozen refresh must not replay the whole group")
  _assert_eq(changed.resets, 1, "a set change under freeze must still clear the stale highlight")
end

-- #595 场景 017:迟到的旧选择关闭不能解除新选择的冻结。这条经生产链路走,
-- 此前输入侧把「关闭」压成清旗标,刷新层误读为槽位命令而错误解冻。
function TestItemSlotsHighlight:test_stale_choice_close_does_not_unfreeze_the_new_choice()
  local state = {}
  highlight_lifecycle.push(state, "confirm_item_use", "C1")
  _drive({ state = state, sig = { true, false, true } })
  highlight_lifecycle.push(state, "confirm_item_use", "C2")
  _drive({ state = state, sig = { true, false, true } })
  highlight_lifecycle.push(state, "choice_released", "C1")
  local kinds = _drive({ state = state, sig = { true, true, true } })
  _assert_eq(kinds.resets, 1, "a stale close only clears the stale highlight")
  _assert_eq(kinds.replays, 0, "a stale close must not replay: C2 is still frozen")
end

-- #595:刷新必须消费生命周期队列。事件留在状态里会在后续刷新迟到生效,
-- 把冻结挪到错误的时刻。
function TestItemSlotsHighlight:test_refresh_consumes_the_lifecycle_queue()
  local state = {}
  highlight_lifecycle.push(state, "confirm_item_use", "c1")
  _drive({ state = state, sig = { true, false, true } })
  _assert_eq(highlight_lifecycle.drain(state), nil,
    "refresh must consume the queue, not leave events to take effect late")
end

-- #595 场景 018:关闭匹配当前冻结的选择才解冻,之后集合变化恢复整组重播。
function TestItemSlotsHighlight:test_matching_choice_close_unfreezes_and_replays()
  local state = {}
  highlight_lifecycle.push(state, "confirm_item_use", "C1")
  _drive({ state = state, sig = { true, false, true } })
  highlight_lifecycle.push(state, "choice_released", "C1")
  local kinds = _drive({ state = state, sig = { true, true, true } })
  _assert_eq(kinds.replays, 1, "a matching close unfreezes and replays the whole group")
end

-- #594:缺失身份是独立的展示视角,不与任何真实 id 合并——记忆隔离取代了
-- 旧 gate key 的字面量兜底("global"/"none")。缺省角色的重放不能被
-- 「角色1」的既有记忆吃掉,反之亦然。
function TestItemSlotsHighlight:test_missing_identities_are_their_own_perspective()
  local snapshot = { true, false, true }
  local state = {}
  _drive({ state = state, sig = snapshot })
  local missing_role = _drive({ state = state, sig = snapshot, missing_role = true })
  _assert_eq(missing_role.emits, 1,
    "a missing role id is a distinct perspective and still replays")
  local missing_player = _drive({ state = state, sig = snapshot, missing_player = true })
  _assert_eq(missing_player.emits, 1,
    "a missing display player is a distinct perspective and still replays")
  local repeated = _drive({ state = state, sig = snapshot, missing_role = true })
  _assert_eq(repeated.emits, 0,
    "the same missing-identity perspective remembers its own replay")
end

	-- #362 D3:maybe_emit_phase_advance_reset 锚定可选槽集合签名。
	-- 首次发重置并缓存签名;集合不变不重发;集合变为空仍发清场重置。
	-- 杀 ==→~= / ==→true(恒发)/ ==→false(首发不发) 与 build→nil 变异
	-- (签名恒 nil,必与缓存 "1,2" 不等而误发)。
	function TestItemSlotsHighlight:test_phase_advance_reset_emits_when_pickable_signature_changes()
	  local emit_count = 0
	  support.with_patches({
	    { target = events, key = "emit_global_reset_animation", value = function()
	      emit_count = emit_count + 1
	    end },
	  }, function()
	    local state = { game = { turn = { phase = "roll", item_phase_active = "" } } }
	    highlight.maybe_emit_phase_advance_reset(state, { true, false })
	    _assert_eq(emit_count, 1, "the first paint with a pickable set emits the global reset")
	    highlight.maybe_emit_phase_advance_reset(state, { true, false })
	    _assert_eq(emit_count, 1, "an unchanged pickable set does not re-emit")
	    highlight.maybe_emit_phase_advance_reset(state, {})
	    _assert_eq(emit_count, 2, "the set emptying emits a clearing reset")
	    highlight.maybe_emit_phase_advance_reset(state, {})
	    _assert_eq(emit_count, 2, "the empty set is remembered and does not re-emit")
	  end)
	end

	-- #362 D3:phase 签名翻转但槽位集合不变 → 不发全局重置(高亮框不回位)。
	function TestItemSlotsHighlight:test_phase_advance_reset_ignores_phase_flips()
	  local emit_count = 0
	  support.with_patches({
	    { target = events, key = "emit_global_reset_animation", value = function()
	      emit_count = emit_count + 1
	    end },
	  }, function()
	    local state = { game = { turn = { phase = "roll", item_phase_active = "" } } }
	    highlight.maybe_emit_phase_advance_reset(state, { true })
	    state.game.turn.phase = "post_action"
	    state.game.turn.item_phase_active = "active"
	    highlight.maybe_emit_phase_advance_reset(state, { true })
	    _assert_eq(emit_count, 1,
	      "phase flips without a pickable set change must not re-emit")
	  end)
	end

	-- turn 缺省时不 emit(覆盖 ==nil 守卫)
	function TestItemSlotsHighlight:test_phase_advance_reset_no_turn()
	  local emit_count = 0
	  support.with_patches({
	    { target = events, key = "emit_global_reset_animation", value = function()
	      emit_count = emit_count + 1
	    end },
	  }, function()
	    highlight.maybe_emit_phase_advance_reset({ game = {} }, { true })
	    _assert_eq(emit_count, 0, "missing turn should not emit")
	  end)
	end

	-- #596:无快照(nil)与空集合是两个不同状态,不再靠 "none" 字符串哨兵区分。
	-- 连续无快照自洽去重;从无快照转到空集合算变化,要发清场重置。
	function TestItemSlotsHighlight:test_phase_advance_reset_absent_snapshot_is_distinct()
	  local emit_count = 0
	  support.with_patches({
	    { target = events, key = "emit_global_reset_animation", value = function()
	      emit_count = emit_count + 1
	    end },
	  }, function()
	    local state = { game = { turn = {} } }
	    highlight.maybe_emit_phase_advance_reset(state, nil)
	    _assert_eq(emit_count, 1, "the first absent snapshot emits once")
	    highlight.maybe_emit_phase_advance_reset(state, nil)
	    _assert_eq(emit_count, 1, "a repeated absent snapshot must not re-emit")
	    highlight.maybe_emit_phase_advance_reset(state, {})
	    _assert_eq(emit_count, 2, "an empty set is not the same state as an absent snapshot")
	  end)
	end

return TestItemSlotsHighlight
