-- #293 批3 pin:src/ui/view/item_slice.lua 的幸存者分四簇:
-- ① resolve_slot_count(默认 5 / item_slots 覆写的比较与取数链);
-- ② build_item_slots_by_player(归一化 id 键、池化复用、尾部裁剪);
-- ③ build_delegated_by_player(读取玩家控制快照的托管位);
-- ④ resolve_item_choice_owner_id(pending 优先、choice 次之、当前玩家兜底)。

local lu = require("luaunit")
local item_slice = require("src.ui.view.item_slice")
local control = require("src.player.control")

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _player(id, items)
  return {
    id = id,
    inventory = { items = items or {} },
  }
end

local function _snapshot(players)
  local game = { players = players }
  require("src.turn.output.player_control_snapshot").install(game)
  return game.player_control_snapshots
end

TestItemSlice = {}

function TestItemSlice:test_resolve_slot_count_defaults_to_five()
  -- L7 `slot_count = 5` 换 nil 与 L9 `type(...) == "table"` 的 == -> ~=:
  -- 无 item_slots 时槽位数必须回退 5。
  _assert_eq(item_slice.resolve_slot_count(nil), 5, "nil runtime must default to five slots")
  _assert_eq(item_slice.resolve_slot_count({}), 5, "runtime without item_slots must default to five")
  _assert_eq(item_slice.resolve_slot_count({ item_slots = "not_a_table" }), 5,
    "non-table item_slots must default to five")
end

function TestItemSlice:test_resolve_slot_count_uses_item_slots_length()
  -- L10 `#ui_runtime.item_slots` 换 nil 与 L9 `> 0` 的 > -> >=:item_slots
  -- 非空时槽位数必须取其长度;空表必须回退 5。
  _assert_eq(item_slice.resolve_slot_count({ item_slots = { "a", "b", "c" } }), 3,
    "slot count must follow item_slots length")
  _assert_eq(item_slice.resolve_slot_count({ item_slots = {} }), 5,
    "empty item_slots must default to five")
end

function TestItemSlice:test_resolve_slot_count_honors_single_slot_runtime()
  -- L8 `#ui_runtime.item_slots > 0` 的 0 -> 1(变异体把单槽误判为空):
  -- 单槽运行时槽位数必须为 1。
  _assert_eq(item_slice.resolve_slot_count({ item_slots = { "only" } }), 1,
    "single slot runtime must report one")
end

function TestItemSlice:test_build_item_slots_for_player_clears_tail_when_slot_count_shrinks()
  -- #526:池表复用时 slot_count 缩小,slot_count 之外的尾部残槽必须清掉——
  -- 同进程内先大后小两连填,不依赖任何前序用例。
  item_slice.build_item_slots_for_player(_player("1", {
    { id = "a" }, { id = "b" }, { id = "c" },
  }), 3)
  local slots = item_slice.build_item_slots_for_player(_player("1", {
    { id = "a" },
  }), 1)
  _assert_eq(slots[1], "a", "slot 1 maps bag index 1")
  _assert_eq(slots[2], nil, "stale slot 2 from the wider fill must be cleared")
  _assert_eq(slots[3], nil, "stale slot 3 from the wider fill must be cleared")
end

function TestItemSlice:test_build_item_slots_for_player_maps_bag_index_to_slot_directly()
  -- CONTEXT「道具槽位」 稳定槽位:槽位 i 直映射背包第 i 格,不做密排压缩——
  -- 无 id 的条目所在槽位置空,后面的卡不补位;超出槽位数的部分裁掉。
  local slots = item_slice.build_item_slots_for_player(_player("1", {
    { id = "i1" }, {}, { id = "i2" },
  }), 2)
  _assert_eq(slots[1], "i1", "slot 1 maps bag index 1")
  _assert_eq(slots[2], nil, "a bag entry without id leaves slot 2 empty (no compaction)")
  _assert_eq(slots[3], nil, "slots beyond the limit must be trimmed")
end

