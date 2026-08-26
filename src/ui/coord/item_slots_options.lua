local M = {}

local _option_id_set = {}
local _cached_option_choice_ref

local function _option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

local function _clear_option_id_set()
  for k in pairs(_option_id_set) do
    _option_id_set[k] = nil
  end
end

local function _fill_option_id_set(options)
  _clear_option_id_set()
  for _, option in ipairs(options) do
    local option_id = _option_id(option)
    if option_id ~= nil then
      _option_id_set[tostring(option_id)] = true
    end
  end
end

function M.build(choice)
  if not (choice and type(choice.options) == "table") then
    -- 无效 choice(回合推进后 choice 清空/缺 options):清空集合并作废旧引用,
    -- 否则上一条 choice 的可选项永久残留(高亮错挂,真机实证 #340);
    -- 引用不置 nil 的话,同一 options 表复用会被「引用相同」短路跳过重建。
    _clear_option_id_set()
    _cached_option_choice_ref = nil
    return _option_id_set
  end
  if choice.options == _cached_option_choice_ref then
    return _option_id_set
  end
  _cached_option_choice_ref = choice.options
  _fill_option_id_set(choice.options)
  return _option_id_set
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=9b10cf541a22911c
scope.0.id=chunk:src/ui/coord/item_slots_options.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=47
scope.0.semanticHash=90c1e7c562813fa2
scope.1.id=function:_option_id
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=90c051feb9cf542f
scope.2.id=function:_clear_option_id_set
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=17
scope.2.semanticHash=c52367dcd62d5b7e
scope.3.id=function:_fill_option_id_set
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=27
scope.3.semanticHash=8cad3ee5a6bae397
scope.4.id=function:M.build
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=44
scope.4.semanticHash=87dc62a89478679a
]]
