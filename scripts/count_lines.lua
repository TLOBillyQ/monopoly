-- Count Lua lines per module.
-- Reports both total physical lines and effective code lines (non-blank after stripping comments).
-- Run with: lua scripts/count_lines.lua

local function git_ls_files()
  local p = io.popen("git ls-files")
  if not p then
    return {}
  end
  local out = p:read("*a")
  p:close()
  local files = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    table.insert(files, line)
  end
  return files
end

local function is_lua(path)
  return path:sub(-4) == ".lua"
end

local function match_long_bracket(src, i)
  -- Matches [=*[ starting at i; returns eq_count, open_len
  if src:byte(i) ~= 91 then
    return nil
  end
  local j = i + 1
  local eq = 0
  while src:byte(j) == 61 do
    eq = eq + 1
    j = j + 1
  end
  if src:byte(j) ~= 91 then
    return nil
  end
  return eq, (j - i + 1)
end

local function find_long_bracket_close(src, start_i, eq)
  -- Finds ]=*=] starting from start_i; returns close_start, close_len or nil
  local n = #src
  local i = start_i
  while i <= n do
    if src:byte(i) == 93 then
      local j = i + 1
      local k = 0
      while k < eq and src:byte(j) == 61 do
        k = k + 1
        j = j + 1
      end
      if k == eq and src:byte(j) == 93 then
        return i, (j - i + 1)
      end
    end
    i = i + 1
  end
  return nil
end

local function strip_lua_comments(src)
  -- Removes Lua comments while preserving strings/long strings.
  local n = #src
  local out = {}
  local i = 1.0

  local function push(s)
    out[#out + 1] = s
  end

  while i <= n do
    local b = src:byte(i)

    -- Short strings
    if b == 34 or b == 39 then
      local quote = b
      push(src:sub(i, i))
      i = i + 1
      while i <= n do
        local cb = src:byte(i)
        push(src:sub(i, i))
        if cb == 92 then
          i = i + 1
          if i <= n then
            push(src:sub(i, i))
          end
        elseif cb == quote then
          i = i + 1
          break
        end
        i = i + 1
      end

    -- Long strings: [=*[ ... ]=*=]
    elseif b == 91 then
      local eq, open_len = match_long_bracket(src, i)
      if eq then
        push(src:sub(i, i + open_len - 1))
        i = i + open_len
        local close_start, close_len = find_long_bracket_close(src, i, eq)
        if not close_start then
          push(src:sub(i))
          break
        end
        push(src:sub(i, close_start + close_len - 1))
        i = close_start + close_len
      else
        push(src:sub(i, i))
        i = i + 1
      end

    -- Comments: --...
    elseif b == 45 and src:byte(i + 1) == 45 then
      local next_i = i + 2
      local eq, open_len = match_long_bracket(src, next_i)
      if eq then
        i = next_i + open_len
        local close_start, close_len = find_long_bracket_close(src, i, eq)
        if not close_start then
          break
        end
        local body = src:sub(i, close_start - 1)
        local _, newlines = body:gsub("\n", "\n")
        if newlines > 0 then
          push(string.rep("\n", newlines))
        end
        i = close_start + close_len
      else
        i = i + 2
        while i <= n do
          local cb = src:byte(i)
          if cb == 10 then
            push("\n")
            i = i + 1
            break
          elseif cb == 13 then
            if src:byte(i + 1) == 10 then
              push("\r\n")
              i = i + 2
            else
              push("\n")
              i = i + 1
            end
            break
          else
            i = i + 1
          end
        end
      end

    else
      push(src:sub(i, i))
      i = i + 1
    end
  end

  return table.concat(out)
end

local prefix_map = {
  ["src/adapters/"] = "src/adapters",
  ["src/bootstrap/"] = "src/bootstrap",
  ["src/config/"] = "src/config",
  ["src/core/"] = "src/core",
  ["src/gameplay/"] = "src/gameplay",
  ["src/util/"] = "src/util",
  ["src/app.lua"] = "src/app.lua",
  ["main.lua"] = "main.lua",
}

local function category_for(path)
  for prefix, name in pairs(prefix_map) do
    if path:sub(1, #prefix) == prefix then
      return name
    end
  end
  return "other"
end

local function count_total_lines(content)
  local count = 0
  for _ in (content or ""):gmatch("\n") do
    count = count + 1
  end
  if content ~= "" and content:sub(-1) ~= "\n" then
    count = count + 1
  end
  return count
end

local function count_effective_code_lines(content)
  local stripped = strip_lua_comments(content or "")
  local count = 0
  -- Count non-blank lines after stripping comments
  for line in (stripped .. "\n"):gmatch("(.-)\n") do
    if line:match("%S") then
      count = count + 1
    end
  end
  return count
end

local function count_file(path)
  local f = io.open(path, "rb")
  if not f then
    return { total = 0, code = 0 }
  end
  local content = f:read("*a")
  f:close()
  return {
    total = count_total_lines(content),
    code = count_effective_code_lines(content),
  }
end

local stats = {}
local total_lines = 0
local total_code_lines = 0
local total_files = 0

for _, path in ipairs(git_ls_files()) do
  if is_lua(path) then
    local cat = category_for(path)
    stats[cat] = stats[cat] or { lines = 0, code = 0, files = 0 }
    local c = count_file(path)
    stats[cat].lines = stats[cat].lines + c.total
    stats[cat].code = stats[cat].code + c.code
    stats[cat].files = stats[cat].files + 1
    total_lines = total_lines + c.total
    total_code_lines = total_code_lines + c.code
    total_files = total_files + 1
  end
end

local ordered = {}
for name, data in pairs(stats) do
  table.insert(ordered, { name = name, lines = data.lines, code = data.code, files = data.files })
end

table.sort(ordered, function(a, b)
  if a.code == b.code then
    return a.name < b.name
  end
  return a.code > b.code
end)

print(string.format("%-20s %10s %10s %8s", "Module", "Code", "Total", "Files"))
print(string.rep("-", 40))
for _, entry in ipairs(ordered) do
  print(string.format("%-20s %10d %10d %8d", entry.name, entry.code, entry.lines, entry.files))
end
print(string.rep("-", 40))
print(string.format("%-20s %10d %10d %8d", "TOTAL", total_code_lines, total_lines, total_files))
