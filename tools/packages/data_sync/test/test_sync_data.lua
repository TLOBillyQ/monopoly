---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/data_sync/test/test_sync_data.lua") end
require("test.bootstrap").install_package_paths()

-- sync_data.lua 的聚焦单测:UINodes → UIManagerNodes 转换(parse/render,移植自
-- UIManager_web script.js,无 length 行)+ sync_from_deploy 沙箱文件系统行为。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local sync_data = require("packages.data_sync.sync_data")

local SAMPLE_UINODES = table.concat({
  "---AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT",
  "",
  "return {",
  '\t["位置-槽位1投影"] = "1519736575|1821865760" --[[@as EImage]],',
  '\t基础屏 = "1519736575|2147314485" --[[@as ECanvas]],',
  '\t--["旧节点"] = "1519736575|2147314485" --[[@as EImage]],',
  '\t["日志"] = "1519736575|1002562102" --[[@as ELabel]],',
  "}",
  "",
}, "\n")

local EXPECTED_RENDER = table.concat({
  "---AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT",
  "",
  "return {",
  '\t["1519736575|1002562102"] = {"日志", "ELabel"},',
  '\t["1519736575|1821865760"] = {"位置-槽位1投影", "EImage"},',
  '\t["1519736575|2147314485"] = {"旧节点", "EImage"},',
  "}",
  "",
}, "\n")

