local lu = require("luaunit")
local scene_ui = require("src.host.scene_ui")

TestSceneUi = {}

function TestSceneUi:test_set_scene_ui_visible_returns_false_without_gameapi()
  local result = scene_ui.set_scene_ui_visible(1, "role", true)
  lu.assertEvalToTrue(result == false, "expected false without GameAPI")
end

function TestSceneUi:test_destroy_scene_ui_returns_false_without_gameapi()
  local result = scene_ui.destroy_scene_ui(1)
  lu.assertEvalToTrue(result == false, "expected false without GameAPI")
end

function TestSceneUi:test_has_scene_ui_support_returns_false_without_gameapi()
  local result = scene_ui.has_scene_ui_support()
  lu.assertEvalToTrue(result == false, "expected false without GameAPI")
end

function TestSceneUi:test_get_eui_node_at_scene_ui_returns_nil_without_gameapi()
  local result = scene_ui.get_eui_node_at_scene_ui(1, "node")
  lu.assertEvalToTrue(result == nil, "expected nil without GameAPI")
end

-- #293:测试环境的 Eggy fake 把 GameAPI 装成真值但无方法的对象,`and`→`or`
-- 变异后走 pcall 错误路径返回 false,与正常路径观测相同——既有
-- 「without_gameapi」测试因此杀不掉守卫变异。显式把全局置 nil 才能测到
-- 真正的缺失语义(变异后是 nil 索引崩溃,不是优雅回落)。
local function _without_gameapi(fn)
  local saved = _G.GameAPI
  _G.GameAPI = nil
  local ok, result = pcall(fn)
  _G.GameAPI = saved
  return ok, result
end

function TestSceneUi:test_set_scene_ui_visible_guard_handles_truly_absent_gameapi()
  local ok, result = _without_gameapi(function()
    return scene_ui.set_scene_ui_visible(1, "role", true)
  end)
  lu.assertEvalToTrue(ok == true and result == false,
    "absent GameAPI should return false without crashing")
end

function TestSceneUi:test_destroy_scene_ui_guard_handles_truly_absent_gameapi()
  local ok, result = _without_gameapi(function()
    return scene_ui.destroy_scene_ui(1)
  end)
  lu.assertEvalToTrue(ok == true and result == false,
    "absent GameAPI should return false without crashing")
end

function TestSceneUi:test_has_scene_ui_support_guard_handles_truly_absent_gameapi()
  local ok, result = _without_gameapi(function()
    return scene_ui.has_scene_ui_support()
  end)
  lu.assertEvalToTrue(ok == true and result == false,
    "absent GameAPI should report no support without crashing")
end

function TestSceneUi:test_get_eui_node_guard_handles_truly_absent_gameapi()
  local ok, result = _without_gameapi(function()
    return scene_ui.get_eui_node_at_scene_ui(1, "node")
  end)
  lu.assertEvalToTrue(ok == true and result == nil,
    "absent GameAPI should return nil without crashing")
end

function TestSceneUi:test_get_eui_node_skips_lookup_when_args_are_incomplete()
  -- #293:_complete_args 的 `and`→`or` 变异只在单参缺失时可分;GameAPI 有
  -- 方法时,变异会让缺参调用真的发起查询。
  local calls = 0
  local saved = _G.GameAPI
  _G.GameAPI = {
    get_eui_node_at_scene_ui = function()
      calls = calls + 1
      return "node"
    end,
  }
  local result = scene_ui.get_eui_node_at_scene_ui(nil, "node")
  _G.GameAPI = saved
  lu.assertEvalToTrue(result == nil, "incomplete args should short-circuit before lookup")
  lu.assertEvalToTrue(calls == 0, "lookup must not run with incomplete args")
end


return TestSceneUi
