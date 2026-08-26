-- 可用槽位高亮重放的展示状态直测(#594):plan_refresh 的三态判定与
-- 逐视角记忆隔离,apply_lifecycle 的确认冻结/命令解冻,以及两个公开操作的
-- 入参断言。本模块是纯展示状态(ui.state),不碰宿主动画。
local support = require("test.support.shared_support")
local replay = require("src.ui.state.item_slot_highlight_replay")

local _assert_eq = support.assert_eq

local function _new_state()
  return {}
end

local function _perspective(role_id, display_player_id)
  return { role_id = role_id, display_player_id = display_player_id }
end

TestItemSlotHighlightReplay = {}

-- 首次观察三态:非空集合重放,空集合只清除,无快照不动。
function TestItemSlotHighlightReplay:test_first_observation_plans_by_snapshot()
  local state = _new_state()
  _assert_eq(replay.plan_refresh(state, _perspective(1, 1), { true, false, true, false, false }),
    "replay", "首次观察非空集合重放")
  _assert_eq(replay.remembered_signature(state, _perspective(1, 1)), "1,3",
    "记忆可选槽位编号集合")

  local empty_state = _new_state()
  _assert_eq(replay.plan_refresh(empty_state, _perspective(1, 1), { false, false, false, false, false }),
    "reset", "首次观察空集合只清除")
  _assert_eq(replay.remembered_signature(empty_state, _perspective(1, 1)), "",
    "空集合记为空集合而非无记忆")

  local blank_state = _new_state()
  _assert_eq(replay.plan_refresh(blank_state, _perspective(1, 1), nil),
    "none", "无槽位快照不动")
  _assert_eq(replay.remembered_signature(blank_state, _perspective(1, 1)), nil,
    "无槽位快照不建立记忆")
end

-- 可选编号集合未变化 → 翻新不重放(卡牌身份换掉也不算变化)。
function TestItemSlotHighlightReplay:test_unchanged_pickable_set_does_not_replay()
  local state = _new_state()
  local perspective = _perspective(1, 1)
  replay.plan_refresh(state, perspective, { true, false, true, false, false })
  _assert_eq(replay.plan_refresh(state, perspective, { true, false, true, false, false }),
    "none", "集合未变化不重放")
end

-- 集合真实变化才产生新计划;变为空集合也是 replay(不是 reset)。
function TestItemSlotHighlightReplay:test_changed_pickable_set_replays()
  local cases = {
    { snapshot = { true, true, true, false, false }, plan = "replay", memory = "1,2,3" },
    { snapshot = { true, false, false, false, false }, plan = "replay", memory = "1" },
    { snapshot = { false, false, false, false, false }, plan = "replay", memory = "" },
    { snapshot = nil, plan = "none", memory = "1,3" },
  }
  for _, case in ipairs(cases) do
    local state = _new_state()
    local perspective = _perspective(1, 1)
    replay.plan_refresh(state, perspective, { true, false, true, false, false })
    _assert_eq(replay.plan_refresh(state, perspective, case.snapshot), case.plan,
      "集合变化后的高亮计划")
    _assert_eq(replay.remembered_signature(state, perspective), case.memory,
      "集合变化后的记忆")
  end
end

-- 每个「本机角色 + 展示玩家」视角独立记忆;缺失侧是独立身份,不与真实 id 混。
function TestItemSlotHighlightReplay:test_each_perspective_remembers_independently()
  local cases = {
    { replayed = _perspective(1, 1), pending = _perspective(2, 1) },
    { replayed = _perspective(1, 1), pending = _perspective(1, 2) },
    { replayed = _perspective(1, 1), pending = _perspective(nil, 1) },
    { replayed = _perspective(1, 1), pending = _perspective(1, nil) },
    { replayed = _perspective(nil, nil), pending = _perspective(1, 1) },
  }
  for _, case in ipairs(cases) do
    local state = _new_state()
    local snapshot = { true, false, true, false, false }
    replay.plan_refresh(state, case.replayed, snapshot)
    _assert_eq(replay.plan_refresh(state, case.pending, snapshot), "replay",
      "另一展示视角首次观察仍重放")
    _assert_eq(replay.remembered_signature(state, case.replayed), "1,3",
      "已重放视角的记忆不受影响")
  end
end

-- 等价身份(字符串 vs 整数)归一化为同一视角 → 不重放。
function TestItemSlotHighlightReplay:test_equivalent_identities_normalize_to_one_perspective()
  local cases = {
    { replayed = _perspective(1, 1), equivalent = _perspective("1", 1) },
    { replayed = _perspective(1, 1), equivalent = _perspective(1, "1") },
    { replayed = _perspective("1", 1), equivalent = _perspective(1, 1) },
  }
  for _, case in ipairs(cases) do
    local state = _new_state()
    local snapshot = { true, false, true, false, false }
    replay.plan_refresh(state, case.replayed, snapshot)
    _assert_eq(replay.plan_refresh(state, case.equivalent, snapshot), "none",
      "等价身份视为同一展示视角")
  end
end

-- 确认使用道具后冻结重放:同一待决选择在发起确认的视角内不重放,
-- 其它视角照常;槽位命令解除冻结但不强制重放。
function TestItemSlotHighlightReplay:test_confirmation_freezes_replay_until_slot_command()
  local state = _new_state()
  local perspective = _perspective(1, 1)
  replay.plan_refresh(state, perspective, { true, false, true, false, false })
  replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "c1" })
  _assert_eq(replay.plan_refresh(state, perspective, { true, true, true, false, false }),
    "reset", "冻结期间集合变化只清除旧高亮(#595)")
  replay.apply_lifecycle(state, perspective, { kind = "slot_command", choice_id = "c1" })
  _assert_eq(replay.plan_refresh(state, perspective, { true, true, true, false, false }),
    "none", "槽位命令解除冻结但不强制重放")
  _assert_eq(replay.plan_refresh(state, perspective, { true, false, false, false, false }),
    "replay", "解冻后集合再变化恢复重放")
