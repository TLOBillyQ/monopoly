--- 解析 busted JUnit XML 输出，落出测试名清单与慢测试 top N。
--- 仅用于 spec 重构期间的基线对比，Step 7 删除。

package.path = package.path .. ";./?.lua;./?/init.lua"

local common = require("tools.shared.lib.common")

local M = {}

local function _parse_args(args)
  local options = {
    xml = "tools/refactor/baseline/behavior.xml",
    tests_out = "tools/refactor/baseline/behavior_tests.txt",
    slow_out = "tools/refactor/baseline/behavior_slow.txt",
    slow_top = 50,
  }
  local index = 1
  while index <= #args do
    local arg_value = args[index]
    if arg_value == "--xml" then
      options.xml = args[index + 1]
      index = index + 2
    elseif arg_value == "--tests-out" then
      options.tests_out = args[index + 1]
      index = index + 2
    elseif arg_value == "--slow-out" then
      options.slow_out = args[index + 1]
      index = index + 2
    elseif arg_value == "--slow-top" then
      options.slow_top = tonumber(args[index + 1]) or 50
      index = index + 2
    else
      index = index + 1
    end
  end
  return options
end

--- 反转义 XML attribute 中常见实体。
local function _xml_unescape(text)
  if text == nil then
    return ""
  end
  return (text
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&quot;", "\"")
    :gsub("&apos;", "'")
    :gsub("&amp;", "&"))
end

--- 解析 XML 中所有 <testcase ... /> 或 <testcase ...>...</testcase> 标签。
--- 返回 list，每项 {classname, name, time}。
--- 抓 attribute 值，支持单引号或双引号包裹。
--- 用前导空格（或行首）作为词边界，避免 "name" 误匹配 "classname"。
local function _attr(attrs, key)
  local prefixed = "[%s\"\']" .. key
  local s = " " .. attrs
  local v = s:match(prefixed .. "%s*=%s*\"([^\"]*)\"")
  if v ~= nil then return v end
  v = s:match(prefixed .. "%s*=%s*'([^']*)'")
  return v
end

function M.parse_testcases(xml_text)
  local testcases = {}
  local pattern = "<testcase%s+([^>]-)/?>"
  for attrs in xml_text:gmatch(pattern) do
    local classname = _attr(attrs, "classname") or ""
    local name = _attr(attrs, "name") or ""
    local time_str = _attr(attrs, "time") or "0"
    testcases[#testcases + 1] = {
      classname = _xml_unescape(classname),
      name = _xml_unescape(name),
      time = tonumber(time_str) or 0,
    }
  end
  return testcases
end

local function _ensure_parent(path)
  local parent = path:match("^(.+)/[^/]+$")
  if parent ~= nil and parent ~= "" then
    common.ensure_dir(parent)
  end
end

local function _write_text(path, lines)
  _ensure_parent(path)
  local content = table.concat(lines, "\n")
  if #lines > 0 then
    content = content .. "\n"
  end
  local ok = common.write_file(path, content)
  if ok == nil then
    error("write failed: " .. path)
  end
end

function M.run(args)
  local options = _parse_args(args or {})
  local xml_text = common.read_file(options.xml)
  if xml_text == nil then
    error("baseline XML not found: " .. options.xml)
  end

  local testcases = M.parse_testcases(xml_text)
  io.write(string.format("parsed %d testcases from %s\n", #testcases, options.xml))

  -- busted JUnit 输出里 classname 是 spec 文件路径 + 行号，对迁移对比无用；
  -- name 字段已包含 describe block 前缀（"<describe> <it>"），可直接用。
  local tests_lines = {}
  for _, tc in ipairs(testcases) do
    tests_lines[#tests_lines + 1] = tc.name
  end
  table.sort(tests_lines)
  _write_text(options.tests_out, tests_lines)
  io.write(string.format("wrote %d test names → %s\n", #tests_lines, options.tests_out))

  local sorted_by_time = {}
  for _, tc in ipairs(testcases) do
    sorted_by_time[#sorted_by_time + 1] = tc
  end
  table.sort(sorted_by_time, function(a, b)
    return a.time > b.time
  end)
  local slow_lines = {}
  local top_n = math.min(options.slow_top, #sorted_by_time)
  for i = 1, top_n do
    local tc = sorted_by_time[i]
    slow_lines[#slow_lines + 1] = string.format(
      "%.4fs\t%s",
      tc.time,
      tc.name
    )
  end
  _write_text(options.slow_out, slow_lines)
  io.write(string.format("wrote top %d slow tests → %s\n", top_n, options.slow_out))

  return {
    total = #testcases,
    tests_out = options.tests_out,
    slow_out = options.slow_out,
  }
end

if arg ~= nil and arg[0] and arg[0]:match("extract_baseline%.lua$") then
  M.run(arg)
end

return M