local function _with_sandbox(fn)
  local root = env_lib.make_temp_path("sync_data_spec_", "")
  fs_lib.remove_path(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

local function _write(path, content)
  local ok, err = fs_lib.write_file(path, content)
  if not ok then
    error(err)
  end
end

local function _make_deploy_dir(root)
  local deploy_dir = root .. "/deploy"
  _write(deploy_dir .. "/Data/Prefab.lua", "---AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT\n\nreturn {\n\tunit = {\n\t\tlv1 = 1073786977,\n\t},\n}\n")
  _write(deploy_dir .. "/Data/UINodes.lua", SAMPLE_UINODES)
  _write(deploy_dir .. "/EggyAPI.lua", "-- EggyAPI: 游戏API\n-- Auto-generated, do not edit\n\n---@class Other\n\nOther = {}\n")
  _write(deploy_dir .. "/EggyEditorAPI.lua", "-- EggyEditorAPI: 编辑器编辑时API\n-- Auto-generated, do not edit\n\n---@class Other\n\nOther = {}\n")
  return deploy_dir
end

TestParseUinodes = {}

function TestParseUinodes.test_bracket_and_bare_and_commented_forms()
  local data = sync_data.parse_uinodes(SAMPLE_UINODES)
  lu.assertEquals(data["1519736575|1821865760"], { name = "位置-槽位1投影", node_type = "EImage" })
  lu.assertEquals(data["1519736575|1002562102"], { name = "日志", node_type = "ELabel" })
  -- 同 id 后者覆盖:注释行里的"旧节点"覆盖裸键形式的"基础屏"(与 JS 一致)。
  lu.assertEquals(data["1519736575|2147314485"], { name = "旧节点", node_type = "EImage" })
end

function TestParseUinodes.test_ignores_non_entry_lines()
  local data = sync_data.parse_uinodes(SAMPLE_UINODES)
  local count = 0
  for _ in pairs(data) do
    count = count + 1
  end
  lu.assertEquals(count, 3)
end

function TestParseUinodes.test_empty_input_yields_empty_map()
  lu.assertEquals(next(sync_data.parse_uinodes("")), nil)
  lu.assertEquals(next(sync_data.parse_uinodes(nil)), nil)
end

TestRender = {}

function TestRender.test_render_sorted_without_length_line()
  local rendered = sync_data.render_ui_manager_nodes(sync_data.parse_uinodes(SAMPLE_UINODES))
  lu.assertEquals(rendered, EXPECTED_RENDER)
  lu.assertIsNil(rendered:find("length", 1, true))
end

TestSyncFromDeploy = {}

function TestSyncFromDeploy.test_sync_writes_all_files()
  _with_sandbox(function(root)
    local deploy_dir = _make_deploy_dir(root)
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNotIsNil(stats, tostring(err))
    lu.assertEquals(stats.node_count, 3)
    lu.assertTrue(stats.prefab_changed)
    lu.assertTrue(stats.nodes_changed)
    lu.assertTrue(stats.prefab_bytes > 0)
    lu.assertTrue(stats.api_changed)
    lu.assertTrue(stats.editor_api_changed)
    lu.assertTrue(stats.api_bytes > 0)
    lu.assertTrue(stats.editor_api_bytes > 0)

    lu.assertEquals(fs_lib.read_file(repo_root .. "/Data/UIManagerNodes.lua"), EXPECTED_RENDER)
    lu.assertEquals(
      fs_lib.read_file(repo_root .. "/Data/Prefab.lua"),
      fs_lib.read_file(deploy_dir .. "/Data/Prefab.lua")
    )
    lu.assertEquals(
      fs_lib.read_file(repo_root .. "/EggyAPI.lua"),
      fs_lib.read_file(deploy_dir .. "/EggyAPI.lua")
    )
    lu.assertEquals(
      fs_lib.read_file(repo_root .. "/EggyEditorAPI.lua"),
      fs_lib.read_file(deploy_dir .. "/EggyEditorAPI.lua")
    )
  end)
end

function TestSyncFromDeploy.test_second_run_reports_no_change()
  _with_sandbox(function(root)
    local deploy_dir = _make_deploy_dir(root)
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    sync_data.sync_from_deploy(deploy_dir, repo_root)
    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNotIsNil(stats, tostring(err))
    lu.assertFalse(stats.prefab_changed)
    lu.assertFalse(stats.nodes_changed)
    lu.assertFalse(stats.api_changed)
    lu.assertFalse(stats.editor_api_changed)
  end)
end

function TestSyncFromDeploy.test_missing_prefab_is_error_and_writes_nothing()
  _with_sandbox(function(root)
    local deploy_dir = root .. "/deploy"
    _write(deploy_dir .. "/Data/UINodes.lua", SAMPLE_UINODES)
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNil(stats)
    lu.assertStrContains(tostring(err), "Prefab.lua")
    lu.assertFalse(fs_lib.path_exists(repo_root .. "/Data/UIManagerNodes.lua"))
  end)
end

function TestSyncFromDeploy.test_missing_uinodes_is_error()
  _with_sandbox(function(root)
    local deploy_dir = root .. "/deploy"
    _write(deploy_dir .. "/Data/Prefab.lua", "return {}\n")
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNil(stats)
    lu.assertStrContains(tostring(err), "UINodes.lua")
  end)
end

function TestSyncFromDeploy.test_unparseable_uinodes_is_error_and_writes_nothing()
  _with_sandbox(function(root)
    local deploy_dir = root .. "/deploy"
    _write(deploy_dir .. "/Data/Prefab.lua", "return {}\n")
    _write(deploy_dir .. "/Data/UINodes.lua", "return {}\n")
    _write(deploy_dir .. "/EggyAPI.lua", "Other = {}\n")
    _write(deploy_dir .. "/EggyEditorAPI.lua", "Other = {}\n")
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNil(stats)
    lu.assertStrContains(tostring(err), "未解析出任何节点")
    lu.assertFalse(fs_lib.path_exists(repo_root .. "/Data/Prefab.lua"))
  end)
end

function TestSyncFromDeploy.test_missing_eggy_api_is_error_and_writes_nothing()
  _with_sandbox(function(root)
    local deploy_dir = root .. "/deploy"
    _write(deploy_dir .. "/Data/Prefab.lua", "return {}\n")
    _write(deploy_dir .. "/Data/UINodes.lua", SAMPLE_UINODES)
    _write(deploy_dir .. "/EggyEditorAPI.lua", "Other = {}\n")
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNil(stats)
    lu.assertStrContains(tostring(err), "EggyAPI.lua")
    lu.assertFalse(fs_lib.path_exists(repo_root .. "/Data/Prefab.lua"))
    lu.assertFalse(fs_lib.path_exists(repo_root .. "/EggyEditorAPI.lua"))
  end)
end

function TestSyncFromDeploy.test_missing_eggy_editor_api_is_error_and_writes_nothing()
  _with_sandbox(function(root)
    local deploy_dir = root .. "/deploy"
    _write(deploy_dir .. "/Data/Prefab.lua", "return {}\n")
    _write(deploy_dir .. "/Data/UINodes.lua", SAMPLE_UINODES)
    _write(deploy_dir .. "/EggyAPI.lua", "Other = {}\n")
    local repo_root = root .. "/repo"
    fs_lib.ensure_dir(repo_root .. "/Data")

    local stats, err = sync_data.sync_from_deploy(deploy_dir, repo_root)
    lu.assertNil(stats)
    lu.assertStrContains(tostring(err), "EggyEditorAPI.lua")
    lu.assertFalse(fs_lib.path_exists(repo_root .. "/Data/Prefab.lua"))
    lu.assertFalse(fs_lib.path_exists(repo_root .. "/EggyAPI.lua"))
  end)
end

TestCliArgs = {}

function TestCliArgs.test_unexpected_arg_is_usage_error()
  lu.assertEquals(sync_data.main({ "extra" }), 2)
end
