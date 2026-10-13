local luassert = assert
local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local support = require("test.support.shared_support")
local player_control_snapshot = require("src.turn.output.player_control_snapshot")

-- item_phase_passive is an inline choice (no choice modal opened). The gate state
-- must treat it as open=true so that should_warn and should_reconcile stay false
-- even when the local player is the active owner and the phase is not blocked.
-- multiplayer_seat_gate 独立 suite 的 after_each 重置 runtime_ports。

local function _make_game()
  local game = {
    turn = { phase = "item_phase", current_player_index = 1 },
    players = { { id = 1, is_ai = false } },
  }
  player_control_snapshot.install(game)
  return game
end

local function _make_role(role_id)
  return { get_roleid = function() return role_id end }
end

-- 本地角色经 client_role 表达(#341);「上一次点击者缓存」已随 #601 整体退役。
local function _make_state()
  return { ui = {} }
end

-- client_role 表达「这块屏幕是谁」,seat_ids 是本进程服务的房间席位名册。
-- 两者分开传:#444 后门控只问名册,client_role 不参与判定,故二者可以不一致
-- (正是 test_served_owner_true_when_client_role_differs_but_owner_seated 要钉的形状)。
-- seat_ids 省略时默认单人房(只坐 client_role 自己)。
-- 用单字段 patch 而非 runtime_ports.configure:后者是整表替换
-- (runtime_ports.lua:25),会连带清空 rng_next_int / schedule 等同表端口。
local function _with_client_and_seats(role_id, fn, seat_ids)
  local seats = {}
  for _, seat_id in ipairs(seat_ids or { role_id }) do
    seats[#seats + 1] = _make_role(seat_id)
  end
  return support.with_patches({
    {
      target = runtime_ui,
      key = "get_client_role",
      value = function()
        return _make_role(role_id)
      end,
    },
    {
      target = runtime_ports,
      key = "resolve_roles",
      value = function()
        return seats
      end,
    },
  }, fn)
end

local function _make_choice()
  return { kind = "item_phase_passive", route_key = "item_phase_passive", owner_role_id = 1 }
end

describe("TestUiChoiceState", function()

-- 本组全部用例经 _with_client_and_seats → with_patches 铺环境,
-- with_patches 出入两侧都刷回共享端口基线,不留泄漏。

  it("test_item_phase_passive_gate_should_warn_false", function()
  _with_client_and_seats(1, function()
    local gate = choice_ui_state.resolve_gate_state(_make_game(), _make_state(), _make_choice())
    luassert.is.equal(true, gate.served_owner, "test precondition: served_owner must be true to exercise the warn path")
    luassert.is.equal(true, gate.expects_ui, "test precondition: expects_ui must be true so open drives should_warn")
    luassert.is.equal(false, gate.should_warn, "item_phase_passive inline choice must not trigger a pending-UI warn")
  end)
  end)

  it("test_item_phase_passive_should_reconcile_false", function()
  _with_client_and_seats(1, function()
    local result = choice_ui_state.should_reconcile(_make_game(), _make_state(), _make_choice())
    luassert.is.equal(false, result, "item_phase_passive inline choice must not trigger modal reconcile")
  end)
  end)
end)

local function _make_multi_game()
  local game = {
    turn = { phase = "wait_choice", current_player_index = 1 },
    players = {
      { id = 1, is_ai = false },
      { id = 2, is_ai = false },
      { id = 3, is_ai = false },
      { id = 4, is_ai = false },
    },
  }
  player_control_snapshot.install(game)
  return game
end

local function _make_target_choice()
  return { kind = "item_target_tile", route_key = "target", owner_role_id = 1 }
end

describe("TestUiChoiceStateMultiplayerSeatGate", function()
  after_each(function()
    runtime_ports.reset_for_tests()
    -- 上面的 reset 把共享端口基线拆到未配置态,必须装回(#217)。
    support.restore_runtime_services()
  end)

-- 四槽多真人:owner 是房间席位之一时必须开面板。蛋仔运行时是一个进程服务整个
-- 房间(resolve_roles 取 GameAPI.get_all_valid_roles,host_push 在 client_role
-- 为 nil 时向 allroles 广播),不存在「另一个客户端」;可见性由下游逐席位的
-- switch_modal_canvas 决定,操作授权由 validator_actor 独立校验。
-- 真机实证:4 真人时面板永不弹、仅靠 15s action_timeout 推进回合;1 真人 + 3 AI 正常。
  it("test_roster_seat_owner_expects_ui_when_multiple_roles", function()
  runtime_ports.configure({
    resolve_roles = function()
      return { _make_role(1), _make_role(2), _make_role(3), _make_role(4) }
    end,
  })
  local state = { ui = {} }
  local gate = choice_ui_state.resolve_gate_state(
    _make_multi_game(), state, _make_target_choice()
  )
  luassert.is.equal(true, gate.served_owner,
    "owner seated in the room roster must be served by this process")
  luassert.is.equal(true, gate.expects_ui,
    "a roster seat's choice must open the panel; per-seat visibility is decided downstream")
  end)

-- owner 不在房间席位里时仍必须拒绝——保住原用例真正守的 invariant:
-- current_player_id 是展示态,不得单独授权 choice UI。
  it("test_current_player_id_alone_does_not_make_multiplayer_choice_served", function()
  runtime_ports.configure({
    resolve_roles = function()
      return { _make_role(2), _make_role(3), _make_role(4) }
    end,
  })
  local state = { ui = {}, ui_runtime = { ui_model = { current_player_id = 1 } } }
  local gate = choice_ui_state.resolve_gate_state(
    _make_multi_game(), state, _make_target_choice()
  )
  luassert.is.equal(false, gate.served_owner,
    "current_player_id is display state and must not authorize choice UI for an unseated owner")
  luassert.is.equal(false, gate.expects_ui,
    "an owner outside the room roster must not open choice UI")
  end)

  it("test_single_role_player_served_owner_true", function()
  runtime_ports.configure({
    resolve_roles = function()
      return { _make_role(1) }
    end,
  })
  local state = { ui = {} }
  local gate = choice_ui_state.resolve_gate_state(
    _make_multi_game(), state, _make_target_choice()
  )
  luassert.is.equal(true, gate.served_owner,
    "with single role matching owner, served_owner must be true")
  end)

-- 落地确认面板回归用例:精确复现真机条件——4 个真人席位、owner 为当前回合玩家、
-- 落地路由 secondary_confirm,且【不 patch get_client_role】。不打 patch 是本用例
-- 的全部意义:既有门控用例全都伪造了环境角色,制造出生产环境恰好缺失的条件,
-- 因此 6187 个用例全绿却漏掉了这个 bug。
  it("test_landing_secondary_confirm_opens_for_four_real_players", function()
  runtime_ports.configure({
    resolve_roles = function()
      return { _make_role(1), _make_role(2), _make_role(3), _make_role(4) }
    end,
  })
  local game = {
    turn = { phase = "wait_choice", current_player_index = 1 },
    players = {
      { id = 1, is_ai = false },
      { id = 2, is_ai = false },
      { id = 3, is_ai = false },
      { id = 4, is_ai = false },
    },
  }
  player_control_snapshot.install(game)
  local choice = {
    id = 1,
    kind = "secondary_confirm",
    route_key = "secondary_confirm",
    owner_role_id = 1,
  }
  local gate = choice_ui_state.resolve_gate_state(game, { ui = {} }, choice)

  luassert.is.equal(false, gate.owner_computer_controlled, "test precondition: four real players, owner must not be computer controlled")
  luassert.is.equal(false, gate.open, "test precondition: panel starts closed")
  luassert.is.equal(true, gate.served_owner,
    "four real players: landing owner is a room seat and must be served")
  luassert.is.equal(true, gate.expects_ui,
    "landing secondary_confirm must expect UI, otherwise the turn only advances by timeout")
  luassert.is.equal(true, choice_ui_state.should_reconcile(game, { ui = {} }, choice),
    "closed landing panel with an expected UI must reconcile so the modal opens")
  end)

-- 钉死房间席位判定语义:client_role 有值且不等于 owner 时,只要 owner 在房间
-- 席位内仍须为 true。这是原 resolve_local 第一级(已随 #446 拆除)的反例——
-- 若它还在,此用例必失败(client_role=2 != owner=1 → served_owner=false)。
  it("test_served_owner_true_when_client_role_differs_but_owner_seated", function()
  -- client_role = 2(这块屏幕是 2 号),owner = 1,四席全在册。
  _with_client_and_seats(2, function()
    local gate = choice_ui_state.resolve_gate_state(
      _make_multi_game(), { ui = {} }, _make_target_choice()
    )
    luassert.is.equal(true, gate.served_owner,
      "owner in room roster must be served even when client_role points to a different seat")
  end, { 1, 2, 3, 4 })
  end)
end)
