-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe 拍平为文件级 Test* 类,
-- before_each 转 setUp,用例数与改写前一一对应(8 例)。
-- #293 批3:补 resolve 端口直测(9 例)——registry 只挂 descriptor_for 不挂
-- handlers,descriptor_for 分支与 handlers 回退分支必须被直接驱动。

local lu = require("luaunit")
local choice_resolver = require("src.rules.choice.resolver")
local event_kinds = require("src.config.gameplay.event_kinds")

local _contains = choice_resolver._M_test._contains

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _fixture()
  local executed = {}
  local descriptor = {
    execute = function(game, choice, action)
      executed.action = action
      return { status = "executed" }
    end,
  }
  local game = {
    turn = {},
    dirty = { turn = false },
    registries = {
      choices = {
        -- 只提供 descriptor_for,不提供 handlers:L57 回退链变异体在
        -- handlers[kind] 撞 nil 报错,原实现走 descriptor_for 成功。
        descriptor_for = function(kind)
          return descriptor
        end,
      },
    },
  }
  local choice = {
    id = "c1",
    kind = "test_kind",
    title = "标题",
    options = { { id = "a" }, { id = "b" } },
  }
  return game, choice, descriptor, executed
end

local _config_reset = require("test.support.config_reset")

TestResolver = {}

function TestResolver:setUp()
  _config_reset.reset_all()
end

function TestResolver:test_contains_returns_true_when_value_present()
  _assert_eq(_contains({ "a", "b", "c" }, "b"), true, "contains present value")
end

function TestResolver:test_contains_returns_false_when_value_missing()
  _assert_eq(_contains({ "a", "b" }, "z"), false, "contains missing value")
end

function TestResolver:test_contains_returns_false_for_empty_table()
  _assert_eq(_contains({}, "a"), false, "contains empty list")
end

function TestResolver:test_contains_returns_false_for_nil_list()
  _assert_eq(_contains(nil, "a"), false, "contains nil list")
end

function TestResolver:test_contains_returns_false_for_string_list()
  _assert_eq(_contains("abc", "a"), false, "contains string list")
end

function TestResolver:test_contains_returns_false_for_number_list()
  _assert_eq(_contains(123, 1), false, "contains number list")
end

function TestResolver:test_contains_works_with_numeric_values()
  _assert_eq(_contains({ 1, 2, 3 }, 2), true, "contains numeric value")
end

function TestResolver:test_contains_returns_false_for_numeric_mismatch()
  _assert_eq(_contains({ 1, 2, 3 }, 4), false, "contains numeric mismatch")
end

function TestResolver:test_resolve_executes_descriptor_for_known_kind()
  -- L57 `type(descriptor_for) == "function" and descriptor_for(...) or handlers[...]`
  -- 三连变异(调用换 nil / == -> ~= / "function" 换 nil / or -> and)都会掉到
  -- handlers 回退,而 registry 只挂 descriptor_for:变异体撞 nil 报错即杀。
  local game, choice, _, executed = _fixture()
  local result = choice_resolver.resolve(game, choice, { type = "pick", option_id = "a" })
  _assert_eq(executed.action.option_id, "a", "descriptor_for should resolve the action")
  _assert_eq(result.status, "executed", "execute result should pass through")
end

function TestResolver:test_resolve_invalid_option_rejects_with_stay()
  -- L171 `status="rejected"` 换 nil / `stay=true` 换 false:无效选项必须
  -- rejected + stay。
  local game, choice, _, executed = _fixture()
  local result = choice_resolver.resolve(game, choice, { type = "pick", option_id = "zzz" })
  _assert_eq(result.status, "rejected", "invalid option must reject")
  _assert_eq(result.stay, true, "rejected result must stay")
  lu.assertEvalToTrue(executed.action == nil, "invalid option must not execute")
end

function TestResolver:test_resolve_missing_option_id_rejects()
  -- L36 `_option_exists` 的 nil 守卫 `return false` -> true:无 option_id 的
  -- action 必须被拒,变异体放行去 execute。
  local game, choice, _, executed = _fixture()
  local result = choice_resolver.resolve(game, choice, { type = "pick" })
  _assert_eq(result.status, "rejected", "missing option_id must reject")
  lu.assertEvalToTrue(executed.action == nil, "missing option_id must not execute")
end

function TestResolver:test_resolve_matches_option_id_through_tostring()
  -- L39 `option_id == target or tostring(option_id) == tostring(target)`:
  -- 数字 id 与字符串 "1" 必须互认;`or->and` 与两个 `tostring(...)->nil`
  -- 变异体都会误拒。
  local game, choice, _, executed = _fixture()
  choice.options = { { id = 1 }, { id = 2 } }
  local result = choice_resolver.resolve(game, choice, { type = "pick", option_id = "1" })
  _assert_eq(result.status, "executed", "string-form option id must resolve the numeric option")
  _assert_eq(executed.action.option_id, "1", "string option id should be passed to execute")
end

function TestResolver:test_helpers_finish_choice_waiting_and_resolved()
  -- L31 `stay and "waiting" or "resolved"` 的 waiting 换 nil:stay 时状态
  -- 必须 waiting。
  local helpers = choice_resolver.helpers()
  local waiting = helpers.finish_choice({ turn = {}, dirty = { turn = false } }, true)
  _assert_eq(waiting.status, "waiting", "finish_choice stay must report waiting")
  local resolved = helpers.finish_choice({ turn = {}, dirty = { turn = false } }, false)
  _assert_eq(resolved.status, "resolved", "finish_choice no-stay must report resolved")
