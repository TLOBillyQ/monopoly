--- spec/ 重构期间的临时迁移脚本。
--- 解析 spec/suites/<area>/<name>.lua，生成 spec/behavior/<area>/<name>_spec.lua。
--- 在 Step 7 末尾删除（连同 tools/refactor/ 整个目录）。
---
--- 子命令:
---   plan <suite_module>      仅打印将要生成的 it 列表，不写文件
---   migrate <suite_module>   执行迁移，写出对应的 *_spec.lua
---   migrate-dir <area>       批量迁移 spec/suites/<area>/ 下的全部类 A suite
---   diff [--baseline path]   把当前 behavior 测试名与 baseline.txt 对比，输出漂移
---   help                     列出子命令

package.path = package.path .. ";./?.lua;./?/init.lua"

local common = require("tools.shared.lib.common")

local M = {}

-- =============================================================================
-- 工具函数：测试名自然语言化
-- =============================================================================

--- 已知缩写：在转换时保留为大写或目标形式。
local _ACRONYMS = {
  ui = "UI",
  ai = "AI",
  api = "API",
  url = "URL",
  rng = "RNG",
  npc = "NPC",
  cpu = "CPU",
  io = "IO",
  json = "JSON",
  xml = "XML",
  http = "HTTP",
  id = "ID",
  ids = "IDs",
  t1 = "T1",
  t2 = "T2",
  t3 = "T3",
  t4 = "T4",
  t5 = "T5",
  t6 = "T6",
}

