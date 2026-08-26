local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")

local function _tmp_dir(name)
  local token = tostring(os.time()) .. "_" .. tostring({}):gsub("[^%w]+", "")
  local dir = path_lib.join_path("tmp", name .. "_" .. token)
  fs_lib.remove_path(dir)
  assert(fs_lib.ensure_dir(dir))
  return dir
end

local function _write_sample_feature(path)
  assert(fs_lib.write_file(path, table.concat({
    "Feature: mutate lane sample",
    "",
    "Scenario Outline: integer conversion",
    "  Given project acceptance step handlers are loaded",
    "  And a text value <raw>",
    "  When the project converts it to an integer",
    "  Then the integer result is <result>",
    "",
    "Examples:",
    "  | raw | result |",
    "  | 1   | 1      |",
    "",
  }, "\n")))
end

local function _run_lane(options)
  local args = {
    options.env_prefix or "",
    "lua", shell_lib.shell_quote("tools/packages/acceptance_mutate/mutate_lane.lua"),
    "--feature", shell_lib.shell_quote(options.feature_path),
    "--work-dir", shell_lib.shell_quote(options.work_dir),
    "--level", options.level or "full",
    "--workers", "2",
  }
  return proc_lib.run_command(table.concat(args, " "))
end

-- #361 P4:原差分跳过 e2e 两例已删——soft 全跳过/改动后重跑与
-- test_mutator_level 集成层重复,健康路径与上层重复;差分语义面由
-- test_scenario_manifest(decide_scenario_skip 全分支)+ test_mutator_level
-- (skipped/total 计数)承接。此处只留探针失败大声退非零的回归钉。
TestMutateLane = {}

-- 回归钉:runner adapter 坏掉时(典型:Lua 5.4 launcher 解析不到,子进程退回
-- PATH 上的 lua 5.5),soft 差分档会跳过全部变异体、报 total=0 然后退 0——
-- 一个测试都没跑却报绿。车道必须先探针、后变异,探针挂了就大声退非零。
function TestMutateLane:test_aborts_loudly_when_the_runner_adapter_cannot_run_tests()
  local tmp_dir = _tmp_dir("mutate_lane_broken")
  local feature_path = path_lib.join_path(tmp_dir, "sample.feature")
  _write_sample_feature(feature_path)

  local result = _run_lane({
    env_prefix = "ACCEPTANCE_LUA_BIN=/nonexistent/lua",
    feature_path = feature_path,
    work_dir = path_lib.join_path(tmp_dir, "work"),
    level = "soft",
  })

  lu.assertFalse(result.ok)
  lu.assertEvalToTrue(tostring(result.output):find("infrastructure_error", 1, true))
  lu.assertEvalToTrue(tostring(result.output):find("ACCEPTANCE_LUA_BIN", 1, true))

  fs_lib.remove_path(tmp_dir)
end

return TestMutateLane
