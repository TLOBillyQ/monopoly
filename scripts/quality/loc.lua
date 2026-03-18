local _raw_script_path = arg and arg[0] or "scripts/quality/loc.lua"

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/quality/loc.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local env = bootstrap.install(_raw_script_path)
local common = require("shared.lib.common")
local json_writer = require("shared.lib.json_writer")
local loc_scan = require("shared.lib.loc_scan")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _println(text)
  print(tostring(text or ""))
end

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _write_chart_data(data, path)
  local lines = { "date\tsrc_loc\ttests_loc" }
  for _, item in ipairs(data or {}) do
    lines[#lines + 1] = table.concat({
      tostring(item.date or ""):sub(1, 19),
      tostring(item.src_loc or 0),
      tostring(item.tests_loc or 0),
    }, "\t")
  end

  local ok, err = common.write_file(path, table.concat(lines, "\n") .. "\n")
  if not ok then
    return nil, err
  end
  return true
end

local function _generate_chart(data, output_path)
  if not common.command_exists("gnuplot") then
    _println(_text("⚠ 未安装 gnuplot，跳过图表生成", "⚠ gnuplot is not installed, skipping chart generation"))
    _println(_text("  可选安装命令: gnuplot", "  Optional install target: gnuplot"))
    return true
  end

  local data_path = common.make_temp_path("loc_chart", ".tsv")
  local script_path = common.make_temp_path("loc_chart", ".gp")

  local data_ok, data_err = _write_chart_data(data, data_path)
  if not data_ok then
    _println(_text("⚠ 写入图表数据失败: ", "⚠ Failed to write chart data: ") .. tostring(data_err))
    return true
  end

  local script_text = table.concat({
    "set terminal pngcairo size 1600,1200 enhanced font ',12'",
    "set output " .. common.shell_quote(output_path),
    "set datafile separator '\t'",
    "set xdata time",
    "set timefmt '%Y-%m-%d %H:%M:%S'",
    "set format x '%m-%d\\n%H:%M'",
    "set grid",
    "set key left top",
    "set multiplot layout 2,1 title 'LOC Trend (Last 3 Days)'",
    "set title 'src/ Directory LOC Trend'",
    "set ylabel 'Lines of Code (LOC)'",
    "plot " .. common.shell_quote(data_path) .. " using 1:2 with linespoints linewidth 2 pointtype 7 title 'src/'",
    "set title 'tests/ Directory LOC Trend'",
    "set xlabel 'Commit Time'",
    "set ylabel 'Lines of Code (LOC)'",
    "plot " .. common.shell_quote(data_path) .. " using 1:3 with linespoints linewidth 2 pointtype 5 title 'tests/'",
    "unset multiplot",
    "",
  }, "\n")
  local write_ok, write_err = common.write_file(script_path, script_text)
  if not write_ok then
    _println(_text("⚠ 写入图表脚本失败: ", "⚠ Failed to write chart script: ") .. tostring(write_err))
    common.remove_path(data_path)
    return true
  end

  local result = common.run_command({ "gnuplot", script_path })
  common.remove_path(data_path)
  common.remove_path(script_path)

  if not result.ok then
    _println(_text("⚠ 图表生成失败，已跳过 PNG 输出", "⚠ Chart generation failed, skipped PNG output"))
    if _trim(result.output) ~= "" then
      _println(_trim(result.output))
    end
    return true
  end

  _println(_text("图表已保存到: ", "Chart saved to: ") .. common.normalize_path(output_path))
  return true
end

local function _write_json(data, output_path)
  local ok, err = common.write_file(output_path, json_writer.encode(data) .. "\n")
  if not ok then
    return nil, err
  end
  return true
end

local function _get_git_root()
  local result = common.run_command({ "git", "-C", env.repo_root, "rev-parse", "--show-toplevel" })
  if not result.ok then
    return nil, _text("无法获取 git 仓库根目录", "Cannot resolve git repository root")
  end

  local output = _trim(result.output)
  if output == "" then
    return nil, _text("无法获取 git 仓库根目录", "Cannot resolve git repository root")
  end
  return common.normalize_path(output)
end

