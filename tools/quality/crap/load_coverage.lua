-- 加载期覆盖率记录 / 回放。
--
-- 上游 crap4lua 的覆盖 hook 只在用例执行期间生效（before_case/after_case），
-- 而 resolve_suites 加载 spec 时执行的行——模块主块、函数定义行、describe 体内
-- 的加载期调用——全部发生在 hook 之外，被系统性记为未覆盖。
--
-- record() 用等价的 debug 行 hook 把这些加载期 (source, line) 命中记下来，
-- 并按事件来源分桶：主块（what == "main"）与真实函数调用。
-- replay() 在上游 hook 生效后重放：对每个 source 用其原始串作 chunkname 构造
-- 只含无副作用语句的合成 chunk 并执行，让上游按与真实加载完全一致的口径
-- 归一化、过滤并计入这些行。
--
-- 主块桶回放前先按 luac 函数跨度过滤：闭包定义会在函数的收尾 `end` 行（及函数
-- 头行）触发主块行事件，若原样回放，从未被调用的函数会凭定义期事件获得行覆盖
-- （单行函数直接 0% → 100%），进而把真实的 CRAP 违规刷成通过。落在任何内层
-- 函数跨度内的主块命中一律丢弃；跨度解析失败时丢弃该文件全部主块命中——
-- 宁可少计（回到旧盲区），不虚计函数体覆盖。

local M = {}

local function _make_recorder(getinfo)
  local function_cache = setmetatable({}, { __mode = "k" })
  local hits = { main = {}, call = {} }
  local function hook(_, line_no)
    local info = getinfo(2, "f")
    local func = info and info.func
    if func == nil then
      return
    end
    local cached = function_cache[func]
    if cached then
      cached[line_no] = true
      return
    end
    if cached == false then
      return
    end
    local source_info = getinfo(func, "S")
    local source = source_info and source_info.source
    -- 保守超集过滤：只留可能归一化到被跟踪 src/ 路径的 source；
    -- 是否真正入账由回放时的上游 hook 决定。
    if source == nil or source:find("src/", 1, true) == nil then
      function_cache[func] = false
      return
    end
    local bucket = source_info.what == "main" and hits.main or hits.call
    local lines = bucket[source]
    if lines == nil then
      lines = {}
      bucket[source] = lines
    end
    function_cache[func] = lines
    lines[line_no] = true
  end
  return hook, hits
end

-- 执行 body 并返回期间命中的 { main = {source -> {line -> true}}, call = 同构 }。
function M.record(body, opts)
  local debug_api = (opts and opts.debug_api) or debug
  local hook, hits = _make_recorder(debug_api.getinfo)
  debug_api.sethook(hook, "l")
  local ok, err = xpcall(body, debug.traceback)
  debug_api.sethook()
  if not ok then
    error(err, 0)
  end
  return hits
end

-- 用上游 analyzer（luac -p -l）解析 source 对应真实文件的内层函数跨度。
-- 解析不了（文件不存在、luac 不可用）返回 nil。
local function _inner_function_spans(source, opts)
  local ok, analyzer = pcall(require, "crap4lua.analyzer")
  if not ok then
    return nil
  end
  local path = tostring(source or ""):gsub("^@", "")
  local functions = analyzer.analyze_file(path, { luac_cmd = opts and opts.luac_cmd or nil })
  if type(functions) ~= "table" then
    return nil
  end
  local spans = {}
  for _, fn in ipairs(functions) do
    if (fn.start_line or 0) > 0 then
      spans[#spans + 1] = { start_line = fn.start_line, end_line = fn.end_line }
    end
  end
  return spans
end

local function _keep_main_lines_outside_spans(lines, spans)
  if spans == nil then
    return {}
  end
  local kept = {}
  for line_no in pairs(lines) do
    local inside = false
    for _, span in ipairs(spans) do
      if line_no >= span.start_line and line_no <= span.end_line then
        inside = true
        break
      end
    end
    if not inside then
      kept[line_no] = true
    end
  end
  return kept
end

local function _synthetic_chunk_source(lines)
  local max_line = 0
  for line_no in pairs(lines) do
    if line_no > max_line then
      max_line = line_no
    end
  end
  local parts = {}
  for line_no = 1, max_line do
    -- `_ = _` 在空沙盒环境里读写 env._（恒为 nil），只产生行事件、无任何副作用。
    parts[line_no] = lines[line_no] and "_ = _" or ""
  end
  return table.concat(parts, "\n")
end

local function _sorted_sources(hits)
  local sources = {}
  for source in pairs(hits or {}) do
    sources[#sources + 1] = source
  end
  table.sort(sources)
  return sources
end

local function _merge_lines(target, lines)
  for line_no in pairs(lines) do
    target[line_no] = true
  end
end

-- 在调用方已装好覆盖 hook 的前提下，重放 record() 的命中。
-- 调用桶原样重放；主块桶先过滤掉落在内层函数跨度内的定义期事件。
function M.replay(hits, opts)
  hits = hits or {}
  local merged = {}
  for source, lines in pairs(hits.call or {}) do
    merged[source] = {}
    _merge_lines(merged[source], lines)
  end
  for source, lines in pairs(hits.main or {}) do
    local kept = _keep_main_lines_outside_spans(lines, _inner_function_spans(source, opts))
    merged[source] = merged[source] or {}
    _merge_lines(merged[source], kept)
  end
  for _, source in ipairs(_sorted_sources(merged)) do
    local chunk = load(_synthetic_chunk_source(merged[source]), source, "t", {})
    if chunk ~= nil then
      chunk()
    end
  end
end

return M
