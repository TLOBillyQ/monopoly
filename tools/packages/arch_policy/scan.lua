-- packages/arch_policy.scan —— policy 的模块级扫描面(#92)。
--
-- 门禁自己读源码,不再经外部 rock 的分析器:`source_roots` 下的每个 `.lua`
-- 是一个模块,模块 id 与旧 arch_view 口径一致(项目根相对路径,`/`→`.`,
-- 去掉结尾 `.init`),`require` 名按同口径折叠 `.init` 后命中模块 id 即一条内部依赖边,否则是外部
-- 依赖(外部依赖不进门禁图,与旧工具同口径)。
--
-- 注释与字符串处理与 uml-viewer 的 LuaGraph 同源:行注释、长注释、长括号串
-- 整段抹掉(保留换行),引号串原样保留但记为「洞」,关键词落在洞里就不算
-- require —— 于是 `-- require("x")` 与 `local s = "require(\"x\")"` 都不会
-- 造出假边。
local proc_lib = require("foundation.proc")
local fs_lib = require("foundation.fs")
local env_lib = require("foundation.env")
local path_lib = require("foundation.path")

local M = {}

local function _blank(text)
  return (tostring(text):gsub("[^\r\n]", " "))
end

local function _long_bracket_eqs(text, index)
  return text:match("^%[(=*)%[", index)
end

local function _mask(source)
  local out = {}
  local holes = {}
  local index = 1
  local length = #source
  while index <= length do
    local char = source:sub(index, index)
    local next_char = source:sub(index + 1, index + 1)
    if char == "-" and next_char == "-" then
      local eqs = _long_bracket_eqs(source, index + 2)
      local stop
      if eqs ~= nil then
        local closer = "]" .. eqs .. "]"
        local found = source:find(closer, index + 4 + #eqs, true)
        stop = found and (found + #closer - 1) or length
      else
        local newline = source:find("\n", index, true)
        stop = newline and (newline - 1) or length
      end
      out[#out + 1] = _blank(source:sub(index, stop))
      index = stop + 1
    elseif char == "[" and _long_bracket_eqs(source, index) ~= nil then
      local eqs = _long_bracket_eqs(source, index)
      local closer = "]" .. eqs .. "]"
      local found = source:find(closer, index + 2 + #eqs, true)
      local stop = found and (found + #closer - 1) or length
      out[#out + 1] = _blank(source:sub(index, stop))
      index = stop + 1
    elseif char == "\"" or char == "'" then
      local cursor = index + 1
      local closed = false
      while cursor <= length do
        local current = source:sub(cursor, cursor)
        if current == "\\" then
          cursor = cursor + 2
        elseif current == char then
          closed = true
          break
        else
          cursor = cursor + 1
        end
      end
      local stop = closed and cursor or length
      out[#out + 1] = source:sub(index, stop)
      holes[#holes + 1] = { index + 1, stop - 1 }
      index = stop + 1
    else
      out[#out + 1] = char
      index = index + 1
    end
  end
  return table.concat(out), holes
end

local function _in_hole(holes, position)
  for _, hole in ipairs(holes) do
    if position >= hole[1] and position <= hole[2] then
      return true
    end
  end
  return false
end

local function _identifier_char(char)
  return char ~= nil and char ~= "" and char:match("[%w_]") ~= nil
end

-- 关键词左侧的字符:`require` 作为字段名(`obj.require`)或方法名(`a:require`)
-- 出现时不算指令,与 uml-viewer 的 keyword-at? 同口径。
local function _keyword_boundary_char(char)
  return char == "." or char == ":"
end

local function _lookahead(text, index)
  while index <= #text and (text:sub(index, index) == " " or text:sub(index, index) == "\t") do
    index = index + 1
  end
  return index
end

-- `require` 实参名字:跳过空白与可选括号,取引号串开头的 `[A-Za-z_][%w_.]*`。
-- 与 uml-viewer 的 require-arg/quoted-name 同口径(`require("1bad")`、
-- `require(name)` 都不算;下划线是名字的一部分,`src.app.event_bridge` 必须
-- 完整取到,截断成 `src.app.event` 会凭空造出一条指向不存在模块的假边)。
local function _require_argument(text, index)
  local cursor = _lookahead(text, index)
  if text:sub(cursor, cursor) == "(" then
    cursor = _lookahead(text, cursor + 1)
  end
  local quote = text:sub(cursor, cursor)
  if quote ~= "\"" and quote ~= "'" then
    return nil
  end
  return text:match("^[A-Za-z_][%w_.]*", cursor + 1)
end

function M.requires(source)
  local text, holes = _mask(source)
  local names = {}
  local seen = {}
  local from = 1
  while true do
    local start_index, end_index = text:find("require", from, true)
    if start_index == nil then
      break
    end
    from = end_index + 1
    local before = start_index > 1 and text:sub(start_index - 1, start_index - 1) or nil
    local after = text:sub(end_index + 1, end_index + 1)
    if not _in_hole(holes, start_index)
      and not _identifier_char(before)
      and not _keyword_boundary_char(before)
      and not _identifier_char(after) then
      local name = _require_argument(text, end_index + 1)
      if name ~= nil and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

function M.module_id(relative_path)
  return (tostring(relative_path):gsub("%.lua$", ""):gsub("/", "."):gsub("%.init$", ""))
end

local function _relative(project_root, path)
  local root = path_lib.normalize_path(project_root):gsub("/+$", "")
  local full = path_lib.normalize_path(path)
  if root ~= "" and full:sub(1, #root + 1) == root .. "/" then
    return full:sub(#root + 2)
  end
  return full
end

-- 扫描 `policy.source_roots` 下的全部模块,返回门禁图。`graph.external` 记录
-- 未被任何模块 id 命中的 require 名(诊断用,门禁不判定)。
function M.graph(project_root, policy)
  -- 文件发现给的是绝对路径,先把项目根解成绝对路径,模块 id 才与 cwd 形态无关。
  local root = path_lib.resolve_path(env_lib.current_dir(), project_root or ".")
  local files = {}
  for _, source_root in ipairs(policy.source_roots or {}) do
    local root_path = path_lib.join_path(root, source_root)
    local collected, err = proc_lib.collect_files(root_path, ".lua")
    if collected == nil then
      return nil, err
    end
    for _, path in ipairs(collected) do
      files[#files + 1] = path
    end
  end
  table.sort(files)

  local modules = {}
  local requires_by_module = {}
  for _, path in ipairs(files) do
    local module_id = M.module_id(_relative(root, path))
    if modules[module_id] == nil then
      modules[module_id] = true
      local source = fs_lib.read_file(path)
      if source == nil then
        return nil, "cannot read module source: " .. tostring(path)
      end
      requires_by_module[module_id] = M.requires(source)
    end
  end

  local module_ids = {}
  for module_id in pairs(modules) do
    module_ids[#module_ids + 1] = module_id
  end
  table.sort(module_ids)

  local edges = {}
  local external = {}
  local seen_external = {}
  for _, module_id in ipairs(module_ids) do
    local seen_targets = {}
    for _, name in ipairs(requires_by_module[module_id]) do
      -- `require("src.x.init")` 与 `require("src.x")` 落到同一文件:require 名按
      -- 模块 id 同口径折叠 `.init`,否则这条边掉进 external 桶、门禁漏判。
      local required = name:gsub("%.init$", "")
      if modules[required] ~= nil then
        if required ~= module_id and not seen_targets[required] then
          seen_targets[required] = true
          edges[#edges + 1] = { from = module_id, to = required }
        end
      elseif not seen_external[required] then
        seen_external[required] = true
        external[#external + 1] = required
      end
    end
  end
  table.sort(edges, function(a, b)
    if a.from ~= b.from then return a.from < b.from end
    return a.to < b.to
  end)
  table.sort(external)

  return { modules = module_ids, edges = edges, external = external }
end

return M
