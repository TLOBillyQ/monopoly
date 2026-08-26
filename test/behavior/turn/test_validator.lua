local lu = require("luaunit")

do
local validator = require("src.turn.actions.validator")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game_with_player(role_id, current_index)
  current_index = current_index or 1
  return {
    turn = {
      current_player_index = current_index,
    },
    players = {
      [current_index] = { id = role_id },
    },
  }
end

-- choice 的 owner 回退链走 game:current_player()(方法),与 ui_button 走的
-- game.turn.current_player_index 是两条不同的解析路径。要钉住「declared owner
-- 优先于 current player」与「无 declared owner 时回退到 current player」,就必须
-- 造一个真有 current_player 方法的 game —— 若用 game = {},owner 恒解析为 nil,
-- 而 validator 在 owner == nil 时直接放行,于是断言会**空洞地转绿**(工单 #134)。
local function _game_with_current_player(role_id)
  return {
    current_player = function() return { id = role_id } end,
  }
end

local _config_reset = require("test.support.config_reset")

TestValidator = {}

function TestValidator:setUp()
  _config_reset.reset_all()
end

-- 表驱动：动作 + 上下文 → 放行与否 + 原因。ctx 为函数时惰性构建。
local cases = {
  -- 入参兜底
  {
    name = "nil action is refused with missing_action",
    action = nil,
    ctx = {},
    ok = false,
    reason = "missing_action",
  },
  {
    name = "unknown action types pass through unvalidated",
    action = { type = "roll_dice" },
    ctx = {},
    ok = true,
  },
  -- 输入闸门
  {
    name = "gate_state with input_blocked refuses choice_select",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = function()
      return { gate_state = { input_blocked = true }, choice = { id = 10, owner_role_id = 1001 } }
    end,
    ok = false,
    reason = "input_blocked",
  },
  {
    name = "gate_state without input_blocked lets a valid choice through",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = function()
      return { gate_state = { input_blocked = false }, choice = { id = 10, owner_role_id = 1001 } }
    end,
    ok = true,
  },
  -- ui_button 行动人校验
  {
    name = "ui_button non-turn-bound action always passes",
    action = { type = "ui_button", id = "buy", actor_role_id = 1002 },
    ctx = function() return { game = _make_game_with_player(1001) } end,
    ok = true,
  },
  {
    name = "ui_button next with matching actor passes",
    action = { type = "ui_button", id = "next", actor_role_id = 1001 },
    ctx = function() return { game = _make_game_with_player(1001) } end,
    ok = true,
  },
  {
    name = "ui_button next with nil actor_role_id is refused",
    action = { type = "ui_button", id = "next", actor_role_id = nil },
    ctx = function() return { game = _make_game_with_player(1001) } end,
    ok = false,
    reason = "actor_not_current",
  },
  {
    name = "ui_button next with missing current player is refused",
    action = { type = "ui_button", id = "next", actor_role_id = 1001 },
    ctx = { game = { turn = { current_player_index = 1 }, players = {} } },
    ok = false,
    reason = "actor_not_current",
  },
  {
    name = "ui_button next with wrong actor is refused",
    action = { type = "ui_button", id = "next", actor_role_id = 1002 },
    ctx = function() return { game = _make_game_with_player(1001) } end,
    ok = false,
    reason = "actor_not_current",
  },
  -- market 导航动作被 _CHOICE_BOUND_ACTION_TYPES 收进 choice 校验管道
  {
    name = "market_page_prev with matching owner passes",
    action = { type = "market_page_prev", actor_role_id = 1001, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = true,
  },
  {
    name = "market_page_prev with wrong actor is refused",
    action = { type = "market_page_prev", actor_role_id = 1002, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = false,
    reason = "choice_actor_mismatch",
  },
  {
    name = "market_page_next with matching owner passes",
    action = { type = "market_page_next", actor_role_id = 1001, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = true,
  },
  {
    name = "market_page_next with wrong actor is refused",
    action = { type = "market_page_next", actor_role_id = 1002, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = false,
    reason = "choice_actor_mismatch",
  },
  {
    name = "market_tab_select with matching owner passes",
    action = { type = "market_tab_select", actor_role_id = 1001, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = true,
  },
  {
    name = "market_tab_select with wrong actor is refused",
    action = { type = "market_tab_select", actor_role_id = 1002, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = false,
    reason = "choice_actor_mismatch",
  },
  -- choice 类动作校验
  {
    name = "choice action without pending choice is refused",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = {},
    ok = false,
    reason = "missing_choice",
  },
  {
    name = "choice action against a choice without id is refused",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = { choice = {} },
    ok = false,
    reason = "missing_choice",
  },
  {
    name = "choice action with nil actor_role_id is refused",
    action = { type = "choice_select", actor_role_id = nil, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy" } },
    ok = false,
    reason = "choice_actor_mismatch",
  },
  -- 下面两条 game = {} 的用例只钉「owner 解析不出时放行」这一条退路。
  -- 它们**不能**证明 owner 被正确读到 —— 无论 owner 解析对错,结果都是 true。
  -- 真正区分「读到了」与「没读到」的是紧随其后的两条 current_player 用例(#134)。
  {
    name = "choice action with nil owner accepts any actor",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy" } },
    ok = true,
  },
  {
    name = "choice action with matching owner passes",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = true,
  },
  -- 判别式用例 ①:choice 上声明的 owner 必须**优先于** current player。
  -- 若 owner 解析退化成「只看 current player」(例如被委托给一个依赖 game.turn
  -- 的实现),这里会拿 actor 1001 去比 current 1002 → 拒绝 → 本条变红。
  {
    name = "choice owner declared on the choice wins over the current player",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = {
      game = _game_with_current_player(1002),
      choice = { id = 10, kind = "market_buy", owner_role_id = 1001 },
    },
    ok = true,
  },
  -- 判别式用例 ②:choice 未声明 owner 时,必须回退到 current player 并据此拦人。
  -- 若 owner 解析在无声明时返回 nil(而非回退),validator 会直接放行 → 本条变红。
  -- 这两条合起来堵死「委托后 owner 恒为 nil → 校验被静默跳过」那条退路。
  {
    name = "choice without a declared owner falls back to the current player and refuses others",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = {
      game = _game_with_current_player(1002),
      choice = { id = 10, kind = "market_buy" },
    },
    ok = false,
    reason = "choice_actor_mismatch",
  },
  {
    name = "choice action with wrong owner is refused",
    action = { type = "choice_cancel", actor_role_id = 1002, choice_id = 10 },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy", owner_role_id = 1001 } },
    ok = false,
    reason = "choice_actor_mismatch",
  },
  {
    name = "choice action with mismatched choice_id is refused",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = 10 },
    ctx = { game = {}, choice = { id = 99, kind = "market_buy" } },
    ok = false,
    reason = "choice_id_mismatch",
  },
  {
    name = "choice action with nil action.choice_id is refused",
    action = { type = "choice_select", actor_role_id = 1001, choice_id = nil },
    ctx = { game = {}, choice = { id = 10, kind = "market_buy" } },
    ok = false,
    reason = "choice_id_mismatch",
  },
}

for _, case in ipairs(cases) do
  TestValidator["test_" .. case.name] = function(self)
    local ctx = type(case.ctx) == "function" and case.ctx() or case.ctx
    local ok, reason = validator.validate(case.action, ctx)
    _assert_eq(ok, case.ok, case.name .. " (ok)")
    _assert_eq(reason, case.reason, case.name .. " (reason)")
  end
end

-- 与 TestValidator 同处一个 do 块:共享 _assert_eq / _make_game_with_player 等辅助。
TestValidatorNamedSurface = {}

function TestValidatorNamedSurface:setUp()
  _config_reset.reset_all()
end

function TestValidatorNamedSurface:test_validate_choice_id_nil_action_returns_false()
  _assert_eq(validator.validate_choice_id(nil, { id = 10 }), false,
    "nil action should return false")
end

function TestValidatorNamedSurface:test_validate_choice_id_nil_choice_returns_false()
  _assert_eq(validator.validate_choice_id({ choice_id = 10 }, nil), false,
    "nil choice should return false")
end

function TestValidatorNamedSurface:test_validate_choice_id_matching_id_returns_true()
  _assert_eq(validator.validate_choice_id({ choice_id = 10 }, { id = 10 }), true,
    "matching choice_id should return true")
end

function TestValidatorNamedSurface:test_validate_choice_action_success()
  local choice = { id = 10, owner_role_id = 1001 }
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, choice), true,
    "valid actor and choice_id should return true")
end

function TestValidatorNamedSurface:test_validate_choice_action_nil_choice_returns_false()
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, nil), false,
    "nil choice should return false")
end

function TestValidatorNamedSurface:test_validate_choice_action_choice_without_id_returns_false()
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, {}), false,
    "choice without id should return false")
end

function TestValidatorNamedSurface:test_validate_choice_action_actor_mismatch_returns_false()
  local choice = { id = 10, owner_role_id = 1001 }
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1002, choice_id = 10 }, choice), false,
    "actor not matching choice owner should return false")