end

-- 冻结只作用于发起确认的视角。
function TestItemSlotHighlightReplay:test_freeze_is_scoped_to_the_confirming_perspective()
  local state = _new_state()
  local confirming, other = _perspective(1, 1), _perspective(2, 1)
  replay.plan_refresh(state, confirming, { true, false, true, false, false })
  replay.apply_lifecycle(state, confirming, { kind = "confirm_item_use", choice_id = "c1" })
  _assert_eq(replay.plan_refresh(state, other, { true, false, true, false, false }),
    "replay", "其它视角不受冻结影响")
end

-- 槽位命令无条件解冻,不按 choice_id 匹配:玩家已经动过手,冻结不该再挂着。
-- kills "slot_command" -> nil(变异体退化成只按 choice_id 匹配解冻)。
function TestItemSlotHighlightReplay:test_slot_command_unfreezes_regardless_of_choice_id()
  local state = _new_state()
  local perspective = _perspective(1, 1)
  replay.plan_refresh(state, perspective, { true, false, true, false, false })
  replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "c1" })
  replay.apply_lifecycle(state, perspective, { kind = "slot_command", choice_id = "c2" })
  _assert_eq(replay.plan_refresh(state, perspective, { true, false, false, false, false }),
    "replay", "槽位命令即使 choice_id 不匹配也解冻")
end

