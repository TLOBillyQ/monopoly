-- endgame_life: consolidated life specs(ADR 0046 落码后:盲试链与 LifeComp 组件
-- 路径已删除,规则层经 runtime_ports 触达宿主适配;#610 取证后签名钉扎改为「不传
-- self」,保留返回值判据与签名钉扎)。
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local endgame = require("src.rules.endgame")

-- 签名钉扎:宿主调用一律不传 self(真机取证 #610,冒号调用被宿主拒收)。
-- 只接受 nil 首参的 die 是成功;要求把 role 当 self 收的 die 现在是失败。
local function _only_accepting(expected_first_arg)
  return function(first)
    if first ~= expected_first_arg then
      error("unsupported die signature", 0)
    end
    return true
  end
end

TestEndgameLife = {}

function TestEndgameLife:test_try_call_life_die_returns_false_for_nil_role()
  local result = endgame._try_call_life_die(nil)
  _assert_eq(result, false, "nil role returns false")
end

function TestEndgameLife:test_try_call_life_die_returns_true_when_role_die_succeeds()
  local role = {
    die = function() return true end,
  }
  local result = endgame._try_call_life_die(role)
  _assert_eq(result, true, "role.die success returns true")
end

-- 真值但不是 table 的 role(字符串/数字)会一路走到 role.die 探测:宿主适配在
-- 索引失败时留痕并判失败,不会把没死成的角色报成已死。
function TestEndgameLife:test_try_call_life_die_returns_false_for_a_truthy_non_table_role()
  _assert_eq(endgame._try_call_life_die("not a table"), false, "string role must not report death")
  _assert_eq(endgame._try_call_life_die(42), false, "number role must not report death")
end

-- 钉唯一签名:die 不带 self 调得通即成功;不再有降级臂可退。
function TestEndgameLife:test_try_call_life_die_uses_the_role_die_method_signature_first()
  local role = { id = 10, die = _only_accepting(nil) }

  local result = endgame._try_call_life_die(role)
  _assert_eq(result, true, "die called without self must be accepted")
end

function TestEndgameLife:test_try_call_life_die_returns_false_when_die_rejects_the_contract()
  local role = { id = 11 }
  role.die = _only_accepting(role)

  local result = endgame._try_call_life_die(role)
  _assert_eq(result, false, "a die that demands the role as self must report failure under the no-self contract")
end

function TestEndgameLife:test_resolve_bankruptcy_text_uses_reason_from_opts_when_present()
  local player = { name = "玩家A" }
  local text = endgame._resolve_bankruptcy_text(player, { reason = "自定义原因" })
  _assert_eq(text, "自定义原因", "custom reason used")
end

function TestEndgameLife:test_resolve_bankruptcy_text_falls_back_to_default_text()
  local player = { name = "玩家A" }
  local text = endgame._resolve_bankruptcy_text(player, {})
  _assert_eq(text, "玩家A 破产出局", "default text used")
end

function TestEndgameLife:test_resolve_bankruptcy_text_falls_back_when_opts_nil()
  local player = { name = "玩家B" }
  local text = endgame._resolve_bankruptcy_text(player, nil)
  _assert_eq(text, "玩家B 破产出局", "nil opts uses default")
end

function TestEndgameLife:test_resolve_bankruptcy_text_falls_back_when_reason_empty()
  local player = { name = "玩家C" }
  local text = endgame._resolve_bankruptcy_text(player, { reason = "" })
  _assert_eq(text, "玩家C 破产出局", "empty reason uses default")
end


return TestEndgameLife