end

function TestValidatorNamedSurface:test_validate_actor_role_next_matching_actor_returns_true()
  local game = _make_game_with_player(1001)
  _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1001 }), true,
    "'next' with matching actor should return true")
end

function TestValidatorNamedSurface:test_resolve_gate_state_without_ports()
  local state = { game = { turn = { phase = "land" } } }
  local gate = validator.resolve_gate_state(state, nil)
  lu.assertEvalToTrue(type(gate) == "table", "should return gate table")
  _assert_eq(gate.phase, "land", "phase should be from game.turn")
  _assert_eq(gate.input_blocked, false, "input_blocked defaults to false")
  _assert_eq(gate.choice_active, false, "choice_active defaults to false")
  _assert_eq(gate.detained_wait_active, false, "detained_wait_active defaults to false")
end

function TestValidatorNamedSurface:test_resolve_gate_state_with_ports()
  local state = {}
  local ui_sync_ports = {
    resolve_ui_gate = function(_)
      return { input_blocked = true, choice_active = true, market_active = false, popup_active = true }
    end,
  }
  local gate = validator.resolve_gate_state(state, ui_sync_ports)
  _assert_eq(gate.input_blocked, true, "input_blocked from ui_gate should be true")
  _assert_eq(gate.choice_active, true, "choice_active from ui_gate should be true")
  _assert_eq(gate.popup_active, true, "popup_active from ui_gate should be true")
