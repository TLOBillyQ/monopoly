package.path = package.path .. ";./tests/?.lua"

local migration_pairs = require("support.migration_pairs")

local M = {}
local retired_config_roots = {
  "Config/",
  "src/core/config/",
}

local function is_forwarding_shim(text, new_module)
  if text == nil then
    return false
  end

  local normalized = text
  normalized = normalized:gsub("%-%-[^\n]*", "")
  normalized = normalized:gsub("%s+", " ")
  normalized = normalized:match("^%s*(.-)%s*$") or ""

  return normalized == 'return require("' .. new_module .. '")'
    or normalized == "return require('" .. new_module .. "')"
end

local function contains_alias_registration(text, alias_modules)
  if text == nil then
    return false
  end

  local alias_hits = 0
  for _, alias in ipairs(alias_modules or {}) do
    local quoted_double = 'package.loaded["' .. alias .. '"]'
    local quoted_single = "package.loaded['" .. alias .. "']"
    if text:find(quoted_double, 1, true) or text:find(quoted_single, 1, true) then
      alias_hits = alias_hits + 1
    end
  end

  return alias_hits >= 2
end

local function is_aliasing_forwarding_shim(text, new_module, alias_modules)
  if text == nil then
    return false
  end

  if not text:find('require("' .. new_module .. '")', 1, true)
    and not text:find("require('" .. new_module .. "')", 1, true)
  then
    return false
  end

  if not text:find("return module", 1, true) then
    return false
  end

  return contains_alias_registration(text, alias_modules)
end

local function is_retired_config_pair(pair)
  local old_path = pair and pair.old_path or ""
  for _, root in ipairs(retired_config_roots) do
    if old_path:sub(1, #root) == root then
      return true
    end
  end
  return false
end

local function needs_alias_validation(pair)
  return pair.init_kind ~= "forward_only" or #(pair.alias_modules or {}) > 2
end

function M.run()
  for _, pair in ipairs(migration_pairs.iter_pairs()) do
    if is_retired_config_pair(pair) then
      return {
        ok = false,
        error = "migration_shim_rules: retired config shim path must not appear in migration pairs: " .. pair.old_path,
      }
    end

    if migration_pairs.file_exists(pair.old_path) and migration_pairs.file_exists(pair.new_path) then
      local text = migration_pairs.read_file(pair.old_path)
      if needs_alias_validation(pair) then
        if not is_aliasing_forwarding_shim(text, pair.new_module, pair.alias_modules) then
          return {
            ok = false,
            error = "migration_shim_rules: " .. pair.old_path
              .. " must forward to " .. pair.new_module
              .. " and register alias package.loaded keys",
          }
        end
      elseif not is_forwarding_shim(text, pair.new_module) then
        return {
          ok = false,
          error = "migration_shim_rules: " .. pair.old_path
            .. " must be a pure forwarding shim to " .. pair.new_module,
        }
      end
    end
  end

  return { ok = true, message = "migration_shim_rules ok" }
end

function M.main()
  local result = M.run()
  if not result.ok then
    io.stderr:write(result.error, "\n")
    os.exit(1)
  end
  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
