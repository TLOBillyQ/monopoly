local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir(script_path)
  local normalized = _normalize_path(script_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local _raw_script_path = arg and arg[0] or "scripts/loc.lua"
local _entry_script_dir = _script_dir(_raw_script_path)
local _entry_parent_dir = _entry_script_dir:match("^(.*)/[^/]+$") or "."
package.path = _entry_script_dir .. "/?.lua;"
  .. _entry_script_dir .. "/?/?.lua;"
  .. _entry_parent_dir .. "/?.lua;"
  .. _entry_parent_dir .. "/?/?.lua;"
  .. package.path

local bootstrap = require("bootstrap")
local env = bootstrap.install(_raw_script_path)
local common = require("lib.common")
local json_writer = require("lib.json_writer")
local loc_counter = require("lib.loc_counter")

local _blob_stats_cache = {}

local function _println(text)
  print(tostring(text or ""))
end

local function _run_git(args, git_root)
  local command = { "git", "-C", git_root }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return common.run_command(command)
end

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _split_lines(text)
  local lines = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function _command_exists(name)
  local result = common.run_command("command -v " .. tostring(name))
  return result.ok and _trim(result.output) ~= ""
end

local function _get_git_root()
  local result = _run_git({ "rev-parse", "--show-toplevel" }, env.repo_root)
  if not result.ok then
    return nil, "✗ 无法获取 git 仓库根目录"
  end
  local output = _trim(result.output)
  if output == "" then
    return nil, "✗ 无法获取 git 仓库根目录"
  end
  return common.normalize_path(output)
end

local function _get_commits(git_root)
  local result = _run_git({ "log", "--since=3 days ago", "--format=%H|%ci|%s", "--reverse" }, git_root)
  if not result.ok then
    return {}
  end

  local commits = {}
  for _, line in ipairs(_split_lines(result.output)) do
    local normalized = _trim(line)
    if normalized ~= "" and normalized:find("|", 1, true) ~= nil then
      local full_hash, date_text, message = normalized:match("^([^|]+)|([^|]+)|(.+)$")
      if full_hash ~= nil then
        commits[#commits + 1] = {
          hash = full_hash:sub(1, 8),
          full_hash = full_hash,
          date = date_text,
          message = message,
        }
      end
    end
  end
  return commits
end

local function _write_temp_lines(lines)
  local path = common.make_temp_path("git_blob_batch", ".txt")
  local ok, err = common.write_file(path, table.concat(lines, "\n") .. "\n")
  if not ok then
    return nil, err
  end
  return path
end

local function _list_commit_lua_blobs(commit_hash, git_root)
  local result = _run_git({ "ls-tree", "-r", commit_hash, "src", "tests" }, git_root)
  if not result.ok then
    return {}
  end

  local entries = {}
  for _, line in ipairs(_split_lines(result.output)) do
    local object_type, object_id, file_path = line:match("^%d+%s+(%S+)%s+([0-9a-f]+)%s+(.+)$")
    if object_type == "blob" and file_path ~= nil and file_path:match("%.lua$") ~= nil then
      local bucket = nil
      if file_path:match("^src/") ~= nil then
        bucket = "src"
      elseif file_path:match("^tests/") ~= nil then
        bucket = "tests"
      end

      if bucket ~= nil then
        entries[#entries + 1] = {
          bucket = bucket,
          object_id = object_id,
          file_path = file_path,
        }
      end
    end
  end

  return entries
end

local function _parse_cat_file_batch(output, object_ids)
  local stats_by_id = {}
  local cursor = 1

  for _, object_id in ipairs(object_ids or {}) do
    local header_end = output:find("\n", cursor, true)
    if header_end == nil then
      return nil, "git cat-file batch output ended unexpectedly"
    end

    local header = output:sub(cursor, header_end - 1)
    local actual_id, object_type, size_text = header:match("^([0-9a-f]+)%s+(%S+)%s+(%d+)$")
    if actual_id == nil then
      return nil, "unexpected git cat-file header: " .. tostring(header)
    end
    if actual_id ~= object_id then
      return nil, "git cat-file batch order mismatch: expected " .. tostring(object_id) .. " got " .. tostring(actual_id)
    end
    if object_type ~= "blob" then
      return nil, "git cat-file returned non-blob object: " .. tostring(actual_id)
    end

    local size = common.to_integer(size_text)
    if size == nil then
      return nil, "invalid git cat-file blob size: " .. tostring(size_text)
    end

    local content_start = header_end + 1
    local content_end = content_start + size - 1
    local content = ""
    if size > 0 then
      content = output:sub(content_start, content_end)
    end

    stats_by_id[object_id] = {
      line_count = loc_counter.count_effective_lines(content),
      has_content = size > 0,
    }

    cursor = content_end + 2
  end

  return stats_by_id
end

local function _populate_blob_stats_cache(object_ids, git_root)
  if #object_ids == 0 then
    return true
  end

  local ids_path, ids_err = _write_temp_lines(object_ids)
  if ids_path == nil then
    return nil, ids_err
  end

  local command = "git -C " .. common.shell_quote(git_root) .. " cat-file --batch < " .. common.shell_quote(ids_path)
  local result = common.run_command(command)
  common.remove_path(ids_path)
  if not result.ok then
    return nil, _trim(result.output) ~= "" and _trim(result.output) or "git cat-file --batch failed"
  end

  local stats_by_id, parse_err = _parse_cat_file_batch(result.output, object_ids)
  if stats_by_id == nil then
    return nil, parse_err
  end

  for object_id, stats in pairs(stats_by_id) do
    _blob_stats_cache[object_id] = stats
  end

  return true
end

local function _accumulate_bucket_totals(entries)
  local src_loc = 0
  local src_files = 0
  local tests_loc = 0
  local tests_files = 0

  for _, entry in ipairs(entries or {}) do
    local stats = _blob_stats_cache[entry.object_id]
    if stats ~= nil and stats.has_content then
      if entry.bucket == "src" then
        src_loc = src_loc + (stats.line_count or 0)
        src_files = src_files + 1
      elseif entry.bucket == "tests" then
        tests_loc = tests_loc + (stats.line_count or 0)
        tests_files = tests_files + 1
      end
    end
  end

  return src_loc, src_files, tests_loc, tests_files
end

local function _populate_blob_stats_cache_slow(entries, commit_hash, git_root)
  for _, entry in ipairs(entries or {}) do
    if _blob_stats_cache[entry.object_id] == nil then
      local content_result = _run_git({ "show", commit_hash .. ":" .. entry.file_path }, git_root)
      if content_result.ok then
        _blob_stats_cache[entry.object_id] = {
          line_count = loc_counter.count_effective_lines(content_result.output),
          has_content = content_result.output ~= "",
        }
      else
        _blob_stats_cache[entry.object_id] = {
          line_count = 0,
          has_content = false,
        }
      end
    end
  end
end

local function _count_loc_at_commit(commit_info, git_root)
  local entries = _list_commit_lua_blobs(commit_info.full_hash, git_root)
  local missing_ids = {}
  local seen_missing = {}
  for _, entry in ipairs(entries) do
    if _blob_stats_cache[entry.object_id] == nil and not seen_missing[entry.object_id] then
      seen_missing[entry.object_id] = true
      missing_ids[#missing_ids + 1] = entry.object_id
    end
  end

  if #missing_ids > 0 then
    local cache_ok = _populate_blob_stats_cache(missing_ids, git_root)
    if not cache_ok then
      _populate_blob_stats_cache_slow(entries, commit_info.full_hash, git_root)
    end
  end

  local src_loc, src_files, tests_loc, tests_files = _accumulate_bucket_totals(entries)
  return {
    hash = commit_info.hash,
    date = commit_info.date,
    message = commit_info.message,
    src_loc = src_loc,
    src_files = src_files,
    tests_loc = tests_loc,
    tests_files = tests_files,
    total_loc = src_loc + tests_loc,
    total_files = src_files + tests_files,
  }
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
  if not _command_exists("gnuplot") then
    _println("⚠ 未安装 gnuplot，跳过图表生成")
    _println("  可选安装: brew install gnuplot")
    return true
  end

  local data_path = common.make_temp_path("loc_chart", ".tsv")
  local script_path = common.make_temp_path("loc_chart", ".gp")

  local data_ok, data_err = _write_chart_data(data, data_path)
  if not data_ok then
    _println("⚠ 写入图表数据失败: " .. tostring(data_err))
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
    _println("⚠ 写入图表脚本失败: " .. tostring(write_err))
    common.remove_path(data_path)
    return true
  end

  local result = common.run_command({ "gnuplot", script_path })
  common.remove_path(data_path)
  common.remove_path(script_path)

  if not result.ok then
    _println("⚠ 图表生成失败，已跳过 PNG 输出")
    if _trim(result.output) ~= "" then
      _println(_trim(result.output))
    end
    return true
  end

  _println("图表已保存到: " .. common.normalize_path(output_path))
  return true
end

local function _write_json(data, output_path)
  local ok, err = common.write_file(output_path, json_writer.encode(data) .. "\n")
  if not ok then
    return nil, err
  end
  return true
end

local function main()
  local start_clock = os.clock()

  _println(string.rep("=", 60))
  _println("src/ 和 tests/ 目录有效代码行数变化分析（Lua 版）")
  _println("平台: " .. (common.is_windows() and "Windows" or (common.is_macos() and "macOS" or "Linux/Unix")) .. " | Lua: " .. tostring(_VERSION or "Lua"))
  _println(string.rep("=", 60))

  local git_version = common.run_command({ "git", "--version" })
  if not git_version.ok then
    io.stderr:write("✗ 未找到 git 命令，请确保已安装 git 并添加到 PATH\n")
    return 1
  end
  _println("Git: " .. _trim(git_version.output))
  _println("")

  _println("正在获取最近3天提交...")
  local git_root, git_root_err = _get_git_root()
  if git_root == nil then
    io.stderr:write(tostring(git_root_err), "\n")
    return 1
  end

  local commits = _get_commits(git_root)
  _println("共找到 " .. tostring(#commits) .. " 个提交")
  if #commits == 0 then
    _println("没有找到最近三天的提交！")
    return 0
  end

  _println("")
  _println("开始分析每个提交的代码行数...")
  _println(string.rep("-", 60))

  local data = {}
  for index, commit in ipairs(commits) do
    local result = _count_loc_at_commit(commit, git_root)
    data[#data + 1] = result
    _println(string.format(
      "[%3d/%3d] %s | src: %5d lines/%3d files | tests: %5d lines/%3d files | %s",
      index,
      #commits,
      tostring(result.hash),
      result.src_loc,
      result.src_files,
      result.tests_loc,
      result.tests_files,
      tostring(result.message or ""):sub(1, 30)
    ))
  end

  _println(string.rep("-", 60))

  local output_dir = env.script_dir
  local json_path = common.join_path(output_dir, "loc_data.json")
  local chart_path = common.join_path(output_dir, "loc_trend.png")

  local json_ok, json_err = _write_json(data, json_path)
  if not json_ok then
    io.stderr:write(tostring(json_err), "\n")
    return 1
  end
  _println("")
  _println("数据已保存到: " .. json_path)
  _println("")
  _println("正在生成折线图...")
  _generate_chart(data, chart_path)

  local elapsed = os.clock() - start_clock
  _println("")
  _println(string.rep("=", 60))
  _println("Analysis Summary")
  _println(string.rep("=", 60))

  if #data > 0 then
    local first = data[1]
    local last = data[#data]
    _println("Period: " .. tostring(first.date):sub(1, 10) .. " ~ " .. tostring(last.date):sub(1, 10))
    _println("Commits Analyzed: " .. tostring(#data))
    _println("")
    _println("src/ Directory:")
    local src_change = last.src_loc - first.src_loc
    _println("  Start: " .. tostring(first.src_loc) .. " lines  |  End: " .. tostring(last.src_loc) .. " lines")
    if first.src_loc > 0 then
      _println(string.format("  Change: %+d lines (%.1f%%)", src_change, (src_change / first.src_loc) * 100))
    else
      _println(string.format("  Change: %+d lines", src_change))
    end
    _println("")
    _println("tests/ Directory:")
    local tests_change = last.tests_loc - first.tests_loc
    _println("  Start: " .. tostring(first.tests_loc) .. " lines  |  End: " .. tostring(last.tests_loc) .. " lines")
    if first.tests_loc > 0 then
      _println(string.format("  Change: %+d lines (%.1f%%)", tests_change, (tests_change / first.tests_loc) * 100))
    else
      _println(string.format("  Change: %+d lines", tests_change))
    end
    _println("")
    _println("Total (src + tests): " .. tostring(last.total_loc) .. " lines")
  end
  _println(string.format("Elapsed Time: %.1fs", elapsed))

  return 0
end

os.exit(main())
