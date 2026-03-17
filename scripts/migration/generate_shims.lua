local common = require("scripts.migration.common")

local M = {}

local function file_exists(path)
  local file = io.open(path, "r")
  if not file then
    return false
  end
  file:close()
  return true
end

local function ensure_parent_dir(path)
  local parent = path:match("^(.*)/[^/]+$")
  if parent ~= nil and parent ~= "" then
    os.execute('mkdir -p "' .. parent .. '"')
  end
end

local function shim_text(entry)
  local lines = {}
  lines[#lines + 1] = 'local module = require("' .. entry.new_module .. '")'
  for _, alias in ipairs(entry.alias_modules or {}) do
    lines[#lines + 1] = 'package.loaded["' .. alias .. '"] = module'
  end
  lines[#lines + 1] = "return module"
  return table.concat(lines, "\n") .. "\n"
end

function M.run(args)
  local opts = common.parse_args(args)
  local planned = {}

  for _, entry in ipairs(common.iter_entries()) do
    if entry.keep_shim ~= false and file_exists(entry.new_path) then
      planned[#planned + 1] = entry
      if opts.write then
        ensure_parent_dir(entry.old_path)
        common.write_file(entry.old_path, shim_text(entry))
      end
    end
  end

  print((opts.write and "generate_shims apply" or "generate_shims dry-run") .. " entries=" .. tostring(#planned))
  for _, entry in ipairs(planned) do
    print(entry.old_path .. " -> " .. entry.new_path)
  end

  return 0
end

function M.main()
  return M.run(arg or {})
end

os.exit(M.main())
