-- 道具槽 route 的职责边界：只报事实（谁点了第几个槽），不做任何阶段判断、
-- 不读 choice、不读槽位镜像、不发提示。裁定与反馈全在 turn 层。
-- 这条边界正是老设计的病根所在——UI 猜一次阶段、turn 再猜一次，口径不一致
-- 就掉进「两边都不提示」的夹缝，所以这里逐条钉死「UI 什么都不猜」。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local route_item_slots = require("src.ui.input.route_item_slots")
local tips = require("src.foundation.tips")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

local function _role(role_id)
  return { get_roleid = function() return role_id end }
end

local function _state(overrides)
  local ui = {
    item_slots = { "基础_道具1", "基础_道具2" },
  }
  for key, value in pairs(overrides or {}) do
    ui[key] = value
  end
  return { ui = ui }
end

local function _spec_named(state, node_name)
  for _, spec in ipairs(route_item_slots.build(state)) do
    if spec.name == node_name then
      return spec
    end
  end
  return nil
end

TestRouteItemSlots = {}

do
  TestRouteItemSlots["test_无遮挡时恒产 item_slot_click,不看局面"] = function(self)
    local intent = _spec_named(_state(), "基础_道具2").build_intent({ role = _role(3) })
    _assert_eq(intent and intent.type, "item_slot_click", "intent type")
    _assert_eq(intent and intent.slot_index, 2, "slot index follows node order")
    _assert_eq(intent and intent.actor_role_id, 3, "actor is the clicker")
  end

  TestRouteItemSlots["test_他人回合、对手开着道具窗,照样产 intent 交给 turn 裁定"] = function(self)
    local state = _state()
    state.game = {
      turn = {
        current_player_index = 1,
        pending_choice = {
          id = "c1", kind = "item_phase_passive", uses_item_slots = true,
          owner_role_id = 1, options = { { id = "item_b" } }, meta = { phase = "pre_action" },
        },
      },
      players = { { id = 1 }, { id = 2 } },
    }
    local intent = _spec_named(state, "基础_道具1").build_intent({ role = _role(2) })
    _assert_eq(intent and intent.type, "item_slot_click",
      "UI must not swallow off-turn clicks — the verdict belongs to turn")
    _assert_eq(intent and intent.actor_role_id, 2, "actor is the clicker, not the turn player")
  end

  TestRouteItemSlots["test_弹层遮挡时静默:不产 intent 也不发提示"] = function(self)
    local captured = {}
    tips.clear()
    tips.configure_runtime({
      presenter = function(text) captured[#captured + 1] = text end,
      scheduler = function() return true end,
      test_mode = false,
    })
    local intent = _spec_named(_state({ popup_active = true }), "基础_道具1").build_intent({ role = _role(1) })
    tips.clear()
    -- 清了共享 tips 基线必须装回,否则 mutate 车道窄 suite 子集撞空 presenter(#217)
    support.restore_runtime_services()
    _assert_eq(intent, nil, "occluded click must not dispatch")
    _assert_eq(#captured, 0, "route must not raise tips of its own")
  end

  TestRouteItemSlots["test_route 不再产 ui_button:道具槽已不是回合绑定按钮"] = function(self)
    local intent = _spec_named(_state(), "基础_道具1").build_intent({ role = _role(1) })
    lu.assertEvalToTrue(intent.type ~= "ui_button", "item slot clicks must not ride the ui_button lane")
    _assert_eq(intent.id, nil, "item_slot_click carries slot_index, not a button id")
  end

  -- #341/#601:事件无身份时 intent 不得落到任何既有身份头上(不误投他人,
  -- 也不误放裁定——nil actor 由 turn 层按空槽位口径静默)。「上一次点击者
  -- 缓存」已退役,state 上的同名旧字段即使残留也不得被读。
  TestRouteItemSlots["test_匿名点击不带身份"] = function(self)
    local state = _state()
    state.local_actor_role_id = 2 -- 退役缓存的残留字段,不得参与解析
    local intent = _spec_named(state, "基础_道具1").build_intent({})
    _assert_eq(intent and intent.type, "item_slot_click", "anonymous click still yields a slot intent")
    _assert_eq(intent and intent.actor_role_id, nil,
      "anonymous click must carry no actor; cached clicker must not be reused (#341)")
  end
end


return TestRouteItemSlots