-- 释放选择只解除匹配该选择的冻结。
function TestItemSlotHighlightReplay:test_choice_release_only_clears_matching_freeze()
  local state = _new_state()
  local perspective = _perspective(1, 1)
  replay.plan_refresh(state, perspective, { true, false, true, false, false })
  replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "c1" })
  replay.apply_lifecycle(state, perspective, { kind = "choice_released", choice_id = "c2" })
  -- 仍处冻结:集合变了只清除(#595),而不是整组重播——重播才意味着解冻。
  _assert_eq(replay.plan_refresh(state, perspective, { true, true, true, false, false }),
    "reset", "不匹配的释放不解冻")
  replay.apply_lifecycle(state, perspective, { kind = "choice_released", choice_id = "c1" })
  _assert_eq(replay.plan_refresh(state, perspective, { true, false, false, false, false }),
    "replay", "匹配的释放解冻")
end

-- 公开操作的入参断言(#594 场景 010)。
function TestItemSlotHighlightReplay:test_public_operations_assert_invalid_input()
  local state, perspective = _new_state(), _perspective(1, 1)
  local lifecycle = { kind = "slot_command", choice_id = "c1" }
  local cases = {
    { label = "apply_lifecycle 缺失展示状态",
      call = function() replay.apply_lifecycle(nil, perspective, lifecycle) end },
    { label = "apply_lifecycle 缺失展示视角",
      call = function() replay.apply_lifecycle(state, nil, lifecycle) end },
    { label = "apply_lifecycle 未知生命周期事件种类",
      call = function() replay.apply_lifecycle(state, perspective, { kind = "不存在的事件" }) end },
    { label = "plan_refresh 缺失展示状态",
      call = function() replay.plan_refresh(nil, perspective, { true }) end },
    { label = "plan_refresh 缺失展示视角",
      call = function() replay.plan_refresh(state, nil, { true }) end },
    { label = "plan_refresh 非布尔槽位数组",
      call = function() replay.plan_refresh(state, perspective, { "可" }) end },
  }
  for _, case in ipairs(cases) do
    _assert_eq(pcall(case.call), false, case.label .. " 应断言失败")
  end
end

-- ===== 性质覆盖(#594):例子测试逐个钉三态,这里钉住例子跨不过的不变量 =====
do
  local lu = require("luaunit")
  local property = require("test.support.property")

  local _PLANS = { replay = true, reset = true, none = true }
  -- Lua 数组存不了 nil 空洞,用一个独立站位对象表示「无槽位快照」这一侧。
  local nil_marker = {}
  local _SLOT_COUNT = 5

  -- 测试侧独立算一遍签名(可选槽位编号升序),不复用被测模块的内部实现。
  local function _signature_of(slots)
    local parts = {}
    for index, can_pick in ipairs(slots) do
      if can_pick then
        parts[#parts + 1] = tostring(index)
      end
    end
    return table.concat(parts, ",")
  end

  -- 随机可选槽位快照 + 随机视角。视角 id 故意从小集合抽,让不同用例之间
  -- 复用同一记忆桶,序列里才会出现真实的「同视角连续刷新」。
  local function _gen_case(rng)
    local slots = {}
    for index = 1, _SLOT_COUNT do
      slots[index] = rng:bool()
    end
    return {
      slots = slots,
      perspective = _perspective(rng:int(1, 3), rng:int(1, 3)),
      choice_id = "c" .. tostring(rng:int(1, 3)),
    }
  end

  -- plan_refresh 只返回三态之一,永不返回别的东西(全域性)。
  function TestItemSlotHighlightReplay:test_plan_refresh_only_ever_returns_a_known_plan()
    property.for_all(_gen_case, function(case)
      local plan = replay.plan_refresh(_new_state(), case.perspective, case.slots)
      lu.assertEvalToTrue(_PLANS[plan] == true,
        "plan_refresh 必须返回三态之一, 实际: " .. tostring(plan))
    end)
  end

  -- 幂等:同一快照连刷第二次一定 none, 且记忆不变。
  function TestItemSlotHighlightReplay:test_repeating_the_same_snapshot_is_idempotent()
    property.for_all(_gen_case, function(case)
      local state = _new_state()
      replay.plan_refresh(state, case.perspective, case.slots)
      local remembered = replay.remembered_signature(state, case.perspective)
      for _ = 1, 3 do
        lu.assertEvalToTrue(
          replay.plan_refresh(state, case.perspective, case.slots) == "none",
          "重复同一快照不应再产生计划")
        lu.assertEvalToTrue(
          replay.remembered_signature(state, case.perspective) == remembered,
          "重复同一快照不应改变记忆")
      end
    end)
  end

  -- 记忆锚定「可选槽位编号集合」:任意快照的记忆签名必须正是那些编号,
  -- 与未选中的槽位无关。
  function TestItemSlotHighlightReplay:test_remembered_signature_lists_exactly_the_pickable_slots()
    property.for_all(_gen_case, function(case)
      local state = _new_state()
      replay.plan_refresh(state, case.perspective, case.slots)
      lu.assertEvalToTrue(
        replay.remembered_signature(state, case.perspective) == _signature_of(case.slots),
        "记忆签名必须恰好是可选槽位编号升序")
    end)
  end

  -- 冻结不变量(#595 收窄):确认后永不整组重播,但集合真的变了要清除旧高亮;
  -- 记忆照记 —— 解冻后不补陈旧重放,而是以最新集合为基准继续判定。
  function TestItemSlotHighlightReplay:test_confirmation_freeze_suppresses_every_plan_but_keeps_remembering()
    property.for_all(_gen_case, function(case, rng)
      local state = _new_state()
      replay.plan_refresh(state, case.perspective, case.slots)
      replay.apply_lifecycle(state, case.perspective,
        { kind = "confirm_item_use", choice_id = case.choice_id })
      local latest = replay.remembered_signature(state, case.perspective)
      for _ = 1, 3 do
        local next_case = _gen_case(rng)
        lu.assertEvalToTrue(
          replay.plan_refresh(state, case.perspective, next_case.slots) ~= "replay",
          "冻结期间不得整组重播")
        latest = replay.remembered_signature(state, case.perspective)
      end
      replay.apply_lifecycle(state, case.perspective,
        { kind = "slot_command", choice_id = case.choice_id })
      lu.assertEvalToTrue(
        replay.remembered_signature(state, case.perspective) == latest,
        "解冻不得丢弃冻结期间记下的集合")
      -- 解冻后判定以「冻结期间记下的最新集合」为基准:与之相同则不动,
      -- 不同则整组重播(记忆已非空, 故不会是 reset)。
      local signature_now = _signature_of(case.slots)
      local expected = (latest == signature_now) and "none" or "replay"
      lu.assertEvalToTrue(
        replay.plan_refresh(state, case.perspective, case.slots) == expected,
        "解冻后必须以冻结期间记下的最新集合为基准判定, 期望: " .. expected)
    end)
  end

  -- 冻结替换的时序性质(#595 场景 014/017):任意 confirm / choice_released
  -- 交错序列后,「是否仍冻结」只由最后一次 confirm 的 choice_id 是否在其之后
  -- 被释放决定。例子测试只钉了三种手挑组合,这里让随机序列跨遍时序。
  -- 独立跑一遍这条规则(不复用被测模块),再拿计划三态反推冻结状态。
  local function _frozen_after(events)
    local frozen = nil
    for _, event in ipairs(events) do
      if event.kind == "confirm_item_use" then
        frozen = event.choice_id
      elseif event.kind == "slot_command" then
        frozen = nil
      elseif frozen ~= nil and tostring(frozen) == tostring(event.choice_id) then
        frozen = nil
      end
    end
    return frozen ~= nil
  end

  function TestItemSlotHighlightReplay:test_freeze_state_follows_the_last_unreleased_confirmation()
    property.for_all(function(rng)
      local ids = { "C1", "C2", "C3" }
      local events = {}
      for _ = 1, rng:int(1, 6) do
        local kind = rng:pick({ "confirm_item_use", "choice_released", "slot_command" })
        events[#events + 1] = { kind = kind, choice_id = rng:pick(ids) }
      end
      return { events = events, perspective = _perspective(rng:int(1, 3), rng:int(1, 3)) }
    end, function(case)
      local state = _new_state()
      -- 先建立一个非空记忆,这样后续集合变化的计划才能区分 reset 与 replay。
      replay.plan_refresh(state, case.perspective, { true, false, false, false, false })
      for _, event in ipairs(case.events) do
        replay.apply_lifecycle(state, case.perspective, event)
      end
      -- 冻结中集合变化 → reset;未冻结 → replay。计划即冻结状态的可观察投影。
      local expected = _frozen_after(case.events) and "reset" or "replay"
      lu.assertEvalToTrue(
        replay.plan_refresh(state, case.perspective, { true, true, false, false, false }) == expected,
        "冻结状态必须只跟随最后一次未被释放的确认, 期望计划: " .. expected)
    end)
  end

  -- phase-advance 全局去重线的性质(#596):连续观察序列里,「是否发重置」
  -- 恰好等价于「本次快照与上一次观察到的不同」。例子测试钉了几条手挑序列,
  -- 这里让随机序列(含 nil 快照与空集合交错)跨遍相邻组合。
  function TestItemSlotHighlightReplay:test_phase_advance_reset_fires_exactly_on_change()
    property.for_all(function(rng)
      local observations = {}
      for _ = 1, rng:int(1, 8) do
        if rng:int(1, 4) == 1 then
          observations[#observations + 1] = nil_marker
        else
          local slots = {}
          for index = 1, 3 do
            slots[index] = rng:bool()
          end
          observations[#observations + 1] = slots
        end
      end
      return observations
    end, function(observations)
      local state = _new_state()
      -- nil_marker 站位表示「无快照」,因为 Lua 数组里不能存 nil 空洞。
      local previous, seen_any = nil, false
      for _, observation in ipairs(observations) do
        local slots = (observation ~= nil_marker) and observation or nil
        local signature = (slots ~= nil) and _signature_of(slots) or nil
        local expected = (not seen_any) or previous ~= signature
        lu.assertEvalToTrue(
          replay.needs_phase_advance_reset(state, slots) == expected,
          "全局重置必须恰在快照与上一次观察不同时发出, 期望: " .. tostring(expected))
        previous, seen_any = signature, true
      end
    end)
  end

  -- 视角隔离:在一个视角上刷新, 绝不建立或改动另一个视角的记忆。
  function TestItemSlotHighlightReplay:test_refreshing_one_perspective_never_touches_another()
    property.for_all(_gen_case, function(case, rng)
      local other = _perspective(case.perspective.role_id + 10,
        case.perspective.display_player_id + 10)
      local state = _new_state()
      replay.plan_refresh(state, other, _gen_case(rng).slots)
      local other_before = replay.remembered_signature(state, other)
      replay.plan_refresh(state, case.perspective, case.slots)
      replay.apply_lifecycle(state, case.perspective,
        { kind = "confirm_item_use", choice_id = case.choice_id })
      lu.assertEvalToTrue(replay.remembered_signature(state, other) == other_before,
        "刷新与冻结都不得越过视角边界")
    end)
  end
end

-- #595-012:冻结期间集合变化不再是「什么都不做」,而是只清除旧高亮并记住
-- 新集合——旧高亮框指向的槽位已经变了,留在屏上就是错的视觉。
function TestItemSlotHighlightReplay:test_frozen_set_change_clears_and_remembers()
  local state = _new_state()
  local perspective = _perspective(1, 1)
  replay.plan_refresh(state, perspective, { true, false, true, false, false })
  replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "C1" })
  _assert_eq(replay.plan_refresh(state, perspective, { true, true, true, false, false }),
    "reset", "冻结期间集合变化只清除旧高亮")
  _assert_eq(replay.remembered_signature(state, perspective), "1,2,3",
    "冻结期间仍记忆新集合")
end

-- 冻结期间集合没变则什么都不做(不该反复清除)。
function TestItemSlotHighlightReplay:test_frozen_unchanged_set_does_nothing()
  local state = _new_state()
  local perspective = _perspective(1, 1)
  replay.plan_refresh(state, perspective, { true, false, true, false, false })
  replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "C1" })
  _assert_eq(replay.plan_refresh(state, perspective, { true, false, true, false, false }),
    "none", "冻结期间集合未变化不清除")
end

-- #595-014/017:确认幂等;新选择替换旧冻结后,迟到的旧选择关闭不解除新冻结。
function TestItemSlotHighlightReplay:test_confirm_replaces_freeze_and_late_close_is_ignored()
  local cases = {
    { second = "C1", closed = "C1", plan = "replay" },
    { second = "C2", closed = "C2", plan = "replay" },
    { second = "C2", closed = "C1", plan = "reset" },
  }
  for _, case in ipairs(cases) do
    local state = _new_state()
    local perspective = _perspective(1, 1)
    replay.plan_refresh(state, perspective, { true, false, true, false, false })
    replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "C1" })
    replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = case.second })
    replay.apply_lifecycle(state, perspective, { kind = "choice_released", choice_id = case.closed })
    _assert_eq(replay.plan_refresh(state, perspective, { true, true, true, false, false }),
      case.plan, "确认幂等与替换后的解冻结果")
  end
end

-- #595-016:槽位命令只解除该视角的冻结,别的视角仍冻结。
function TestItemSlotHighlightReplay:test_slot_command_unfreezes_only_its_perspective()
  local state = _new_state()
  local first, second = _perspective(1, 1), _perspective(2, 1)
  local snapshot = { true, false, true, false, false }
  replay.plan_refresh(state, first, snapshot)
  replay.plan_refresh(state, second, snapshot)
  replay.apply_lifecycle(state, first, { kind = "confirm_item_use", choice_id = "C1" })
  replay.apply_lifecycle(state, second, { kind = "confirm_item_use", choice_id = "C2" })
  replay.apply_lifecycle(state, first, { kind = "slot_command" })
  _assert_eq(replay.plan_refresh(state, second, { true, true, true, false, false }),
    "reset", "另一视角的冻结不被解除")
end

-- #595-013:解冻后集合未再变化不补发过时重放(冻结期间已记住新集合)。
function TestItemSlotHighlightReplay:test_unfreeze_does_not_replay_stale_set()
  for _, unfreeze in ipairs({
    { kind = "slot_command" },
    { kind = "choice_released", choice_id = "C1" },
  }) do
    local state = _new_state()
    local perspective = _perspective(1, 1)
    replay.plan_refresh(state, perspective, { true, false, true, false, false })
    replay.apply_lifecycle(state, perspective, { kind = "confirm_item_use", choice_id = "C1" })
    replay.plan_refresh(state, perspective, { true, true, true, false, false })
    replay.apply_lifecycle(state, perspective, unfreeze)
    _assert_eq(replay.plan_refresh(state, perspective, { true, true, true, false, false }),
      "none", "解冻后集合未变化不补发重放")
  end
end

-- #596:phase-advance 的「集合变了才发全局重置」判定并入本模块,取代 coord 侧
-- 那份平行的 _last_emitted_pickable_signature + "none" 字符串哨兵。
-- 无快照与空集合必须是不同状态:前者是「还不知道」,后者是「确实没有可选槽」。
function TestItemSlotHighlightReplay:test_phase_advance_reset_tracks_pickable_set()
  local state = _new_state()
  _assert_eq(replay.needs_phase_advance_reset(state, { true, false }), true,
    "首次观察到集合发全局重置")
  _assert_eq(replay.needs_phase_advance_reset(state, { true, false }), false,
    "集合未变化不重发")
  _assert_eq(replay.needs_phase_advance_reset(state, {}), true,
    "集合变空仍发清场重置")
  _assert_eq(replay.needs_phase_advance_reset(state, {}), false,
    "空集合之间自洽去重")
end

-- 无快照(nil)与空集合互不冒充,且 nil 之间也能自洽去重。
function TestItemSlotHighlightReplay:test_phase_advance_reset_distinguishes_absent_snapshot()
  local state = _new_state()
  _assert_eq(replay.needs_phase_advance_reset(state, nil), true,
    "首次无快照发一次重置")
  _assert_eq(replay.needs_phase_advance_reset(state, nil), false,
    "连续无快照不重发")
  _assert_eq(replay.needs_phase_advance_reset(state, {}), true,
    "空集合不同于无快照")
  _assert_eq(replay.needs_phase_advance_reset(state, nil), true,
    "回到无快照也是变化")
end

function TestItemSlotHighlightReplay:test_phase_advance_reset_asserts_missing_state()
  _assert_eq(pcall(function() replay.needs_phase_advance_reset(nil, { true }) end), false,
    "缺失展示状态应断言失败")
  _assert_eq(pcall(function()
    replay.needs_phase_advance_reset({}, { "可" })
  end), false, "非布尔槽位数组应断言失败")
end

return TestItemSlotHighlightReplay