function TestItemSlice:test_build_item_slots_preserves_positions_across_holes()
  -- 空洞(false 占位)保位:洞显示为空槽,洞后卡不左移。
  local slots = item_slice.build_item_slots_for_player(_player("1", {
    { id = "a" }, false, { id = "c" },
  }), 5)
  _assert_eq(slots[1], "a", "slot 1 keeps the first card")
  _assert_eq(slots[2], nil, "a false hole renders as an empty slot")
  _assert_eq(slots[3], "c", "the card after a hole keeps slot 3")
  _assert_eq(slots[4], nil, "tail slots stay empty")
  _assert_eq(slots[5], nil, "tail slots stay empty")
end

function TestItemSlice:test_build_item_slots_for_player_uses_shared_empty_for_missing_inventory()
  -- L29 `_player_items` 的 and/or 变异(背包缺失时落到空表):无背包/非表
  -- items 时必须返回空槽,不得撞 nil。
  local slots = item_slice.build_item_slots_for_player({ id = "1" }, 3)
  _assert_eq(slots[1], nil, "player without inventory must yield empty slots")
  local slots2 = item_slice.build_item_slots_for_player({ id = "1", inventory = { items = "nope" } }, 3)
  _assert_eq(slots2[1], nil, "non-table items must yield empty slots")
end

function TestItemSlice:test_build_item_slots_by_player_normalizes_ids_and_pools_tables()
  -- L82 `role_id_utils.write` 调用换 nil 与 L75 `_pooled_slots` 的 id 键:
  -- 槽表按归一化 id 落键,同一 player 复用同一张表,无效 id 跳过。
  local first = item_slice.build_item_slots_by_player({
    _player("1", { { id = "a1" } }),
    _player(2, { { id = "b1" } }),
    _player(nil, { { id = "c1" } }),
  }, 4)
  _assert_eq(first[1][1], "a1", "string id one must be written under its normalized key")
  _assert_eq(first[2][1], "b1", "numeric id two must be written under its normalized key")
  _assert_eq(first["nil"], nil, "player without id must be skipped")
  local second = item_slice.build_item_slots_by_player({ _player("1", { { id = "a2" } }) }, 4)
  _assert_eq(second[1], first[1], "the same player must reuse the pooled slot table")
  _assert_eq(second[1][1], "a2", "the pooled table must be refilled")
end

function TestItemSlice:test_build_delegated_by_player_reads_the_player_control_snapshot()
  local delegated = _player("1", {})
  local direct = _player(2, {})
  local missing = _player("3", {})
  control.initialize(delegated)
  control.toggle_manual_delegation(delegated)
  control.initialize(direct)
  control.initialize(missing)

  local result = item_slice.build_delegated_by_player(_snapshot({ delegated, direct, missing }))
  _assert_eq(result[1], true, "delegated player must be true")
  _assert_eq(result[2], false, "direct player must be false")
  _assert_eq(result[3], false, "missing delegation flag must be false")
end

function TestItemSlice:test_resolve_item_choice_owner_falls_back_to_current_player()
  -- L109 `return owner_role_id` 的 normalize 链与 L104 `~= nil` 的 == -> ~=:
  -- 无 pending/choice 归属时兜底当前玩家(归一化)。
  local owner = item_slice.resolve_item_choice_owner_id({}, { type = "pick" }, "3")
  _assert_eq(owner, 3, "string current player id must normalize")
end

function TestItemSlice:test_resolve_item_choice_owner_prefers_pending_choice()
  -- L105 `_pending_choice(game)` 调用换 nil(变异体掉到 choice 归属)与
  -- L104 `~= nil` 的 == -> ~=:待决 choice 的归属必须优先。
  local game = { turn = { pending_choice = { owner_role_id = "9" } } }
  local owner = item_slice.resolve_item_choice_owner_id(game, { type = "pick", owner_role_id = "7" }, "3")
  _assert_eq(owner, 9, "pending choice owner must win")
end

function TestItemSlice:test_resolve_item_choice_owner_uses_choice_owner()
  -- L107 `choice_owner_role_id ~= nil` 的 == -> ~= 与 L108 赋值换 nil:
  -- 无 pending 时 choice 的归属必须覆盖当前玩家。
  local owner = item_slice.resolve_item_choice_owner_id({}, { type = "pick", owner_role_id = "7" }, "3")
  _assert_eq(owner, 7, "choice owner must override the current player")
end

return TestItemSlice