end

function TestValidatorNamedSurface:test_should_block_action_blocked_when_input_blocked()
  local result = validator.should_block_action(true, "choice_select")
  _assert_eq(result, true, "true gate_state should block choice_select action")
end

function TestValidatorNamedSurface:test_should_block_action_passes_when_not_blocked()
  local result = validator.should_block_action(false, "choice_select")
  _assert_eq(result, false, "false gate_state should not block")
end
end

-- ===== merged from test_validator_extended.lua (#27) =====
do

local validator = require("src.turn.actions.validator")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local _config_reset = require("test.support.config_reset")

TestValidatorExtendedCoverage = {}

function TestValidatorExtendedCoverage:setUp()
  _config_reset.reset_all()
end

function TestValidatorExtendedCoverage:test_validate_choice_action_with_nil_action_returns_false_via_missing_actor()
  local choice = { id = 10, kind = "market_buy" }
  _assert_eq(
    validator.validate_choice_action({}, nil, choice),
    false, "nil action should fail validate_choice_actor (no actor)"
  )
end

function TestValidatorExtendedCoverage:test_validate_choice_actor_with_nil_action_returns_false()
  _assert_eq(
    validator.validate_choice_actor({}, nil, { id = 10 }),
    false, "nil action should return false"
  )
end

function TestValidatorExtendedCoverage:test_validate_choice_actor_uses_current_player_when_choice_has_no_owner_role_id()
  local game = {
    current_player = function() return { id = 1001 } end,
  }
  local choice = { id = 10, kind = "market_buy" }
  _assert_eq(
    validator.validate_choice_actor(game, { actor_role_id = 1001 }, choice),
    true, "actor matching current_player should pass when no owner_role_id"
  )
  _assert_eq(
    validator.validate_choice_actor(game, { actor_role_id = 1002 }, choice),
    false, "actor not matching current_player should fail"
  )
end

-- 道具槽点击已不是回合绑定 ui_button:它的行动者是「点击者」,不是当前回合玩家。
-- 若 validate_actor_role 又把 item_slot_X 当成回合绑定,他人回合的点击会在这里
-- 被静默拒掉、拿不到 item_slot_click 的拒因提示——本条就是那条回归的探针。
function TestValidatorExtendedCoverage:test_validate_actor_role_treats_item_slot_x_as_non_turn_bound_and_passes_any_role()
  local game = {
    turn = { current_player_index = 1 },
    players = { [1] = { id = 1001 } },
  }
  _assert_eq(
    validator.validate_actor_role(game, { id = "item_slot_3", actor_role_id = 9999 }),
    true, "item_slot_X must not be gated by the current-turn actor check"
  )
end

function TestValidatorExtendedCoverage:test_resolve_gate_state_derives_detained_wait_active_from_game_turn()
  local state = { game = { turn = { phase = "land", detained_wait_active = true } } }
  local gate = validator.resolve_gate_state(state, nil)
  _assert_eq(gate.detained_wait_active, true, "detained_wait_active should be exposed")
  _assert_eq(gate.phase, "land", "phase should be passed through")
end

function TestValidatorExtendedCoverage:test_resolve_gate_state_with_no_game_returns_empty_phase_gate()
  local gate = validator.resolve_gate_state({}, nil)
  _assert_eq(gate.phase, nil, "phase should be nil with no game")
  _assert_eq(gate.detained_wait_active, false, "detained_wait_active defaults to false")
end
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestValidator,
  TestValidatorNamedSurface,
  TestValidatorExtendedCoverage
)
