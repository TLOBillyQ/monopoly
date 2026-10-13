require("test.bootstrap").install_package_paths()
local check = require("luassert")
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
describe("mutate lane boundary", function()

-- Windows 上即使 runner 配置损坏,也先报告平台不可用(#96),不给变异结论。
it("reports unavailable before probing a broken runner", function()
  local tmp_dir = _tmp_dir("mutate_lane_broken")
  local feature_path = path_lib.join_path(tmp_dir, "sample.feature")
  _write_sample_feature(feature_path)

  local result = _run_lane({
    env_prefix = 'set "ACCEPTANCE_LUA_BIN=missing-lua.exe" &&',
    feature_path = feature_path,
    work_dir = path_lib.join_path(tmp_dir, "work"),
    level = "soft",
  })

  check.same(result.code, 3, result.output)
  check.truthy(tostring(result.output):find("status=unavailable", 1, true))
  check.is_nil(tostring(result.output):find("infrastructure_error", 1, true),
    "平台不可用要在 runner 探针之前诊断")

  fs_lib.remove_path(tmp_dir)
end)

end)