end

function TestResolver:test_resolve_cancel_followup_rebuilds_select_action()
  -- L47 `type="choice_select"` 换 nil 与 L50 `action and action.actor_role_id or nil`
  -- 的 and/or 变异:select_option 取消回填必须带 type 与 actor_role_id。
  local game, choice, descriptor, executed = _fixture()
  descriptor.cancel = { mode = "select_option", option_id = "b" }
  local result = choice_resolver.resolve(game, choice,
    { type = "choice_cancel", choice_id = "c1", actor_role_id = "r1" })
  _assert_eq(result.status, "executed", "cancel followup should execute the rebuilt action")
  _assert_eq(executed.action.type, "choice_select", "rebuilt action must be a choice_select")
  _assert_eq(executed.action.option_id, "b", "rebuilt action must carry the fallback option")
  _assert_eq(executed.action.actor_role_id, "r1", "rebuilt action must carry the actor role id")
end

function TestResolver:test_resolve_cancel_stay_result_keeps_waiting_status()
  -- L111 `cancel_result.status or "waiting"` 的 or->and / waiting->nil:
  -- stay 的取消结果必须补 waiting 状态。
  local game, choice, descriptor, _ = _fixture()
  descriptor.cancel = {
    resolve = function(g, c)
      return { stay = true }
    end,
  }
  local result = choice_resolver.resolve(game, choice, { type = "choice_cancel" })
  _assert_eq(result.status, "waiting", "stay cancel result must default to waiting")
  _assert_eq(result.stay, true, "stay cancel result must keep stay")
end

function TestResolver:test_resolve_cancel_non_stay_emits_skip_event()
  -- L104 `tip=false` -> true 与 L21 `"请选择"` -> nil、L18 `choice and
  -- choice.title and ...` 的 and->or / `~= ""` -> `~= nil`:无标题的 skip
  -- 事件必须带默认标题与 tip=false。
  local game, choice, _, _ = _fixture()
  choice.title = nil
  local captured = nil
  local result = choice_resolver.resolve(game, choice, { type = "choice_cancel" }, {
    on_event = function(payload)
      captured = payload
    end,
  })
  _assert_eq(result.status, "resolved", "non-stay cancel must resolve")
  _assert_eq(captured.kind, event_kinds.choice_skipped, "skip event kind must be stable")
  _assert_eq(captured.text, "跳过选择：请选择", "missing title must fall back to the default label")
  _assert_eq(captured.tip, false, "skip event must not tip")
end

function TestResolver:test_resolve_cancel_skip_event_with_empty_title()
  -- L18 `choice.title ~= ""` 的 `~= ""` -> `~= nil`:空串标题必须回退默认文案。
  local game, choice, _, _ = _fixture()
  choice.title = ""
  local captured = nil
  choice_resolver.resolve(game, choice, { type = "choice_cancel" }, {
    on_event = function(payload)
      captured = payload
    end,
  })
  _assert_eq(captured.text, "跳过选择：请选择", "empty title must fall back to the default label")
end

function TestResolver:test_resolve_normalize_action_uses_normalized_action()
  -- L141 `descriptor.normalize_action(game, choice, action)` 换 nil 与
  -- L142 `~=` -> `==`:normalize 产物必须交给 execute,不能用原始 action。
  local game, choice, descriptor, executed = _fixture()
  descriptor.normalize_action = function(g, c, action)
    return { type = "normalized", option_id = action.option_id, actor_role_id = "r9" }
  end
  local result = choice_resolver.resolve(game, choice, { type = "pick", option_id = "a" })
  _assert_eq(result.status, "executed", "normalized action should still execute")
  _assert_eq(executed.action.type, "normalized", "execute must receive the normalized action")
  _assert_eq(executed.action.actor_role_id, "r9", "normalize may rewrite actor role")
end

function TestResolver:test_resolve_plain_result_passes_through_without_status()
  -- L147 `result and result.stay` 的 and->or:非 stay 结果必须原样透传,
  -- 变异体擅自补 waiting 状态。
  local game, choice, descriptor, _ = _fixture()
  descriptor.execute = function(g, c, action)
    return { stay = false }
  end
  local result = choice_resolver.resolve(game, choice, { type = "pick", option_id = "a" })
  _assert_eq(result.stay, false, "non-stay result must pass through")
  lu.assertEvalToTrue(result.status == nil, "non-stay result must keep its status as-is")
end

function TestResolver:test_resolve_nil_execute_result_falls_back_to_resolved()
  -- L151 `{ status = "resolved", stay = false }` 的 resolved 换 nil / false
  -- 换 true:execute 返回 nil 时回退结果必须 resolved + 不 stay。
  local game, choice, descriptor, _ = _fixture()
  descriptor.execute = function(g, c, action)
    return nil
  end
  local result = choice_resolver.resolve(game, choice, { type = "pick", option_id = "a" })
  _assert_eq(result.status, "resolved", "nil execute result must fall back to resolved")
  _assert_eq(result.stay, false, "fallback result must not stay")
end

function TestResolver:test_helpers_metatable_is_hidden_from_getmetatable()
  -- L95 `__metatable = false` -> true:helpers 的防护元表必须对外隐藏。
  local helpers = choice_resolver.helpers()
  lu.assertEvalToTrue(getmetatable(helpers) == false,
    "helpers metatable must be hidden; got " .. tostring(getmetatable(helpers)))
  local ok = pcall(function()
    helpers.something_new = 1
  end)
  _assert_eq(ok, false, "helpers must reject writes")
end


return TestResolver
