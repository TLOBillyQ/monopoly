-- 输入侧 → 刷新层的高亮生命周期队列直测(#595)。这个 seam 存在的理由是
-- 「输入侧知道发生了什么、但还不知道展示视角」,所以它只搬运种类与选择标识,
-- 顺序必须保留(冻结/解冻是时序语义),且事件只应被应用一次。
local support = require("test.support.shared_support")
local queue = require("src.ui.state.item_slot_highlight_lifecycle_queue")

local _assert_eq = support.assert_eq

TestItemSlotHighlightLifecycleQueue = {}

-- 没有任何登记时 drain 返回 nil,而不是空表:调用方据此跳过整段应用。
function TestItemSlotHighlightLifecycleQueue:test_draining_an_empty_queue_yields_nil()
  _assert_eq(queue.drain({}), nil, "空队列 drain 返回 nil")
end

function TestItemSlotHighlightLifecycleQueue:test_push_then_drain_returns_the_event()
  local state = {}
  queue.push(state, "confirm_item_use", "C1")
  local drained = queue.drain(state)
  _assert_eq(drained ~= nil and #drained, 1, "登记一次得到一个事件")
  _assert_eq(drained[1].kind, "confirm_item_use", "事件种类原样搬运")
  _assert_eq(drained[1].choice_id, "C1", "选择标识原样搬运")
end

-- 顺序即语义:确认后紧跟解冻,与解冻后紧跟确认的最终冻结状态相反。
function TestItemSlotHighlightLifecycleQueue:test_events_keep_registration_order()
  local state = {}
  queue.push(state, "confirm_item_use", "C1")
  queue.push(state, "slot_command", "C1")
  queue.push(state, "confirm_item_use", "C2")
  local drained = queue.drain(state)
  _assert_eq(#drained, 3, "三次登记得到三个事件")
  _assert_eq(drained[1].kind .. "," .. drained[2].kind .. "," .. drained[3].kind,
    "confirm_item_use,slot_command,confirm_item_use", "按登记顺序取出")
  _assert_eq(drained[3].choice_id, "C2", "后登记的事件带自己的选择标识")
end

-- 取走而非只读:留在状态里会在下一次刷新重复冻结/解冻。
function TestItemSlotHighlightLifecycleQueue:test_drain_consumes_the_queue()
  local state = {}
  queue.push(state, "slot_command", "C1")
  queue.drain(state)
  _assert_eq(queue.drain(state), nil, "drain 之后队列为空,事件不会被应用两次")
end

-- 缺失的选择标识是合法的:确认时可能还没有待决选择(choice 为 nil)。
function TestItemSlotHighlightLifecycleQueue:test_a_missing_choice_id_is_allowed()
  local state = {}
  queue.push(state, "confirm_item_use", nil)
  local drained = queue.drain(state)
  _assert_eq(drained ~= nil and #drained, 1, "缺失选择标识仍登记事件")
  _assert_eq(drained[1].choice_id, nil, "缺失的选择标识保持缺失")
end

function TestItemSlotHighlightLifecycleQueue:test_invalid_input_asserts()
  _assert_eq(pcall(function() queue.push(nil, "slot_command", "C1") end), false,
    "缺失展示状态应断言失败")
  _assert_eq(pcall(function() queue.push({}, nil, "C1") end), false,
    "缺失事件种类应断言失败")
  _assert_eq(pcall(function() queue.drain(nil) end), false,
    "drain 缺失展示状态应断言失败")
end

return TestItemSlotHighlightLifecycleQueue
