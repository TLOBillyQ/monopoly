-- host_push.push 的契约:UIManager 子树「推给谁」的唯一裁决点。
-- 各 __update_* 已不再自己写双分支,故这里直接钉住三条约定:
--   1. 有 client_role → 只推给它,allroles 一个都不碰;
--   2. 无 client_role → 按 allroles 顺序广播;
--   3. 一次 apply 内推多个宿主方法时,按「每角色依次执行 apply」推进
--      —— EButton:__update_disabled 的 touch/enabled 成对下发依赖这个顺序。
-- #542 再加三条「宿主个体差异」约定:
--   4. role 代理缺目标方法 → 跳过该 role + warn 留痕(带 role 与方法名),
--      广播不中断;
--   5. 单推的 client_role 缺方法 → 同样跳过 + warn,不上抛;
--   6. 方法在但执行抛错 → 原样上抛,观测性不回退(#541)。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local logger = require("src.foundation.log")
local push = require("src.ui.manager.host_push").push

TestHostPush = {}

local calls

-- 录制型 role:记下收到的方法名与角色,顺序即调用顺序。
local function _make_role(roleid)
  return setmetatable({ get_roleid = function() return roleid end }, {
    __index = function(_, method)
      return function(...)
        calls[#calls + 1] = { roleid = roleid, method = method, args = table.pack(...) }
      end
    end,
  })
end

local function _clear_context()
  for i = #context.allroles, 1, -1 do
    context.allroles[i] = nil
  end
  context.client_role = nil
end

function TestHostPush:setUp()
  _clear_context()
  calls = {}
end

function TestHostPush:tearDown()
  _clear_context()
end

function TestHostPush:test_pushes_to_the_client_role_only_when_one_is_set()
  context.client_role = _make_role(7)
  table.insert(context.allroles, _make_role(101))
  table.insert(context.allroles, _make_role(102))

  push(function(role) role.set_node_visible("node_42", true) end)

  lu.assertEvalToTrue(#calls == 1, ("expected exactly 1 host call, got %d"):format(#calls))
  lu.assertEvalToTrue(calls[1].roleid == 7, "client_role should be the only receiver")
  lu.assertEvalToTrue(calls[1].method == "set_node_visible", "should forward the host method")
  lu.assertEvalToTrue(calls[1].args[1] == "node_42" and calls[1].args[2] == true, "should forward the host args")
end

function TestHostPush:test_broadcasts_to_every_role_in_allroles_order_when_there_is_no_client_role()
  table.insert(context.allroles, _make_role(101))
  table.insert(context.allroles, _make_role(102))
  table.insert(context.allroles, _make_role(103))

  push(function(role) role.set_node_visible("node_42", false) end)

  lu.assertEvalToTrue(#calls == 3, ("expected one host call per role, got %d"):format(#calls))
  lu.assertEvalToTrue(calls[1].roleid == 101 and calls[2].roleid == 102 and calls[3].roleid == 103,
    "should broadcast in allroles order")
end

-- 这条是 EButton:__update_disabled 的地基:成对下发必须 role1.a、role1.b、role2.a、role2.b,
-- 而不是拆成两次广播后的 role1.a、role2.a、role1.b、role2.b。
function TestHostPush:test_runs_a_multi_call_apply_fully_per_role_before_moving_to_the_next_role()
  table.insert(context.allroles, _make_role(101))
  table.insert(context.allroles, _make_role(102))

  push(function(role)
    role.set_node_touch_enabled("node_42", true)
    role.set_button_enabled("node_42", true)
  end)

  lu.assertEvalToTrue(#calls == 4, ("expected 2 methods x 2 roles, got %d"):format(#calls))
  local seen = {}
  for i, call in ipairs(calls) do
    seen[i] = call.roleid .. ":" .. call.method
  end
  lu.assertEvalToTrue(table.concat(seen, ",") ==
    "101:set_node_touch_enabled,101:set_button_enabled,102:set_node_touch_enabled,102:set_button_enabled",
    "每个角色应先跑完整个 apply,再轮到下一个角色;实际: " .. table.concat(seen, ","))
end

function TestHostPush:test_does_nothing_when_there_is_no_client_role_and_no_roles_at_all()
  push(function(role) role.set_node_visible("node_42", true) end)

  lu.assertEvalToTrue(#calls == 0, "没有任何角色时不应推送")
end

-- 缺 UI 方法的 role 代理:只有 get_roleid,没有 __index 自动造方法——
-- 索引任何推送方法都得 nil,与真机 AI 位(role=-4)的宿主代理同形。
local function _make_method_less_role(roleid)
  return { get_roleid = function() return roleid end }
end

-- 用 ui_sink 截住本用例内的日志条目(warn 默认只进 print,sink 收全部 entry),
-- 跑完即拆,不外泄给其他用例。
local function _capture_log_entries(fn)
  local entries = {}
  logger.set_ui_sink(function(entry)
    entries[#entries + 1] = entry
  end)
  local ok, err = pcall(fn)
  logger.set_ui_sink(nil)
  if not ok then
    error(err, 0)
  end
  return entries
end

local function _warn_texts(entries)
  local texts = {}
  for _, entry in ipairs(entries) do
    if entry.level == "warn" then
      texts[#texts + 1] = entry.text
    end
  end
  return texts
end

local function _assert_one_skip_warn(warns, role_text, method)
  lu.assertEvalToTrue(#warns == 1, ("expected exactly 1 skip warn, got %d"):format(#warns))
  lu.assertEvalToTrue(warns[1]:find(role_text, 1, true) ~= nil,
    "skip warn should name the role, got: " .. tostring(warns[1]))
  lu.assertEvalToTrue(warns[1]:find(method, 1, true) ~= nil,
    "skip warn should name the missing method, got: " .. tostring(warns[1]))
end

function TestHostPush:test_skips_a_role_missing_the_method_without_breaking_the_broadcast()
  table.insert(context.allroles, _make_role(101))
  table.insert(context.allroles, _make_method_less_role(-4))
  table.insert(context.allroles, _make_role(103))

  local entries = _capture_log_entries(function()
    push(function(role) role.set_node_visible("node_42", true) end)
  end)

  lu.assertEvalToTrue(#calls == 2, ("healthy roles should still be pushed, got %d calls"):format(#calls))
  lu.assertEvalToTrue(calls[1].roleid == 101 and calls[2].roleid == 103,
    "缺方法的 role 不得中断广播,排在其后的 role 必须照常收到推送")
  _assert_one_skip_warn(_warn_texts(entries), "-4", "set_node_visible")
end

function TestHostPush:test_skips_a_client_role_missing_the_method_without_raising()
  context.client_role = _make_method_less_role(-4)
  table.insert(context.allroles, _make_role(101))

  local entries = _capture_log_entries(function()
    push(function(role) role.set_node_visible("node_42", true) end)
  end)

  lu.assertEvalToTrue(#calls == 0, "单推目标缺方法时不应推送,也不应碰 allroles")
  _assert_one_skip_warn(_warn_texts(entries), "-4", "set_node_visible")
end

-- #542 最极端宿主个体差异:role 代理连 get_roleid 都没有(纯宿主对象,无任何
-- 方法)。缺方法跳过时 warn 里的 role 标识必须落到 tostring(role) 兜底,
-- 不能炸 nil 调用,也不能中断广播(虽然这里没有任何健康角色可推)。
function TestHostPush:test_skip_warn_falls_back_to_tostring_when_role_has_no_roleid()
  table.insert(context.allroles, {})

  local entries = _capture_log_entries(function()
    push(function(role) role.set_node_visible("node_42", true) end)
  end)

  lu.assertEvalToTrue(#calls == 0, "no healthy roles to receive the push")
  _assert_one_skip_warn(_warn_texts(entries), "table:", "set_node_visible")
end

function TestHostPush:test_lets_a_method_that_raises_propagate_unchanged()
  context.client_role = {
    set_node_visible = function()
      error("host exploded", 0)
    end,
  }

  local ok, err = pcall(function()
    push(function(role) role.set_node_visible("node_42", true) end)
  end)

  lu.assertEvalToTrue(not ok, "方法存在但抛错必须原样上抛,不得被跳过逻辑吞掉")
  lu.assertEvalToTrue(tostring(err):find("host exploded", 1, true) ~= nil,
    "原始错误正文不得被改写, got: " .. tostring(err))
end


return TestHostPush
