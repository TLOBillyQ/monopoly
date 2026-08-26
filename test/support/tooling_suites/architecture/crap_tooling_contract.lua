local bootstrap = require("test.bootstrap")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local crap = require("packages.crap.runner")
local gate = require("packages.crap.gate")
local report_io = require("packages.crap.report_io")
local package_path_helper = require("foundation.package_path_helper")
local json_reader = require("foundation.json_reader")
local json_writer = require("foundation.json_writer")

bootstrap.install_package_paths()

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function _assert_not_contains(text, unexpected, message)
  if tostring(text or ""):find(unexpected, 1, true) ~= nil then
    error((message or "unexpected text found") .. "\nunexpected: " .. tostring(unexpected) .. "\nactual: " .. tostring(text))
  end
end

local function _buffer()
  local parts = {}
  return {
    write = function(_, ...)
      local count = select("#", ...)
      for index = 1, count do
        parts[#parts + 1] = tostring(select(index, ...))
      end
    end,
    text = function()
      return table.concat(parts)
    end,
  }
end

local function _test_env_preserves_monopoly_path_convention()
  local env = crap.env
  assert(env.tmp_root:find("eggy_crap", 1, true) ~= nil,
    "default tmp root should preserve monopoly-specific directory name")
  assert(env.default_config:find("tools/packages/crap/config.lua", 1, true) ~= nil,
    "default config should point at monopoly wrapper config")
  assert(env.default_gate_threshold == 5.0,
    "gate threshold should align with upstream v0.1.0 via config.lua (6 -> 5.0)")
end

local function _test_install_eggy_package_paths_only_installs_canonical_repo_patterns()
  local original_package_path = package.path
  package.path = "/tmp/monopoly_package_path_sentinel.lua"

  local ok, err = pcall(function()
    package_path_helper.install_eggy_package_paths({
      repo_root = "/repo",
      arch_view_root = "/repo/.swarmforge/tools/arch_view@abc",
    })
    _assert_contains(package.path, "/repo/tools/?.lua", "helper should keep canonical repo tool paths")
    _assert_contains(package.path, "/repo/test/?.lua", "helper should keep canonical spec paths")
    _assert_not_contains(package.path, "/repo/.swarmforge/tools/arch_view@abc",
      "package helper should not install tool cache paths")
  end)

  package.path = original_package_path
  if not ok then
    error(err)
  end
end

-- luacov adapter 契约：resolve_suites 暴露两个 lane 的 suites，run
-- 委托 harness(空 suites 返回 total=0)。require 即顶层 init luacov(hook 早装
-- 覆盖 spec 加载期行)——本测试只验证形状,不跑真实用例。
local function _test_luacov_adapter_resolves_lanes_and_delegates_run()
  local adapter = require("packages.crap.luacov_adapter")
  local behavior_suites = adapter.resolve_suites("behavior")
  assert(#behavior_suites > 0, "behavior lane should expose behavior suites")
  local contract_suites = adapter.resolve_suites("contract")
  assert(#contract_suites > 0, "contract lane should expose contract suites")
  assert(type(adapter.run) == "function", "adapter should expose the run contract")
  local result = adapter.run({}, {})
  _assert_eq(result.total, 0, "adapter.run with no suites should return total 0")
  _assert_eq(result.failed, false, "adapter.run with no suites should not fail")
end

-- 新 JSON 形状(files[path].exec/hit 行号集合)经 collect JSON 往返后行号键是
-- 字符串,report_io 必须 tonumber 再喂 analyzer——字符串与数字比较会直接崩。
local function _test_report_io_coerces_string_line_keys_from_collect_json()
  local in_json = env_lib.make_temp_path("crap_report_io_probe", ".json")
  local ok_write, write_err = fs_lib.write_file(in_json, json_writer.encode({
    project_root = ".",
    project_name = "probe",
    source_roots = { "src" },
    coverage_result = {
      files = {
        ["src/probe.lua"] = { exec = { ["1"] = true, ["2"] = true }, hit = { ["1"] = true } },
      },
      lanes = {},
      coverage_available = true,
      report_path = "build/luacov.crap.report.out",
    },
  }))
  if not ok_write then
    error(write_err)
  end

  local collected = report_io.load_collect(in_json)
  fs_lib.remove_path(in_json)
  assert(type(collected) == "table", "collect JSON should load")
  local entry = collected.coverage_result.files["src/probe.lua"]
  assert(type(entry.exec[1]) == "boolean", "exec line keys must be coerced to numbers")
  assert(type(entry.exec[2]) == "boolean", "exec line keys must be coerced to numbers")
  _assert_eq(entry.exec[3], nil, "lines not present must stay absent")
end

-- #361 P1:report/collect 契约不再真跑 contract 车道(单测各 26-27s,独占 tooling
-- 车道 66%)。改喂 3 文件 fixture 项目(test/fixtures/crap/basic_project):stub
-- adapter 毫秒级落一罐固定 luacov 报告,CLI 真实路径(参数解析 → collect →
-- analyze → 写 JSON → stdout)照常走,只是覆盖输入从「整个车道」换成固定产物。
local function _fixture_config_path()
  return path_lib.join_path(crap.env.cwd, "test/fixtures/crap/basic_project/crap_config.lua")
end

local function _test_cli_report_generates_report_json()
  local out = _buffer()
  local err = _buffer()
  local tmp_out = env_lib.make_temp_path("crap_contract_report", ".json")
  local ok = crap.run({
    "report",
    "--config", _fixture_config_path(),
    "--out", tmp_out,
    "--top", "3",
  }, {
    stdout = out,
    stderr = err,
  })

  assert(ok == true, "cli report should return true: " .. err:text())
  _assert_contains(out:text(), "crap report json:", "report stdout should print report path")
  assert(fs_lib.path_exists(tmp_out), "report json should exist at output path")
  local content = fs_lib.read_file(tmp_out)
  _assert_contains(content, '"functions"', "report json should contain functions array")
  _assert_contains(content, '"crap_score"', "report json should contain crap_score field")
  _assert_contains(content, '"complexity"', "report json should contain complexity field")
  _assert_contains(content, '"hit_line_count"', "report json should contain hit_line_count")
  _assert_contains(content, '"executable_line_count"', "report json should contain executable_line_count")
  _assert_contains(content, "alpha.lua", "report json should score the fixture sources")
  fs_lib.remove_path(tmp_out)
end

local function _test_cli_collect_writes_coverage_json()
  local out = _buffer()
  local err = _buffer()
  local tmp_out = env_lib.make_temp_path("crap_contract_collect", ".json")
  local ok = crap.run({
    "collect",
    "--config", _fixture_config_path(),
    "--out", tmp_out,
  }, {
    stdout = out,
    stderr = err,
  })

  assert(ok == true, "collect should return true: " .. err:text())
  _assert_contains(out:text(), "crap collect json:", "collect stdout should print collect path")
  assert(fs_lib.path_exists(tmp_out), "collect json should exist at output path")
  local content = fs_lib.read_file(tmp_out)
  _assert_contains(content, '"coverage_result"', "collect json should contain coverage_result")
  _assert_contains(content, '"files"', "collect json should contain v0.1.0 files shape")
  _assert_contains(content, '"coverage_available"', "collect json should carry coverage availability")
  _assert_contains(content, "src/alpha.lua", "collect json should carry the fixture file keys")
  fs_lib.remove_path(tmp_out)
end

local function _test_cli_summary_out_prints_resolved_json_path()
  local in_json = env_lib.make_temp_path("crap_summary_input", ".json")
  local ok_write, write_err = fs_lib.write_file(in_json, '{"functions":[]}')
  if not ok_write then
    error(write_err)
  end

  local out = _buffer()
  local summary_out = env_lib.make_temp_path("crap_summary_output", ".json")
  local ok = crap.run({
    "summary",
    "--in-json", in_json,
    "--out", summary_out,
  }, {
    stdout = out,
    stderr = _buffer(),
  })
  fs_lib.remove_path(in_json)

  assert(ok == true, "summary should return true")
  _assert_contains(out:text(), "crap summary json:",
    "summary stdout should print resolved summary json path")
  fs_lib.remove_path(summary_out)
end

-- #361 P8:no_go_binary_references_in_reference_cli 已删——扫描对象是
-- .toolcache/luarocks tree 里的第三方 rock 源码是钉定装载面，文本不受
-- 本仓控制、升级即假红;「go binary 不回潮」由 tools.lock 钉版 + 本仓消费面
-- 契约承担。

local function _test_gate_bar_is_flat_with_no_complexity_exemption()
  -- Anything strictly above the threshold violates, whatever its complexity.
  assert(gate.is_violation({ complexity = 3, crap = 5.5 }, 5.0) == true,
    "crap 5.5 should violate a threshold of 5.0")
  assert(gate.is_violation({ complexity = 5, crap = 5.0 }, 5.0) == false,
    "crap exactly at the threshold should pass")
  -- A high-complexity function gets no exemption: its 100% floor still fails.
  assert(gate.is_violation({ complexity = 8, crap = 8.0 }, 5.0) == true,
    "cx=8 at its full-coverage floor should still violate; it must be split")
end

local function _test_gate_treats_unmeasurable_coverage_as_violation()
  -- #275-③:N/A 计违例。crap 为 null 表示覆盖率不可测,必须按违例算,
  -- 绝不能当 0 分放行。两种形态都要拦:JSON 往返后 null -> nil,analyzer
  -- 内存对象是 json_writer.null 哨兵表。
  assert(gate.is_violation({ complexity = 2, crap = nil }, 5.0) == true,
    "null crap (N/A coverage) must violate the gate")
  assert(gate.is_violation({ complexity = 2, crap = {} }, 5.0) == true,
    "json_writer.null sentinel (table) must violate the gate")
  assert(gate.is_violation({ complexity = 2, crap = 0.0 }, 5.0) == false,
    "measurable 0.0 crap at full coverage passes")
end

local function _test_gate_violations_group_by_file()
  local by_file = gate.violations_by_file({
    { source_path = "src/a.lua", name = "f1", complexity = 8, crap = 9.0 },
    { source_path = "src/a.lua", name = "f2", complexity = 5, crap = 10.0 },
    { source_path = "src/a.lua", name = "ok", complexity = 4, crap = 4.0 },
    { source_path = "src/b.lua", name = "f3", complexity = 3, crap = 7.2 },
  }, 5.0)
  _assert_eq(by_file["src/a.lua"].count, 2, "src/a.lua should have 2 violations")
  _assert_eq(by_file["src/b.lua"].count, 1, "src/b.lua should have 1 violation")
  _assert_eq(gate.total_violations(by_file), 3, "total violations should be 3")
end

local function _test_gate_evaluate_reports_every_violation()
  local by_file = {
    ["src/b.lua"] = { count = 1, functions = { { name = "g", crap = 7.2, complexity = 3 } } },
    ["src/a.lua"] = { count = 2, functions = {
      { name = "f", crap = 9.0, complexity = 8 },
      { name = "h", crap = 12.0, complexity = 5 },
    } },
  }
  local offenders = gate.evaluate(by_file)
  _assert_eq(#offenders, 2, "every file with violations should be reported")
  _assert_eq(offenders[1].source_path, "src/a.lua", "offenders should be sorted by path")
  _assert_eq(offenders[1].count, 2, "offender should carry its violation count")
  _assert_eq(offenders[1].functions[1].name, "h", "functions should sort by descending crap")
end

local function _test_gate_exposes_no_baseline_escape_hatch()
  assert(gate.render_baseline == nil, "gate must not offer a baseline renderer")
  assert(gate.ceiling == nil, "gate must not offer a complexity-aware ceiling")
  local baseline_path = path_lib.join_path(crap.env.repo_root, "tools/packages/crap/crap_gate_baseline.lua")
  assert(fs_lib.read_file(baseline_path) == nil, "the per-file ratchet baseline must not exist")
end

-- coverage_tiers.lua 是纯数据,先前零 spec 覆盖(issue #124):改坏了没有任何东西会响。
-- 它的危险不在于取值,而在于顺序与完整性——下面三条契约守的正是这两点。

local function _load_tiers()
  local config = dofile(crap.env.default_tier_config)
  assert(type(config) == "table" and type(config.tiers) == "table",
    "tier config must return { tiers = { ... } }")
  return config.tiers
end

-- 归类算法只有一份,在 crap4lua 里(cli.lua 的 _file_tier_index,file-local、不导出)。
-- 这里绝不重抄它:抄出来的镜像只会验证它自己——tools.lock 换了 crap4lua 实现(重新钉定
-- 是 re-baseline 事件),镜像照绿,而真实归类可能已经变了,恰好漏掉 #124 要防的那个静默
-- 错判。所以走公开 seam:喂一份合成报告给 `crap summary`,从它的 tier 行读回归类结果。
--
-- 不传 --tier-config:让它走 env.default_tier_config,契约守的正是生产接线里的那份配置。
local function _tier_rows_for(source_paths)
  local functions = {}
  for _, path in ipairs(source_paths) do
    functions[#functions + 1] = {
      source_path = path,
      executable_line_count = 1,
      hit_line_count = 1,
    }
  end

  local in_json = env_lib.make_temp_path("crap_tier_probe_in", ".json")
  local out_json = env_lib.make_temp_path("crap_tier_probe_out", ".json")
  local ok_write, write_err = fs_lib.write_file(in_json, json_writer.encode({ functions = functions }))
  if not ok_write then
    error(write_err)
  end

  local err = _buffer()
  local ok = crap.run({
    "summary",
    "--in-json", in_json,
    "--out", out_json,
  }, {
    stdout = _buffer(),
    stderr = err,
  })
  fs_lib.remove_path(in_json)
  assert(ok == true, "crap summary should classify the probe report: " .. err:text())

  local payload = json_reader.decode(fs_lib.read_file(out_json))
  fs_lib.remove_path(out_json)
  assert(type(payload) == "table" and type(payload.tiers) == "table",
    "summary json must expose tier rows")
  return payload.tiers
end

-- 单文件探针:真实算法把这个 path 归到哪个 tier?一个 tier 都没 +1 就是 nil
-- (= 掉进 uncategorized,被静默吞掉)。
local function _tier_row_of(source_path)
  for _, row in ipairs(_tier_rows_for({ source_path })) do
    if (row.file_count or 0) > 0 then
      return row
    end
  end
  return nil
end

-- 顺序敏感:src/ui/manager/ 是 src/ui/ 的子路径,谁在前谁命中。把 ui_host_adapter
-- 挪到 ui_surface 之后,manager 文件就会静默改判到 ui_surface(阈值 0.60 -> 0.65),
-- 而聚合照样出结果、不报错。
local function _test_tier_order_keeps_ui_manager_out_of_ui_surface()
  local manager = _tier_row_of("src/ui/manager/board_manager.lua")
  assert(manager ~= nil, "a src/ui/manager file must land in some tier")
  _assert_eq(manager.name, "ui_host_adapter",
    "src/ui/manager must match ui_host_adapter first; ui_host_adapter has to precede ui_surface")
  _assert_eq(manager.threshold, 0.60, "ui_host_adapter keeps the host_bridge-grade threshold")

  local surface = _tier_row_of("src/ui/panel/shop_panel.lua")
  assert(surface ~= nil and surface.name == "ui_surface",
    "a plain src/ui file still belongs to ui_surface")
end

-- 完整性:src/ 下任何 .lua 都必须落进某个 tier。新开一层(例如 src/audio/)而忘了
-- 挂 tier,聚合不会报错——那些文件只是无声地掉进 uncategorized,再也不计入门槛。
-- 绿路径只跑一次 summary:tier 行的 file_count 之和少于文件总数,就说明有文件掉出去了。
local function _test_every_src_file_lands_in_a_tier()
  local src_root = path_lib.join_path(crap.env.cwd, "src")
  local files = proc_lib.collect_lua_files(src_root) or {}
  assert(#files > 0, "src/ should contain lua files")

  local relatives = {}
  for _, absolute in ipairs(files) do
    local relative = path_lib.normalize_path(absolute):match("(src/.*)$")
    if relative then
      relatives[#relatives + 1] = relative
    end
  end
  _assert_eq(#relatives, #files, "every collected src file should yield a src/-relative path")

  local classified = 0
  for _, row in ipairs(_tier_rows_for(relatives)) do
    classified = classified + (row.file_count or 0)
  end

  if classified < #relatives then
    -- 已经红了,再逐个探针把掉队的文件点名出来(只有红路径才付这份钱)。
    local orphans = {}
    for _, relative in ipairs(relatives) do
      if _tier_row_of(relative) == nil then
        orphans[#orphans + 1] = relative
      end
    end
    error("every src/ file must map to a tier, else it silently falls into uncategorized; orphans: "
      .. table.concat(orphans, ", "))
  end
end

local function _test_tier_shape_is_wellformed()
  local tiers = _load_tiers()
  assert(#tiers > 0, "tier config must define at least one tier")

  local seen = {}
  for _, tier in ipairs(tiers) do
    assert(type(tier.name) == "string" and tier.name ~= "", "each tier needs a name")
    assert(seen[tier.name] == nil, "tier names must be unique; duplicated: " .. tostring(tier.name))
    seen[tier.name] = true

    assert(type(tier.threshold) == "number" and tier.threshold > 0 and tier.threshold <= 1,
      "tier " .. tier.name .. " needs a threshold in (0, 1]; got " .. tostring(tier.threshold))

    assert(type(tier.includes) == "table" and #tier.includes > 0,
      "tier " .. tier.name .. " needs at least one include prefix")
    for _, prefix in ipairs(tier.includes) do
      assert(prefix:sub(1, 4) == "src/",
        "tier " .. tier.name .. " include must be under src/; got " .. tostring(prefix))
      assert(prefix:sub(-1) == "/",
        "tier " .. tier.name .. " include must end with / so it cannot prefix-match a sibling; got " .. tostring(prefix))
    end
  end
end

return {
  name = "crap_tooling_contract",
  tests = {
    { name = "env_preserves_monopoly_paths", run = _test_env_preserves_monopoly_path_convention },
    { name = "install_eggy_package_paths_only_installs_canonical_repo_patterns", run = _test_install_eggy_package_paths_only_installs_canonical_repo_patterns },
    { name = "luacov_adapter_resolves_lanes_and_delegates_run", run = _test_luacov_adapter_resolves_lanes_and_delegates_run },
    { name = "report_io_coerces_string_line_keys_from_collect_json", run = _test_report_io_coerces_string_line_keys_from_collect_json },
    { name = "cli_report_generates_report_json", run = _test_cli_report_generates_report_json },
    { name = "cli_collect_writes_coverage_json", run = _test_cli_collect_writes_coverage_json },
    { name = "cli_summary_out_prints_resolved_json_path", run = _test_cli_summary_out_prints_resolved_json_path },
    { name = "gate_bar_is_flat_with_no_complexity_exemption", run = _test_gate_bar_is_flat_with_no_complexity_exemption },
    { name = "gate_treats_unmeasurable_coverage_as_violation", run = _test_gate_treats_unmeasurable_coverage_as_violation },
    { name = "gate_violations_group_by_file", run = _test_gate_violations_group_by_file },
    { name = "gate_evaluate_reports_every_violation", run = _test_gate_evaluate_reports_every_violation },
    { name = "gate_exposes_no_baseline_escape_hatch", run = _test_gate_exposes_no_baseline_escape_hatch },
    { name = "tier_order_keeps_ui_manager_out_of_ui_surface", run = _test_tier_order_keeps_ui_manager_out_of_ui_surface },
    { name = "every_src_file_lands_in_a_tier", run = _test_every_src_file_lands_in_a_tier },
    { name = "tier_shape_is_wellformed", run = _test_tier_shape_is_wellformed },
  },
}
