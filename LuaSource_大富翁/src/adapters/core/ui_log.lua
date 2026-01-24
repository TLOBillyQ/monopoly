local Log = {}

function Log.build_log_entries(entries, max_lines)
  if not entries then
    return {}
  end
  local total = #entries
  local start = math.max(1, total - max_lines)
  local out = {}
  for i = start, total do
    out[#out + 1] = entries[i]
  end
  return out
end

return Log
