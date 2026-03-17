local common = require("scripts.migration.common")

local M = {}

local function escape_pattern(text)
  return tostring(text):gsub("([^%w])", "%%%1")
end

local function build_replacements()
  local replacements = {}
  for _, entry in ipairs(common.iter_entries()) do
    for _, alias in ipairs(entry.alias_modules or {}) do
      if alias ~= entry.canonical_module then
        replacements[#replacements + 1] = {
          from = alias,
          to = entry.canonical_module,
        }
      end
    end
  end

  table.sort(replacements, function(left, right)
    if left.from == right.from then
      return left.to < right.to
    end
    return left.from > right.from
  end)

  return replacements
end

function M.run(args)
  local opts = common.parse_args(args)
  local replacements = build_replacements()
  local touched = {}

  for _, path in ipairs(common.list_repo_files()) do
    local text = common.read_file(path)
    if text ~= nil then
      local next_text = text
      local file_hits = 0
      for _, replacement in ipairs(replacements) do
        local escaped = escape_pattern(replacement.from)
        local rewritten, count = next_text:gsub(escaped, replacement.to)
        if count > 0 then
          file_hits = file_hits + count
          next_text = rewritten
        end
      end

      if file_hits > 0 then
        touched[#touched + 1] = { path = path, replacements = file_hits }
        if opts.write then
          common.write_file(path, next_text)
        end
      end
    end
  end

  print((opts.write and "rewrite_modules apply" or "rewrite_modules dry-run") .. " entries=" .. tostring(#touched))
  for _, entry in ipairs(touched) do
    print(string.format("%4d  %s", entry.replacements, entry.path))
  end

  return 0
end

function M.main()
  return M.run(arg or {})
end

if ... == "scripts.migration.rewrite_modules" then
  return M
end

os.exit(M.main())
