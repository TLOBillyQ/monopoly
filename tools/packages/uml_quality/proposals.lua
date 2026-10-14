-- packages/uml_quality/proposals.lua —— uml ir 的覆盖文件合并(#99 / ADR 0070)。
--
-- 仓根 policy.edn 是 arch_policy.project_uml_policy 的生成物;上游 policy 里唯一要人手
-- 维护的 :proposals / :omit 存在入库的 docs/architecture.proposals.edn,生成时拼进投影。
-- 覆盖文件只许顶层 map + 这两个键(值为 vector),其余键报错,防止它长成第二份 policy。
-- 值按原文切片拼接,不做 EDN 语义解释——形状由上游 ir-generator 判定。
-- 纯函数:不读写文件;落盘与起上游在 cli.lua。
local M = {}

M.OVERRIDE_PATH = "docs/architecture.proposals.edn"

local _ALLOWED_KEYS = { [":proposals"] = true, [":omit"] = true }
local _CLOSE = { ["["] = "]", ["{"] = "}", ["("] = ")" }

local function _is_delimiter(c)
  return c == "" or c:match("[%s,;\"%[%]{}()]") ~= nil
end

local function _fail(text, index, message)
  local _, newlines = text:sub(1, index - 1):gsub("\n", "")
  return nil, M.OVERRIDE_PATH .. " (line " .. (newlines + 1) .. "): " .. message
end

-- 跳过空白、逗号与 ; 注释。
local function _skip(text, index)
  while true do
    local c = text:sub(index, index)
    if c ~= "" and c:match("[%s,]") then
      index = index + 1
    elseif c == ";" then
      local newline = text:find("\n", index, true)
      if newline == nil then return #text + 1 end
      index = newline + 1
    else
      return index
    end
  end
end

local _form_end

local function _collection_end(text, index, close)
  local cursor = index + 1
  while true do
    cursor = _skip(text, cursor)
    local c = text:sub(cursor, cursor)
    if c == close then return cursor end
    if c == "" then return _fail(text, index, "unterminated '" .. text:sub(index, index) .. "'") end
    local last, err = _form_end(text, cursor)
    if last == nil then return nil, err end
    cursor = last + 1
  end
end

local function _atom_end(text, index)
  local cursor = index
  while not _is_delimiter(text:sub(cursor + 1, cursor + 1)) do cursor = cursor + 1 end
  return cursor
end

-- 返回从 index 起一个完整 EDN form 的末位下标。
_form_end = function(text, index)
  local c = text:sub(index, index)
  if c == "" then return _fail(text, index, "unexpected end of file") end
  if c == '"' then
    local cursor = index + 1
    while true do
      local d = text:sub(cursor, cursor)
      if d == "" then return _fail(text, index, "unterminated string") end
      if d == "\\" then cursor = cursor + 2 elseif d == '"' then return cursor else cursor = cursor + 1 end
    end
  end
  if _CLOSE[c] then return _collection_end(text, index, _CLOSE[c]) end
  if c == "]" or c == "}" or c == ")" then return _fail(text, index, "unexpected '" .. c .. "'") end
  if c == "\\" then
    if text:sub(index + 1, index + 1) == "" then return _fail(text, index, "unexpected end of file") end
    return _atom_end(text, index + 1)
  end
  if c == "#" then
    if text:sub(index + 1, index + 1) == "{" then return _collection_end(text, index + 1, "}") end
    -- 标签字面量与 #_ 丢弃:标签本身之后还跟一个 form。
    return _form_end(text, _skip(text, _atom_end(text, index) + 1))
  end
  return _atom_end(text, index)
end

-- 覆盖文件 -> { [":proposals"] = 原文, [":omit"] = 原文 };缺失/空/纯注释视为空表。
function M.parse(text)
  local values = {}
  if text == nil then return values end
  local start = _skip(text, 1)
  if start > #text then return values end
  if text:sub(start, start) ~= "{" then return _fail(text, start, "top level must be a map {:proposals [...] :omit [...]}") end
  local cursor = start + 1
  while true do
    cursor = _skip(text, cursor)
    local c = text:sub(cursor, cursor)
    if c == "}" then break end
    if c == "" then return _fail(text, start, "unterminated '{'") end
    local key_end, err = _form_end(text, cursor)
    if key_end == nil then return nil, err end
    local key = text:sub(cursor, key_end)
    if not _ALLOWED_KEYS[key] then
      return _fail(text, cursor, "unexpected key " .. key .. "; only :proposals and :omit are allowed")
    end
    if values[key] ~= nil then return _fail(text, cursor, "duplicate key " .. key) end
    local value_start = _skip(text, key_end + 1)
    local opener = text:sub(value_start, value_start)
    if opener == "}" or opener == "" then return _fail(text, cursor, "missing value for " .. key) end
    if opener ~= "[" then return _fail(text, value_start, key .. " must be a vector [...]") end
    local value_end, value_err = _form_end(text, value_start)
    if value_end == nil then return nil, value_err end
    values[key] = text:sub(value_start, value_end)
    cursor = value_end + 1
  end
  local rest = _skip(text, cursor + 1)
  if rest <= #text then return _fail(text, rest, "unexpected content after the top-level map") end
  return values
end

local function _edn_string(value)
  return '"' .. tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- 投影 policy 文本 + 覆盖文件原文 -> 完整 policy.edn 文本;覆盖文件非法时 nil, err。
function M.merge(projected, override_text, out_path)
  local values, err = M.parse(override_text)
  if values == nil then return nil, err end
  local head = tostring(projected):match("^(.*)}%s*$")
  if head == nil then return nil, "projected uml policy is not an EDN map" end
  return table.concat({
    head,
    "\n :out " .. _edn_string(out_path),
    "\n :proposals " .. (values[":proposals"] or "[]"),
    "\n :omit " .. (values[":omit"] or "[]"),
    "}\n",
  })
end

return M