--- 把 _test_<suite>_<rest> 中的 <rest> 转成自然语言 it 字符串。
--- 规则：
---   1. 去掉 "_test_<suite>_" 前缀
---   2. 下划线变空格
---   3. 已知缩写恢复大写
---   4. 保留连字符（机械转换不引入），其他原样
function M.naturalize_test_name(test_function_name, suite_name)
  local body = test_function_name
  if body:sub(1, 6) == "_test_" then
    body = body:sub(7)
  end
  if suite_name and suite_name ~= "" then
    local prefix = suite_name .. "_"
    if body:sub(1, #prefix) == prefix then
      body = body:sub(#prefix + 1)
    end
  end
  body = body:gsub("_", " ")
  -- 单词级缩写恢复
  body = body:gsub("(%w+)", function(word)
    local lower = word:lower()
    if _ACRONYMS[lower] ~= nil then
      return _ACRONYMS[lower]
    end
    return word
  end)
  return body
end

-- =============================================================================
-- Lua 源代码解析（文本级，不依赖完整 AST）
-- =============================================================================

--- 找到从 line_index 行开始的 `local function NAME(...)` 函数体的结束行。
--- 用 do/end/then/function 等关键字配对计数。
--- 返回 end 所在行号 (含)。失败返回 nil。
function M.find_function_end(lines, start_line)
  local depth = 0
  local started = false
  for i = start_line, #lines do
    local line = lines[i]
    -- 移除字符串与注释（粗略处理：只处理 -- 单行注释）
    local code = line:gsub("%-%-.*$", "")
    -- 计算关键字（用 word boundary）
    -- 增加深度的关键字: function, do, then, repeat
    -- 减少深度的关键字: end, until
    -- 注意 elseif/else 不影响深度
    for token in code:gmatch("[%a_]+") do
      if token == "function" or token == "do" or token == "then" or token == "repeat" then
        depth = depth + 1
        started = true
      elseif token == "end" or token == "until" then
        depth = depth - 1
        if started and depth == 0 then
          return i
        end
      end
    end
  end
  return nil
end

--- 将 `_test_<full_name>` 函数体解析成 list of {name, body_lines}。
--- body_lines 是函数内部行（不含 `local function ...` 与 `end`）。
function M.extract_test_functions(lines)
  local results = {}
  for i, line in ipairs(lines) do
    local fn_name = line:match("^local%s+function%s+(_test_[%w_]+)%s*%(")
    if fn_name ~= nil then
      local end_line = M.find_function_end(lines, i)
      if end_line == nil then
        error(string.format("cannot find end of function %s starting at line %d", fn_name, i))
      end
      local body = {}
      for j = i + 1, end_line - 1 do
        body[#body + 1] = lines[j]
      end
      results[#results + 1] = {
        name = fn_name,
        start_line = i,
        end_line = end_line,
        body = body,
      }
    end
  end
  return results
end

--- 解析 suite 文件返回的 `tests = { {name=..., run=...}, ... }` 部分。
--- 提取每个 case 的 name 字段（在 tests 列表里的顺序）。
function M.extract_suite_test_order(source_text)
  -- 匹配 `tests = {` 或 `tests={` 直到匹配的 `}`
  local order = {}
  -- 简单做法：抓所有 `name = "..."` 在 return 块内
  local return_idx = source_text:find("return%s*{[^}]*name%s*=", 1)
  if return_idx == nil then
    return order
  end
  local after_return = source_text:sub(return_idx)
  for case_name in after_return:gmatch("name%s*=%s*\"([^\"]+)\"") do
    order[#order + 1] = case_name
  end
  -- 第一个 name 是 suite 自己的 name，跳过
  if #order > 0 then
    table.remove(order, 1)
  end
  return order
end

--- 提取 suite 模块 return 块中的 name 字段（suite 名）。
function M.extract_suite_name(source_text)
  return source_text:match("name%s*=%s*\"([^\"]+)\"")
end

--- 提取文件顶部的 require 与 local 赋值（`tests` 块之前的内容）。
function M.extract_preamble(lines)
  local preamble = {}
  for i, line in ipairs(lines) do
    if line:match("^local%s+function%s+_test_") then
      break
    end
    preamble[#preamble + 1] = line
  end
  return preamble
end

--- 提取测试间的 helper 函数（`local function _xxx` 但非 `_test_` 前缀）。
function M.extract_helpers(lines)
  local helpers = {}
  local i = 1
  while i <= #lines do
    local line = lines[i]
    local fn_name = line:match("^local%s+function%s+([%w_]+)%s*%(")
    if fn_name ~= nil and not fn_name:match("^_test_") then
      local end_line = M.find_function_end(lines, i)
      if end_line == nil then
        i = i + 1
      else
        local body = {}
        for j = i, end_line do
          body[#body + 1] = lines[j]
        end
        helpers[#helpers + 1] = {
          name = fn_name,
          body = body,
          start_line = i,
          end_line = end_line,
        }
        i = end_line + 1
      end
    else
      i = i + 1
    end
  end
  return helpers
end

-- =============================================================================
-- shim opts 解析
-- =============================================================================

--- 解析 spec/behavior/<area>/<name>_spec.lua 中的 shim 调用。
--- 返回 {suite_module, opts_text, leading_text}
--- opts_text 是 `{` 到 `}` 的原文（含），用于后续 ad-hoc 解析。
function M.parse_shim(spec_source)
  -- 匹配 require("spec.behavior._shim").bind(_ENV, "<module>", { ... })
  -- 或不带 opts 的形式
  local module_name = spec_source:match("%.bind%s*%(%s*_ENV%s*,%s*\"([^\"]+)\"")
  if module_name == nil then
    return nil
  end
  -- 抽取 opts 部分（从第一个 `{` 到匹配的 `}`）
  local opts_start = spec_source:find(",%s*{", 1)
  local opts_text = nil
  if opts_start ~= nil then
    -- 找匹配的 }
    local depth = 0
    local i = opts_start
    while i <= #spec_source do
      local ch = spec_source:sub(i, i)
      if ch == "{" then
        depth = depth + 1
      elseif ch == "}" then
        depth = depth - 1
        if depth == 0 then
          opts_text = spec_source:sub(opts_start + 1, i)
          break
        end
      end
      i = i + 1
    end
  end
  -- 抽 leading（在 require shim 之前的内容，比如 turn_timer_policy_coverage 的 logger require）
  local shim_idx = spec_source:find("require%s*%(\"spec%.behavior%._shim\"%)")
  local leading_text = ""
  if shim_idx ~= nil and shim_idx > 1 then
    leading_text = spec_source:sub(1, shim_idx - 1)
  end
  return {
    module = module_name,
    opts_text = opts_text,
    leading = leading_text,
  }
end

--- 从 opts_text 里抽取 reset / fallback_pending / skip / wrap 标志。
function M.parse_opts(opts_text)
  if opts_text == nil then
    return {}
  end
  local opts = {}
  if opts_text:match("reset%s*=%s*true") then
    opts.reset = true
  end
  if opts_text:match("fallback_pending%s*=%s*true") then
    opts.fallback_pending = true
  end
  -- skip = { ["name"] = "reason", ... }
  local skip_block = opts_text:match("skip%s*=%s*({[^}]*})")
  if skip_block ~= nil then
    opts.skip = {}
    for k, v in skip_block:gmatch("%[\"([^\"]+)\"%]%s*=%s*\"([^\"]+)\"") do
      opts.skip[k] = v
    end
  end
  -- wrap = function(run) return function() ...; run() end end
  -- 我们需要保留 wrap 函数体；简化：抓 `wrap = ` 之后到外层 `,` 或 `}` 之前的内容
  if opts_text:match("wrap%s*=") then
    opts.wrap_text = opts_text:match("wrap%s*=%s*(function%(.-end)%s*[,}]")
    -- 上面正则可能贪婪有问题，回退手动解析
    if opts.wrap_text == nil then
      opts.wrap_text = "/*wrap_unparsed*/"
    end
  end
  return opts
end

-- =============================================================================
-- 单 suite 迁移
-- =============================================================================

--- 把一个 suite + spec 文件迁移成新 spec 内容（字符串）。
--- inputs:
---   suite_lines        list[string]，suite 文件的每一行
---   suite_source       string，原始 suite 文件全文
---   shim_info          {module, opts_text, leading}
---   suite_module_path  例 "suites.runtime.runtime_bootstrap"
--- 返回 (new_spec_text, mapping[]) 其中 mapping = {{old, new}, ...}
function M.build_spec_text(suite_lines, suite_source, shim_info)
  local suite_name = M.extract_suite_name(suite_source) or "unnamed_suite"
  local opts = M.parse_opts(shim_info and shim_info.opts_text)
  local test_order = M.extract_suite_test_order(suite_source)
  local test_fns = M.extract_test_functions(suite_lines)
  local fn_by_name = {}
  for _, t in ipairs(test_fns) do
    fn_by_name[t.name] = t
  end

  -- 在 suite 文件里，case 的 name 字段不带 _test_ 前缀；但 fn_by_name 的 key 带 _test_
  -- 通过 `run = _test_xxx` 关联：先查 source 里 `name = "X"` 与 `run = _test_Y` 的配对
  -- 简化策略：用源代码里 case 表的 name 字段的顺序，配上 fn 列表的顺序
  -- 假设 suite 文件 tests 列表里 `{name="X", run=_test_X}` X 与 fn 名 _test_X 一致

  local preamble = M.extract_preamble(suite_lines)
  local helpers = M.extract_helpers(suite_lines)
  -- 注意：preamble 已包含 helpers 文本（因为 helpers 在 _test_ 之前）
  -- 我们不重复输出 helpers，直接用 preamble（它把所有 _test_ 之前的内容都带进来了）

  local out = {}
  -- 导言部分
  if shim_info and shim_info.leading ~= nil and shim_info.leading ~= "" then
    -- 把 spec 自己的 leading（如 logger require）加到最顶
    local leading_trim = shim_info.leading:gsub("\n+$", "")
    if leading_trim ~= "" then
      out[#out + 1] = leading_trim
    end
  end
  for _, line in ipairs(preamble) do
    out[#out + 1] = line
  end
  -- 去掉 preamble 末尾空行
  while #out > 0 and out[#out]:match("^%s*$") do
    out[#out] = nil
  end
  out[#out + 1] = ""
  out[#out + 1] = string.format("describe(\"%s\", function()", suite_name)

  if opts.reset then
    out[#out + 1] = "  local config_reset = require(\"spec.support.config_reset\")"
    out[#out + 1] = "  before_each(function() config_reset.reset_all() end)"
  end

  local mapping = {}
  for _, case_name in ipairs(test_order) do
    local fn_full_name = "_test_" .. case_name
    local test_fn = fn_by_name[fn_full_name]
    local pretty = M.naturalize_test_name(fn_full_name, suite_name)
    local skip_reason = opts.skip and opts.skip[case_name]
    if skip_reason then
      out[#out + 1] = string.format("  it(%q, function()", pretty)
      out[#out + 1] = string.format("    pending(%q)", skip_reason)
      out[#out + 1] = "  end)"
    elseif test_fn ~= nil then
      out[#out + 1] = string.format("  it(%q, function()", pretty)
      if opts.wrap_text then
        -- 简化处理：把 wrap 转成 per-test 一行（如 logger.set_test_mode(false)）
        out[#out + 1] = "    -- TODO(spec_migrate): wrap 选项需要手动审视：" .. opts.wrap_text
      end
      for _, body_line in ipairs(test_fn.body) do
        out[#out + 1] = "  " .. body_line
      end
      out[#out + 1] = "  end)"
    else
      -- 找不到对应函数（可能是 _case 间接引用，类 B），脚本不处理
      out[#out + 1] = string.format("  -- TODO(spec_migrate): missing test fn %s", fn_full_name)
    end
    mapping[#mapping + 1] = { old = case_name, new = pretty }
  end

  out[#out + 1] = "end)"

  return table.concat(out, "\n") .. "\n", mapping, opts
end

-- =============================================================================
-- baseline diff
-- =============================================================================

function M.diff(args)
  local baseline_path = "tools/refactor/baseline/behavior_tests.txt"
  local current_path = "tools/refactor/baseline/behavior_tests_current.txt"
  for i, value in ipairs(args or {}) do
    if value == "--baseline" then
      baseline_path = args[i + 1]
    elseif value == "--current" then
      current_path = args[i + 1]
    end
  end
  local baseline_text = common.read_file(baseline_path)
  if baseline_text == nil then
    error("baseline missing: " .. baseline_path)
  end
  local current_text = common.read_file(current_path)
  if current_text == nil then
    error("current missing: " .. current_path)
  end

  local function _to_set(text)
    local set = {}
    for line in text:gmatch("[^\r\n]+") do
      set[line] = true
    end
    return set
  end

  local baseline_set = _to_set(baseline_text)
  local current_set = _to_set(current_text)

  local missing, extra = {}, {}
  for k in pairs(baseline_set) do
    if current_set[k] == nil then
      missing[#missing + 1] = k
    end
  end
  for k in pairs(current_set) do
    if baseline_set[k] == nil then
      extra[#extra + 1] = k
    end
  end
  table.sort(missing)
  table.sort(extra)

  io.write(string.format("baseline=%d current=%d missing=%d extra=%d\n",
    _count(baseline_set), _count(current_set), #missing, #extra))
  if #missing > 0 then
    io.write("--- missing (in baseline, not in current) ---\n")
    for _, line in ipairs(missing) do
      io.write(line .. "\n")
    end
  end
  if #extra > 0 then
    io.write("--- extra (in current, not in baseline) ---\n")
    for _, line in ipairs(extra) do
      io.write(line .. "\n")
    end
  end
  return { missing = missing, extra = extra }
end

function _count(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

-- =============================================================================
-- CLI 入口
-- =============================================================================

local function _print_help()
  io.write([[
spec_migrate.lua — spec/ 重构期间的临时迁移脚本

Subcommands:
  plan <suite_module>          打印 suite → spec 计划，不写文件
  migrate <suite_module>       迁移单个 suite，写出对应 _spec.lua
  migrate-dir <area>           批量迁移 spec/suites/<area>/ 下全部类 A suite
  diff [--baseline P] [--current P]  对比 baseline.txt vs current.txt
  help                         显示本帮助
]])
end

function M.main(argv)
  argv = argv or {}
  local cmd = argv[1] or "help"
  if cmd == "help" or cmd == "-h" or cmd == "--help" then
    _print_help()
    return 0
  elseif cmd == "diff" then
    local rest = {}
    for i = 2, #argv do rest[#rest + 1] = argv[i] end
    M.diff(rest)
    return 0
  elseif cmd == "plan" or cmd == "migrate" or cmd == "migrate-dir" then
    io.write("subcommand " .. cmd .. " not yet implemented; will land in Step 2\n")
    return 0
  else
    io.write("unknown subcommand: " .. cmd .. "\n")
    _print_help()
    return 1
  end
end

if arg ~= nil and arg[0] and arg[0]:match("spec_migrate%.lua$") then
  os.exit(M.main(arg))
end

return M
