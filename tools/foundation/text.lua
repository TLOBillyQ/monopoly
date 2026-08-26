-- 纯文本工具:不碰文件系统、不起子进程、不探测平台。
local text = {}

function text.bilingual(zh, en)
  return tostring(zh or "") .. " / " .. tostring(en or "")
end

-- 去首尾空白。必须落到一个单独的 return,不能写成
--   return tostring(v):gsub("^%s+",""):gsub("%s+$","")
-- ——gsub 返回 (结果, 替换次数),那样写会把计数一起吐出去,于是
-- `return trim(x)` 的函数就从"返回 1 个值"变成"返回 2 个值",
-- 把 (value) / (nil, err) 这类契约悄悄改成 (value, count)。
function text.trim(value)
  local trimmed = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed
end

-- 几乎所有 file/path 失败分支都用 "中文前缀 .. path / English prefix .. path" 这种
-- 双语后缀格式。集中到这里，单一规则;copy_tree 用 exit_code 走同一路径。
function text.bilingual_with_suffix(zh_prefix, en_prefix, suffix)
  local suffix_text = tostring(suffix)
  return text.bilingual(zh_prefix .. suffix_text, en_prefix .. suffix_text)
end

function text.split(value, delimiter)
  local parts = {}
  local source = tostring(value or "")
  if source == "" then
    return parts
  end
  local start_index = 1
  while true do
    local hit_start, hit_end = string.find(source, delimiter, start_index, true)
    if hit_start == nil then
      parts[#parts + 1] = string.sub(source, start_index)
      break
    end
    parts[#parts + 1] = string.sub(source, start_index, hit_start - 1)
    start_index = hit_end + 1
  end
  return parts
end

return text
