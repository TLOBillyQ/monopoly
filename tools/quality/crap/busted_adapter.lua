local common = require("shared.lib.common")

local M = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/crap/busted_adapter.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality/crap"
end

local function _repo_root()
  return common.resolve_path(_module_dir(), "../../..")
end

local function _is_contract_spec(path)
  local normalized = _normalize_path(path)
  local name = normalized:match("([^/]+)$") or ""
  if not name:match("_spec%.lua$") then
    return false
  end
  if name:sub(1, 1) == "_" then
    return false
  end
  return true
end

local function _to_repo_relative(path)
  local normalized = _normalize_path(path)
  local root = _normalize_path(_repo_root()):gsub("/+$", "")
  local prefix = root .. "/"
  if normalized:sub(1, #prefix) == prefix then
    return normalized:sub(#prefix + 1)
  end
  return normalized
end

function M.discover_specs(lane)
  local lane_name = tostring(lane or "")
  if lane_name == "" then
    lane_name = "contract"
  end
  local spec_root = common.join_path(_repo_root(), "spec/" .. lane_name)
  if common.path_exists(spec_root) ~= true then
    return {}
  end
  local files, err = common.collect_lua_files(spec_root)
  if files == nil then
    error(err)
  end
  local specs = {}
  for _, file in ipairs(files) do
    if _is_contract_spec(file) then
      specs[#specs + 1] = _to_repo_relative(file)
    end
  end
  table.sort(specs)
  return specs
end

function M.resolve_suites(lane)
  local specs = M.discover_specs(lane)
  local tests = {}
  for _, spec_file in ipairs(specs) do
    tests[#tests + 1] = {
      name = spec_file,
      run = function() end,
    }
  end
  return {
    {
      name = tostring(lane or "contract"),
      tests = tests,
    },
  }, lane
end

function M.run(suites, opts)
  local run_opts = opts or {}
  local failures = {}
  local total = 0
  for _, suite in ipairs(suites or {}) do
    for _, test in ipairs(suite.tests or {}) do
      total = total + 1
      if type(run_opts.before_case) == "function" then
        run_opts.before_case(suite, test)
      end
      local ok, run_err = pcall(test.run)
      if type(run_opts.after_case) == "function" then
        run_opts.after_case(suite, test)
      end
      if not ok then
        failures[#failures + 1] = {
          suite = suite.name,
          name = test.name,
          message = tostring(run_err),
        }
      end
    end
  end
  return {
    total = total,
    failed = #failures > 0,
    failures = failures,
  }
end

M.debug_api = debug

M.resolve_lane_suites = M.resolve_suites
M.run_all = M.run

return M