local function main()
  local start_time = os.time()

  _println(string.rep("=", 60))
  _println(_text(
    "src/ 和 tests/ 目录有效代码行数变化分析（Lua 版）",
    "Effective LOC trend for src/ and tests/ (Lua)"
  ))
  _println(_text("平台", "Platform") .. ": "
    .. (common.is_windows() and "Windows" or (common.is_macos() and "macOS" or "Linux/Unix"))
    .. " | Lua: " .. tostring(_VERSION or "Lua"))
  _println(string.rep("=", 60))

  local git_version = common.run_command({ "git", "--version" })
  if not git_version.ok then
    io.stderr:write(_text(
      "✗ 未找到 git 命令，请确保已安装 git 并添加到 PATH",
      "✗ git command was not found, make sure git is installed and available in PATH"
    ), "\n")
    return 1
  end
  _println("Git: " .. _trim(git_version.output))
  _println("")

  _println(_text("正在获取最近 3 天提交...", "Fetching commits from the last 3 days..."))
  local git_root, git_root_err = _get_git_root()
  if git_root == nil then
    io.stderr:write(tostring(git_root_err), "\n")
    return 1
  end

  local history_result, history_err = loc_scan.count_history({
    git_root = git_root,
    since = "3 days ago",
  })
  if history_result == nil then
    io.stderr:write(tostring(history_err), "\n")
    return 1
  end

  local data = history_result.rows or {}
  _println(_text("共找到 ", "Found ") .. tostring(#data) .. _text(" 个提交", " commits"))
  if #data == 0 then
    _println(_text("最近 3 天没有找到提交。", "No commits were found in the last 3 days."))
    return 0
  end

  _println("")
  _println(_text("开始分析每个提交的代码行数...", "Analyzing LOC for each commit..."))
  _println(string.rep("-", 60))

  for index, row in ipairs(data) do
    _println(string.format(
      "[%3d/%3d] %s | src: %5d lines/%3d files | tests: %5d lines/%3d files | %s",
      index,
      #data,
      tostring(row.hash),
      row.src_loc,
      row.src_files,
      row.tests_loc,
      row.tests_files,
      tostring(row.message or ""):sub(1, 30)
    ))
  end

  _println(string.rep("-", 60))

  local output_dir = common.join_path(git_root, "tmp")
  local json_path = common.join_path(output_dir, "loc_data.json")
  local chart_path = common.join_path(output_dir, "loc_trend.png")

  local json_ok, json_err = _write_json(data, json_path)
  if not json_ok then
    io.stderr:write(tostring(json_err), "\n")
    return 1
  end
  _println("")
  _println(_text("数据已保存到: ", "Data saved to: ") .. json_path)
  _println("")
  _println(_text("正在生成折线图...", "Generating line chart..."))
  _generate_chart(data, chart_path)

  local elapsed = os.time() - start_time
  _println("")
  _println(string.rep("=", 60))
  _println(_text("分析摘要", "Analysis Summary"))
  _println(string.rep("=", 60))

  local first = data[1]
  local last = data[#data]
  _println(_text("周期", "Period") .. ": " .. tostring(first.date):sub(1, 10) .. " ~ " .. tostring(last.date):sub(1, 10))
  _println(_text("分析提交数", "Commits analyzed") .. ": " .. tostring(#data))
  _println("")
  _println(_text("src/ 目录", "src/ Directory") .. ":")
  local src_change = last.src_loc - first.src_loc
  _println("  " .. _text("起始", "Start") .. ": " .. tostring(first.src_loc) .. " lines  |  "
    .. _text("结束", "End") .. ": " .. tostring(last.src_loc) .. " lines")
  if first.src_loc > 0 then
    _println(string.format("  %s: %+d lines (%.1f%%)", _text("变化", "Change"), src_change, (src_change / first.src_loc) * 100))
  else
    _println(string.format("  %s: %+d lines", _text("变化", "Change"), src_change))
  end
  _println("")
  _println(_text("tests/ 目录", "tests/ Directory") .. ":")
  local tests_change = last.tests_loc - first.tests_loc
  _println("  " .. _text("起始", "Start") .. ": " .. tostring(first.tests_loc) .. " lines  |  "
    .. _text("结束", "End") .. ": " .. tostring(last.tests_loc) .. " lines")
  if first.tests_loc > 0 then
    _println(string.format("  %s: %+d lines (%.1f%%)", _text("变化", "Change"), tests_change, (tests_change / first.tests_loc) * 100))
  else
    _println(string.format("  %s: %+d lines", _text("变化", "Change"), tests_change))
  end
  _println("")
  _println(_text("总计（src + tests）", "Total (src + tests)") .. ": " .. tostring(last.total_loc) .. " lines")
  _println(string.format("%s: %.1fs", _text("耗时", "Elapsed time"), elapsed))

  return 0
end

os.exit(main())
