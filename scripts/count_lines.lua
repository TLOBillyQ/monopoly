-- Count Lua lines per module. Run with: lua scripts/count_lines.lua

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

local prefix_map = {
  ["src/adapters/"] = "src/adapters",
  ["src/bootstrap/"] = "src/bootstrap",
  ["src/config/"] = "src/config",
  ["src/core/"] = "src/core",
  ["src/gameplay/"] = "src/gameplay",
  ["src/util/"] = "src/util",
  ["src/app.lua"] = "scr/app.lua",
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

local function count_lines(path)
  local f = io.open(path, "rb")
  if not f then
    return 0
  end
  local content = f:read("*a")
  f:close()
  local count = 0
  for _ in content:gmatch("\n") do
    count = count + 1
  end
  -- If file is non-empty and does not end with \n, count the last line
  if content ~= "" and content:sub(-1) ~= "\n" then
    count = count + 1
  end
  return count
end

local stats = {}
local total_lines = 0
local total_files = 0

for _, path in ipairs(git_ls_files()) do
  if is_lua(path) then
    local cat = category_for(path)
    stats[cat] = stats[cat] or { lines = 0, files = 0 }
    local lc = count_lines(path)
    stats[cat].lines = stats[cat].lines + lc
    stats[cat].files = stats[cat].files + 1
    total_lines = total_lines + lc
    total_files = total_files + 1
  end
end

local ordered = {}
for name, data in pairs(stats) do
  table.insert(ordered, { name = name, lines = data.lines, files = data.files })
end

table.sort(ordered, function(a, b)
  if a.lines == b.lines then
    return a.name < b.name
  end
  return a.lines > b.lines
end)

print(string.format("%-20s %8s %8s", "Module", "Lines", "Files"))
print(string.rep("-", 40))
for _, entry in ipairs(ordered) do
  print(string.format("%-20s %8d %8d", entry.name, entry.lines, entry.files))
end
print(string.rep("-", 40))
print(string.format("%-20s %8d %8d", "TOTAL", total_lines, total_files))
