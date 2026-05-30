local _raw_script_path = arg and arg[0] or "tools/quality/loc.lua"

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/loc.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local env = bootstrap.install(_raw_script_path)
local common = require("shared.lib.common")
local json_writer = require("shared.lib.json_writer")
local loc_history = require("shared.lib.loc_history")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local _DEFAULT_PRINT_SINK = function(msg) print(tostring(msg)) end
local _print_sink = _DEFAULT_PRINT_SINK
local _quiet = false

local function _println(text)
  _print_sink(tostring(text or ""))
end

local function _emit_narrative(text)
  if not _quiet then
    _print_sink(tostring(text or ""))
  end
end

local function _set_quiet(value)
  _quiet = value == true
end

local function _set_print_sink_for_tests(sink)
  _print_sink = sink or _DEFAULT_PRINT_SINK
end

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _xml_escape(text)
  local source = tostring(text or "")
  source = source:gsub("&", "&amp;")
  source = source:gsub("<", "&lt;")
  source = source:gsub(">", "&gt;")
  source = source:gsub("\"", "&quot;")
  return source
end

local function _series_bounds(rows, key)
  local min_value, max_value
  for _, row in ipairs(rows) do
    local value = tonumber(row[key]) or 0
    if min_value == nil or value < min_value then
      min_value = value
    end
    if max_value == nil or value > max_value then
      max_value = value
    end
  end
  if min_value == nil then
    return 0, 1
  end
  if max_value == min_value then
    max_value = min_value + 1
  end
  return min_value, max_value
end

local function _render_panel(rows, key, title, y_top, y_bottom, x_left, x_right, color)
  local panel_lines = {}
  local height = y_bottom - y_top
  local width = x_right - x_left
  local count = #rows
  local min_value, max_value = _series_bounds(rows, key)
  local value_range = max_value - min_value

  local function _x_at(index)
    if count <= 1 then
      return x_left + width / 2
    end
    return x_left + (index - 1) / (count - 1) * width
  end

  local function _y_at(value)
    local normalized = (value - min_value) / value_range
    return y_bottom - normalized * height
  end

  panel_lines[#panel_lines + 1] = string.format(
    '<text x="%d" y="%d" class="title">%s</text>',
    x_left, y_top - 12, _xml_escape(title)
  )

  panel_lines[#panel_lines + 1] = string.format(
    '<rect x="%d" y="%d" width="%d" height="%d" class="frame"/>',
    x_left, y_top, width, height
  )

  for tick = 0, 4 do
    local fraction = tick / 4
    local y = y_top + fraction * height
    local label_value = math.floor(max_value - fraction * value_range + 0.5)
    panel_lines[#panel_lines + 1] = string.format(
      '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" class="grid"/>',
      x_left, y, x_right, y
    )
    panel_lines[#panel_lines + 1] = string.format(
      '<text x="%d" y="%.1f" class="axis y">%d</text>',
      x_left - 8, y + 4, label_value
    )
  end

  if count > 0 then
    local x_tick_count = math.min(count, 8)
    for tick_index = 1, x_tick_count do
      local row_index
      if x_tick_count == 1 then
        row_index = 1
      else
        row_index = 1 + math.floor((tick_index - 1) * (count - 1) / (x_tick_count - 1) + 0.5)
      end
      if row_index < 1 then row_index = 1 end
      if row_index > count then row_index = count end
      local label = tostring(rows[row_index].date or ""):sub(6, 10)
      local x = _x_at(row_index)
      panel_lines[#panel_lines + 1] = string.format(
        '<text x="%.1f" y="%d" class="axis x">%s</text>',
        x, y_bottom + 18, _xml_escape(label)
      )
    end
  end

  local points = {}
  for index, row in ipairs(rows) do
    local value = tonumber(row[key]) or 0
    points[#points + 1] = string.format("%.1f,%.1f", _x_at(index), _y_at(value))
  end
  if #points > 0 then
    panel_lines[#panel_lines + 1] = string.format(
      '<polyline points="%s" fill="none" stroke="%s" stroke-width="2"/>',
      table.concat(points, " "), color
    )
  end

  for index, row in ipairs(rows) do
    local value = tonumber(row[key]) or 0
    panel_lines[#panel_lines + 1] = string.format(
      '<circle cx="%.1f" cy="%.1f" r="3" fill="%s"><title>%s: %d</title></circle>',
      _x_at(index), _y_at(value), color, _xml_escape(tostring(row.date or "")), value
    )
  end

  return table.concat(panel_lines, "\n")
end

local function _render_svg(rows, options)
  options = options or {}
  rows = rows or {}
  local width = 1600
  local height = 1200
  local x_left = 100
  local x_right = width - 40

  local style = table.concat({
    "<style>",
    "  .title { font: 18px ui-monospace, monospace; fill: #1a1a1a; }",
    "  .axis  { font: 12px ui-monospace, monospace; fill: #444; }",
    "  .axis.y { text-anchor: end; }",
    "  .axis.x { text-anchor: middle; }",
    "  .frame { fill: #fafafa; stroke: #888; stroke-width: 1; }",
    "  .grid  { stroke: #ddd; stroke-width: 1; stroke-dasharray: 4 4; }",
    "  .header { font: 14px ui-monospace, monospace; fill: #222; }",
    "  .footer { font: 11px ui-monospace, monospace; fill: #666; }",
    "</style>",
  }, "\n")

  local header = string.format(
    '<text x="%d" y="30" class="header">LOC Daily Trend (%d days, %s ~ %s)</text>',
    x_left, options.days or 0,
    _xml_escape(tostring(options.first_day or "")),
    _xml_escape(tostring(options.last_day or ""))
  )

  local src_panel = _render_panel(rows, "src_loc", "src/ Lines of Code",
    80, 540, x_left, x_right, "#2a6fb8")
  local tests_panel = _render_panel(rows, "tests_loc", "spec/ Lines of Code",
    640, 1100, x_left, x_right, "#b8612a")

  local footer = string.format(
    '<text x="%d" y="%d" class="footer">generated %s | %d data points</text>',
    x_left, height - 20,
    _xml_escape(os.date("%Y-%m-%d %H:%M:%S")), #rows
  )

  return table.concat({
    '<?xml version="1.0" encoding="UTF-8"?>',
    string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">',
      width, height, width, height),
    style,
    header,
    src_panel,
    tests_panel,
    footer,
    "</svg>",
    "",
  }, "\n")
