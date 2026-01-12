-- Strips Lua comments from .lua files.
-- Removes single-line comments (--) and long comments (--[[ ]], --[=[ ]=], ...).
-- Preserves strings and long strings.
--
-- Usage:
--   lua scripts/strip_lua_comments.lua --check src
--   lua scripts/strip_lua_comments.lua --write src
--
-- Exit codes:
--   0 success
--   2 usage error
--   3 processing error

local function fprintf(fmt, ...)
  io.stderr:write(string.format(fmt, ...))
end

local function read_file(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, content)
  local f, err = io.open(path, "wb")
  if not f then return nil, err end
  f:write(content)
  f:close()
  return true
end

local function is_ident_char_byte(b)
  return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95
end

local function match_long_bracket(src, i)
  -- Matches [=*[  starting at i; returns eq_count, open_len
  if src:byte(i) ~= 91 then return nil end -- '['
  local j = i + 1
  local eq = 0
  while src:byte(j) == 61 do -- '='
    eq = eq + 1
    j = j + 1
  end
  if src:byte(j) ~= 91 then return nil end -- '['
  return eq, (j - i + 1)
end

local function find_long_bracket_close(src, start_i, eq)
  -- Finds ]=*=] starting from start_i; returns close_start, close_len or nil
  local n = #src
  local i = start_i
  while i <= n do
    if src:byte(i) == 93 then -- ']'
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

local function strip_comments(src)
  local n = #src
  local out = {}
  local i = 1

  local function push(s)
    out[#out + 1] = s
  end

  while i <= n do
    local b = src:byte(i)

    -- Short strings
    if b == 34 or b == 39 then -- '"' or "'"
      local quote = b
      local j = i
      push(src:sub(i, i))
      i = i + 1
      while i <= n do
        local cb = src:byte(i)
        push(src:sub(i, i))
        if cb == 92 then -- backslash escape
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
    elseif b == 91 then -- '['
      local eq, open_len = match_long_bracket(src, i)
      if eq then
        local open = src:sub(i, i + open_len - 1)
        push(open)
        i = i + open_len
        local close_start, close_len = find_long_bracket_close(src, i, eq)
        if not close_start then
          -- Unterminated; just emit rest
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
    elseif b == 45 and src:byte(i + 1) == 45 then -- "--"
      -- Long comment?
      local next_i = i + 2
      local eq, open_len = match_long_bracket(src, next_i)
      if eq then
        -- Consume opener "--[=*["
        i = next_i + open_len
        local close_start, close_len = find_long_bracket_close(src, i, eq)
        if not close_start then
          -- Unterminated comment: drop rest
          break
        end
        -- Preserve newlines inside the removed block comment to keep line structure.
        local body = src:sub(i, close_start - 1)
        local _, newlines = body:gsub("\n", "\n")
        if newlines > 0 then push(string.rep("\n", newlines)) end
        i = close_start + close_len
      else
        -- Single-line comment: drop until newline, but keep the newline
        i = i + 2
        while i <= n do
          local cb = src:byte(i)
          if cb == 10 then -- '\n'
            push("\n")
            i = i + 1
            break
          elseif cb == 13 then -- '\r' (CRLF)
            -- Preserve CRLF as a single newline
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

local function list_lua_files(root)
  -- Minimal directory walk using `find` via io.popen (portable enough for macOS/Linux).
  local cmd = string.format("find %q -type f -name '*.lua'", root)
  local p = io.popen(cmd)
  if not p then return nil, "failed to run find" end
  local files = {}
  for line in p:lines() do
    files[#files + 1] = line
  end
  p:close()
  return files
end

local function usage()
  fprintf("Usage: lua scripts/strip_lua_comments.lua (--check|--write) <dir>\n")
end

local mode = arg[1]
local root = arg[2]
if mode ~= "--check" and mode ~= "--write" then
  usage()
  os.exit(2)
end
if not root or root == "" then
  usage()
  os.exit(2)
end

local files, lerr = list_lua_files(root)
if not files then
  fprintf("Error: %s\n", lerr)
  os.exit(3)
end

local changed = 0
local processed = 0
for _, path in ipairs(files) do
  local content, err = read_file(path)
  if not content then
    fprintf("Error reading %s: %s\n", path, err)
    os.exit(3)
  end
  local stripped = strip_comments(content)
  processed = processed + 1
  if stripped ~= content then
    changed = changed + 1
    if mode == "--write" then
      local ok, werr = write_file(path, stripped)
      if not ok then
        fprintf("Error writing %s: %s\n", path, werr)
        os.exit(3)
      end
    end
  end
end

print(string.format("Processed %d file(s), %d would change%s.", processed, changed, mode == "--write" and " (written)" or ""))
