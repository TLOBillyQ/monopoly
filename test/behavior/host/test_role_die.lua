-- role_die 宿主适配 spec(ADR 0046 / #610 真机取证):宿主 CampRole 无 die,
-- die 在 role.get_ctrl_unit() 返回的单位上,签名单参无 self、无返回值,成功以
-- unit.is_die_status() 翻 true 判定,随后经 GameAPI.destroy_unit 移除棋子;
-- 合成 AI 适配器(自竖 is_synthetic_actor 标志、自带 die 返回布尔)走原有 truthy
-- 判据,分派认标志不认 die 存在性。失败必留痕。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local role_die = require("src.host.role_die")
local logger = require("src.foundation.log")

-- 在 with_patches 窗口内执行调用并捕获全部 warn 日志。
local function _call(role, game_api)
  local warns = {}
  local result
  local patches = {
    {
      target = logger,
      key = "warn",
      value = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
    },
  }
  if game_api ~= nil then
    patches[#patches + 1] = { key = "GameAPI", value = game_api }
  end
  support.with_patches(patches, function()
    result = role_die.call_role_die(role)
  end)
  return result, warns
end

-- 宿主真人 Role 替身:自身无 die,只经 get_ctrl_unit 暴露控制单位。
local function _host_role(unit)
  return {
    get_ctrl_unit = function()
      return unit
    end,
    lose = function()
      return true
    end,
  }
end

-- 宿主单位替身:die 无返回值,只翻 is_die_status;记录实参个数与首参。
local function _host_unit(opts)
  opts = opts or {}
  local unit = { dead = opts.dead == true, die_calls = 0 }
  unit.die = function(...)
    unit.die_calls = unit.die_calls + 1
    unit.die_arg_count = select("#", ...)
    unit.die_first_arg = select(1, ...)
    if opts.die_raises then
      error("host unit die failed")
    end
    if opts.stays_alive ~= true then
      unit.dead = true
    end
  end
  if opts.without_status ~= true then
    unit.is_die_status = function()
      return unit.dead
    end
  end
  return unit
end

local function _destroy_recorder()
  local seen = {}
  return seen, {
    destroy_unit = function(handle)
      seen[#seen + 1] = handle
    end,
  }
end

TestRoleDie = {}

-- ── 宿主真人 Role:经控制单位出局 ────────────────────────────────

function TestRoleDie:test_kills_ctrl_unit_when_role_has_no_die()
  local unit = _host_unit()
  local destroyed, game_api = _destroy_recorder()
  local result, warns = _call(_host_role(unit), game_api)
  lu.assertEvalToTrue(result == true, "a flipped is_die_status yields true")
  lu.assertEvalToTrue(#warns == 0, "the happy path must not warn; got " .. tostring(warns[1]))
  lu.assertEvalToTrue(unit.die_calls == 1, "unit.die must be called exactly once")
  lu.assertEvalToTrue(unit.die_arg_count ~= nil and unit.die_arg_count <= 1,
    "unit.die takes at most one dmg_unit argument; got " .. tostring(unit.die_arg_count))
  lu.assertEvalToTrue(unit.die_first_arg == nil, "unit.die must not receive self")
  lu.assertEvalToTrue(destroyed[1] == unit, "the ctrl unit must be removed from the board")
end

function TestRoleDie:test_returns_false_and_warns_when_die_status_stays_false()
  local unit = _host_unit({ stays_alive = true })
  local destroyed, game_api = _destroy_recorder()
  local result, warns = _call(_host_role(unit), game_api)
  lu.assertEvalToTrue(result == false, "an unflipped is_die_status must yield false")
  lu.assertEvalToTrue(#warns == 1, "an unflipped status must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("is_die_status", 1, true) ~= nil,
    "warn should name the status probe; got " .. tostring(warns[1]))
  lu.assertEvalToTrue(#destroyed == 0, "a failed kill must not remove the unit")
end

function TestRoleDie:test_treats_an_already_dead_unit_as_success()
  local unit = _host_unit({ dead = true })
  local destroyed, game_api = _destroy_recorder()
  local result = _call(_host_role(unit), game_api)
  lu.assertEvalToTrue(result == true, "die is idempotent: an already dead unit still yields true")
  lu.assertEvalToTrue(destroyed[1] == unit, "an already dead unit is still removed")
end

function TestRoleDie:test_returns_false_and_warns_when_die_raises()
  local unit = _host_unit({ die_raises = true })
  local result, warns = _call(_host_role(unit))
  lu.assertEvalToTrue(result == false, "a throwing unit.die must yield false")
  lu.assertEvalToTrue(#warns == 1, "a throwing unit.die must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("host unit die failed", 1, true) ~= nil,
    "warn should carry the raised detail; got " .. tostring(warns[1]))
end

function TestRoleDie:test_returns_false_and_warns_when_unit_lacks_die()
  local result, warns = _call(_host_role({ is_die_status = function() return false end }))
  lu.assertEvalToTrue(result == false, "a unit without die must yield false")
  lu.assertEvalToTrue(#warns == 1, "a unit without die must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("die", 1, true) ~= nil,
    "warn should name the missing method; got " .. tostring(warns[1]))
end

function TestRoleDie:test_returns_false_and_warns_when_unit_lacks_is_die_status()
  local result, warns = _call(_host_role(_host_unit({ without_status = true })))
  lu.assertEvalToTrue(result == false, "a unit without is_die_status must yield false")
  lu.assertEvalToTrue(#warns == 1, "a unit without is_die_status must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("is_die_status", 1, true) ~= nil,
    "warn should name the missing probe; got " .. tostring(warns[1]))
end

function TestRoleDie:test_returns_false_and_warns_when_role_has_no_ctrl_unit()
  local result, warns = _call({ get_ctrl_unit = function() return nil end })
  lu.assertEvalToTrue(result == false, "a role without a ctrl unit must yield false")
  lu.assertEvalToTrue(#warns == 1, "a missing ctrl unit must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("ctrl unit", 1, true) ~= nil,
    "warn should name the missing ctrl unit; got " .. tostring(warns[1]))
end

function TestRoleDie:test_returns_false_and_warns_when_get_ctrl_unit_raises()
  local result, warns = _call({ get_ctrl_unit = function() error("no ctrl unit") end })
  lu.assertEvalToTrue(result == false, "a throwing get_ctrl_unit must yield false")
  lu.assertEvalToTrue(#warns == 1, "a throwing get_ctrl_unit must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("no ctrl unit", 1, true) ~= nil,
    "warn should carry the raised detail; got " .. tostring(warns[1]))
end

function TestRoleDie:test_returns_false_and_warns_when_role_exposes_neither_die_nor_ctrl_unit()
  local result, warns = _call({})
  lu.assertEvalToTrue(result == false, "a role without die and get_ctrl_unit must yield false")
  lu.assertEvalToTrue(#warns == 1, "such a role must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("get_ctrl_unit", 1, true) ~= nil,
    "warn should name the missing accessor; got " .. tostring(warns[1]))
end

function TestRoleDie:test_returns_false_and_warns_for_nil_role()
  local result, warns = _call(nil)
  lu.assertEvalToTrue(result == false, "nil role must yield false")
  lu.assertEvalToTrue(#warns == 1, "nil role must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("role is nil", 1, true) ~= nil,
    "nil role warn should carry the skip reason; got " .. tostring(warns[1]))
end

-- 单位移除失败:出局语义已由 is_die_status 达成,端口仍返回 true,只留一条 warn。
function TestRoleDie:test_warns_but_still_succeeds_when_unit_removal_is_unavailable()
  local unit = _host_unit()
  local result, warns = _call(_host_role(unit), {})
  lu.assertEvalToTrue(result == true, "a failed removal does not undo the elimination")
  lu.assertEvalToTrue(#warns == 1, "a failed removal must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("destroy", 1, true) ~= nil,
    "warn should name the removal step; got " .. tostring(warns[1]))
end

function TestRoleDie:test_warns_but_still_succeeds_when_destroy_unit_raises()
  local unit = _host_unit()
  local result, warns = _call(_host_role(unit), {
    destroy_unit = function()
      error("host destroy failed")
    end,
  })
  lu.assertEvalToTrue(result == true, "a throwing removal does not undo the elimination")
  lu.assertEvalToTrue(#warns == 1, "a throwing removal must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("host destroy failed", 1, true) ~= nil,
    "warn should carry the raised detail; got " .. tostring(warns[1]))
end

-- ── 合成 AI 适配器:自带 die,行为与改前一致 ──────────────────────

function TestRoleDie:test_synthetic_adapter_die_keeps_the_truthy_contract()
  local calls = 0
  local ctrl_unit_reads = 0
  local destroyed, game_api = _destroy_recorder()
  local adapter = {
    -- 合成适配器的真实形状(synthetic_actor_registry._build_adapter):自带标志、
    -- die 与 get_ctrl_unit;分派必须认标志,不能靠 die 存在性。
    is_synthetic_actor = true,
    die = function()
      calls = calls + 1
      return true
    end,
    get_ctrl_unit = function()
      ctrl_unit_reads = ctrl_unit_reads + 1
      return _host_unit()
    end,
  }
  local result, warns = _call(adapter, game_api)
  lu.assertEvalToTrue(result == true, "a succeeding adapter die yields true")
  lu.assertEvalToTrue(calls == 1, "the adapter die must be called exactly once")
  lu.assertEvalToTrue(#warns == 0, "the adapter happy path must not warn")
  lu.assertEvalToTrue(ctrl_unit_reads == 0, "an adapter with die must not fall through to the unit path")
  lu.assertEvalToTrue(#destroyed == 0, "the adapter retires its own unit; role_die must not double destroy")
end

-- #263 的误判形状:一个自带 die 的宿主 Role。分派认 is_synthetic_actor 标志,
-- 有控制单位的对象一律走单位路径,不会退回被证伪的 truthy 判据。
function TestRoleDie:test_a_host_role_that_grows_a_die_method_still_takes_the_unit_path()
  local unit = _host_unit()
  local role_die_calls = 0
  local role = _host_role(unit)
  role.die = function()
    role_die_calls = role_die_calls + 1
    return true
  end
  local destroyed, game_api = _destroy_recorder()
  local result = _call(role, game_api)
  lu.assertEvalToTrue(result == true, "the unit path still reports success")
  lu.assertEvalToTrue(role_die_calls == 0, "a role with a ctrl unit must not use its own die")
  lu.assertEvalToTrue(unit.die_calls == 1, "the ctrl unit must be the one that dies")
  lu.assertEvalToTrue(destroyed[1] == unit, "the ctrl unit must still be removed")
end

function TestRoleDie:test_returns_false_and_warns_when_a_flagged_adapter_has_no_die()
  local result, warns = _call({ is_synthetic_actor = true })
  lu.assertEvalToTrue(result == false, "a flagged adapter without die must yield false")
  lu.assertEvalToTrue(#warns == 1, "such an adapter must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("synthetic adapter", 1, true) ~= nil,
    "warn should name the adapter; got " .. tostring(warns[1]))
end

function TestRoleDie:test_synthetic_adapter_die_accepts_any_truthy_return()
  local result = _call({ die = function() return 1 end })
  lu.assertEvalToTrue(result == true, "a truthy non-boolean return still counts as success")
end

function TestRoleDie:test_returns_false_and_warns_when_adapter_die_returns_falsy()
  local result_nil, warns_nil = _call({ die = function() return nil end })
  lu.assertEvalToTrue(result_nil == false, "nil return must yield false")
  lu.assertEvalToTrue(#warns_nil == 1, "nil return must leave exactly one warn")
  lu.assertEvalToTrue(warns_nil[1]:find("falsy: nil", 1, true) ~= nil,
    "warn should carry the nil return detail; got " .. tostring(warns_nil[1]))

  local result_false, warns_false = _call({ die = function() return false end })
  lu.assertEvalToTrue(result_false == false, "false return must yield false")
  lu.assertEvalToTrue(#warns_false == 1, "false return must leave exactly one warn")
  lu.assertEvalToTrue(warns_false[1]:find("falsy: false", 1, true) ~= nil,
    "warn should carry the falsy value detail; got " .. tostring(warns_false[1]))
end

function TestRoleDie:test_returns_false_and_warns_when_adapter_die_raises()
  local result, warns = _call({ die = function() error("adapter die failed") end })
  lu.assertEvalToTrue(result == false, "a throwing adapter die must yield false")
  lu.assertEvalToTrue(#warns == 1, "a throwing adapter die must leave exactly one warn")
  lu.assertEvalToTrue(warns[1]:find("adapter die failed", 1, true) ~= nil,
    "warn should carry the raised error detail; got " .. tostring(warns[1]))
end

return TestRoleDie