end

local function _write_json(data, output_path)
  local ok, err = common.write_file(output_path, json_writer.encode(data) .. "\n")
  if not ok then
    return nil, err
  end
  return true
end

local function _write_svg(rows, output_path, options)
  local svg = _render_svg(rows, options)
  local ok, err = common.write_file(output_path, svg)
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

local function _parse_args(args)
  local options = { days = 14 }
  local index = 1
  while index <= #args do
    local token = args[index]
    if token == "--quiet" then
      _set_quiet(true)
    elseif token == "--days" then
      index = index + 1
      local value = tonumber(args[index])
      if value and value > 0 then
        options.days = math.floor(value)
      end
    else
      local inline = token:match("^%-%-days=(%d+)$")
      if inline then
        local value = tonumber(inline)
        if value and value > 0 then
          options.days = math.floor(value)
        end
      end
    end
    index = index + 1
  end
  return options
end

local function main(args)
  args = args or {}
  local options = _parse_args(args)
  local start_time = os.time()

  _emit_narrative(string.rep("=", 60))
  _emit_narrative(_text(
    "src/ 和 spec/ 目录有效代码行数按天统计（Lua 版）",
    "Effective LOC daily trend for src/ and spec/ (Lua)"
  ))
  _emit_narrative(_text("平台", "Platform") .. ": "
    .. (common.is_windows() and "Windows" or (common.is_macos() and "macOS" or "Linux/Unix"))
    .. " | Lua: " .. tostring(_VERSION or "Lua"))
  _emit_narrative(_text("窗口", "Window") .. ": "
    .. tostring(options.days) .. _text(" 天", " days"))
  _emit_narrative(string.rep("=", 60))

  local git_version = common.run_command({ "git", "--version" })
  if not git_version.ok then
    io.stderr:write(_text(
      "✗ 未找到 git 命令，请确保已安装 git 并添加到 PATH",
      "✗ git command was not found, make sure git is installed and available in PATH"
    ), "\n")
    return 1
  end
  _emit_narrative("Git: " .. _trim(git_version.output))
  _emit_narrative("")

  _emit_narrative(_text("正在按天扫描提交...", "Scanning commits by day..."))
  local git_root, git_root_err = _get_git_root()
  if git_root == nil then
    io.stderr:write(tostring(git_root_err), "\n")
    return 1
  end

  local history_result, history_err = loc_history.count_history({
    git_root = git_root,
    days = options.days,
  })
  if history_result == nil then
    io.stderr:write(tostring(history_err), "\n")
    return 1
  end

  local rows = history_result.rows or {}
  _emit_narrative(_text("共得到 ", "Got ") .. tostring(#rows) .. _text(" 个日数据点", " daily data points"))
  if #rows == 0 then
    _println(_text("最近 ", "No commits found in the last ") .. tostring(options.days)
      .. _text(" 天没有找到提交。", " days."))
    return 0
  end

  local output_dir = common.join_path(git_root, "tmp")
  local json_path = common.join_path(output_dir, "loc_data.json")
  local svg_path = common.join_path(output_dir, "loc_trend.svg")

  local json_ok, json_err = _write_json(rows, json_path)
  if not json_ok then
    io.stderr:write(tostring(json_err), "\n")
    return 1
  end
  _emit_narrative("")
  _println(_text("数据已保存到: ", "Data saved to: ") .. json_path)

  local first = rows[1]
  local last = rows[#rows]
  local svg_ok, svg_err = _write_svg(rows, svg_path, {
    days = options.days,
    first_day = first.date,
    last_day = last.date,
  })
  if not svg_ok then
    io.stderr:write(tostring(svg_err), "\n")
    return 1
  end
  _println(_text("图表已保存到: ", "Chart saved to: ") .. svg_path)

  local elapsed = os.time() - start_time
  _emit_narrative("")
  _emit_narrative(string.rep("=", 60))
  _println(_text("分析摘要", "Analysis Summary"))
  _emit_narrative(string.rep("=", 60))
  _println(_text("周期", "Period") .. ": " .. tostring(first.date) .. " ~ " .. tostring(last.date))
  _println(_text("统计天数", "Days analyzed") .. ": " .. tostring(#rows))
  _emit_narrative("")
  local function _print_loc_summary(label_zh, label_en, start_loc, end_loc)
    _println(_text(label_zh, label_en) .. ":")
    local change = end_loc - start_loc
    _println("  " .. _text("起始", "Start") .. ": " .. tostring(start_loc) .. " lines  |  "
      .. _text("结束", "End") .. ": " .. tostring(end_loc) .. " lines")
    if start_loc > 0 then
      _println(string.format("  %s: %+d lines (%.1f%%)", _text("变化", "Change"), change, (change / start_loc) * 100))
    else
      _println(string.format("  %s: %+d lines", _text("变化", "Change"), change))
    end
    _emit_narrative("")
  end

  _print_loc_summary("src/ 目录", "src/ Directory", first.src_loc, last.src_loc)
  _print_loc_summary("spec/ 目录", "spec/ Directory", first.tests_loc, last.tests_loc)
  _println(_text("总计（src + spec）", "Total (src + spec)") .. ": " .. tostring(last.total_loc) .. " lines")
  _println(string.format("%s: %.1fs", _text("耗时", "Elapsed time"), elapsed))

  return 0
end

local M = {
  main = main,
  _emit_narrative = _emit_narrative,
  _set_quiet = _set_quiet,
  _set_print_sink_for_tests = _set_print_sink_for_tests,
  _render_svg = _render_svg,
  _parse_args = _parse_args,
}

if ... == "quality.loc" then
  return M
end

os.exit(main(arg))
